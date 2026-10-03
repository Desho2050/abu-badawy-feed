/* طبقة الوصول إلى Supabase + وضع الاستعراض دون اتصال (يقرأ الملفات المنشورة).
   التطبيق نفسه لا يستدعي هذا الملف ولا يلمس Supabase: هذه اللوحة فقط. */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const BUCKET = 'media';
export const MAX_BYTES = 26214400;
/* مشروع Supabase الخاص بهذا التطبيق — يُملأ تلقائيًا في بوابة الاتصال، ويمكن
   تغييره من اللوحة دون تعديل الكود (يُحفظ في localStorage). */
export const PROJECT_URL = 'https://hrsrtvrrpnwxqhadxhfg.supabase.co';
export const MEDIA_TYPES = {
  image: ['image/jpeg', 'image/png', 'image/webp', 'image/avif', 'image/gif'],
  audio: ['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/wav', 'audio/x-wav'],
  video: ['video/mp4', 'video/webm', 'video/quicktime']
};

/* الأيقونات المتاحة = ما يعرفها sectionIcon() في ui/common/SectionIcons.kt. */
export const ICONS = [
  ['info', 'معلومات (info)'], ['landmark', 'معلم (landmark)'], ['map', 'خريطة (map)'],
  ['person', 'شخص (person)'], ['people', 'مجموعة (people)'], ['newspaper', 'جريدة (newspaper)'],
  ['public', 'عالم (public)'], ['trophy', 'كأس (trophy)'], ['currency', 'عملة (currency)'],
  ['gold', 'ذهب (gold)'], ['sell', 'عرض (sell)'], ['shop', 'متجر (shop)'],
  ['ads', 'إعلان (ads)'], ['history', 'تراث (history)'], ['water', 'زراعة/ماء (water)'],
  ['list', 'قائمة (list)'], ['menu', 'شبكة (menu)'], ['settings', 'إعدادات (settings)']
];

export const LAYOUTS = [
  ['list', 'قائمة (list)'], ['richArticle', 'مقال مفصل (richArticle)'], ['cards', 'بطاقات (cards)'],
  ['profiles', 'تراجم (profiles)'], ['offers', 'عروض (offers)'], ['ads', 'إعلانات (ads)'],
  ['rates', 'أسعار (rates)'], ['directory', 'دليل (directory)']
];

export const KINDS = [
  ['json', 'json — عناصر من اللوحة'], ['rss', 'rss — تغذية خارجية'], ['html', 'html — صفحة بمُحدِّد'],
  ['fx', 'fx — أسعار العملات'], ['gold', 'gold — أسعار الذهب'], ['inline', 'inline — مضمّن في index.json']
];

export const STATUSES = [
  ['draft', 'مسودة'], ['scheduled', 'مجدول'], ['published', 'منشور'], ['archived', 'مؤرشف']
];

/* ريبو الملفات المنشورة: النشر فيه مجدول، والتشغيل اليدوي من GitHub نفسه.
   اللوحة لا تحمل أي مفتاح لهذا الريبو — جلسة Supabase هي الصلاحية الوحيدة. */
export const FEED_REPO = 'Desho2050/abu-badawy-feed';
export const PUBLISH_ACTIONS_URL = 'https://github.com/' + FEED_REPO + '/actions/workflows/publish.yml';
export const PUBLISH_EVERY_MINUTES = 5;

const LS = {
  url: 'abuBadawyDash.url',
  anon: 'abuBadawyDash.anon'
};

/* اللوحة لم تعد تعرف شيئًا عن مفاتيح GitHub — تُمسح بقاياها من متصفحات من ضبطها سابقًا. */
['abuBadawyDash.ghToken', 'abuBadawyDash.ghRepo', 'abuBadawyDash.ghBranch'].forEach((key) => localStorage.removeItem(key));

let db = null;

export function savedConnection() {
  return { url: localStorage.getItem(LS.url) || '', anon: localStorage.getItem(LS.anon) || '' };
}

