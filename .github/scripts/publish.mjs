#!/usr/bin/env node
/*
 * ناشر محتوى قرية أبو بدوي: يقرأ كل شيء من Supabase ويكتب الملفات التي
 * يقرأها تطبيق أندرويد وصفحة الويب من GitHub Pages.
 *
 *   جدول app_settings + sections  ← data/index.json
 *   جدول items                    ← data/sections/<section>.json   (managedBy: admin)
 *   جدول legal_docs               ← data/legal/privacy.json و terms.json
 *   جدول price_rows               ← data/prices/fx.json و gold.json
 *   جدول publish_log              ← سجل كل تشغيل
 *
 * يعمل داخل GitHub Action (جدولة كل ١٥ دقيقة أو Run workflow يدويًا)، ويمكن
 * تشغيله محليًا من داخل مجلد web/:
 *   SUPABASE_URL=… SUPABASE_SERVICE_KEY=… node .github/scripts/publish.mjs
 *
 * بلا أي اعتماديات — Node 20 فقط.
 */

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';

/* قيمة السرّ تُنسخ أحيانًا ومعها مسافة أو رمز خفي أو مقطع /rest/v1 زائد، فترفضها
   بوابة Supabase بخطأ PGRST125 الذي لا يوحي بإطلاقًا أن المشكلة في الإعداد. */
const RAW_URL = String(process.env.SUPABASE_URL || '').replace(/[\s\u0000-\u001f\u200b-\u200f\ufeff]/g, '');
const SUPABASE_URL = RAW_URL ? new URL(RAW_URL).origin : RAW_URL;
const SERVICE_KEY = String(process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || '')
  .replace(/[\s\u0000-\u001f\u200b-\u200f\ufeff]/g, '');
const DATA_DIR = process.env.DATA_DIR || 'data';
const MAX_ITEMS = Number(process.env.MAX_ITEMS || 80);
const ALLOW_EMPTY = process.env.ALLOW_EMPTY === '1';
const FORCE = process.env.FORCE === '1';
const COMMIT_SHA = process.env.GITHUB_SHA || null;

if (SUPABASE_URL && !/^https:\/\/[A-Za-z0-9.-]+$/.test(SUPABASE_URL)) {
  console.error('\n-- ERROR: SUPABASE_URL في أسرار GitHub يجب أن يكون نطاق المشروع وحده مثل\n' +
    '   https://xxxx.supabase.co — القيمة بعد التنظيف: ' + JSON.stringify(SUPABASE_URL) + '\n');
  process.exit(1);
}

const NOW = new Date();
const nowIso = NOW.toISOString().replace(/\.\d+Z$/, 'Z');
const dayIso = nowIso.slice(0, 10);

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('\n-- ERROR: ناقص: SUPABASE_URL / SUPABASE_SERVICE_KEY — ' +
    'أضفهما في Settings ← Secrets and variables ← Actions.\n');
  process.exit(1);
}

function fail(message) {
  throw new Error(message);
}

function notice(message) {
  console.log('-- NOTICE: ' + message);
}

/* ── 1) قوائم بيضاء للتنظيف ──────────────────────────────────────────────── */
const ALLOWED_TAGS = new Set([
  'p', 'br', 'h2', 'h3', 'h4', 'strong', 'b', 'em', 'i', 'u',
  'ul', 'ol', 'li', 'a', 'blockquote', 'span'
]);
const DANGEROUS = ['script', 'style', 'iframe', 'object', 'embed', 'link', 'meta', 'form', 'input', 'svg', 'math'];
const SAFE_HREF = /^(https?:|mailto:)/i;
const ABSOLUTE = /^https?:\/\//i
const MEDIA_KINDS = new Set(['image', 'video', 'audio']);
/* مسار نسبي داخل الموقع: بلا بروتوكول ولا ../ ولا // — التطبيق يحوّله إلى مطلق مقابل baseUrl. */
const SAFE_RELATIVE = /^[A-Za-z0-9؀-ۿ._\-\/]+\.(svg|png|jpe?g|webp|gif|avif|mp3|mp4|webm|m4a|aac|ogg|wav)$/i;

