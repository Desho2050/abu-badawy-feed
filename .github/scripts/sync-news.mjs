#!/usr/bin/env node
/*
 * مزامن الأخبار: يجلب خلاصات RSS عربية رسمية (ويستقصي NewsAPI إن وُجد مفتاحه)،
 * ويجلب أخبار محافظة كفر الشيخ من بوابتها الرسمية، ويكتب العناصر في جدول items —
 * وهي الصفوف نفسها التي تحررها اللوحة، ويولّد منها publish.mjs ملفات
 * data/sections/world_news.json و sports.json و local_news.json.
 *
 *   node .github/scripts/sync-news.mjs                      # كل الأقسام الثلاثة
 *   node .github/scripts/sync-news.mjs --dry-run            # يطبع ما سيُكتب، بلا كتابة
 *   node .github/scripts/sync-news.mjs --section=sports
 *   node .github/scripts/sync-news.mjs --section=local_news # المحلّي وحده (خلاصات+بوابة)
 *   node .github/scripts/sync-news.mjs --no-newsapi         # الخلاصات والبوابة وحدهما
 *
 * لا يكتب هذا السكريبت الملفات مباشرة، مثل sync-prices.mjs: يبقى مصدر التعديل
 * واحدًا (القاعدة)، فترى اللوحة الأخبار نفسها وتثبّتها أو تؤرشفها، ولا يتصارع
 * ريبو وقاعدة على كتابة JSON. وبينهما publish.yml كل خمس دقائق، فالبطاقة تصل
 * التطبيق بعد حتى خمس دقائق من آخر جولة جلب.
 *
 * ملكية العناصر: ما يكتبه هذا السكريبت يبدأ الslug عنده بـ rss-، والعناصر الأخرى
 * يدوية فلا يمسّها. وللمدراء تحكّم يبقى بعد كل جولة: التثبيت والعاجلة لا يرسلهما
 * السكريبت عند التحديث، وحالة archived تعني «لا تُحدّث هذا الخبر أبدًا».
 *
 * الصور: إن غابت عن التغذية (الجزيرة والرياضية مثلًا) يُجلب og:image من صفحة الخبر
 * ويخزَّن في link_previews — الجدول الذي يستخدمه الناشر أصلًا، فلا يُجلب رابط مرتين.
 *
 * سياسة الجلب: لا استخراج من صفحات الوكالات ولا من الشبكات الاجتماعية. المصادر كلها
 * واجهات مخصّصة للاستهلاك الآلي: تغذيات RSS تنشرها المواقع لأنفسها، وNewsAPI واجهة
 * رسمية بمفتاح، وبوابة المحافظة الرسمية robots.txt عندها بلا أي منع. ولا يُنقل متن
 * الخبر كاملًا: بطاقة بعنوان وملخّص قصير واسم مصدر ورابط «افتح المصدر».
 *
 * يعمل بلا اعتماديات على Node 20. المفاتيح من أسرار GitHub Actions.
 */

import { createHash } from 'node:crypto';

/* مثل publish.mjs: مسافة أو رمز خفي في السرّ يفسد كل طلب. */
const squeeze = (value) => String(value ?? '').replace(/[\s\p{Cc}\p{Cf}]/gu, '');

const RAW_URL = squeeze(process.env.SUPABASE_URL);
const SUPABASE_URL = RAW_URL ? new URL(RAW_URL).origin : '';
const SERVICE_KEY = squeeze(process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY);
const NEWS_API_KEY = squeeze(process.env.NEWS_API_KEY);

const ARGS = process.argv.slice(2);
const DRY = ARGS.includes('--dry-run');
const SKIP_NEWSAPI = ARGS.includes('--no-newsapi');
/* نافذة NewsAPI تسقط إن جاء الدور متأخرًا عن أول الساعة (جدولة هذا المستودع متأخرة
   فعلًا)، فالتشغيل اليدوي وحده يقدر يتجاوزها — أما الجدول فلا يتجاوزها. */
const FORCE_NEWSAPI = ARGS.includes('--force-newsapi');
const WHICH = (ARGS.find((arg) => arg.startsWith('--section=')) || '--section=both').split('=')[1];
const ALL_SECTIONS = ['world_news', 'sports', 'local_news'];
const SECTIONS = WHICH === 'both' ? [...ALL_SECTIONS] : [WHICH];
const WANTS_LOCAL = SECTIONS.includes('local_news');

const UA = 'AbuBadawyVillageApp/1.0 (content sync; GitHub Desho2050)';
const FEED_TIMEOUT = 20000;
const PAGE_TIMEOUT = 10000;
const PER_FEED = 25;
const PER_SECTION = 40;
const PER_SOURCE = 12;
/* الناشر ينشر 80 عنصرًا لكل قسم (MAX_ITEMS) بترتيب sort_order ثم التاريخ، والعناصر
   اليدوية sort_order فيها أكبر فتسبق دائمًا — فالسقف هنا يترك لها متنفسًا. */
const KEEP_PER_SECTION = 60;
const MAX_AGE_HOURS = 96;
const OG_LIMIT = 12;

/* خلاصات عربية رسمية، محققة الفتح في 2026-10-04 (كلها 200 وعنصرها مطلق https).
   «سكاي نيوز» و«الجزيرة» تخلطان الرياضة بالعالم، فيُحوَّل ما مساره رياضي إلى قسم الرياضة. */