export function saveConnection(url, anon) {
  localStorage.setItem(LS.url, url);
  localStorage.setItem(LS.anon, anon);
}

export function forgetConnection() {
  Object.values(LS).forEach((key) => localStorage.removeItem(key));
}

export function connect(url, anon) {
  db = createClient(url.replace(/\/+$/, ''), anon, { auth: { persistSession: true, autoRefreshToken: true } });
  return db;
}

export function client() {
  if (!db) throw new Error('لا اتصال بـ Supabase بعد.');
  return db;
}

export async function currentUser() {
  if (!db) return null;
  const { data } = await db.auth.getSession();
  return data.session ? data.session.user : null;
}

export async function signIn(email, password) {
  const { error } = await db.auth.signInWithPassword({ email: email.trim(), password });
  if (error) throw new Error(error.message);
}

export async function signOut() {
  if (db) await db.auth.signOut();
}

/** RLS تُرجع صفوفًا فقط لبريد موجود في admin_emails — فلا حاجة لدالة تحقق إضافية. */
export async function editors() {
  const { data, error } = await db.from('admin_emails').select('email,label,added_at').order('added_at');
  if (error) throw new Error(error.message);
  return data || [];
}

export async function addEditor(email, label) {
  const { error } = await db.from('admin_emails').upsert({ email: email.trim().toLowerCase(), label: label || null }, { onConflict: 'email' });
  if (error) throw new Error(error.message);
}

export async function removeEditor(email) {
  const { error } = await db.from('admin_emails').delete().eq('email', email);
  if (error) throw new Error(error.message);
}

/* ── قراءة النموذج كاملًا ─────────────────────────────────────────────────── */
export async function loadModel() {
  const [settings, sections, items, legal, prices, media, log, previews] = await Promise.all([
    db.from('app_settings').select('*').limit(1),
    db.from('sections').select('*').order('sort_order', { ascending: true }),
    db.from('items').select('*').order('sort_order', { ascending: false }).order('updated_at', { ascending: false }),
    db.from('legal_docs').select('*'),
    db.from('price_rows').select('*').order('kind').order('sort_order'),
    db.from('media_library').select('*').order('created_at', { ascending: false }),
    db.from('publish_log').select('*').order('created_at', { ascending: false }).limit(25),
    /* جدول اختياري: موجود فقط بعد تنفيذ قسم link_previews في supabase-setup.sql. */
    db.from('link_previews').select('url,title,site_name,fetched_at,failed_at').order('fetched_at', { ascending: false }).limit(500)
  ]);
  [[settings, 'app_settings'], [sections, 'sections'], [items, 'items'], [legal, 'legal_docs'],
    [prices, 'price_rows'], [media, 'media_library'], [log, 'publish_log']]
    .forEach(([res, name]) => { if (res.error) throw new Error(name + ': ' + res.error.message); });

  return {
    demo: false,
    settings: settings.data && settings.data[0] ? settings.data[0] : blankSettings(),
    sections: sections.data || [],
    items: items.data || [],
    legal: legal.data || [],
    prices: prices.data || [],
    media: media.data || [],
    log: log.data || [],
    previews: previews.error ? [] : (previews.data || [])
  };
}

export function blankSettings() {
  return { id: 1, schema_version: 1, brand: {}, digest: {}, prices: {}, notice: null };
}

/* ── الكتابة ───────────────────────────────────────────────────────────────── */
export async function saveSettings(patch) {
  const { error } = await db.from('app_settings').upsert({ id: 1, ...patch }, { onConflict: 'id' });
  if (error) throw new Error(error.message);
}

export async function saveSection(row) {
  const clean = { ...row };
  delete clean.created_at;
  delete clean.updated_at;
  const { error } = await db.from('sections').upsert(clean, { onConflict: 'id' });
  if (error) throw new Error(error.message);
}