function escapeAttr(value) {
  return value.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

/* عنوان خام في نص مقروء: http/https أو www. أو بريد — بلا علامات ترقيم ذيل. */
const BARE_LINK = /(?:https?:\/\/|www\.)[^\s<>"'،؛]+|[A-Za-z0-9._%+\-']+@[\w-]+(?:\.[\w-]+)+/g;
const TRAILING_PUNCTUATION = /[.,;:!?)}\]"'«»،؛؟]+$/;

function bareHref(found) {
  if (/^www\./i.test(found)) return 'https://' + found;
  if (found.includes('@')) return 'mailto:' + found;
  return found;
}

/* `(https://example.com/x)` ← القوس ملك الجملة، لكن
   `https://ar.wikipedia.org/wiki/_(عزبة_بدوي)` ← قوساه جزء من العنوان نفسه. */
function trimUrl(found) {
  const cut = found.replace(TRAILING_PUNCTUATION, '');
  const opens = (found.match(/\(/g) || []).length;
  const closes = (cut.match(/\)/g) || []).length;
  return opens > closes ? found : cut;
}

/** يحوّل العناوين المكتوبة كنص إلى وسوم <a>، ويتخطّى ما هو داخل رابط موجود أصلًا. */
function linkifyText(html) {
  let insideLink = 0;
  return html.split(/(<\/?[a-z][a-z0-9]*\b[^>]*>)/gi).map((part) => {
    if (/^<a\b/i.test(part)) { insideLink += 1; return part; }
    if (/^<\/a[\s>]/i.test(part)) { insideLink = Math.max(0, insideLink - 1); return part; }
    if (insideLink || part.startsWith('<')) return part;
    return part.replace(BARE_LINK, (match) => {
      const url = trimUrl(match);
      if (!url) return match;
      /* النص وصل بعد التنقية بلا وسوم ولا علامات اقتباس، فيُدرج كما هو. */
      return '<a href="' + bareHref(url) + '" rel="noopener noreferrer nofollow" target="_blank">' +
        url + '</a>' + match.slice(url.length);
    });
  }).join('');
}

/* صفحة الويب تدرج المتن بـ innerHTML، فالتنقية هنا شرط أمان لا تجميل. */
function sanitizeHtml(raw) {
  if (!raw) return '';
  let html = String(raw).replace(/<!--[\s\S]*?-->/g, '');
  DANGEROUS.forEach((tag) => {
    html = html.replace(new RegExp('<\\s*' + tag + '\\b[\\s\\S]*?<\\s*/\\s*' + tag + '\\s*>', 'gi'), '');
    html = html.replace(new RegExp('<\\s*/?\\s*' + tag + '\\b[^>]*>', 'gi'), '');
  });
  /* stack يمنع وسم إغلاق يتيم بعد حذف وسمه الافتتاحي (مثل <a href="javascript:…">). */
  const stack = [];
  const clean = html.replace(/<\/?([a-zA-Z][a-zA-Z0-9]*)\b([^>]*)>/g, (match, name, rest) => {
    const tag = name.toLowerCase();
    if (!ALLOWED_TAGS.has(tag)) return '';
    if (match.charAt(1) === '/') {
      if (!stack.length || stack[stack.length - 1] !== tag) return '';
      stack.pop();
      return '</' + tag + '>';
    }
    if (tag === 'br') return '<br>';
    if (tag === 'a') {
      const hit = /\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i.exec(rest);
      const href = ((hit && (hit[1] || hit[2] || hit[3])) || '').trim();
      if (!SAFE_HREF.test(href)) return '';
      stack.push('a');
      return '<a href="' + escapeAttr(href) + '" rel="noopener noreferrer nofollow" target="_blank">';
    }
    stack.push(tag);
    return '<' + tag + '>';
  });
  return linkifyText(clean);
}

function plain(raw, limit = 300) {
  return String(raw == null ? '' : raw).replace(/\s+/g, ' ').trim().slice(0, limit);
}