const FEEDS = [
  { section: 'world_news', name: 'بي بي سي عربي', url: 'https://feeds.bbci.co.uk/arabic/rss.xml' },
  { section: 'world_news', name: 'فرانس 24', url: 'https://www.france24.com/ar/rss' },
  { section: 'world_news', name: 'سكاي نيوز عربية', url: 'https://www.skynewsarabia.com/rss.xml' },
  { section: 'world_news', name: 'الجزيرة نت', url: 'https://www.aljazeera.net/feed' },
  { section: 'world_news', name: 'سبوتنيك عربي', url: 'https://arabic.sputniknews.com/export/rss2/archive/index.xml' },
  /* هاتان تزوّدان فلتر المحافظة: تغطيتهما لمصر أوفر من خلاصات العالم وحدها. */
  { section: 'world_news', name: 'سي إن إن عربي', url: 'https://arabic.cnn.com/rss' },
  { section: 'world_news', name: 'روسيا اليوم عربي', url: 'https://arabic.rt.com/rss/' },
  { section: 'sports', name: 'الرياضية', url: 'https://www.arriyadiyah.com/rss' }
];

const ALL_SPORT_HOSTS = new Set(['www.arriyadiyah.com', 'arriyadiyah.com']);

/* ── أخبار المحافظة: كلماتها ومصادرها ─────────────────────────────────────── */

/* البوابة الرسمية لمحافظة كفر الشيخ: صفحة «أخبار المحافظة» قائمةٌ ثابتة البنية
   (post-card / card-title / card-excerpt / meta-date) والوصول إليها مسموح في
   robots.txt («Disallow:» فارغة). صفحتان لكل جولة = 18 بطاقة، فلا حمل على الموقع.
   عمر العنصر هنا أطول من الخلاصات: البوابة تنشر على فترات، والإعلان الرسمي عن
   قرار أو مشروع يبقى مفيدًا أسابيع، بخبر الوكالة الذي يخلق بعد يوم. */
const OFFICIAL_LOCAL = {
  name: 'البوابة الرسمية لمحافظة كفر الشيخ',
  url: 'https://kfs.gov.eg/posts?category=akhbar-almhafth',
  pages: 2,
  maxAgeHours: 24 * 180,
  perPage: 12
};

/* الكلمات: ما لا يشتبه مع كلام آخر قويّ وحده، وما يحتاج قرينة مصرية بجانبه.
   «فوه» مثلًا داخل «فوهة»، و«بيلا» داخل «بيلاطس» أو اسم إيطالي، و«الروضة» روضة
   أطفال وروضة غراء — فلا تُقبل إلا مع «مصر/محافظة/كفر/دسوق/…». */
const LOCAL_STRONG = [
  'كفر الشيخ', 'كفرالشيخ', 'محافظة كفر', 'دسوق', 'مطوبس', 'الحامول',
  'قلين', 'بلطيم', 'سيدي سالم', 'سيدي غازي', 'البرلس'
];
const LOCAL_WEAK = ['فوه', 'بيلا', 'الروضة', 'البدريم', 'المثنى', 'شليمة', 'مرشد', 'القني'];
const LOCAL_CONTEXT = ['مصر', 'محافظة', 'محافظ', 'كفر', 'دلتا', 'دسوق', 'بلطيم', 'الحامول', 'مطوبس', 'قلين'];
const LOCAL_QUERY = '"كفر الشيخ" OR "كفرالشيخ" OR دسوق OR بلطيم OR مطوبس OR الحامول OR "سيدي سالم" OR "سيدي غازي" OR البرلس';

/* فهرس GDELT (api.gdeltproject.org): واجهة مفتوحة مخصّصة للسؤال الآلي، حدّها المعلن
   «طلب كل خمس ثوان» ودوريتنا أبطأ من ذلك بكثير، وتُرجع العنوان والمصدر والرابط بلا
   متن الخبر — فلا نسخة عن مقال ولا صورة من أرشيفه. فائدتها هنا التغطية: خلاصات
   الوكالات لا تذكر المحافظة إلا نادرًا، وGDELT يفهرس صحف المحافظات المصرية نفسها.
   الأسماء المفردة تُترك بلا اقتطاس لأن GDELT يرفض العبارة القصيرة المقتبَسة. */
const GDELT_LOCAL = {
  name: 'فهرس GDELT (كفر الشيخ)',
  feeder: 'GDELT',
  query: '(كفرالشيخ OR دسوق OR بلطيم OR مطوبس OR الحامول OR قلين OR البرلس OR ' +
    '"كفر الشيخ" OR "سيدي سالم" OR "سيدي غازي") sourcelang:ara',
  timespan: '3d',
  maxAgeHours: 24 * 3,
  maxRecords: 50
};

const NEWSAPI_SOURCES = [
  { section: 'world_news', category: 'general', name: 'NewsAPI (عالمي)' },
  { section: 'sports', category: 'sports', name: 'NewsAPI (رياضة)' },
  /* بحث المحافظة على الواجهة الرسمية نفسها، بكلمات كفر الشيخ. دورته أبطأ (كل ست ساعات)
     لأن الحصة المجانية 100 طلب/يوم، وللخطة المجانية تأخير أربع وعشرين ساعة عن النشر
     — فسؤالها كل ربع ساعة لا يأتي بجديد ويحرق الحصة. */
  { section: 'local_news', query: LOCAL_QUERY, name: 'NewsAPI (كفر الشيخ)', everyHours: 6 }
];