export async function deleteSection(id) {
  const { error } = await db.from('sections').delete().eq('id', id);
  if (error) throw new Error(error.message);
}

export function blankItem(sectionId) {
  return {
    id: null, section_id: sectionId, slug: null, title: '', subtitle: '', body: '', image: null,
    image_credit: null, link: null, source_name: null, source_url: null, tags: [], fields: {},
    attachments: [], pinned: false, breaking: false, status: 'draft', event_date: '',
    publish_at: null, published_at: null, sort_order: 0
  };
}

export async function saveItem(row) {
  const clean = { ...row };
  delete clean.created_at;
  delete clean.updated_at;
  delete clean.created_by;
  if (!clean.id) delete clean.id;
  if (clean.status === 'published' && !clean.published_at) clean.published_at = new Date().toISOString();
  if (clean.status !== 'scheduled') clean.publish_at = null;
  if (clean.status !== 'published') clean.published_at = null;
  const { data, error } = await db.from('items').upsert(clean, { onConflict: 'id' }).select('id');
  if (error) throw new Error(error.message);
  return data && data[0] ? data[0].id : clean.id;
}

export async function deleteItem(id) {
  const { error } = await db.from('items').delete().eq('id', id);
  if (error) throw new Error(error.message);
}

export async function saveLegal(row) {
  const { error } = await db.from('legal_docs').upsert({ key: row.key, title: row.title, body: row.body }, { onConflict: 'key' });
  if (error) throw new Error(error.message);
}

export async function savePrice(row) {
  const { error } = await db.from('price_rows').upsert(row, { onConflict: 'kind,code' });
  if (error) throw new Error(error.message);
}

export async function deletePrice(id) {
  const { error } = await db.from('price_rows').delete().eq('id', id);
  if (error) throw new Error(error.message);
}

/* ── الوسائط ───────────────────────────────────────────────────────────────── */
export function kindOf(file) {
  const type = String(file.type || '');
  if (type.startsWith('image/')) return 'image';
  if (type.startsWith('audio/')) return 'audio';
  if (type.startsWith('video/')) return 'video';
  const ext = String(file.name || '').split('.').pop().toLowerCase();
  if (['jpg', 'jpeg', 'png', 'webp', 'avif', 'gif'].includes(ext)) return 'image';
  if (['mp3', 'm4a', 'aac', 'ogg', 'wav'].includes(ext)) return 'audio';
  if (['mp4', 'webm', 'mov', 'm4v'].includes(ext)) return 'video';
  return null;
}