function safeAsset(raw) {
  const url = plain(raw, 600);
  if (!url) return null;
  if (ABSOLUTE.test(url)) return url;
  if (url.startsWith('//') || url.includes('..') || url.includes(':')) return null;
  return SAFE_RELATIVE.test(url) ? url : null;
}

function guessKind(url) {
  const clean = String(url || '').split('?')[0].toLowerCase();
  if (/\.(mp4|webm|mov|m4v|mkv)$/.test(clean)) return 'video';
  if (/\.(mp3|m4a|aac|ogg|wav)$/.test(clean)) return 'audio';
  return 'image';
}

/* ── 2) Supabase REST بمفتاح service_role ─────────────────────────────────── */
/* بوابة Supabase ترجع أحيانًا 404/PGRST125 أو 5xx على مسار سليم من مستضيف
   GitHub، والاستعلام نفسه ينجح من جهاز آخر، فتُعاد المحاولة قبل الفشل. */
const ATTEMPTS = 3;
const sleep = (ms) => new Promise((done) => setTimeout(done, ms));

async function request(table, params, init = {}) {
  const query = new URLSearchParams(params).toString();
  const url = SUPABASE_URL + '/rest/v1/' + table + (query ? '?' + query : '');
  let res, lastError = '';
  for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
    try {
      res = await fetch(url, {
        ...init,
        headers: {
          apikey: SERVICE_KEY,
          Authorization: 'Bearer ' + SERVICE_KEY,
          'Content-Type': 'application/json',
          ...(init.headers || {})
        },
        signal: AbortSignal.timeout(60000)
      });
      if (res.ok) break;
      lastError = 'Supabase رجّع ' + res.status + ': ' + (await res.text()).slice(0, 240);
      if (res.status !== 404 && res.status < 500) attempt = ATTEMPTS;
    } catch (error) {
      res = null;
      lastError = 'تعذّر الوصول إلى Supabase: ' + error.message;
    }
    if (attempt < ATTEMPTS) {
      notice('إعادة محاولة /rest/v1/' + table + ' (' + (attempt + 1) + '/' + ATTEMPTS + '): ' + lastError);
      await sleep(attempt * 2000);
    }
  }
  if (!res || !res.ok) {
    fail('فشل /rest/v1/' + table + ' — الرابط: ' + url + ' — ' + lastError);
  }
  if ((init.method || 'GET') === 'HEAD' || res.status === 204) return null;
  const text = await res.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch (error) {
    fail('ردّ غير متوقع من /rest/v1/' + table);
  }
}

const AUTH_HEADERS = { apikey: SERVICE_KEY, Authorization: 'Bearer ' + SERVICE_KEY };