const NOW = Date.now();

/* ── أدوات النص ───────────────────────────────────────────────────────────── */

const ENTITIES = {
  amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', hellip: '…',
  mdash: '—', ndash: '–', rsquo: '’', lsquo: '‘', ldquo: '“', rdquo: '”',
  copy: '©', reg: '®', trade: '™', deg: '°', times: '×', middot: '·',
  bull: '•', laquo: '«', raquo: '»', euro: '€', pound: '£', dollar: '$'
};

function safeCodePoint(code) {
  if (!Number.isInteger(code) || code < 0 || code > 0x10ffff) return '';
  try {
    return String.fromCodePoint(code);
  } catch {
    return '';
  }
}

function decodeEntities(text) {
  return String(text || '')
    .replace(/&#x([0-9a-f]+);/gi, (match, hex) => safeCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (match, dec) => safeCodePoint(Number(dec)))
    .replace(/&([a-z]+);/gi, (match, name) => ENTITIES[name.toLowerCase()] ?? match);
}

function stripTags(text) {
  /* CDATA تُفكّ أولًا: وإلا صار «<![CDATA[» و«]]>» وسمًا يبتلع عنوان الخبر كله. */
  const unwrapped = String(text || '').replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1');
  return decodeEntities(unwrapped.replace(/<[^>]*>/g, ' '));
}

/** نص نظيف سطر واحد بحدّ أقصى، مطابقًا لما يقصّه الناشر في toItem. */
function flat(value, max) {
  /* '&nbsp;' هنا ليست خطأً في فكّ الكيانات وحده: البوابة الرسمية تكتب «&amp;nbsp;»
     فتخرج منها المسافة غير القابلة للانفصال نصًا ظاهرًا في البطاقة بعد فكّ واحدة. */
  const text = stripTags(value).replace(/&nbsp;/gi, ' ').replace(/\s+/g, ' ').trim();
  return text.length > max ? text.slice(0, max - 1).trimEnd() : text;
}

function escapeHtml(text) {
  return String(text || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

const CDATA = (value) => String(value || '').replace(/^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/, '$1').trim();

/** https مطلق فقط؛ بلا صورة تُرسم البطاقة نصًا وحدها. */
function httpsUrl(value) {
  const raw = squeeze(decodeEntities(CDATA(value)));
  if (!raw || /^data:/i.test(raw)) return null;
  try {
    const url = new URL(raw);
    if (url.protocol !== 'https:') return null;
    /* بعض الخلاصات تكتب المسار بسلاحين (arriyadiyah.com//media/…) فتُوحَّد. */
    url.pathname = url.pathname.replace(/\/{2,}/g, '/');
    return url.href;
  } catch {
    return null;
  }
}

/** يحذف وسائط التتبع ليبقى الرابط الذي يفهمه القارئ ويُرمَّز به العنصر. */
function plainLink(value) {
  const url = httpsUrl(value);
  if (!url) return null;
  try {
    const parsed = new URL(url);
    const tracking = /^(utm_|ga_|gs_(?:src|em)|gsource|source|traffic_source|at_medium|at_campaign|fbclid|ref|cmp|int|share)/i;
    for (const key of [...parsed.searchParams.keys()]) if (tracking.test(key)) parsed.searchParams.delete(key);
    return parsed.href;
  } catch {
    return url;
  }
}

function isSport(link) {
  try {
    const url = new URL(link);
    return ALL_SPORT_HOSTS.has(url.host) || /\/(sport|sports)\b/i.test(url.pathname);
  } catch {
    return false;
  }
}

function parseDate(value) {
  const time = Date.parse(String(value || '').trim());
  return Number.isNaN(time) ? null : new Date(time).toISOString();
}

function slugFor(link) {
  return 'rss-' + createHash('sha1').update(link).digest('hex').slice(0, 12);
}

/* ── مطابقة كلمات المحافظة ────────────────────────────────────────────────── */

/* صورة واحدة للنص العربي: تشكيل وتطويل محذوف، وهمزات موحَّدة، وتاء مربوطة هاء،
   وألف مقصورة ياء، وكل فراغ (ب فيه nbsp) مسافة واحدة — وإلا ضاعت مطابقة
   «كفرُالشيخ» و«كفر  الشيخ» و«كفرالشيخ» بين ثلاث صور يكتبها كل موقع. */
function normalizeAr(text) {
  return String(text || '')
    .replace(/[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF]/g, '')
    .replace(/[\u0622\u0623\u0625\u0671\u0672\u0673]/g, 'ا')
    .replace(/[\u0624]/g, 'و')
    .replace(/[\u0626]/g, 'ي')
    .replace(/\u0649/g, 'ي')
    .replace(/\u0629/g, 'ه')
    .replace(/\u06A9/g, 'ك')
    .replace(/\u06BE/g, 'ه')
    .replace(/[\s\p{Cf}]+/gu, ' ')
    .toLowerCase();
}

const AR_LETTER = /[\u0620-\u064A\u0671-\u06EF\uFB50-\uFDFF\uFE70-\uFEFF]/;

/* حروف تتصل بالكلمة من أمامها بلا مسافة: الجر والعطف والتعريف والنداء («بالحامول»،
   «والدسوق»، «لكفرالشيخ»). لا تُقبل في آخر الكلمة، فتبقى «تدفوه» مستبعدة. */
const CLITIC_LETTERS = new Set(['ا', 'ل', 'ب', 'و', 'ف', 'ك', 'ي', 'ت', 'م', 'ن', 'س', 'ه']);

/**
 * كلمة عربية بحدودها: ما بعدها حرف يمنعها (ف«فوه» لا تقع في «فوهة» ولا «بيلا» في
 * «بيلاطس»)، وما قبلها يُسامح إن كان حروف اتصال معروفة (ف«بالحامول» خبر عن الحامول).
 */
function hasWord(haystack, term) {
  const needle = normalizeAr(term);
  let at = haystack.indexOf(needle);
  while (at >= 0) {
    const after = haystack[at + needle.length] || '';
    if (!AR_LETTER.test(after)) {
      let before = at;
      while (before > 0 && AR_LETTER.test(haystack[before - 1])) before -= 1;
      const prefix = haystack.slice(before, at);
      if ([...prefix].every((ch) => CLITIC_LETTERS.has(ch))) return true;
    }
    at = haystack.indexOf(needle, at + 1);
  }
  return false;
}

/** هل هذا الخبر عن المحافظة؟ كلمة قوية تكفي، والضعيفة تحتاج قرينة مصرية بجانبها. */
function isLocalNews(item) {
  const hay = normalizeAr([item.title, item.summary, item.category].join(' '));
  if (LOCAL_STRONG.some((term) => hasWord(hay, term))) return true;
  if (!LOCAL_WEAK.some((term) => hasWord(hay, term))) return false;
  return LOCAL_CONTEXT.some((term) => hasWord(hay, term));
}

/* ── تحليل RSS/Atom نصًا، بلا اعتماديات ───────────────────────────────────── */

function blockField(block, names) {
  for (const name of names) {
    const paired = block.match(new RegExp('<' + name + '(?:\\s[^>]*)?>([\\s\\S]*?)</' + name + '\\s*>', 'i'));
    if (paired && CDATA(paired[1])) return paired[1];
    const self = block.match(new RegExp('<' + name + '\\s+[^>]*(?:url|href)="([^"]+)"', 'i'));
    if (self) return self[1];
  }
  return '';
}

function imageFrom(block) {
  const inline = (block.match(/<img[^>]+src="([^"]+)"/i) || [])[1];
  for (const candidate of [
    blockField(block, ['media:thumbnail', 'media:content', 'enclosure', 'main_image']),
    inline
  ]) {
    const url = httpsUrl(candidate);
    if (url) return url;
  }
  return null;
}

function parseFeed(text, feed) {
  const items = [];
  const chunks = String(text || '').match(/<(item|entry)[\s>][\s\S]*?<\/(?:item|entry)>/gi) || [];
  for (const block of chunks) {
    const link = plainLink(blockField(block, ['link', 'guid']));
    const title = flat(blockField(block, ['title']), 200);
    /* أسماء التاريخ تختلف بين المواقع: الرياضية تكتب created_date لا pubDate. */
    const publishedAt = parseDate(blockField(block, ['pubDate', 'published', 'updated', 'created_date', 'publication_time']));
    if (!title || !link || !publishedAt) continue;
    if (NOW - Date.parse(publishedAt) > MAX_AGE_HOURS * 3600000) continue;
    const rawBody = blockField(block, ['content:encoded', 'description', 'content', 'summary', 'announce']);
    items.push({
      section: isSport(link) ? 'sports' : feed.section,
      sourceName: feed.name,
      title,
      summary: flat(rawBody, 240),
      body: flat(rawBody, 1200),
      image: imageFrom(block),
      link,
      publishedAt,
      category: flat(blockField(block, ['category']), 40)
    });
    if (items.length >= PER_FEED) break;
  }
  return items;
}

async function fetchText(url, timeout = FEED_TIMEOUT) {
  const res = await fetch(url, {
    redirect: 'follow',
    signal: AbortSignal.timeout(timeout),
    headers: { 'User-Agent': UA, Accept: 'application/rss+xml, application/atom+xml, application/xml, text/xml, text/html, */*' }
  });
  if (!res.ok) throw new Error('HTTP ' + res.status);
  return res.text();
}

/* ── NewsAPI اختياري ومقنَّن: الخطة المجانية 100 طلب/يوم ─────────────────── */

/* الدورية 15 دقيقة = 96 جولة/يوم، فيُستقصى في أول ثماني دقائق من الساعة فقط:
   24 جولة × طلبان = 48 طلبًا/يوم، ويبقى نصف الحصة لتجارب اللوحة. والمصادر التي لها
   everyHours (مثل بحث المحافظة) تُسأل مرة كل ذلك العدد من الساعات. */
function newsApiDueNow(source) {
  if (FORCE_NEWSAPI) return true;
  const now = new Date();
  if (now.getUTCMinutes() >= 8) return false;
  const every = source.everyHours || 1;
  return every === 1 || now.getUTCHours() % every === 0;
}

function newsApiUrl(source) {
  /* البحث بالكلمات على /v2/everything، لأن top-headlines لا يقبل إلا دولة أو فئة. */
  if (source.query) {
    return 'https://newsapi.org/v2/everything?q=' + encodeURIComponent(source.query) +
      '&language=ar&sortBy=publishedAt&pageSize=60&page=1';
  }
  return 'https://newsapi.org/v2/top-headlines?language=ar&category=' +
    encodeURIComponent(source.category) + '&pageSize=30&page=1';
}

async function fetchNewsApi(source) {
  const res = await fetch(newsApiUrl(source), {
    signal: AbortSignal.timeout(FEED_TIMEOUT),
    headers: { 'User-Agent': UA, Authorization: 'Bearer ' + NEWS_API_KEY }
  });
  if (res.status === 429) throw new Error('تجاوزت الحصة (429)');
  if (!res.ok) throw new Error('NewsAPI HTTP ' + res.status);
  const json = await res.json();
  if (json.status && json.status !== 'ok') throw new Error(json.message || json.status);
  return (json.articles || []).map((article) => {
    const link = plainLink(article.url);
    const publishedAt = parseDate(article.publishedAt);
    const body = flat(article.content || article.description || '', 1200).replace(/\s*\[\+\d+\s*chars?\]$/i, '');
    return {
      section: source.section,
      sourceName: flat(article.source?.name || 'NewsAPI', 120) || 'NewsAPI',
      title: flat(article.title, 200),
      summary: flat(article.description || article.content || '', 240),
      body,
      image: httpsUrl(article.urlToImage),
      link,
      publishedAt,
      category: ''
    };
  }).filter((item) => item.title && item.link && item.publishedAt && !/^\[Removed\]$/i.test(item.title));
}

/* ── البوابة الرسمية للمحافظة: قائمة «أخبار المحافظة» ─────────────────────── */

/* الشهور العربية كما تكتبها البوابة في meta-date («29 يونيو, 2026»)، بعد normalizeAr
   الذي يوحّد الهمزات، فالكلمة تُذكر بصورتها غير المهموزة فقط. */
const AR_MONTHS = {
  يناير: 1, فبراير: 2, مارس: 3, ابريل: 4, مايو: 5, يونيو: 6,
  يوليو: 7, اغسطس: 8, سبتمبر: 9, اكتوبر: 10, نوفمبر: 11, ديسمبر: 12
};

function parseArabicDate(text) {
  const raw = normalizeAr(text).replace(/,/g, ' ').trim();
  const parts = raw.match(/^(\d{1,2})\s+(\S+)\s+(\d{4})$/);
  const month = parts && AR_MONTHS[parts[2]];
  if (!parts || !month) return parseDate(text);
  /* ظهر UTC: تاريخ بلا ساعة، والتوقيت المحلي للموقع مصري (UTC+3)، فلو بُني على
     منتصف الليل لأصبح الخبر «أمس» قبل الفجر حسب مكان القارئ. */
  return new Date(Date.UTC(Number(parts[3]), month - 1, Number(parts[1]), 12, 0, 0)).toISOString();
}

/**
 * بطاقات أخبار البوابة الرسمية. قائمة HTML ثابتة البنية، والموقع يأذن الوصول في
 * robots.txt، فنكتفي بالعنوان والمقتطف الذي كتبه ناشر الموقع نفسه والصورة المصغّرة
 * والتاريخ — ولا نجلب صفحة الخبر أصلًا (لا حاجة: له صورة مصغّرة في القائمة).
 */
async function fetchOfficialLocal() {
  const seen = new Set();
  const items = [];
  for (let page = 1; page <= OFFICIAL_LOCAL.pages; page++) {
    const html = await fetchText(OFFICIAL_LOCAL.url + (page > 1 ? '&page=' + page : ''), PAGE_TIMEOUT);
    /* البوابة تُعيد أحيانًا بطاقة على صفحتين متتاليتين؛ seen يمنع تكرارها. */
    for (const block of html.split('class="post-card"').slice(1)) {
      const chunk = block.slice(0, 4000);
      const link = plainLink((chunk.match(/<h3[^>]*class="card-title"[^>]*>\s*<a[^>]+href="([^"]+)"/i) || [])[1]);
      if (!link) continue;
      let host = '';
      try {
        host = new URL(link).host;
      } catch {
        continue;
      }
      if (!/(^|\.)kfs\.gov\.eg$/.test(host)) continue;
      const title = flat((chunk.match(/<h3[^>]*class="card-title"[^>]*>([\s\S]*?)<\/h3>/i) || [])[1], 200);
      const publishedAt = parseArabicDate((chunk.match(/class="meta-date"[^>]*>([^<]*)</i) || [])[1]);
      if (!title || !publishedAt) continue;
      if (NOW - Date.parse(publishedAt) > OFFICIAL_LOCAL.maxAgeHours * 3600000) continue;
      if (seen.has(link)) continue;
      seen.add(link);
      /* المقتطف كما كتبته البوابة، يُقصَّر ويُختم بنقاط حذف كإشارة إلى المصدر.
         حرف واحد يتسرّب أحيانًا في آخر السطر (واو أو فاء)، فتُحذف مع مسافتها. */
      const rawExcerpt = flat((chunk.match(/class="card-excerpt"[^>]*>([\s\S]*?)<\/p>/i) || [])[1], 240)
        .replace(/(?:\s*\.{3}|\s*…)\s*$/, '')
        .replace(/\s[\u0648\u0641\u0644\u0643\u0628\u0645\u064a\u062a\u062f\u0631]\s*$/, '')
        .trim();
      const excerpt = rawExcerpt ? rawExcerpt + ' …' : '';
      items.push({
        section: 'local_news',
        sourceName: OFFICIAL_LOCAL.name,
        title,
        summary: excerpt,
        body: excerpt,
        image: httpsUrl((chunk.match(/<img[^>]+src="([^"]+)"/i) || [])[1]),
        link,
        publishedAt,
        category: 'كفر الشيخ'
      });
      if (items.length >= OFFICIAL_LOCAL.perPage * OFFICIAL_LOCAL.pages) break;
    }
  }
  return items;
}

/* «20261004T155302Z» كما ترسلها GDELT، إلى صيغة ISO التي يفهمها باقي السكربت. */
function gdeltDate(seendate) {
  const m = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/.exec(String(seendate || ''));
  if (!m) return '';
  const iso = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6])).toISOString();
  return NOW - Date.parse(iso) > GDELT_LOCAL.maxAgeHours * 3600000 ? '' : iso;
}

async function fetchGdeltLocal() {
  const url = 'https://api.gdeltproject.org/api/v2/doc/doc?query=' +
    encodeURIComponent(GDELT_LOCAL.query) +
    '&mode=artlist&format=json&maxrecords=' + GDELT_LOCAL.maxRecords +
    '&timespan=' + GDELT_LOCAL.timespan + '&sort=DateDesc';
  let res;
  try {
    res = await fetch(url, { signal: AbortSignal.timeout(FEED_TIMEOUT), headers: { 'User-Agent': UA } });
  } catch (error) {
    throw new Error('تعذّر الاتصال بـ GDELT: ' + (error.cause?.code || error.name));
  }
  const text = await res.text();
  /* GDELT تردّ أحيانًا بنصٍّ صريح بدل JSON (رسالة الحدّ أو خطأ استعلام)، فلا يُبتلع
     السبب: يُطبع أول السطر في التحذير ليكون قابلًا للتشخيص من سجل التشغيل. */
  let json = null;
  try { json = JSON.parse(text); } catch { json = null; }
  if (!res.ok || !json) {
    throw new Error('GDELT HTTP ' + res.status + ': ' + text.replace(/\s+/g, ' ').trim().slice(0, 120));
  }
  const items = [];
  for (const art of json.articles || []) {
    const link = httpsUrl(art.url);
    const title = flat(art.title || '', 200);
    const publishedAt = gdeltDate(art.seendate);
    if (!link || !title || !publishedAt) continue;
    /* فهرسة GDELT تقرأ النص الكامل للمقال، فيردّ أحيانًا خبرٌ مذكورٌ فيه اسم
       المحافظة عرضًا وهو عن مكان آخر — فيُفلتر بكلمات المحافظة نفسها التي
       تمشي عليها الخلاصات. */
    if (!isLocalNews({ title, summary: '', category: '' })) continue;
    items.push({
      section: 'local_news',
      feeder: GDELT_LOCAL.feeder,
      sourceName: flat(art.domain || 'GDELT', 120) || 'GDELT',
      title,
      summary: '',
      body: 'عنوان من «' + (art.domain || 'GDELT') + '» رصدته واجهة GDELT المفتوحة؛ ' +
        'الخبر كاملًا في موقع ناشره.',
      image: null,
      link,
      publishedAt,
      category: 'كفر الشيخ'
    });
  }
  return items;
}

/* ── Supabase ─────────────────────────────────────────────────────────────── */
async function rest(table, params, init = {}) {
  const url = new URL(SUPABASE_URL + '/rest/v1/' + table);
  Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value));
  const res = await fetch(url, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: 'Bearer ' + SERVICE_KEY,
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(init.headers || {})
    },
    signal: AbortSignal.timeout(45000)
  });
  const text = await res.text();
  if (!res.ok) throw new Error(table + ' → HTTP ' + res.status + ': ' + text.slice(0, 300));
  return text ? JSON.parse(text) : null;
}

