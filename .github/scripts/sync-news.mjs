#!/usr/bin/env node
/*
 * مزامن الأخبار: يجلب خلاصات RSS عربية رسمية (ويستقصي NewsAPI إن وُجد مفتاحه)
 * ويكتب العناصر في جدول items في Supabase — وهي الصفوف نفسها التي تحررها اللوحة
 * ويولّد منها publish.mjs ملفي data/sections/world_news.json و sports.json.
 *
 *   node .github/scripts/sync-news.mjs                 # كل الخلاصات
 *   node .github/scripts/sync-news.mjs --dry-run       # يطبع ما سيُكتب، بلا كتابة
 *   node .github/scripts/sync-news.mjs --section=sports
 *   node .github/scripts/sync-news.mjs --no-newsapi    # الخلاصات وحدها
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
const WHICH = (ARGS.find((arg) => arg.startsWith('--section=')) || '--section=both').split('=')[1];
const SECTIONS = WHICH === 'both' ? ['world_news', 'sports'] : [WHICH];

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
  { section: 'sports', name: 'الرياضية', url: 'https://www.arriyadiyah.com/rss' }
];

const ALL_SPORT_HOSTS = new Set(['www.arriyadiyah.com', 'arriyadiyah.com']);

const NEWSAPI_SOURCES = [
  { section: 'world_news', category: 'general', name: 'NewsAPI (عالمي)' },
  { section: 'sports', category: 'sports', name: 'NewsAPI (رياضة)' }
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
  const text = stripTags(value).replace(/\s+/g, ' ').trim();
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
   24 جولة × طلبان = 48 طلبًا/يوم، ويبقى نصف الحصة لتجارب اللوحة. */
function newsApiDueNow() {
  return new Date().getUTCMinutes() < 8;
}

async function fetchNewsApi(source) {
  const url = 'https://newsapi.org/v2/top-headlines?language=ar&category=' +
    encodeURIComponent(source.category) + '&pageSize=30&page=1';
  const res = await fetch(url, {
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
  const existing = await rest('items', {
    select: 'id,slug,status',
    section_id: 'eq.' + section,
    slug: 'like.rss.*',
    limit: '500'
  });
  const bySlug = new Map((existing || []).map((row) => [row.slug, row]));

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

  /* التقليم: تبقى أحدث KEEP_PER_SECTION بطاقة آلية فقط، فلا يتضخم القسم. */
  const recent = await rest('items', {
    select: 'id',
    section_id: 'eq.' + section,
    slug: 'like.rss.*',
    order: 'published_at.desc',
    limit: '500'
  });
  const stale = (recent || []).slice(KEEP_PER_SECTION).map((row) => row.id);
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

for (const feed of FEEDS) {
  try {
    const items = parseFeed(await fetchText(feed.url), feed);
    if (!items.length) throw new Error('لا عناصر ضمن آخر ' + MAX_AGE_HOURS + ' ساعة');
    console.log('✓ ' + feed.name.padEnd(18) + ' ' + String(items.length).padStart(3) + ' عنصرًا');
    for (const item of items) {
      if (!SECTIONS.includes(item.section)) continue;
      const key = item.section + '|' + item.link;
      if (!byKey.has(key)) byKey.set(key, item);
    }
  } catch (error) {
    failedFeeds += 1;
    console.log('-- WARNING: ' + feed.name + ': ' + error.message);
  }
}

if (NEWS_API_KEY && !SKIP_NEWSAPI) {
  if (!newsApiDueNow()) {
    console.log('-- NOTICE: NewsAPI يعمل في أول ثماني دقائق من الساعة فقط — تُجاوز هذه الجولة.');
  } else {
    for (const source of NEWSAPI_SOURCES) {
      if (!SECTIONS.includes(source.section)) continue;
      try {
        const items = await fetchNewsApi(source);
        console.log('✓ ' + source.name.padEnd(18) + ' ' + String(items.length).padStart(3) + ' عنصرًا');
        for (const item of items) {
          const key = item.section + '|' + item.link;
          if (!byKey.has(key)) byKey.set(key, item);
        }
      } catch (error) {
        console.log('-- WARNING: ' + source.name + ': ' + error.message);
      }
    }
  }
} else {
  console.log('-- NOTICE: NEWS_API_KEY غير مضبوط — الخلاصات وحدها. أضِفه في Settings ← Secrets and variables ← Actions ← New repository secret.');
}

const planned = new Map(SECTIONS.map((section) => [section, []]));
for (const item of byKey.values()) planned.get(item.section).push(item);
for (const items of planned.values()) {
  items.sort((a, b) => Date.parse(b.publishedAt) - Date.parse(a.publishedAt));
  /* سقف لكل مصدر حتى لا يبتلع مصدرٌ واحد القسم: قريةٌ تقرأ أصواتًا عدة. */
  const kept = [];
  const perSource = new Map();
  for (const item of items) {
    const used = perSource.get(item.sourceName) || 0;
    if (used >= PER_SOURCE) continue;
    perSource.set(item.sourceName, used + 1);
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
console.log('\nتمت مزامنة ' + written + ' خبرًا في ' + SECTIONS.join(' و ') + '. ينشرها publish.yml خلال خمس دقائق.');