async function logPublish(status, message, sectionsWritten, itemsWritten) {
  if (!SUPABASE_URL || !SERVICE_KEY) return;
  try {
    await fetch(SUPABASE_URL + '/rest/v1/publish_log', {
      method: 'POST',
      headers: { ...AUTH_HEADERS, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
      body: JSON.stringify({
        status,
        message: String(message || '').slice(0, 500),
        sections_written: sectionsWritten,
        items_written: itemsWritten,
        commit_sha: COMMIT_SHA ? COMMIT_SHA.slice(0, 40) : null
      }),
      signal: AbortSignal.timeout(20000)
    });
  } catch (error) {
    console.log('-- NOTICE: لم يُكتب سجل النشر: ' + error.message);
  }
}

/* ── 3) تحويل صف items إلى عنصر وفق عقد index.json / data-ab-* ───────────── */
function toAttachments(raw) {
  const list = Array.isArray(raw) ? raw : [];
  return list.reduce((acc, entry) => {
    const url = safeAsset(entry && (entry.url || entry.src));
    if (!url) return acc;
    const kind = MEDIA_KINDS.has(entry.type) ? entry.type : guessKind(url);
    const out = { type: kind, url };
    const poster = safeAsset(entry && entry.poster);
    if (kind === 'video' && poster) out.poster = poster;
    const label = plain(entry && entry.label, 80);
    if (label) out.label = label;
    const duration = Number(entry && entry.duration);
    if (Number.isFinite(duration) && duration > 0) out.duration = Math.round(duration);
    acc.push(out);
    return acc;
  }, []).slice(0, 12);
}

function shortIdFromUuid(uuid) {
  return String(uuid || '').replace(/-/g, '').slice(0, 12);
}

function toItem(row, index) {
  const attachments = toAttachments(row.attachments);
  const firstImage = attachments.find((a) => a.type === 'image');
  const item = {
    id: plain(row.slug, 60) || shortIdFromUuid(row.id) || ('item-' + index),
    title: plain(row.title, 200) || 'بدون عنوان'
  };
  /* تاريخ العرض نصًا كما كتبه المحرر؛ بلا تاريخ لا نختلق تاريخ اليوم. */
  const date = plain(row.event_date || String(row.published_at || '').slice(0, 10), 40);
  if (date) item.date = date;
  const summary = plain(row.subtitle, 240);
  if (summary) item.subtitle = summary;
  const image = safeAsset(row.image) || (firstImage ? firstImage.url : null);
  if (image) item.image = image;
  const credit = plain(row.image_credit, 120);
  if (credit) item.imageCredit = credit;
  const body = sanitizeHtml(row.body);
  if (body) item.body = body;
  const tags = Array.isArray(row.tags) ? row.tags : [];
  if (tags.length) item.tags = tags.map((tag) => plain(tag, 40)).filter(Boolean).slice(0, 8);
  if (row.pinned) item.pinned = true;
  if (row.breaking) item.breaking = true;
  const link = plain(row.link, 500);
  const sourceUrl = plain(row.source_url || row.link, 500);
  const sourceName = plain(row.source_name, 120);
  if (link && ABSOLUTE.test(link)) item.link = link;
  if (sourceName || (sourceUrl && ABSOLUTE.test(sourceUrl))) {
    item.source = { name: sourceName || 'الرابط الأصلي', url: sourceUrl || link || '' };
  }
  const fields = row.fields && typeof row.fields === 'object' && !Array.isArray(row.fields) ? row.fields : {};
  const cleaned = {};
  Object.keys(fields).slice(0, 10).forEach((key) => {
    const k = plain(key, 40);
    const v = plain(fields[key], 200);
    if (k && v) cleaned[k] = v;
  });
  if (Object.keys(cleaned).length) item.fields = cleaned;
  if (attachments.length) item.attachments = attachments;
  return item;
}

/* ── 4) index.json ────────────────────────────────────────────────────────── */
const LAYOUTS = new Set(['richArticle', 'list', 'cards', 'profiles', 'offers', 'ads', 'rates', 'directory']);
const KINDS = new Set(['json', 'rss', 'html', 'fx', 'gold', 'inline']);
const CLAMP = (value, min, max, fallback) => {
  const n = Number(value);
  return Number.isFinite(n) ? Math.round(Math.min(max, Math.max(min, n))) : fallback;
};

function sectionFileOf(section) {
  return section.feed_url || path.posix.join(DATA_DIR, 'sections', section.id + '.json');
}

function renderIndex(settings, sectionRows, legalRows) {
  const brand = settings.brand && typeof settings.brand === 'object' ? settings.brand : {};
  const digest = settings.digest && typeof settings.digest === 'object' ? settings.digest : {};
  const prices = settings.prices && typeof settings.prices === 'object' ? settings.prices : {};
  const knownIds = new Set(sectionRows.map((s) => s.id));
  const legalTitle = (key, fallback) => {
    const row = legalRows.find((doc) => doc.key === key);
    return plain((row && row.title) || fallback, 120) || fallback;
  };

  const out = {
    schemaVersion: CLAMP(settings.schema_version, 1, 99, 1),
    generatedAt: nowIso,
    notice: plain(settings.notice, 240) || null,
    brand: {
      name: plain(brand.name, 120) || 'أبو بدوي',
      tagline: plain(brand.tagline, 200),
      logoUrl: safeAsset(brand.logoUrl) || null,
      /* التطبيق يقبل seedColor أو primaryColor — نكتب الاثنين لصفحة الويب أيضًا. */
      primaryColor: /^#[0-9a-f]{6}$/i.test(String(brand.primaryColor || brand.seedColor || ''))
        ? String(brand.primaryColor || brand.seedColor) : null,
      supportEmail: /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(brand.supportEmail || '')) ? plain(brand.supportEmail, 120) : null,
      fontUrl: ABSOLUTE.test(String(brand.fontUrl || '')) ? plain(brand.fontUrl, 400) : null,
      fontFamily: plain(brand.fontFamily, 60) || null
    },
    digest: {
      defaultSections: (Array.isArray(digest.defaultSections) ? digest.defaultSections : [])
        .map((id) => plain(id, 60)).filter((id) => knownIds.has(id)),
      hour: CLAMP(digest.hour, 0, 23, 7),
      minute: CLAMP(digest.minute, 0, 59, 30)
    },
    prices: {
      fxUrl: safeAsset(prices.fxUrl) || path.posix.join(DATA_DIR, 'prices', 'fx.json'),
      goldUrl: safeAsset(prices.goldUrl) || path.posix.join(DATA_DIR, 'prices', 'gold.json'),
      liveFxApi: ABSOLUTE.test(String(prices.liveFxApi || '')) ? plain(prices.liveFxApi, 400) : null,
      liveGoldApi: ABSOLUTE.test(String(prices.liveGoldApi || '')) ? plain(prices.liveGoldApi, 400) : null
    },
    legal: {
      privacy: { title: legalTitle('privacy', 'سياسة الخصوصية'), url: path.posix.join(DATA_DIR, 'legal', 'privacy.json') },
      terms: { title: legalTitle('terms', 'شروط الاستخدام'), url: path.posix.join(DATA_DIR, 'legal', 'terms.json') }
    },
    sections: sectionRows
      .slice()
      .sort((a, b) => (a.sort_order - b.sort_order) || String(a.id).localeCompare(String(b.id)))
      .map((row) => {
        const kind = KINDS.has(row.source_kind) ? row.source_kind : 'json';
        const section = {
          id: plain(row.id, 60),
          title: plain(row.title, 120) || plain(row.id, 120),
          icon: plain(row.icon, 40) || 'article',
          layout: LAYOUTS.has(row.layout) ? row.layout : 'list',
          order: CLAMP(row.sort_order, 0, 9999, 100),
          home: row.show_on_home !== false,
          enabled: row.enabled !== false
        };
        const subtitle = plain(row.subtitle, 200);
        if (subtitle) section.subtitle = subtitle;
        const managed = row.items_source === 'admin' && kind === 'json';
        if (managed) section.managedBy = 'admin';
        const source = { kind };
        if (kind === 'json') source.url = sectionFileOf(row);
        if ((kind === 'rss' || kind === 'html') && ABSOLUTE.test(String(row.feed_url || ''))) {
          source.url = plain(row.feed_url, 500);
          if (plain(row.item_selector, 120)) source.selector = plain(row.item_selector, 120);
          const headers = row.headers && typeof row.headers === 'object' && !Array.isArray(row.headers) ? row.headers : {};
          const cleanHeaders = {};
          Object.keys(headers).slice(0, 6).forEach((key) => {
            const value = plain(headers[key], 200);
            if (plain(key, 40) && value) cleanHeaders[plain(key, 40)] = value;
          });
          if (Object.keys(cleanHeaders).length) source.headers = cleanHeaders;
        }
        section.source = source;
        section.notifications = { default: row.notify_default === true, breaking: row.allow_breaking !== false };
        return section;
      })
  };

  if (!out.brand.tagline) delete out.brand.tagline;
  return out;
}