/** الصورة الغائبة من link_previews أولًا، ثم من og:image بحدّ OG_LIMIT صفحة. */
async function backfillImages(items) {
  const missing = items.filter((item) => !item.image);
  if (!missing.length) return { fromCache: 0, fetched: 0 };
  const cache = new Map();
  if (SUPABASE_URL && SERVICE_KEY) {
    try {
      const rows = await rest('link_previews', { select: 'url,image_url', order: 'fetched_at.desc', limit: '2000' });
      for (const row of rows || []) if (row.image_url) cache.set(row.url, row.image_url);
    } catch (error) {
      console.log('-- NOTICE: link_previews غير متاح، تُجلب الصور من الصفحات: ' + error.message);
    }
  }

  let fromCache = 0;
  let fetched = 0;
  for (const item of missing) {
    const cached = cache.get(item.link);
    if (cached) {
      item.image = cached;
      fromCache += 1;
      continue;
    }
    if (fetched >= OG_LIMIT) continue;
    fetched += 1;
    try {
      const html = (await fetchText(item.link, PAGE_TIMEOUT)).slice(0, 250000);
      const found = (html.match(/<meta[^>]+(?:property|name)="og:image"[^>]+content="([^"]+)"/i) ||
        html.match(/<meta[^>]+content="([^"]+)"[^>]+(?:property|name)="og:image"/i) || [])[1];
      const url = httpsUrl(found);
      if (!url) continue;
      item.image = url;
      cache.set(item.link, url);
      if (SUPABASE_URL && SERVICE_KEY && !DRY) {
        await rest('link_previews', { on_conflict: 'url' }, {
          method: 'POST',
          headers: { Prefer: 'return=minimal,resolution=merge-duplicates' },
          body: JSON.stringify([{
            url: item.link,
            host: new URL(item.link).host,
            image_url: url,
            fetched_at: new Date().toISOString(),
            failed_at: null
          }])
        });
      }
    } catch {
      /* صفحة لا تُفتح — تُترك البطاقة بلا صورة، فلا تتوقف الجولة كلها لأجلها. */
    }
  }
  return { fromCache, fetched };
}