/** يبقي الأحرف العربية والأرقام والشرطات فقط، فيبقى المسار صالحًا كـ URL. */
export function safeName(name) {
  const base = String(name || 'file').split('/').pop();
  const dot = base.lastIndexOf('.');
  const stem = dot > 0 ? base.slice(0, dot) : base;
  const ext = dot > 0 ? base.slice(dot) : '';
  const clean = stem.replace(/[^\w؀-ۿ\-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60) || 'file';
  return clean + ext.toLowerCase().replace(/[^.\w]/g, '');
}

export function uuid() {
  return (crypto.randomUUID && crypto.randomUUID()) ||
    ('x'.repeat(32).replace(/x/g, () => Math.floor(Math.random() * 16).toString(16)));
}

async function readDuration(url, kind) {
  return new Promise((resolve) => {
    const node = document.createElement(kind === 'video' ? 'video' : 'audio');
    const done = (value) => { node.removeAttribute('src'); node.load(); resolve(value); };
    node.preload = 'metadata';
    node.onloadedmetadata = () => done(Number.isFinite(node.duration) ? Math.round(node.duration) : null);
    node.onerror = () => done(null);
    setTimeout(() => done(null), 8000);
    node.src = url;
  });
}

/** رفع ملف إلى مستودع media وإضافته لمكتبة اللوحة، وإرجاع كائن مرفق جاهز. */
export async function uploadMedia(file, sectionId, onProgress) {
  const kind = kindOf(file);
  if (!kind) throw new Error('نوع غير مدعوم: ' + (file.type || file.name));
  if (file.size > MAX_BYTES) throw new Error('حجم ' + file.name + ' أكبر من 25 MB.');
  const path = (sectionId || 'general') + '/' + uuid() + '/' + safeName(file.name);
  const { error } = await db.storage.from(BUCKET).upload(path, file, {
    contentType: file.type || 'application/octet-stream',
    cacheControl: '3600',
    upsert: false
  });
  if (error) throw new Error(error.message);
  const { data } = db.storage.from(BUCKET).getPublicUrl(path);
  const duration = kind === 'image' ? null : await readDuration(data.publicUrl, kind);
  const meta = {
    path,
    url: data.publicUrl,
    kind,
    bytes: file.size,
    label: safeName(file.name).replace(/\.\w+$/, ''),
    duration_seconds: duration,
    created_at: new Date().toISOString()
  };
  const { error: logError } = await db.from('media_library').upsert(meta, { onConflict: 'path' });
  if (logError) console.warn('-- NOTICE: رُفع الملف لكن لم يُسجَّل في المكتبة:', logError.message);
  return meta;
}

export async function deleteMedia(path) {
  const { error } = await db.storage.from(BUCKET).remove([path]);
  if (error) throw new Error(error.message);
  const { error: rowError } = await db.from('media_library').delete().eq('path', path);
  if (rowError) console.warn('-- NOTICE: حُذف الملف وبقي صفّه في المكتبة:', rowError.message);
}

/** تعديل بيانات وصفية فقط (تسمية/ملصق) دون إعادة رفع الملف. */
export async function saveMedia(meta) {
  const { error } = await db.from('media_library').upsert(
    { path: meta.path, url: meta.url, kind: meta.kind, bytes: meta.bytes, label: meta.label, duration_seconds: meta.duration_seconds, poster_url: meta.poster_url },
    { onConflict: 'path' }
  );
  if (error) throw new Error(error.message);
}

/* ── مزامنة الأسعار من المتصفح: تكفي جلسة الدخول، بلا أي مفتاح خارجي ───────── */
const FX_API = 'https://open.er-api.com/v6/latest/USD';
const GOLD_API = 'https://api.gold-api.com/price/XAU';
const GRAM_PER_OUNCE = 31.1034768;

/* ما يعرفه المستخدم المصري: كم جنيهاً مقابل وحدة العملة — تُعرض أولًا والقائمة تُستكمل تلقائيًا. */
const FX_WATCH = [
  ['USD', 'دولار أمريكي', '$'],
  ['EUR', 'يورو', '€'],
  ['SAR', 'ريال سعودي', '﷼'],
  ['AED', 'درهم إماراتي', 'د.إ'],
  ['KWD', 'دينار كويتي', 'د.ك'],
  ['GBP', 'جنيه إسترليني', '£'],
  ['TRY', 'ليرة تركية', '₺']
];

/* نفس arName في sync-prices.mjs: المتصفح يحمل بيانات CLDR العربية مثل Node. */
const NAMES_AR = typeof Intl.DisplayNames === 'function' ? new Intl.DisplayNames(['ar'], { type: 'currency' }) : null;

function arName(code) {
  if (!NAMES_AR) return code;
  try {
    return NAMES_AR.of(code) || code;
  } catch {
    return code;
  }
}

/* عملة تساوِ أقل من جنيه تُعرض بأربعة منازل، وإلا صارت 0.00. */
function money(value) {
  if (!Number.isFinite(value) || value <= 0) return null;
  return value.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: value < 1 ? 4 : 2 });
}

/** الواجهتان المفتوحتان تسمحان بالقراءة من المتصفح (access-control-allow-origin: *). */
async function openApi(url) {
  const res = await fetch(url, { signal: AbortSignal.timeout(30000) });
  if (!res.ok) throw new Error(url + ' → HTTP ' + res.status);
  return res.json();
}