/* ── 5) الكتابة ───────────────────────────────────────────────────────────── */
async function writeJson(file, payload) {
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, JSON.stringify(payload, null, 2) + '\n', 'utf8');
}

async function readExisting(file) {
  if (!existsSync(file)) return null;
  try {
    return JSON.parse(await readFile(file, 'utf8'));
  } catch (error) {
    return null;
  }
}

function latestIso(rows) {
  return rows
    .map((row) => String(row.updated_at || ''))
    .filter(Boolean)
    .sort()
    .reverse()[0] || nowIso;
}

/* ── 6) الجري والتشكيل ────────────────────────────────────────────────────── */
async function main() {
  const [settingsRows, sectionRows, itemRows, legalRows, priceRows] = await Promise.all([
    request('app_settings', { select: '*', limit: '1' }),
    request('sections', { select: '*', order: 'sort_order.asc' }),
    request('items', {
      select: 'section_id,slug,title,subtitle,body,image,image_credit,link,source_name,source_url,' +
        'tags,fields,attachments,pinned,breaking,status,event_date,publish_at,published_at,sort_order,id,updated_at',
      status: 'in.(published,scheduled)',
      order: 'sort_order.desc,published_at.desc'
    }),
    request('legal_docs', { select: 'key,title,body,updated_at' }),
    request('price_rows', { select: 'kind,code,name,symbol,value,change,sort_order,updated_at', order: 'kind.asc,sort_order.asc' })
  ]);

  if (!Array.isArray(sectionRows)) fail('ردّ غير متوقع من /rest/v1/sections');
  if (!Array.isArray(settingsRows) || !settingsRows.length) {
    fail('جدول app_settings فارغ — نفّذ tools/supabase-setup.sql ثم tools/seed-content.sql.');
  }
  if (!sectionRows.length && !FORCE) {
    fail('جدول sections فارغ: النشر الآن سيمحو إعداد التطبيق بالكامل (data/index.json). ' +
      'نفّذ seed-content.sql أولًا، أو شغّل بـ FORCE=1 إن كنت تبدأ من الصفر فعلًا.');
  }

  /* العناصر المجدولة التي حان وقتها تُنشر ويُرقّى حالها في القاعدة. */
  const due = [];
  const live = (itemRows || []).filter((row) => {
    if (row.status === 'published') return true;
    const at = Date.parse(String(row.publish_at || ''));
    if (!Number.isNaN(at) && at <= NOW.getTime()) {
      due.push(row.id);
      return true;
    }
    return false;
  });
  if (due.length) {
    try {
      await request('items', { id: 'in.("' + due.join('","') + '")' }, {
        method: 'PATCH',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({ status: 'published', published_at: nowIso })
      });
      notice('رُقّي ' + due.length + ' عنصرًا مجدولًا إلى published.');
    } catch (error) {
      notice('لم تُحدَّث حالة العناصر المجدولة في القاعدة (سيُنشر محتواها الآن على أي حال): ' + error.message);
    }
  }

  const settings = settingsRows[0];
  const indexPayload = renderIndex(settings, sectionRows, legalRows || []);
  await writeJson(path.join(DATA_DIR, 'index.json'), indexPayload);
  console.log('✓ index.json ← ' + indexPayload.sections.length + ' قسمًا');

  /* 6أ) أقسام json المُدارة من اللوحة */
  const managed = sectionRows.filter((row) => row.items_source === 'admin' && (row.source_kind || 'json') === 'json');
  const grouped = new Map();
  live.forEach((row) => {
    const id = plain(row.section_id, 60);
    if (!id) return;
    if (!grouped.has(id)) grouped.set(id, []);
    grouped.get(id).push(row);
  });
  const knownSections = new Set(managed.map((row) => plain(row.id, 60)));
  for (const id of grouped.keys()) {
    if (!knownSections.has(id)) {
      notice('عناصر في قسم لا تُنشر: ' + id + ' — اجعل items_source=admin في لوحة الأقسام ليُكتب ملفه.');
    }
  }

  let sectionsWritten = 0;
  let itemsWritten = 0;
  for (const section of managed) {
    const id = plain(section.id, 60);
    if (!id) continue;
    const rows = (grouped.get(id) || []).slice(0, MAX_ITEMS);
    const file = path.resolve(process.cwd(), sectionFileOf(section));
    const items = rows.map((row, index) => toItem(row, index));
    items.forEach((item, i) => {
      if (!item.id || items.findIndex((x) => x.id === item.id) !== i) {
        item.id = id + '-' + (shortIdFromUuid(rows[i].id) || i);
      }
    });

    if (!items.length) {
      const previous = await readExisting(file);
      if (previous && Array.isArray(previous.items) && previous.items.length && !ALLOW_EMPTY) {
        notice('القسم ' + id + ' يحوي ' + previous.items.length + ' عنصرًا ولا عناصر منشورة الآن — تُرِك الملف كما هو. ' +
          'لإفراغه فعلًا شغّل بـ ALLOW_EMPTY=1.');
        continue;
      }
    }

    const payload = { schemaVersion: 1, sectionId: id, updatedAt: nowIso };
    const note = plain(section.note, 400);
    if (note) payload.note = note;
    payload.items = items;
    await writeJson(file, payload);
    sectionsWritten++;
    itemsWritten += items.length;
    console.log('✓ ' + id + ' ← ' + items.length + ' عنصر');
  }

  /* 6ب) القوانين */
  let legalWritten = 0;
  for (const key of ['privacy', 'terms']) {
    const row = (legalRows || []).find((doc) => doc.key === key);
    if (!row || !String(row.body || '').trim()) {
      notice('لا نص ' + key + ' في legal_docs — تُرِك ملفه الحالي كما هو.');
      continue;
    }
    await writeJson(path.join(DATA_DIR, 'legal', key + '.json'), {
      schemaVersion: 1,
      title: plain(row.title, 120) || (key === 'privacy' ? 'سياسة الخصوصية' : 'شروط الاستخدام'),
      updatedAt: dayIso,
      body: sanitizeHtml(row.body)
    });
    legalWritten++;
    console.log('✓ legal/' + key + '.json');
  }

  /* 6ت) الأسعار: من price_rows إلى الملفين اللذين يقرأهما التطبيق */
  const priceSettings = settings.prices && typeof settings.prices === 'object' ? settings.prices : {};
  let pricesWritten = 0;
  for (const kind of ['fx', 'gold']) {
    const rows = (priceRows || []).filter((row) => row.kind === kind);
    const file = path.join(DATA_DIR, 'prices', kind + '.json');
    if (!rows.length) {
      notice('لا صفوف أسعار لنوع ' + kind + ' في price_rows — تُرِك ' + path.posix.basename(file) + ' كما هو.');
      continue;
    }
    const section = sectionRows.find((row) => row.source_kind === kind);
    const title = plain(section && section.title, 120) || (kind === 'fx' ? 'أسعار العملات' : 'أسعار الذهب');
    const payload = {
      schemaVersion: 1,
      title,
      updatedAt: latestIso(rows),
      rates: rows.slice(0, 40).map((row) => {
        const rate = { code: plain(row.code, 30), name: plain(row.name, 120) };
        const symbol = plain(row.symbol, 20);
        if (symbol) rate.symbol = symbol;
        rate.value = plain(row.value, 60);
        const change = plain(row.change, 60);
        if (change) rate.change = change;
        return rate;
      })
    };
    if (kind === 'fx') payload.base = plain(priceSettings.fxBase, 10) || 'EGP';
    const disclaimer = plain(priceSettings[kind + 'Disclaimer'], 240);
    if (disclaimer) payload.disclaimer = disclaimer;
    await writeJson(file, payload);
    pricesWritten++;
    console.log('✓ prices/' + kind + '.json ← ' + payload.rates.length + ' صف');
  }

  const summary = 'أقسام ' + sectionsWritten + '، عناصر ' + itemsWritten +
    '، قوانين ' + legalWritten + '، أسعار ' + pricesWritten;
  const nothingWritten = sectionsWritten + legalWritten + pricesWritten === 0;
  await logPublish(nothingWritten ? 'error' : 'ok', summary, sectionsWritten, itemsWritten);
  console.log('\nتم النشر: ' + summary + ' (' + live.length + ' عنصرًا منشورًا في القاعدة).');
  if (nothingWritten) fail('لم تُكتب أي ملف — راجع الرسائل أعلاه.');
}

try {
  await main();
} catch (error) {
  console.error('\n-- ERROR: ' + (error && error.message ? error.message : String(error)) + '\n');
  await logPublish('error', error && error.message ? error.message : String(error), 0, 0);
  process.exit(1);
}