function rowFor(item) {
  const summary = item.summary || item.body;
  const row = {
    slug: slugFor(item.link),
    section_id: item.section,
    title: item.title,
    subtitle: summary || null,
    body: '<p>' + escapeHtml(item.body || summary) + '</p>',
    image: item.image,
    image_credit: item.image ? 'الصورة من ' + item.sourceName : null,
    link: item.link,
    source_name: item.sourceName,
    source_url: item.link,
    tags: item.category ? [item.category] : [],
    fields: {},
    status: 'published',
    event_date: null,
    published_at: item.publishedAt,
    sort_order: 0
  };
  return row;
}

async function writeSection(section, rows) {
  /* القراءة بحدّ ذاتها بلا فلتر slug: PostgREST يفسّر like.rss.* كأنه LIKE 'rss.%'
     (النقطة حرف لا وايلد)، فالفلترة في JS بالبادئة أدقّ وأضمن. */
  const existing = await rest('items', {
    select: 'id,slug,status',
    section_id: 'eq.' + section,
    order: 'slug.asc,updated_at.desc',
    limit: '1000'
  });
  const bySlug = new Map();
  const duplicates = [];
  for (const row of existing || []) {
    if (!row.slug || !row.slug.startsWith('rss-')) continue;
    /* التكرار من خطأ الفلترة السابق: يبقى الأحدث (الترتيب فوق) وتُمحى نسخه الأخرى. */
    if (bySlug.has(row.slug)) duplicates.push(row.id);
    else bySlug.set(row.slug, row);
  }

  const inserts = [];
  const updates = [];
  let skipped = 0;
  for (const row of rows) {
    const hit = bySlug.get(row.slug);
    if (!hit) {
      inserts.push(row);
      continue;
    }
    /* الأرشيف قرار مدير: لا يُخرج الخبر منه ولا يمسّ التثبيت والعاجلة. */
    if (hit.status === 'archived') {
      skipped += 1;
      continue;
    }
    const { section_id: _drop, ...patch } = row;
    updates.push({ id: hit.id, patch });
  }

  if (!DRY && inserts.length) {
    await rest('items', {}, {
      method: 'POST',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify(inserts)
    });
  }
  for (const update of updates) {
    if (DRY) continue;
    await rest('items', { id: 'eq.' + update.id }, { method: 'PATCH', body: JSON.stringify(update.patch) });
  }
  console.log((DRY ? '[dry-run] ' : '') + section + ' ← جديد ' + inserts.length + '، محدَّث ' + updates.length +
    '، متجاهَل لأرشيف المدير ' + skipped);

  if (duplicates.length) {
    if (!DRY) {
      await rest('items', { id: 'in.(' + duplicates.join(',') + ')' }, {
        method: 'DELETE',
        headers: { Prefer: 'return=minimal' }
      });
    }
    console.log('  dedupe: ' + duplicates.length + ' مكرّرًا (نفس الslug) حُذف — بقي الأحدث لكل خبر');
  }

  /* التقليم: تبقى أحدث KEEP_PER_SECTION بطاقة آلية فقط، فلا يتضخم القسم. */
  const fresh = await rest('items', {
    select: 'id,slug',
    section_id: 'eq.' + section,
    order: 'published_at.desc',
    limit: '1000'
  });
  const auto = (fresh || []).filter((row) => row.slug && row.slug.startsWith('rss-'));
  const stale = auto.slice(KEEP_PER_SECTION).map((row) => row.id);
  if (stale.length) {
    if (!DRY) {
      await rest('items', { id: 'in.(' + stale.join(',') + ')' }, {
        method: 'DELETE',
        headers: { Prefer: 'return=minimal' }
      });
    }
    console.log('  prune: ' + stale.length + ' عنصرًا آليًا خارج أحدث ' + KEEP_PER_SECTION);
  }
}