async function writePrices(rows) {
  if (!rows.length) return;
  const { error } = await db.from('price_rows').upsert(rows, { onConflict: 'kind,code' });
  if (error) throw new Error(error.message);
}

/**
 * يجلب الأسعار لحظيًا ويكتبها في price_rows (نفس جدول prices.yml).
 * يُرجع { fx, gold, errors } — الأخطاء نصية لأن الجولة الناجحة جزئيًا مقبولة.
 */
export async function syncPrices(kind = 'both') {
  if (!db) throw new Error('سجّل الدخول إلى Supabase أولًا.');
  const wantFx = kind !== 'gold';
  const wantGold = kind !== 'fx';
  const result = { fx: 0, gold: 0, errors: [] };

  let usdRates = null;
  async function ratesFromUsd() {
    if (!usdRates) usdRates = (await openApi(FX_API)).rates || {};
    return usdRates;
  }
  async function egpPerUsd() {
    const base = Number((await ratesFromUsd()).EGP);
    if (!Number.isFinite(base) || base <= 0) throw new Error('لا سعر للجنيه في رد العملات');
    return base;
  }

  if (wantFx) {
    try {
      const rates = await ratesFromUsd();
      const base = await egpPerUsd();
      /* كل ما ترسله الواجهة، لا القائمة المختصرة فقط — نفس سلوك sync-prices.mjs. */
      const priced = Object.keys(rates).filter((code) => {
        const perUsd = Number(rates[code]);
        return code !== 'EGP' && Number.isFinite(perUsd) && perUsd > 0;
      });
      const watch = new Map(FX_WATCH.map(([code, name, symbol]) => [code, { name, symbol }]));
      const ordered = [
        ...FX_WATCH.map(([code]) => code).filter((code) => priced.includes(code)),
        ...priced.filter((code) => !watch.has(code)).sort()
      ];
      const rows = [];
      ordered.forEach((code, index) => {
        const value = money(base / Number(rates[code]));
        if (!value) return;
        const curated = watch.get(code);
        rows.push({
          kind: 'fx', code,
          name: curated ? curated.name : arName(code),
          symbol: curated ? curated.symbol : null,
          value, change: null, sort_order: index
        });
      });
      await writePrices(rows);
      result.fx = rows.length;
    } catch (error) {
      result.errors.push('العملات: ' + error.message);
    }
  }

  if (wantGold) {
    try {
      const ounce = await openApi(GOLD_API);
      const ounceUsd = Number(ounce?.price ?? ounce?.data?.price ?? ounce?.USD);
      if (!Number.isFinite(ounceUsd) || ounceUsd <= 0) throw new Error('لا سعر للأوقية في رد الذهب');
      const gram24 = (ounceUsd / GRAM_PER_OUNCE) * (await egpPerUsd());
      const gram21 = (gram24 * 21) / 24;
      const rows = [
        ['24', 'جرام ذهب عيار 24', gram24],
        ['22', 'جرام ذهب عيار 22', (gram24 * 22) / 24],
        ['21', 'جرام ذهب عيار 21', gram21],
        ['18', 'جرام ذهب عيار 18', (gram24 * 18) / 24],
        ['14', 'جرام ذهب عيار 14', (gram24 * 14) / 24],
        ['SOV', 'جنيه ذهب (8 جرام عيار 21)', gram21 * 8],
        ['HALF', 'نصف جنيه ذهب (4 جرام عيار 21)', gram21 * 4],
        ['XAU', 'أوقية الذهب عالميًا', null]
      ].map(([code, name, valueEgp], index) => ({
        kind: 'gold',
        code,
        name,
        symbol: code === 'XAU' ? '$' : 'ج.م',
        value: money(code === 'XAU' ? ounceUsd : valueEgp),
        change: null,
        sort_order: index
      })).filter((row) => row.value);
      await writePrices(rows);
      result.gold = rows.length;
    } catch (error) {
      result.errors.push('الذهب: ' + error.message);
    }
  }

  if (!result.fx && !result.gold && !result.errors.length) throw new Error('لم تُجلب أي أسعار.');
  return result;
}