/* ── التشغيل ──────────────────────────────────────────────────────────────── */

if (!SUPABASE_URL || !SERVICE_KEY) {
  if (DRY) {
    console.log('-- NOTICE: بلا مفاتيح Supabase — لا قراءة لـ link_previews ولا كتابة في القاعدة.');
  } else {
    console.error('\n-- ERROR: ناقص: SUPABASE_URL / SUPABASE_SERVICE_KEY\n');
    process.exit(1);
  }
}

const byKey = new Map();
let failedFeeds = 0;

/** التجمع على مفتاح (القسم|الرابط): الخبر الواحد لا يُكتب مرتين في القسم نفسه. */
function collect(item) {
  if (!item || !SECTIONS.includes(item.section)) return;
  const key = item.section + '|' + item.link;
  if (!byKey.has(key)) byKey.set(key, item);
}

for (const feed of FEEDS) {
  try {
    const items = parseFeed(await fetchText(feed.url), feed);
    if (!items.length) throw new Error('لا عناصر ضمن آخر ' + MAX_AGE_HOURS + ' ساعة');
    console.log('✓ ' + feed.name.padEnd(18) + ' ' + String(items.length).padStart(3) + ' عنصرًا');
    for (const item of items) {
      collect(item);
      /* الخبر الواحد قد يكون عالميًا ومحلّيًا معًا: ما ذكر المحافظة يُنسخ إليها. */
      if (WANTS_LOCAL && isLocalNews(item)) collect({ ...item, section: 'local_news' });
    }
  } catch (error) {
    failedFeeds += 1;
    console.log('-- WARNING: ' + feed.name + ': ' + error.message);
  }
}

if (WANTS_LOCAL) {
  try {
    const items = await fetchOfficialLocal();
    if (!items.length) throw new Error('لا بطاقات في قائمة أخبار المحافظة');
    console.log('✓ ' + OFFICIAL_LOCAL.name.padEnd(18) + ' ' + String(items.length).padStart(3) + ' عنصرًا');
    for (const item of items) collect(item);
  } catch (error) {
    failedFeeds += 1;
    console.log('-- WARNING: ' + OFFICIAL_LOCAL.name + ': ' + error.message);
  }

  try {
    const items = await fetchGdeltLocal();
    console.log('✓ ' + GDELT_LOCAL.name.padEnd(18) + ' ' + String(items.length).padStart(3) + ' عنصرًا');
    for (const item of items) collect(item);
  } catch (error) {
    failedFeeds += 1;
    console.log('-- WARNING: ' + GDELT_LOCAL.name + ': ' + error.message);
  }
}

if (NEWS_API_KEY && !SKIP_NEWSAPI) {
  let anyDue = false;
  for (const source of NEWSAPI_SOURCES) {
    if (!SECTIONS.includes(source.section)) continue;
    if (!newsApiDueNow(source)) continue;
    anyDue = true;
    try {
      const items = await fetchNewsApi(source);
      console.log('✓ ' + source.name.padEnd(18) + ' ' + String(items.length).padStart(3) + ' عنصرًا');
      for (const item of items) collect(item);
    } catch (error) {
      console.log('-- WARNING: ' + source.name + ': ' + error.message);
    }
  }
  if (!anyDue) {
    console.log('-- NOTICE: NewsAPI مؤجَّل في هذه الجولة (يعمل في أول ثماني دقائق من الساعة، وبحث المحافظة كل ست ساعات).');
  }
} else {
  console.log('-- NOTICE: NEWS_API_KEY غير مضبوط — الخلاصات والبوابة الرسمية وحدهما. أضِفه في Settings ← Secrets and variables ← Actions ← New repository secret.');
}