/* ── وضع الاستعراض: نفس النموذج لكن من الملفات المنشورة (قراءة فقط) ───────── */
async function getJson(url) {
  const res = await fetch(url, { cache: 'no-store' });
  if (!res.ok) throw new Error(url + ' → ' + res.status);
  return res.json();
}

export async function loadDemoModel() {
  const config = await getJson('data/index.json');
  const sections = (config.sections || []).map((section) => {
    const source = section.source || {};
    const kind = source.kind || 'json';
    const expected = 'data/sections/' + section.id + '.json';
    return {
      id: section.id,
      title: section.title || section.id,
      subtitle: section.subtitle || null,
      icon: section.icon || 'article',
      layout: section.layout || 'list',
      source_kind: kind,
      feed_url: kind === 'json' && (!source.url || source.url === expected) ? null : (source.url || null),
      item_selector: source.selector || null,
      headers: source.headers || {},
      sort_order: Number.isFinite(section.order) ? section.order : 100,
      enabled: section.enabled !== false,
      show_on_home: section.home !== false,
      notify_default: !!(section.notifications && section.notifications.default),
      allow_breaking: !section.notifications || section.notifications.breaking !== false,
      items_source: section.managedBy === 'admin' ? 'admin' : 'file',
      note: null
    };
  });

  const items = [];
  for (const section of sections) {
    if (section.source_kind !== 'json') continue;
    let feed;
    try { feed = await getJson(section.feed_url || 'data/sections/' + section.id + '.json'); } catch (error) { continue; }
    const list = Array.isArray(feed.items) ? feed.items : [];
    section.note = feed.note || null;
    list.forEach((item, index) => {
      items.push({
        id: null,
        section_id: section.id,
        slug: item.id || null,
        title: item.title || 'بدون عنوان',
        subtitle: item.subtitle || null,
        body: item.body || null,
        image: item.image || null,
        image_credit: item.imageCredit || null,
        link: item.link || null,
        source_name: item.source && item.source.name || item.sourceName || null,
        source_url: item.source && item.source.url || item.sourceUrl || null,
        tags: item.tags || [],
        fields: item.fields || {},
        attachments: item.attachments || [],
        pinned: !!item.pinned,
        breaking: !!item.breaking,
        status: 'published',
        event_date: item.date || '',
        publish_at: null,
        published_at: null,
        sort_order: list.length - index
      });
    });
  }

  const legal = [];
  for (const key of ['privacy', 'terms']) {
    try {
      const doc = await getJson('data/legal/' + key + '.json');
      legal.push({ key, title: doc.title || key, body: doc.body || '' });
    } catch (error) { /* لا وثيقة */ }
  }

  const prices = [];
  for (const kind of ['fx', 'gold']) {
    try {
      const file = await getJson((kind === 'fx' ? config.prices && config.prices.fxUrl : config.prices && config.prices.goldUrl) || 'data/prices/' + kind + '.json');
      (file.rates || []).forEach((rate, index) => {
        prices.push({
          id: null, kind, code: String(rate.code ?? index), name: String(rate.name ?? ''),
          symbol: rate.symbol || null, value: String(rate.value ?? ''), change: rate.change || null, sort_order: index
        });
      });
    } catch (error) { /* لا ملف أسعار */ }
  }

  return {
    demo: true,
    settings: {
      id: 1,
      schema_version: config.schemaVersion || 1,
      brand: config.brand || {},
      digest: config.digest || {},
      prices: config.prices || {},
      notice: config.notice || null
    },
    sections,
    items,
    legal,
    prices,
    media: [],
    log: []
  };
}