const planned = new Map(SECTIONS.map((section) => [section, []]));
for (const item of byKey.values()) planned.get(item.section).push(item);
for (const items of planned.values()) {
  items.sort((a, b) => Date.parse(b.publishedAt) - Date.parse(a.publishedAt));
  /* سقف لكل مصدر حتى لا يبتلع مصدرٌ واحد القسم: قريةٌ تقرأ أصواتًا عدة.
     واجهات الفهرسة (GDELT) تُنسَب إلى ناشرٍ مختلف في كل بطاقة، فالتجميع يكون على
     المُلتمِط (feeder) إن وُجد — وإلا حصّلت صحف المحافظات القسم وحدها. */
  const kept = [];
  const perSource = new Map();
  for (const item of items) {
    const bucket = item.feeder || item.sourceName;
    const used = perSource.get(bucket) || 0;
    if (used >= PER_SOURCE) continue;
    perSource.set(bucket, used + 1);
    kept.push(item);
    if (kept.length >= PER_SECTION) break;
  }
  items.length = 0;
  items.push(...kept);
}

const candidates = [...planned.values()].flat();
if (!candidates.length) {
  console.error('\n-- ERROR: لم يُجلب أي عنصر — تُترك القاعدة كما هي.\n');
  process.exit(1);
}

const filled = await backfillImages(candidates);
console.log('  صور من مخزن link_previews ' + filled.fromCache + '، ومن صفحات الأخبار ' + filled.fetched);

if (DRY) {
  for (const [section, items] of planned) {
    console.log('\n── ' + section + ' (' + items.length + ') ──');
    items.slice(0, 10).forEach((item) => {
      console.log('  ' + item.publishedAt.slice(0, 16) + '  ' + (item.image ? 'img ' : '    ') +
        item.title.slice(0, 72) + '  ⟨' + item.sourceName + '⟩');
    });
  }
  console.log('\n[dry-run] لم تُكتب أي صفوف. المجموع ' + candidates.length + ' عنصرًا، ' +
    candidates.filter((item) => item.image).length + ' منها بصورة.');
  process.exit(0);
}

let written = 0;
for (const [section, items] of planned) {
  if (!items.length) continue;
  written += items.length;
  await writeSection(section, items.map(rowFor));
}

if (!written) {
  console.error('\n-- ERROR: لا عناصر للكتابة — تُترك القاعدة كما هي.\n');
  process.exit(1);
}
console.log('\nتمت مزامنة ' + written + ' خبرًا في ' + SECTIONS.join(' و ') +
  '. ينشرها هذا التشغيل نفسه (publish.mjs ثم دفع data/) فيتمدّد التطبيق خلال دقائق.');
