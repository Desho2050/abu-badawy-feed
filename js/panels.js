/* اللوحات السبع + سجل النشر. كل لوحة تقرأ ctx.model وتكتب عبر api فقط،
   وتبقى حالة الواجهة (فلترات/محرِّر مفتوح) في ui أعلى الملف حتى لا تضيع بعد التحديث. */

import { el, clear, toast, field, input, checkbox, select, card, stateLine, ask } from './dom.js';
import * as api from './db.js';

export const PANELS = {
  overview: { title: 'نظرة عامة', sub: 'حالة المحتوى وما ينقص قبل النشر', render: overviewPanel },
  sections: { title: 'الأقسام', sub: 'إنشاء الأقسام وترتيبها ومصادرها وإشعاراتها', render: sectionsPanel },
  items: { title: 'العناصر', sub: 'منشورات نصية وصور وصوت وفيديو: مسودة أو مجدول أو منشور', render: itemsPanel },
  media: { title: 'الوسائط', sub: 'ملفات مستودع media المستخدمة في العناصر', render: mediaPanel },
  prices: { title: 'الأسعار', sub: 'صفوف أسعار العملات والذهب وإعدادات المزامنة', render: pricesPanel },
  legal: { title: 'القوانين', sub: 'سياسة الخصوصية وشروط الاستخدام', render: legalPanel },
  settings: { title: 'المظهر والإعدادات', sub: 'العلامة، الملخص اليومي، والمحررون', render: settingsPanel },
  log: { title: 'سجل النشر', sub: 'آخر تشغيلات ناشر GitHub Actions', render: logPanel }
};

/* لا زر نشر يدوي في اللوحة: النشر مجدول في مستودع الملفات، ودخول Supabase يكفي للتحرير. */
export const AUTO_PUBLISH = 'النشر التلقائي كل ' + api.PUBLISH_EVERY_MINUTES + ' دقائق';

/* حالة مرشّحات اللوحات؛ يقرأها شريط الأقسام في app.js فيبقى الجانبان متزامنين. */
export const ui = {
  sections: { editing: null },
  items: { section: '', status: '', q: '', editing: null },
  media: { kind: '', q: '' },
  prices: { kind: 'fx', q: '' },
  legal: { key: 'privacy' }
};

/* ── مساعدات ───────────────────────────────────────────────────────────────── */
function button(label, kind, onclick) {
  return el('button', { class: 'btn ' + (kind || ''), onclick }, label);
}

function tiny(label, onclick, title) {
  return el('button', { class: 'iconbtn', title: title || label, onclick }, label);
}

function td(content, cls) {
  const cell = el('td', cls ? { class: cls } : {});
  if (content === null || content === undefined) return cell;
  cell.append(content.nodeType ? content : document.createTextNode(String(content)));
  return cell;
}

function tableNode(head, rows) {
  return el('div', { class: 'wrap' }, el('table', { class: 'table' }, [
    el('thead', {}, el('tr', {}, head.map((h) => el('th', { text: h })))),
    el('tbody', {}, rows)
  ]));
}

function tag(text, cls) {
  return el('span', { class: 'tag ' + (cls || ''), text });
}

function parsePairs(text) {
  const out = {};
  String(text || '').split(/\r?\n/).forEach((line) => {
    const i = line.search(/[:=]/);
    if (i < 1) return;
    const k = line.slice(0, i).trim();
    const v = line.slice(i + 1).trim();
    if (k && v) out[k] = v;
  });
  return out;
}

function pairsText(obj) {
  return Object.entries(obj || {}).map(([k, v]) => k + ': ' + v).join('\n');
}

function fmtBytes(value) {
  const n = Number(value) || 0;
  if (n < 1024) return n + ' B';
  if (n < 1048576) return (n / 1024).toFixed(0) + ' KB';
  return (n / 1048576).toFixed(1) + ' MB';
}

/* عدد ومعدود بالعربية: ١ و٢ بلا رقم، ٣–١٠ جمع قلة، وما فوق مفرد منصوب. */
function arWord(n, forms) {
  const v = Math.abs(Number(n) || 0);
  if (v === 1) return forms.one;
  if (v === 2) return forms.two;
  const mod = v % 100;
  return mod >= 3 && mod <= 10 ? forms.few : forms.many;
}

function arCount(n, forms) {
  const v = Number(n) || 0;
  return v <= 2 ? arWord(v, forms) : v + ' ' + arWord(v, forms);
}

/* مثل arCount لكن بصيغة النفي عند الصفر. */
function bucket(n, forms) {
  const v = Number(n) || 0;
  return v ? arCount(v, forms) : 'لا ' + forms.few;
}

const RTF = new Intl.RelativeTimeFormat('ar', { numeric: 'auto' });
function relTime(iso) {
  const t = Date.parse(String(iso || ''));
  if (Number.isNaN(t)) return '—';
  const diff = (t - Date.now()) / 1000;
  const abs = Math.abs(diff);
  if (abs < 3600) return RTF.format(Math.round(diff / 60), 'minute');
  if (abs < 86400) return RTF.format(Math.round(diff / 3600), 'hour');
  if (abs < 2592000) return RTF.format(Math.round(diff / 86400), 'day');
  return new Date(t).toLocaleDateString('ar-EG');
}

/** يحوّل قيمة datetime-local إلى UTC صالح لعقدها، والعكس عند العرض. */
function toIso(localValue) {
  const t = Date.parse(String(localValue || ''));
  return Number.isNaN(t) ? null : new Date(t).toISOString();
}
function toLocal(iso) {
  const t = Date.parse(String(iso || ''));
  if (Number.isNaN(t)) return '';
  const d = new Date(t);
  const pad = (n) => String(n).padStart(2, '0');
  return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + 'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

const OK_TAGS = new Set(['P', 'BR', 'H2', 'H3', 'H4', 'STRONG', 'B', 'EM', 'I', 'U', 'UL', 'OL', 'LI', 'A', 'BLOCKQUOTE', 'SPAN']);
const DROP_TAGS = new Set(['SCRIPT', 'STYLE', 'IFRAME', 'OBJECT', 'EMBED', 'LINK', 'META', 'FORM', 'INPUT', 'SVG', 'MATH']);

/* معاينة بنفس قوة المُنقِّي في ناشر GitHub: لا سكربتات ولا معالِجات أحداث. */
function previewNode(html) {
  const host = el('div', { class: 'preview' });
  const doc = new DOMParser().parseFromString(String(html || '<p>لا متن بعد.</p>'), 'text/html');
  copyChildren(host, doc.body, false);
  return host;
}

/* نفس قواعد linkifyText في publish.mjs: عنوان خام في النص يصير رابطًا قابلًا للنقر. */
const BARE_LINK = /(?:https?:\/\/|www\.)[^\s<>"'،؛]+|[A-Za-z0-9._%+\-']+@[\w-]+(?:\.[\w-]+)+/g;

function bareHref(found) {
  if (/^www\./i.test(found)) return 'https://' + found;
  return found.includes('@') ? 'mailto:' + found : found;
}

/* نفس trimUrl في publish.mjs: الفاصل اللاحق يُقتطع حرفًا حرفًا، ولا يُحذف قوسٌ
   يترك شريكه بلا مقابل — قواسا عنوان ويكيبيديا جزء منه. */
const TRAILER = /[.,;:!?)}\]"'«»،؛؟]$/;

function trimUrl(found) {
  let cut = found;
  while (cut.length > 1 && TRAILER.test(cut)) {
    const next = cut.slice(0, -1);
    if ((next.match(/\(/g) || []).length > (next.match(/\)/g) || []).length) break;
    cut = next;
  }
  return cut;
}

/* نفس linkLabel في publish.mjs: الرابط يُعرض بالنطاق وآخر مقطع مفيد، لا بعنوان مُشفَّر طويل. */
const LABEL_LIMIT = 64;

function decodeSegment(segment) {
  try {
    return decodeURIComponent(segment.replace(/\+/g, ' '));
  } catch {
    return segment;
  }
}

function linkLabel(url) {
  if (!/^[a-z][\w+.-]*:\/\//i.test(url) && url.includes('@')) return url;
  let parsed;
  try {
    parsed = new URL(bareHref(url));
  } catch {
    return url;
  }
  if (!/^https?:$/.test(parsed.protocol)) return url;
  const host = parsed.hostname.replace(/^www\./i, '');
  const segments = parsed.pathname.split('/').filter(Boolean);
  let last = decodeSegment(segments[segments.length - 1] || '');
  last = last
    .replace(/\.(x?html?|php|aspx?|jsp|shtml)$/i, '')
    .replace(/[-_]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (!last || last.length < 3 || /^\d+$/.test(last) || last.toLowerCase() === 'index') return host;
  const label = last.length > LABEL_LIMIT ? last.slice(0, LABEL_LIMIT).trimEnd() + '…' : last;
  return host + ' › ' + label;
}

/* أسماء الصفحات التي يجلبها الناشر من og:title وتُحفظ في link_previews؛ المعاينة
   تعرض الاسم نفسه الذي سيراه القارئ في التطبيق، لا اسمًا تقريبيًا من المسار. */
const PREVIEW_LIMIT = 72;
let linkTitles = new Map();

export function setLinkPreviews(rows) {
  const next = new Map();
  for (const row of rows || []) {
    const title = String(row.title || '').replace(/\s+/g, ' ').trim();
    if (!row.url || !title) continue;
    const site = String(row.site_name || '').replace(/\s+/g, ' ').trim();
    const named = site && !title.toLowerCase().includes(site.toLowerCase()) ? site + ': ' + title : title;
    next.set(row.url, named.length > PREVIEW_LIMIT ? named.slice(0, PREVIEW_LIMIT).trimEnd() + '…' : named);
  }
  linkTitles = next;
}

function linkText(url) {
  return linkTitles.get(bareHref(url)) || linkLabel(url);
}

function appendText(target, text) {
  BARE_LINK.lastIndex = 0;
  let cursor = 0;
  for (const match of String(text).matchAll(BARE_LINK)) {
    const url = trimUrl(match[0]);
    if (!url) continue;
    if (match.index > cursor) target.append(String(text).slice(cursor, match.index));
    target.append(el('a', {
      href: bareHref(url), rel: 'noopener noreferrer nofollow', target: '_blank', title: url, text: linkText(url)
    }));
    cursor = match.index + url.length;
  }
  if (cursor < String(text).length) target.append(String(text).slice(cursor));
}

function copyChildren(target, source, insideLink) {
  Array.from(source.childNodes).forEach((node) => {
    if (node.nodeType === 3) {
      if (insideLink) target.append(node.data); else appendText(target, node.data);
      return;
    }
    if (node.nodeType !== 1) return;
    if (DROP_TAGS.has(node.tagName)) return;
    if (!OK_TAGS.has(node.tagName)) { copyChildren(target, node, insideLink); return; }
    if (node.tagName === 'A') {
      const href = node.getAttribute('href') || '';
      if (!/^(https?:|mailto:)/i.test(href)) { copyChildren(target, node, insideLink); return; }
      const link = el('a', { href, rel: 'noopener noreferrer nofollow', target: '_blank' });
      copyChildren(link, node, true);
      target.append(link);
      return;
    }
    if (node.tagName === 'BR') { target.append(el('br')); return; }
    const copy = document.createElement(node.tagName.toLowerCase());
    copyChildren(copy, node, insideLink);
    target.append(copy);
  });
}

function sectionIds(model) {
  return model.sections.slice().sort((a, b) => (a.sort_order - b.sort_order)).map((s) => [s.id, s.title + ' (' + s.id + ')']);
}

function sectionTitle(model, id) {
  const found = model.sections.find((s) => s.id === id);
  return found ? found.title : id;
}

/** الأقسام التي ينشرها ناشر GitHub فعليًا من جدول items. */
function managedSections(model) {
  return model.sections.filter((s) => s.items_source === 'admin' && (s.source_kind || 'json') === 'json');
}

function failWith(ctx, error) {
  toast('-- ERROR: ' + (error && error.message ? error.message : String(error)), 6000);
}

/* append الأصلي يحوّل null إلى نص "null"، فهذه الإضافة تتجاهل الفروع الشرطية. */
function put(node, ...kids) {
  kids.flat().forEach((child) => {
    if (child === null || child === undefined || child === false) return;
    node.append(child.nodeType ? child : document.createTextNode(String(child)));
  });
  return node;
}

/* ── ١) نظرة عامة ──────────────────────────────────────────────────────────── */
function overviewPanel(host, ctx) {
  const m = ctx.model;
  const published = m.items.filter((i) => i.status === 'published');
  const drafts = m.items.filter((i) => i.status === 'draft');
  const scheduled = m.items.filter((i) => i.status === 'scheduled');
  const managed = managedSections(m);
  const managedIds = new Set(managed.map((s) => s.id));

  const checks = [];
  const warn = (text) => checks.push(['-- WARNING: ' + text, 'bad']);
  const note = (text) => checks.push(['-- NOTICE: ' + text, '']);
  const good = (text) => checks.push(['-- OK: ' + text, 'ok']);

  const brand = m.settings.brand || {};
  if (!String(brand.name || '').trim()) note('اسم العلامة فارغ؛ سيُنشر «أبو بدوي» تلقائيًا.');
  if (!m.sections.length) warn('لا أقسام في القاعدة — النشر الآن مرفوق بحذف إعداد التطبيق (data/index.json) إن شُغّل بـ FORCE=1.');
  if (!m.sections.some((s) => s.enabled !== false)) warn('كل الأقسام معطَّلة: لن يظهر للتطبيق أي تبويب.');

  const orphans = m.items.filter((i) => !m.sections.some((s) => s.id === i.section_id));
  if (orphans.length) warn(arCount(orphans.length, { one: 'عنصر مربوط', two: 'عنصران مربوطان', few: 'عناصر مربوطة', many: 'عنصرًا مربوطًا' }) + ' بأقسام غير موجودة في جدول sections — لن تُنشر.');
  const unmanaged = m.items.filter((i) => i.status === 'published' && !managedIds.has(i.section_id));
  if (unmanaged.length) note(arCount(unmanaged.length, { one: 'عنصر منشور', two: 'عنصران منشوران', few: 'عناصر منشورة', many: 'عنصرًا منشورًا' }) + ' في أقسام لا تُدار من اللوحة (rss/html/file أو معطَّل) — محتواها يأتي من مصدرها الخارجي.');

  managed.forEach((s) => {
    const count = published.filter((i) => i.section_id === s.id).length;
    if (!count) note('قسم «' + s.title + '» لا عناصر منشورة فيه: سيُبقي الناشر ملفه الحالي كما هو (أو يُفرَغ بـ ALLOW_EMPTY=1).');
  });
  if (!published.length) warn('لا عناصر منشورة إطلاقًا — التطبيق لن يعرض محتوى في الأقسام المُدارة.');

  m.sections.forEach((s) => {
    const kind = s.source_kind || 'json';
    if ((kind === 'rss' || kind === 'html') && !/^https?:\/\//i.test(String(s.feed_url || ''))) {
      warn('قسم «' + s.title + '» مصدره ' + kind + ' بلا رابط مطلق، فلن يُكتب مصدره في index.json.');
    }
  });

  const late = scheduled.filter((i) => Date.parse(String(i.publish_at || '')) <= Date.now());
  if (late.length) note(arCount(late.length, { one: 'عنصر مجدول', two: 'عنصران مجدولان', few: 'عناصر مجدولة', many: 'عنصرًا مجدولًا' }) + ' حان وقته وسيُنشر في الجولة القادمة تلقائيًا.');

  published.forEach((i) => {
    const attachments = Array.isArray(i.attachments) ? i.attachments : [];
    attachments.forEach((a) => {
      const url = String((a && a.url) || '');
      if (!url) return;
      if (!/^https?:\/\//i.test(url) && !/^[A-Za-z0-9؀-ۿ._\-\/]+\.\w+$/.test(url)) {
        warn('مرفق برابط غير صالح في «' + i.title + '»: ' + url.slice(0, 60) + ' — سيُحذف عند النشر.');
      }
    });
    if (/<\s*(script|iframe|style|object|embed)\b/i.test(String(i.body || ''))) {
      warn('متن «' + i.title + '» يحوي وسومًا خطيرة سيُزيلها المُنقِّي عند النشر.');
    }
  });

  const seenSlugs = new Set();
  published.forEach((i) => {
    const id = String(i.slug || i.id || '');
    if (!i.slug) return;
    const key = i.section_id + '/' + id;
    if (seenSlugs.has(key)) warn('تكرار المعرّف «' + id + '» داخل قسم ' + i.section_id + ' — الأول فقط يبقى واضحًا للتطبيق.');
    seenSlugs.add(key);
  });

  if (!m.prices.filter((r) => r.kind === 'fx').length) note('لا صفوف أسعار عملات: ملف data/prices/fx.json سيبقى كما هو.');
  if (!m.legal.length) note('لا وثائق قانونية في legal_docs — صفحة الويب والتطبيق يبقيان النصوص الحالية.');
  if (m.log.length && m.log[0].status === 'error') warn('آخر محاولة نشر فشلت: ' + String(m.log[0].message || '').slice(0, 160));
  if (!checks.length) good('لا ملاحظات: المحتوى جاهز للنشر.');

  host.append(
    card('الحصر', '', el('div', { class: 'grid four' }, [
      tile(m.sections.length, arWord(m.sections.length, { one: 'قسم', two: 'قسمان', few: 'أقسام', many: 'قسمًا' }), arCount(managed.length, { one: 'قسم مُدار', two: 'قسمان مُداران', few: 'أقسام مُدارة', many: 'قسمًا مُدارًا' }) + ' من اللوحة'),
      tile(published.length, arWord(published.length, { one: 'عنصر منشور', two: 'عنصران منشوران', few: 'عناصر منشورة', many: 'عنصرًا منشورًا' }), bucket(drafts.length, { one: 'مسودة', two: 'مسودتان', few: 'مسودات', many: 'مسودة' }) + '، ' + bucket(scheduled.length, { one: 'مجدول', two: 'مجدولان', few: 'مجدولات', many: 'مجدولًا' })),
      tile(m.media.length, arWord(m.media.length, { one: 'ملف وسائط', two: 'ملفّا وسائط', few: 'ملفات وسائط', many: 'ملف وسائط' }), fmtBytes(m.media.reduce((sum, r) => sum + (Number(r.bytes) || 0), 0))),
      tile(m.prices.length, arWord(m.prices.length, { one: 'صف سعر', two: 'صفّّا سعر', few: 'أصول أسعار', many: 'صف سعر' }), relTime(m.log[0] && m.log[0].created_at) + ' آخر نشر')
    ])),
    card('فحص الجاهزية', arWord(checks.length, { one: 'نتيجة', two: 'نتيجتان', few: 'نتائج', many: 'نتيجة' }), checks.map(([text, kind]) => el('div', { class: 'state ' + kind, text }))),
    card('روابط سريعة', '', el('div', { class: 'btnrow' }, [
      button('+ عنصر جديد', '', () => { if (!ctx.writable()) return; ui.items.editing = api.blankItem(managed[0] ? managed[0].id : (m.sections[0] || {}).id || ''); ctx.go('items'); }),
      button('+ قسم جديد', 'ghost', () => { if (!ctx.writable()) return; ui.sections.editing = blankSection(m); ctx.go('sections'); }),
      el('a', { class: 'btn ghost', href: api.PUBLISH_ACTIONS_URL, target: '_blank', rel: 'noopener' }, 'نشر الآن من GitHub'),
      el('a', { class: 'btn plain', href: 'index.html', target: '_blank', rel: 'noopener' }, 'صفحة الموقع العام'),
      el('a', { class: 'btn plain', href: 'data/index.json', target: '_blank', rel: 'noopener' }, 'data/index.json')
    ]))
  );
}

function tile(value, label, hint) {
  return el('div', { class: 'card' }, [
    el('b', { text: value, style: 'font-size:1.6rem' }),
    el('div', { text: label }),
    hint ? el('div', { class: 'muted', text: hint, style: 'font-size:.74rem' }) : null
  ]);
}

function iconOptions(current) {
  const base = [['article', 'مقال (افتراضي)'], ...api.ICONS];
  if (current && !base.some(([key]) => key === current)) base.push([current, current + ' (كما هو في index.json)']);
  return base;
}

function blankSection(model) {
  const last = model.sections.slice().sort((a, b) => a.sort_order - b.sort_order).pop();
  return {
    id: '', title: '', subtitle: '', icon: 'article', layout: 'list', source_kind: 'json',
    feed_url: null, item_selector: null, headers: {}, sort_order: (last ? Number(last.sort_order) || 0 : 0) + 10,
    enabled: true, show_on_home: true, notify_default: false, allow_breaking: true,
    items_source: 'admin', note: '', isNew: true
  };
}

/* ── ٢) الأقسام ────────────────────────────────────────────────────────────── */
function sectionsPanel(host, ctx) {
  const draw = async () => {
    clear(host);
    const list = ctx.model.sections.slice().sort((a, b) => (a.sort_order - b.sort_order) || String(a.id).localeCompare(String(b.id)));
    host.append(card(arCount(list.length, { one: 'قسم', two: 'قسمان', few: 'أقسام', many: 'قسمًا' }), '', [
      el('div', { class: 'btnrow', style: 'margin-bottom:12px' }, [
        button('+ قسم جديد', '', () => { ui.sections.editing = blankSection(ctx.model); draw(); })
      ]),
      tableNode(
        ['الترتيب', 'المعرّف', 'العنوان', 'المصدر', 'العناصر', 'إشعار', 'مُفعَّل', 'إجراءات'],
        list.map((section, index) => {
          const count = ctx.model.items.filter((i) => i.section_id === section.id && i.status === 'published').length;
          const last = list.length - 1;
          const move = async (delta) => {
            if (!ctx.writable()) return;
            const target = index + delta;
            if (target < 0 || target > last) return;
            const a = list[index], b = list[target];
            const orderA = Number(a.sort_order) || 0, orderB = Number(b.sort_order) || 0;
            if (orderA === orderB) {
              const all = list.slice();
              const [moved] = all.splice(index, 1);
              all.splice(target, 0, moved);
              const previous = new Map(list.map((s) => [s.id, Number(s.sort_order) || 0]));
              persist(all.map((s, i) => ({ ...s, sort_order: (i + 1) * 10 })).filter((s) => previous.get(s.id) !== s.sort_order));
              return;
            }
            persist([{ ...a, sort_order: orderB }, { ...b, sort_order: orderA }]);
          };
          return el('tr', {}, [
            td(el('div', { class: 'btnrow' }, [
              tiny('▲', () => move(-1), index === 0 ? 'هو الأول' : 'رفع'),
              tiny('▼', () => move(1), index === last ? 'هو الأخير' : 'خفض')
            ]), 'num'),
            td(el('code', { text: section.id })),
            td(el('div', {}, [el('b', { text: section.title || '—' }), el('div', { class: 'muted', text: section.icon + ' · ' + section.layout })])),
            td((section.source_kind || 'json') + (section.source_kind === 'json' ? ' · ' + section.items_source : '') + (section.source_kind === 'rss' || section.source_kind === 'html' ? ' · خارجي' : '')),
            td(section.items_source === 'admin' && section.source_kind === 'json' ? count : '—'),
            td(section.notify_default ? tag('افتراضي', 'published') : tag('إيقاف')),
            td(el('input', {
              type: 'checkbox', checked: section.enabled !== false,
              onchange: (e) => persist([{ ...section, enabled: e.target.checked }])
            })),
            td(el('div', { class: 'btnrow' }, [
              tiny('تحرير', () => { ui.sections.editing = { ...section }; draw(); }),
              tiny('عناصر', () => { ui.items.section = section.id; ui.items.editing = null; ctx.go('items'); }),
              tiny('حذف', async () => {
                if (!ctx.writable()) return;
                const kids = ctx.model.items.filter((i) => i.section_id === section.id).length;
                if (!ask('حذف قسم ' + section.id + ' سيحذف ' + kids + ' من عناصره المرتبطة. متابعة؟')) return;
                try { await api.deleteSection(section.id); await ctx.refresh(); } catch (error) { failWith(ctx, error); }
              }, 'حذف القسم وعناصره')
            ]), 'acts')
          ]);
        })
      )
    ]));
    if (ui.sections.editing) host.append(sectionEditor(ui.sections.editing, ctx, draw));
  };

  async function persist(rows) {
    if (!ctx.writable()) return;
    try {
      for (const row of rows) await api.saveSection(strip(row));
      await ctx.refresh();
    } catch (error) { failWith(ctx, error); }
  }

  draw();
}

function strip(row) {
  const out = { ...row };
  delete out.isNew;
  Object.keys(out).forEach((key) => { if (out[key] === undefined) out[key] = null; });
  if (!out.feed_url) out.feed_url = null;
  if (!out.item_selector) out.item_selector = null;
  return out;
}

function sectionEditor(initial, ctx, onDone) {
  const draft = { ...initial };
  const fieldsHost = el('div', { class: 'grid two' });
  const line = stateLine('', '');

  const render = () => {
    const kind = draft.source_kind || 'json';
    const cover = imageControl(
      () => draft.cover_image,
      (url) => { draft.cover_image = url; cover.redraw(); },
      ctx,
      () => draft.id || 'general'
    );
    put(clear(fieldsHost),
      field('المعرّف (id)', input({
        dir: 'ltr', value: draft.id, disabled: !draft.isNew, placeholder: 'village_news',
        oninput: (e) => { draft.id = e.target.value; }
      }), draft.isNew ? 'أحرف إنجليزية صغيرة وأرقام و_ فقط، ويبدأ بحرف. لا يمكن تغييره بعد الإنشاء.' : 'تغيير المعرّف يعني قسمًا جديدًا بالكامل.'),
      field('العنوان', input({ value: draft.title, oninput: (e) => { draft.title = e.target.value; } })),
      field('العنوان الفرعي', input({ value: draft.subtitle || '', oninput: (e) => { draft.subtitle = e.target.value; } })),
      field('الأيقونة', select(iconOptions(draft.icon), draft.icon, (v) => { draft.icon = v; })),
      field('صورة القسم (اختيارية)', cover.node),
      field('التخطيط', select(api.LAYOUTS, draft.layout, (v) => { draft.layout = v; }), 'طريقة عرض التطبيق للعناصر.'),
      field('الترتيب', input({ type: 'number', dir: 'ltr', value: String(draft.sort_order ?? 100), oninput: (e) => { draft.sort_order = Number(e.target.value) || 0; } })),
      field('نوع المصدر', select(api.KINDS, kind, (v) => { draft.source_kind = v; render(); }),
        kind === 'fx' || kind === 'gold' ? 'الملف يُبنى من جدول price_rows ومن لوحة الأسعار.'
          : kind === 'prayer' || kind === 'weather' ? 'التطبيق يجلبه مباشرة من واجهة مفتوحة حسب موقع القرية في الإعدادات — بلا رابط ولا عناصر.'
            : kind === 'converter' ? 'آلة حاسبة داخل التطبيق؛ تعمل على أسعار العملات المنشورة.'
              : kind === 'calendar' ? 'تقويم هجري/ميلادي بمناسباته ومحوّله داخل التطبيق؛ يحسبه من Aladhan حسب موقع القرية — بلا رابط ولا عناصر.'
                : 'rss/html يقرؤهما التطبيق مباشرة من الرابط الخارجي.'),
      kind === 'json' ? field('مصدر العناصر', select([['admin', 'من هذه اللوحة'], ['file', 'ملف JSON ثابت في المستودع']], draft.items_source, (v) => { draft.items_source = v; render(); })) : null,
      kind === 'json' && draft.items_source === 'admin' ? field('مسار الملف المنشور (اختياري)', input({ dir: 'ltr', value: draft.feed_url || '', oninput: (e) => { draft.feed_url = e.target.value; } }), 'افتراضيًا data/sections/<id>.json — اتركه فارغًا إلا لو أردت مسارًا آخر.') : null,
      kind === 'json' && draft.items_source === 'file' ? field('مسار ملف JSON في المستودع', input({ dir: 'ltr', value: draft.feed_url || '', oninput: (e) => { draft.feed_url = e.target.value; } }), 'مثال: data/sections/landmarks.json — تحرّره يدويًا أو بأمر git، لا من هذه اللوحة.') : null,
      (kind === 'rss' || kind === 'html') ? field('رابط التغذية أو الصفحة', input({ dir: 'ltr', placeholder: 'https://…', value: draft.feed_url || '', oninput: (e) => { draft.feed_url = e.target.value; } }), 'رابط مطلق https — وهو ما يقرأه التطبيق مباشرة.') : null,
      kind === 'html' ? field('مُحدِّد العناصر', input({ dir: 'ltr', placeholder: 'article.post', value: draft.item_selector || '', oninput: (e) => { draft.item_selector = e.target.value; } })) : null,
      (kind === 'rss' || kind === 'html') ? field('ترويسات الطلب (سطر لكل: Name: value)', textarea(pairsText(draft.headers), (v) => { draft.headers = parsePairs(v); })) : null,
      field('ملاحظة داخلية للمحرِّرين', textarea(draft.note || '', (v) => { draft.note = v; }), 'تُنسخ إلى ملف القسم، ولا تظهر للمستخدم.')
    );
  };

  const box = card((draft.isNew ? 'قسم جديد' : 'تحرير: ' + draft.id), '', [
    fieldsHost,
    el('div', { class: 'grid three', style: 'margin-top:12px' }, [
      checkbox('القسم مُفعَّل', draft.enabled !== false, (v) => { draft.enabled = v; }),
      checkbox('يظهر في الرئيسية', draft.show_on_home !== false, (v) => { draft.show_on_home = v; }),
      checkbox('إشعار افتراضيًا', !!draft.notify_default, (v) => { draft.notify_default = v; }),
      checkbox('السماح بالإشعار العاجل', draft.allow_breaking !== false, (v) => { draft.allow_breaking = v; })
    ]),
    line,
    el('div', { class: 'btnrow', style: 'margin-top:12px' }, [
      button('حفظ القسم', '', async () => {
        if (!ctx.writable()) return;
        if (!/^[a-z][a-z0-9_]{1,40}$/.test(String(draft.id || '').trim())) { setLine2(line, 'المعرّف غير صالح: ' + draft.id, 'bad'); return; }
        if (!String(draft.title || '').trim()) { setLine2(line, 'العنوان مطلوب.', 'bad'); return; }
        setLine2(line, 'جارٍ الحفظ…', '');
        try {
          await api.saveSection(strip(draft));
          ui.sections.editing = null;
          toast('حُفظ القسم.');
          await ctx.refresh();
        } catch (error) { setLine2(line, error.message, 'bad'); }
      }),
      button('إلغاء', 'plain', () => { ui.sections.editing = null; onDone(); })
    ])
  ]);
  render();
  return box;
}

function setLine2(node, message, kind) {
  node.className = 'state ' + (kind || '');
  node.textContent = message;
}

function textarea(value, onInput) {
  return el('textarea', { oninput: (e) => onInput(e.target.value) }, value || '');
}

/* ── ٣) العناصر ────────────────────────────────────────────────────────────── */
function itemsPanel(host, ctx) {
  const managed = managedSections(ctx.model);
  const sourceIds = new Set(ctx.model.sections.map((s) => s.id));
  const remount = () => itemsPanel(host, ctx);

  clear(host);
  if (ui.items.editing) {
    host.append(itemEditor(ui.items.editing, ctx, remount));
    return;
  }

  const results = el('div');

  const filtered = () => {
    const q = ui.items.q.trim().toLowerCase();
    return ctx.model.items.filter((item) => {
      if (ui.items.section && item.section_id !== ui.items.section) return false;
      if (ui.items.status && item.status !== ui.items.status) return false;
      if (!q) return true;
      return [item.title, item.subtitle, item.body, (item.tags || []).join(' ')]
        .some((v) => String(v || '').toLowerCase().includes(q));
    });
  };

  function renderResults() {
    const rows = filtered();
    const sorted = rows.slice().sort((a, b) => (Number(b.sort_order) - Number(a.sort_order)) || String(b.updated_at || '').localeCompare(String(a.updated_at || '')));
    count.textContent = sorted.length + ' من ' + ctx.model.items.length;
    put(clear(results), sorted.length ? tableNode(
      ['العنوان', 'القسم', 'الحالة', 'التاريخ', 'آخر تعديل', 'إجراءات'],
      sorted.map((item) => el('tr', {}, [
        td(el('div', {}, [
          el('b', { text: String(item.title || 'بدون عنوان') }),
          el('div', { class: 'muted', text: [item.pinned ? 'مثبّت' : '', item.breaking ? 'عاجل' : '', Array.isArray(item.attachments) && item.attachments.length ? item.attachments.length + ' مرفق' : ''].filter(Boolean).join(' · ') })
        ])),
        td(sectionTitle(ctx.model, item.section_id) + (sourceIds.has(item.section_id) ? '' : ' (قسم مفقود)')),
        td(tag((api.STATUSES.find((s) => s[0] === item.status) || ['', item.status])[1], item.status)),
        td(item.event_date || '—'),
        td(relTime(item.updated_at)),
        td(el('div', { class: 'btnrow' }, [
          tiny('تحرير', () => { ui.items.editing = { ...item }; remount(); }),
          tiny(item.status === 'published' ? 'إلغاء النشر' : 'نشر', async () => {
            if (!ctx.writable()) return;
            const next = item.status === 'published' ? 'draft' : 'published';
            try { await api.saveItem({ ...item, status: next }); await ctx.refresh(); } catch (error) { failWith(ctx, error); }
          }, nextHint(item)),
          tiny('تكرار', () => {
            if (!ctx.writable()) return;
            ui.items.editing = { ...api.blankItem(item.section_id), ...item, id: null, title: (item.title || '') + ' (نسخة)', status: 'draft', published_at: null, slug: null, updated_at: null, created_at: null };
            remount();
          }),
          tiny('حذف', async () => {
            if (!ctx.writable()) return;
            if (!ask('حذف «' + item.title + '» نهائيًا؟')) return;
            try { await api.deleteItem(item.id); await ctx.refresh(); } catch (error) { failWith(ctx, error); }
          })
        ]), 'acts')
      ]))
    ) : el('div', { class: 'muted', text: 'لا عناصر مطابقة.' }));
  }

  function nextHint(item) {
    if (item.status === 'published') return 'يحوّله إلى مسودة فلا يظهر في التطبيق بعد النشر';
    return 'ينشره في القاعدة؛ يظهر في التطبيق مع ' + AUTO_PUBLISH;
  }

  const count = el('span', { class: 'n', text: '' });
  const search = input({ value: ui.items.q, placeholder: 'عنوان أو متن أو وسم', oninput: () => { ui.items.q = search.value; renderResults(); } });
  const box = el('section', { class: 'card' }, [
    el('h2', {}, ['العناصر', count]),
    el('div', { class: 'grid four' }, [
      field('القسم', select([['', 'كل الأقسام'], ...sectionIds(ctx.model)], ui.items.section, (v) => {
        ui.items.section = v;
        renderResults();
        /* شريط الأقسام في الجانب يقرأ نفس المرشّح */
        document.dispatchEvent(new CustomEvent('ab:section-filter'));
      })),
      field('الحالة', select([['', 'كل الحالات'], ...api.STATUSES], ui.items.status, (v) => { ui.items.status = v; renderResults(); })),
      field('بحث', search),
      el('div', { class: 'btnrow', style: 'align-self:end' }, [
        button('+ عنصر جديد', '', () => {
          if (!ctx.writable()) return;
          ui.items.editing = api.blankItem(ui.items.section || (managed[0] || {}).id || (ctx.model.sections[0] || {}).id || '');
          remount();
        })
      ])
    ]),
    managed.length ? null : el('div', { class: 'state bad', text: 'لا قسم يُدار من اللوحة (json + items_source=admin) — لن يُنشر أي عنصر. أنشئ قسمًا أو غيّر مصدر قسم من لوحة الأقسام.' }),
    results
  ]);
  host.append(box);
  renderResults();
}

function itemEditor(draftIn, ctx, onDone) {
  const draft = { attachments: [], tags: [], fields: {}, ...draftIn };
  const line = stateLine('', '');
  const attachmentsHost = el('div');
  const previewHost = el('div');

  const attachments = Array.isArray(draft.attachments) ? draft.attachments.slice() : [];
  draft.attachments = attachments;

  function drawAttachments() {
    clear(attachmentsHost);
    if (!attachments.length) attachmentsHost.append(el('div', { class: 'muted', text: 'لا مرفقات.' }));
    else attachmentsHost.append(el('div', { class: 'thumbs' }, attachments.map((att, index) => el('div', { class: 'thumb' }, [
      el('div', { class: 'box' + (att.type === 'audio' ? ' audio' : '') }, [
        att.type === 'image' ? el('img', { src: att.url, alt: '', loading: 'lazy' })
          : att.type === 'video' ? el('video', { src: att.url, poster: att.poster || '', muted: true, preload: 'metadata' })
            : el('span', { text: 'صوت' + (att.duration ? ' · ' + att.duration + ' ث' : '') })
      ]),
      el('div', { class: 'foot' }, [
        el('input', { value: att.label || '', placeholder: 'تسمية', oninput: (e) => { att.label = e.target.value; } }),
        libraryRowFor(ctx, att.url) ? replaceControl(libraryRowFor(ctx, att.url), ctx) : null,
        tiny('×', () => { attachments.splice(index, 1); drawAttachments(); }, 'إزالة من هذا العنصر')
      ])
    ]))));
  }

  function drawPreview() {
    put(clear(previewHost),
      el('h3', { class: 'muted', text: 'معاينة المتن (بلا وسوم ممنوعة)' }),
      draft.image ? el('img', { src: draft.image, alt: '', style: 'max-width:100%;border-radius:12px;margin-bottom:8px' }) : null,
      previewNode(draft.body)
    );
  }

  const uploader = el('div', {}, [
    el('div', { class: 'drop', onclick: () => fileInput.click(),
      ondragover: (e) => { e.preventDefault(); e.currentTarget.classList.add('over'); },
      ondragleave: (e) => e.currentTarget.classList.remove('over'),
      ondrop: (e) => { e.preventDefault(); e.currentTarget.classList.remove('over'); handleFiles(e.dataTransfer.files); } },
      'اسحب صورًا/صوتًا/فيديو هنا أو انقر للاختيار — حتى ٢٥ MB للملف (يُرفع إلى مستودع media)'),
    el('input', { id: 'itemFilePick', type: 'file', multiple: true, accept: acceptList(), style: 'display:none', onchange: (e) => handleFiles(e.target.files) }),
    stateLine('', ''),
    libraryPicker()
  ]);
  const fileInput = uploader.querySelector('input');
  const uploadState = uploader.querySelector('.state');

  function libraryPicker() {
    if (!ctx.model.media.length) return null;
    const options = [['', 'إضافة من مكتبة الوسائط…'], ...ctx.model.media.slice(0, 200).map((row) => [row.url, row.kind + ' · ' + (row.label || row.path)])];
    return field('إضافة من مكتبة الوسائط', select(options, '', (value) => {
      if (!value) return;
      const found = ctx.model.media.find((row) => row.url === value);
      if (!found) return;
      attachments.push(toAttachment(found));
      drawAttachments();
      uploader.querySelector('select').value = '';
    }));
  }

  function toAttachment(meta) {
    return { type: meta.kind, url: meta.url, label: meta.label || '', duration: meta.duration_seconds || meta.duration || null, poster: meta.poster_url || null };
  }

  async function handleFiles(fileList) {
    if (!ctx.writable()) return;
    const files = Array.from(fileList || []);
    if (!files.length) return;
    for (const file of files) {
      setLine2(uploadState, 'جارٍ رفع ' + file.name + '…', '');
      try {
        const meta = await api.uploadMedia(file, draft.section_id || 'general');
        attachments.push(toAttachment(meta));
        if (!draft.image && meta.kind === 'image') draft.image = meta.url;
        setLine2(uploadState, 'رُفع ' + file.name + ' (' + fmtBytes(meta.bytes) + ').', 'ok');
        drawAttachments();
        drawPreview();
        cover.redraw();
      } catch (error) {
        setLine2(uploadState, 'تعذّر رفع ' + file.name + ': ' + error.message, 'bad');
      }
    }
  }

  const statusSelect = select(api.STATUSES, draft.status, (v) => { draft.status = v; scheduleField.style.display = v === 'scheduled' ? '' : 'none'; });
  const scheduleField = el('div', {}, [
    field('موعد النشر', input({ type: 'datetime-local', dir: 'ltr', value: toLocal(draft.publish_at), oninput: (e) => { draft._publishLocal = e.target.value; } })),
    el('div', { class: 'muted', text: 'يُنشر تلقائيًا في أول جولة بعد هذا الموعد.', style: 'margin-top:4px' })
  ]);
  scheduleField.style.display = draft.status === 'scheduled' ? '' : 'none';

  async function save() {
    if (!ctx.writable()) return;
    if (!String(draft.title || '').trim()) { setLine2(line, 'العنوان مطلوب.', 'bad'); return; }
    if (!draft.section_id) { setLine2(line, 'اختر قسمًا.', 'bad'); return; }
    setLine2(line, 'جارٍ الحفظ…', '');
    const row = { ...draft };
    row.tags = Array.isArray(draft.tags) ? draft.tags : [];
    row.fields = draft.fields && typeof draft.fields === 'object' ? draft.fields : {};
    row.attachments = attachments.filter((a) => a && a.url);
    row.publish_at = row.status === 'scheduled' ? toIso(row._publishLocal || '') : null;
    delete row._publishLocal;
    try {
      const id = await api.saveItem(row);
      ui.items.editing = null;
      toast(row.status === 'published' ? 'حُفظ ونُشر في القاعدة — يصل إلى التطبيق مع ' + AUTO_PUBLISH + '.' : 'حُفظ العنصر.');
      await ctx.refresh();
      return id;
    } catch (error) { setLine2(line, error.message, 'bad'); }
  }

  const coverInput = input({
    value: draft.image || '', dir: 'ltr',
    oninput: (e) => { draft.image = e.target.value; drawPreview(); },
    onchange: () => cover.redraw()
  });
  const cover = imageControl(
    () => draft.image,
    (url) => { draft.image = url; coverInput.value = url; cover.redraw(); drawPreview(); },
    ctx,
    () => draft.section_id || 'general'
  );

  /* أقسام apps وchannels وmemorials وtrains تعيد قراءة الحقول العامة؛ يحتاج العنصر توضيحًا. */
  const sectionHint = el('div', { class: 'muted', style: 'display:none;margin-top:6px' });
  function drawSectionHint() {
    const row = ctx.model.sections.find((s) => s.id === draft.section_id);
    const layout = row && row.layout;
    const show = ['apps', 'channels', 'memorials', 'trains'].includes(layout);
    sectionHint.style.display = show ? '' : 'none';
    if (!show) return;
    sectionHint.textContent = layout === 'apps'
      ? 'قسم تطبيقات: الصورة هي أيقونة التطبيق، و«رابط خارجي» هو رابط المتجر ويظهر '
        + 'كزر «افتح التطبيق»، وأضف سطرًا في الحقول الإضافية على مثال: '
        + 'المميزات: وضع ليلي، عمل بدون إنترنت، أوقات الصلاة.'
      : layout === 'channels'
        ? 'قسم قنوات: الصورة شعار القناة (مربعة؛ وإن تُرك فارغًا رسم التطبيق رمزًا)، '
          + 'و«رابط خارجي» هو صفحة القناة ويظهر كزر «افتح القناة على يوتيوب»، '
          + 'وأضف سطرًا في الحقول الإضافية على مثال: '
          + 'المواضيع: سكراتش، بايثون، روبوتكس — مع الفئة العمرية واللغة.'
        : layout === 'trains'
          ? 'قسم قطارات: العنوان رقم القطار وخطه على مثال «906 — القاهرة ← الإسكندرية»، '
            + 'واكتب في الحقول الإضافية الأسطر: رقم، النوع، من، إلى، قيام، وصول، المدة، '
            + 'الوقفات، الأسعار، الأيام (عشرة أسطر هو حدها، وما يزيد يُقتطع عند النشر)، '
            + 'و«التاريخ كما يظهر» = تاريخ سريان الجدول بصيغة 2026-10-04 ليعرف القارئ قِدَم '
            + 'المواعيد، و«رابط خارجي» = صفحة المواعيد الرسمية ليظهر كزر «افتح المواعيد '
            + 'الرسمية». المواعيد تُنسخ هنا من إعلان الهيئة؛ فالتطبيق لا يقرأها من موقعها.'
          : 'قسم تذكار: العنوان اسم المتوفّى، و«التاريخ كما يظهر» تاريخ الوفاة بصيغة '
            + '2026-10-04 (يتولّاه التطبيق فيحوّله هجريًا ويحسب ما مضى والذكرى)، والسطر '
            + 'التعريفي كنية أو بلد، والمتن دعاء مخصص؛ وإن تُرك المتن فارغًا دعا التطبيق '
            + 'بالدعاء الافتراضي (المذكّر)، فأنثى تُكتب لها صيغة «اللهم اغفر لها…» في المتن.';
  }
  const sectionField = field('القسم', select(sectionIds(ctx.model), draft.section_id, (v) => { draft.section_id = v; drawSectionHint(); }));
  sectionField.append(sectionHint);

  const form = card(draft.id ? 'تحرير عنصر' : 'عنصر جديد', '', [
    el('div', { class: 'grid two' }, [
      sectionField,
      field('الحالة', statusSelect),
      scheduleField,
      field('العنوان', input({ value: draft.title || '', oninput: (e) => { draft.title = e.target.value; drawPreview(); } })),
      field('السطر التعريفي (يظهر تحت العنوان)', input({ value: draft.subtitle || '', oninput: (e) => { draft.subtitle = e.target.value; } })),
      field('التاريخ كما يظهر', input({ value: draft.event_date || '', placeholder: '1950 أو 2026-05-01', dir: 'ltr', oninput: (e) => { draft.event_date = e.target.value; } }), 'نص حر: سنة أو فصل أو تاريخ كامل.'),
      field('معرّف ثابت في JSON (اختياري)', input({ value: draft.slug || '', dir: 'ltr', oninput: (e) => { draft.slug = e.target.value; } }), 'إن تُرك استُخدم id الصف تلقائيًا.'),
      field('رابط الصورة الرئيسية', coverInput),
      field('صورة الغلاف — رفع أو تغيير', cover.node),
      field('حقوق الصورة', input({ value: draft.image_credit || '', oninput: (e) => { draft.image_credit = e.target.value; } })),
      field('رابط خارجي', input({ value: draft.link || '', dir: 'ltr', oninput: (e) => { draft.link = e.target.value; } })),
      field('اسم المصدر', input({ value: draft.source_name || '', oninput: (e) => { draft.source_name = e.target.value; } })),
      field('رابط المصدر', input({ value: draft.source_url || '', dir: 'ltr', oninput: (e) => { draft.source_url = e.target.value; } })),
      field('وسوم (فاصلة بين كل وسمين)', input({ value: (draft.tags || []).join(', '), oninput: (e) => { draft.tags = e.target.value.split(',').map((t) => t.trim()).filter(Boolean); } })),
      field('حقول إضافية (سطر لكل: الاسم: القيمة)', textarea(pairsText(draft.fields), (v) => { draft.fields = parsePairs(v); }), 'تُعرض في البطاقة، مثل: التكلفة: ٥٠ جنيه'),
      field('الترتيب', input({ type: 'number', dir: 'ltr', value: String(draft.sort_order ?? 0), oninput: (e) => { draft.sort_order = Number(e.target.value) || 0; } })),
      el('div', { class: 'btnrow', style: 'align-self:end' }, [
        checkbox('مثبّت في الأعلى', !!draft.pinned, (v) => { draft.pinned = v; }),
        checkbox('عاجل', !!draft.breaking, (v) => { draft.breaking = v; })
      ])
    ]),
    field('المتن (HTML مبسَّط: p/br/h2/h3/strong/em/ul/li/a/blockquote)', textarea(draft.body || '', (v) => { draft.body = v; drawPreview(); })),
    previewHost,
    el('h3', { class: 'muted', text: 'المرفقات — كما في منشور فيسبوك' }),
    uploader,
    attachmentsHost,
    line,
    el('div', { class: 'btnrow', style: 'margin-top:12px' }, [
      button('حفظ', '', save),
      button('حفظ ونشر', 'ghost', async () => { draft.status = 'published'; await save(); }),
      button('رجوع للقائمة', 'plain', () => { ui.items.editing = null; onDone(); })
    ])
  ]);

  drawAttachments();
  drawPreview();
  drawSectionHint();
  return form;
}

function acceptList() {
  return [...api.MEDIA_TYPES.image, ...api.MEDIA_TYPES.audio, ...api.MEDIA_TYPES.video].join(',');
}

/* ── أزرار الصور: رفع وتغيير واستبدال في كل سطح يعرض صورة ─────────────────── */

/*
   تحكم صورة واحدة (غلاف عنصر أو غلاف قسم): معاينة + رفع + اختيار من المكتبة + مسح.
   القيمة تُقرأ بالدالة حتى يبقى التحكم ملتصقًا بالمسودة أثناء التحرير.
*/
function imageControl(getValue, setValue, ctx, getFolder) {
  const state = stateLine('', '');
  const host = el('div');
  const pick = el('input', {
    type: 'file', accept: api.MEDIA_TYPES.image.join(','), style: 'display:none',
    onchange: async (e) => {
      const file = e.target.files && e.target.files[0];
      e.target.value = '';
      if (!file || !ctx.writable()) return;
      setLine2(state, 'جارٍ رفع ' + file.name + '…', '');
      try {
        const meta = await api.uploadMedia(file, getFolder());
        setLine2(state, 'رُفع ' + file.name + ' (' + fmtBytes(meta.bytes) + ').', 'ok');
        setValue(meta.url);
      } catch (error) { setLine2(state, error.message, 'bad'); }
    }
  });

  function draw() {
    const value = String(getValue() || '');
    const images = ctx.model.media.filter((row) => row.kind === 'image').slice(0, 240);
    const lib = images.length
      ? select([['', 'من مكتبة الوسائط…'], ...images.map((row) => [row.url, row.label || row.path])], '',
        (url) => { if (url && ctx.writable()) setValue(url); })
      : null;
    const foot = [
      tiny('رفع', () => { if (ctx.writable()) pick.click(); }, value ? 'رفع صورة بديلة' : 'رفع صورة جديدة'),
      pick
    ];
    if (lib) foot.push(lib);
    if (value) foot.push(tiny('مسح', () => { if (ctx.writable()) setValue(''); }, 'إزالة الصورة من هذا الموضع'));
    clear(host).append(
      el('div', { class: 'thumb', style: 'max-width:240px' }, [
        el('div', { class: 'box' }, [value ? el('img', { src: value, alt: '', loading: 'lazy' }) : el('span', { text: 'لا صورة' })]),
        el('div', { class: 'foot' }, foot)
      ]),
      state
    );
  }

  draw();
  return { node: host, redraw: draw };
}

/* استبدال ملف مكتبة في نفس مساره: الرابط لا يتغيّر، فتتحدّث كل استخداماته دفعة واحدة. */
function replaceControl(row, ctx) {
  const pick = el('input', {
    type: 'file',
    accept: row.kind === 'image' ? api.MEDIA_TYPES.image.join(',') : acceptList(),
    style: 'display:none',
    onchange: async (e) => {
      const file = e.target.files && e.target.files[0];
      e.target.value = '';
      if (!file || !ctx.writable()) return;
      toast('جارٍ استبدال ' + (row.label || row.path) + '…');
      try {
        await api.replaceMedia(file, row);
        await ctx.refresh();
        toast('استُبدل الملف — الروابط كما هي، ويظهر الجديد خلال دقائق على الأكثر.', 4200);
      } catch (error) { toast(error.message, 5200); }
    }
  });
  return el('div', {}, [
    tiny('استبدال', () => { if (ctx.writable()) pick.click(); },
      'رفع بديل في نفس المسار: كل عنصر يستخدم هذا الرابط يتحدّث'),
    pick
  ]);
}

/* صف المكتبة المقابل لرابط مرفق، إن كان المرفق من المكتبة أصلًا. */
function libraryRowFor(ctx, url) {
  return ctx.model.media.find((row) => (row.url || row.src) === url) || null;
}

/* ── ٤) الوسائط ────────────────────────────────────────────────────────────── */
function mediaPanel(host, ctx) {
  const usage = (url) => ctx.model.items.filter((i) => (i.attachments || []).some((a) => (a.url || a.src) === url)).length;

  const uploadLine = stateLine('', '');
  const pick = el('input', { type: 'file', multiple: true, accept: acceptList(), style: 'display:none', onchange: (e) => upload(e.target.files) });
  const dropZone = el('div', {
    class: 'drop',
    onclick: () => pick.click(),
    ondragover: (e) => { e.preventDefault(); e.currentTarget.classList.add('over'); },
    ondragleave: (e) => e.currentTarget.classList.remove('over'),
    ondrop: (e) => { e.preventDefault(); e.currentTarget.classList.remove('over'); upload(e.dataTransfer.files); }
  }, 'اسحب هنا أو انقر للاختيار — الصور والصوت والفيديو، ٢٥ MB حدًا أقصى للملف');
  const grid = el('div');
  const libCount = el('span', { class: 'n', text: '' });
  const search = input({ value: ui.media.q, placeholder: 'اسم أو مسار أو رابط', oninput: () => { ui.media.q = search.value; renderLibrary(); } });

  async function upload(files) {
    if (!ctx.writable()) return;
    const list = Array.from(files || []);
    if (!list.length) return;
    let done = 0;
    for (const file of list) {
      setLine2(uploadLine, 'جارٍ رفع ' + file.name + '…', '');
      try { await api.uploadMedia(file, 'general'); done++; } catch (error) { setLine2(uploadLine, error.message, 'bad'); }
    }
    if (done) { await ctx.refresh(); toast('رُفع ' + arCount(done, { one: 'ملف', two: 'ملفان', few: 'ملفات', many: 'ملفًا' }) + ' إلى مستودع media.'); }
  }

  function renderLibrary() {
    const q = ui.media.q.trim().toLowerCase();
    const rows = ctx.model.media.filter((row) => {
      if (ui.media.kind && row.kind !== ui.media.kind) return false;
      if (!q) return true;
      return [row.label, row.path, row.url].some((v) => String(v || '').toLowerCase().includes(q));
    });
    const total = rows.reduce((sum, row) => sum + (Number(row.bytes) || 0), 0);
    libCount.textContent = arCount(rows.length, { one: 'ملف', two: 'ملفان', few: 'ملفات', many: 'ملفًا' }) + ' · ' + fmtBytes(total);
    put(clear(grid),
      rows.length ? el('div', { class: 'thumbs' }, rows.map(thumb)) : el('div', { class: 'muted', text: 'لا ملفات بعد — ارفع من الصندوق أعلاه.' }));
  }

  function thumb(row) {
    const inUse = usage(row.url);
    return el('div', { class: 'thumb' }, [
      el('div', { class: 'box' + (row.kind === 'audio' ? ' audio' : '') }, [
        row.kind === 'image' ? el('img', { src: row.url, alt: '', loading: 'lazy' })
          : row.kind === 'video' ? el('video', { src: row.url, muted: true, preload: 'metadata' })
            : el('span', { text: 'صوت' + (row.duration_seconds ? ' · ' + row.duration_seconds + ' ث' : '') }),
        el('span', { class: 'note', text: row.kind + ' · ' + fmtBytes(row.bytes) })
      ]),
      el('div', { class: 'foot' }, [
        el('input', { value: row.label || '', placeholder: 'تسمية', dir: 'auto',
          onchange: async (e) => {
            if (!ctx.writable()) return;
            try { await api.saveMedia({ ...row, label: e.target.value }); toast('حُدِّثت التسمية.'); } catch (error) { failWith(ctx, error); }
          } }),
        tiny('نسخ', () => { navigator.clipboard.writeText(row.url).then(() => toast('نُسخ الرابط.'), () => toast(row.url, 6000)); }),
        replaceControl(row, ctx),
        tiny(String(inUse), () => {
          ui.items.q = ''; ui.items.status = ''; ui.items.editing = null;
          ui.items.section = row.path.split('/')[0] === 'general' ? '' : row.path.split('/')[0];
          ctx.go('items');
        }, 'مستخدم في ' + inUse + ' من العناصر — اضغط لفتح عناصر هذا القسم'),
        tiny('حذف', async () => {
          if (!ctx.writable()) return;
          if (!ask('حذف الملف نهائيًا من مستودع media؟' + (inUse ? ' إنه مستخدم في ' + inUse + ' من العناصر، وستصبح روابطها ميتة.' : ''))) return;
          try { await api.deleteMedia(row.path); await ctx.refresh(); } catch (error) { failWith(ctx, error); }
        })
      ])
    ]);
  }

  clear(host);
  host.append(
    el('section', { class: 'card' }, [el('h2', {}, 'رفع ملفات جديدة'), dropZone, pick, uploadLine]),
    el('section', { class: 'card' }, [
      el('h2', {}, ['المكتبة', libCount]),
      el('div', { class: 'grid three' }, [
        field('النوع', select([['', 'الكل'], ['image', 'صور'], ['video', 'فيديو'], ['audio', 'صوت']], ui.media.kind, (v) => { ui.media.kind = v; renderLibrary(); })),
        field('بحث', search),
        el('div', { class: 'btnrow', style: 'align-self:end' }, [
          el('a', { class: 'btn plain', href: 'https://supabase.com/dashboard', target: '_blank', rel: 'noopener noreferrer' }, 'مستودع Supabase')
        ])
      ]),
      grid
    ])
  );
  renderLibrary();
}

/* يطوي همزات الألف والتاء المربوطة والتطويل، فيطابق البحث «دولار» كتابةً واحدة. */
function searchFold(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[\u064B-\u0652\u0640]/g, '')
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .trim();
}

/* ── ٥) الأسعار ────────────────────────────────────────────────────────────── */
function pricesPanel(host, ctx) {
  const draw = () => {
    clear(host);
    const kind = ui.prices.kind;
    const all = ctx.model.prices.filter((r) => r.kind === kind).sort((a, b) => (a.sort_order - b.sort_order) || String(a.code).localeCompare(String(b.code)));
    const prices = ctx.model.settings.prices || {};
    const line = stateLine('', '');
    const results = el('div');
    const shown = el('div', { class: 'muted', style: 'margin:8px 0' });
    const search = input({
      value: ui.prices.q,
      placeholder: kind === 'fx' ? 'دولار أو USD أو يورو' : 'عيار 21 أو 21 أو جنيه ذهب',
      oninput: () => { ui.prices.q = search.value; renderRows(); }
    });

    const rowNode = (row) => {
      const edit = (key) => input({ value: String(row[key] ?? ''), dir: key === 'sort_order' ? 'ltr' : 'auto' });
      const cells = {};
      ['code', 'name', 'symbol', 'value', 'change'].forEach((key) => { cells[key] = edit(key); });
      const order = input({ type: 'number', dir: 'ltr', value: String(row.sort_order ?? 0) });
      return el('tr', {}, [
        td(withLtr(cells.code)), td(cells.name), td(withLtr(cells.symbol)), td(cells.value), td(cells.change), td(order),
        td(el('div', { class: 'btnrow' }, [
          tiny('حفظ', async () => {
            if (!ctx.writable()) return;
            const next = { ...row, code: cells.code.value.trim(), name: cells.name.value.trim(), symbol: cells.symbol.value.trim(), value: cells.value.value.trim(), change: cells.change.value.trim(), sort_order: Number(order.value) || 0 };
            if (!next.code || !next.name) { toast('الرمز والاسم مطلوبان.'); return; }
            try { await api.savePrice(next); await ctx.refresh(); } catch (error) { failWith(ctx, error); }
          }),
          row.id ? tiny('حذف', async () => {
            if (!ctx.writable()) return;
            if (!ask('حذف صف ' + row.code + '؟')) return;
            try { await api.deletePrice(row.id); await ctx.refresh(); } catch (error) { failWith(ctx, error); }
          }) : tiny('—', () => {})
        ]), 'acts')
      ]);
    };

    function renderRows() {
      const q = searchFold(ui.prices.q);
      const rows = q
        ? all.filter((row) => [row.code, row.name, row.symbol].some((v) => searchFold(v).includes(q)))
        : all;
      shown.textContent = q
        ? 'مطابق ' + rows.length + ' من ' + all.length + ' — الحفظ يعمل على الصفوف الظاهرة فقط.'
        : '';
      put(clear(results), rows.length
        ? tableNode(['الرمز', 'الاسم', 'علامة', 'القيمة', 'التغيّر', 'الترتيب', ''], rows.map(rowNode))
        : el('div', { class: 'muted', text: 'لا صف مطابق لهذا البحث.' }));
    }

    renderRows();

    host.append(
      card('صفوف الأسعار', arCount(all.length, { one: 'صف', two: 'صفّان', few: 'صفوف', many: 'صفًّا' }) + ' في ' + (kind === 'fx' ? 'العملات' : 'الذهب'), [
        el('div', { class: 'btnrow', style: 'margin-bottom:10px' }, [
          button('عملات (fx)', kind === 'fx' ? '' : 'plain', () => { ui.prices.kind = 'fx'; draw(); }),
          button('ذهب (gold)', kind === 'gold' ? '' : 'plain', () => { ui.prices.kind = 'gold'; draw(); }),
          button('+ صف', 'ghost', () => addRow())
        ]),
        el('div', { class: 'grid two' }, [field('بحث', search)]),
        shown,
        results
      ]),
      card('إعدادات الأسعار ونقاط التحديث', '', [
        el('div', { class: 'grid two' }, [
          field('الأساس (base)', input({ dir: 'ltr', value: prices.fxBase || 'EGP', oninput: (e) => { prices.fxBase = e.target.value; } })),
          field('تنبيه أسعار العملات', input({ value: prices.fxDisclaimer || '', oninput: (e) => { prices.fxDisclaimer = e.target.value; } })),
          field('تنبيه أسعار الذهب', input({ value: prices.goldDisclaimer || '', oninput: (e) => { prices.goldDisclaimer = e.target.value; } })),
          field('مسار ملف العملات', input({ dir: 'ltr', value: prices.fxUrl || '', oninput: (e) => { prices.fxUrl = e.target.value; } }), 'افتراضي: data/prices/fx.json'),
          field('مسار ملف الذهب', input({ dir: 'ltr', value: prices.goldUrl || '', oninput: (e) => { prices.goldUrl = e.target.value; } }), 'افتراضي: data/prices/gold.json'),
          field('API للعملات (احتياطي)', input({ dir: 'ltr', value: prices.liveFxApi || '', oninput: (e) => { prices.liveFxApi = e.target.value; } }), 'اختياري: يستخدمه التطبيق فقط إن فشل ملف JSON.'),
          field('API للذهب (احتياطي)', input({ dir: 'ltr', value: prices.liveGoldApi || '', oninput: (e) => { prices.liveGoldApi = e.target.value; } }))
        ]),
        el('div', { class: 'muted', text: 'جدول price_rows هو مصدر الملفات المنشورة. زر «مزامنة الأسعار الآن» يجلبها من المتصفح مباشرةً من open.er-api.com و gold-api ويكتبها بجلسة دخولك؛ ويعمل prices.yml تلقائيًا كل ساعتين على الجلب نفسه. المزامنة تنشر كل عملات الواجهة (١٦٠+) بأسمائها العربية، والصفوف المختارة يدويًا تأتي أولًا في التطبيق.' }),
        line,
        el('div', { class: 'btnrow', style: 'margin-top:10px' }, [
          button('حفظ الإعدادات', '', async () => {
            if (!ctx.writable()) return;
            setLine2(line, 'جارٍ الحفظ…', '');
            try { await api.saveSettings({ prices }); setLine2(line, 'حُفظت إعدادات الأسعار.', 'ok'); await ctx.refresh(); } catch (error) { setLine2(line, error.message, 'bad'); }
          }),
          button('مزامنة الأسعار الآن', 'ghost', async () => {
            if (!ctx.writable()) return;
            setLine2(line, 'جارٍ الجلب من الواجهات المفتوحة…', '');
            try {
              const out = await api.syncPrices('both');
              const parts = [];
              if (out.fx) parts.push(out.fx + ' عملة');
              if (out.gold) parts.push(out.gold + ' صف ذهب');
              setLine2(line, parts.length
                ? 'حُدِّث ' + parts.join(' و ') + ' في price_rows — تُنشر تلقائيًا بعد قليل.'
                : 'لم تُجلب أي أسعار.');
              await ctx.refresh();
            } catch (error) { setLine2(line, error.message, 'bad'); }
          })
        ])
      ])
    );
  };

  function withLtr(node) { return el('div', { dir: 'ltr', style: 'text-align:right' }, node); }

  function addRow() {
    if (!ctx.writable()) return;
    const kind = ui.prices.kind;
    const code = prompt('رمز الصف الجديد (مثل USD أو 24)', kind === 'fx' ? '' : '') || '';
    const name = prompt('الاسم المعروض', '');
    if (!code.trim() || !name) return;
    api.savePrice({
      kind, code: code.trim(), name: name.trim(), symbol: null, value: '', change: null,
      sort_order: (ctx.model.prices.filter((r) => r.kind === kind).length + 1) * 10
    }).then(() => ctx.refresh()).catch((error) => failWith(ctx, error));
  }

  draw();
}

/* ── ٦) القوانين ───────────────────────────────────────────────────────────── */
function legalPanel(host, ctx) {
  const draw = () => {
    clear(host);
    const key = ui.legal.key;
    const row = ctx.model.legal.find((doc) => doc.key === key) || { key, title: key === 'privacy' ? 'سياسة الخصوصية' : 'شروط الاستخدام', body: '' };
    const draft = { ...row };
    const line = stateLine('', '');
    const preview = el('div');
    const sync = () => { clear(preview).append(previewNode(draft.body)); };

    host.append(card(
      key === 'privacy' ? 'سياسة الخصوصية' : 'شروط الاستخدام',
      row.updated_at ? relTime(row.updated_at) : 'غير محفوظة',
      [
        el('div', { class: 'btnrow', style: 'margin-bottom:10px' }, [
          button('الخصوصية', key === 'privacy' ? '' : 'plain', () => { ui.legal.key = 'privacy'; draw(); }),
          button('الشروط', key === 'terms' ? '' : 'plain', () => { ui.legal.key = 'terms'; draw(); })
        ]),
        field('العنوان', input({ value: draft.title || '', oninput: (e) => { draft.title = e.target.value; } })),
        field('المتن (HTML مبسَّط)', textarea(draft.body || '', (v) => { draft.body = v; sync(); }), 'يُنقَّى تلقائيًا عند النشر: لا سكربتات ولا iframes.'),
        preview,
        line,
        el('div', { class: 'btnrow', style: 'margin-top:10px' }, [
          button('حفظ الوثيقة', '', async () => {
            if (!ctx.writable()) return;
            setLine2(line, 'جارٍ الحفظ…', '');
            try {
              await api.saveLegal({ key: draft.key, title: draft.title, body: draft.body });
              setLine2(line, 'حُفظت — ستظهر في التطبيق مع ' + AUTO_PUBLISH + '.', 'ok');
              await ctx.refresh();
            } catch (error) { setLine2(line, error.message, 'bad'); }
          }),
          el('a', { class: 'btn plain', href: 'data/legal/' + key + '.json', target: '_blank', rel: 'noopener' }, 'النسخة المنشورة')
        ])
      ]
    ));
    sync();
  };
  draw();
}

/* ── ٧) المظهر والإعدادات ──────────────────────────────────────────────────── */

/** معاينة من واجهة Aladhan نفسها التي يقرأها التطبيق، بلا مفاتيح. */
async function previewPrayer(location) {
  const lat = Number.isFinite(location.latitude) ? location.latitude : 31.1728;
  const lng = Number.isFinite(location.longitude) ? location.longitude : 31.2210;
  const today = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const url = 'https://api.aladhan.com/v1/timings/' +
    pad(today.getDate()) + '-' + pad(today.getMonth() + 1) + '-' + today.getFullYear() +
    '?latitude=' + lat + '&longitude=' + lng + '&method=5&school=0&timezonestamp=' +
    encodeURIComponent(location.timezone || 'Africa/Cairo');
  const res = await fetch(url);
  if (!res.ok) throw new Error('رمز ' + res.status);
  const body = await res.json();
  const data = (body && body.data) || {};
  const t = data.timings || {};
  const clock = (value) => String(value || '—').split(' ')[0];
  const method = ((data.meta && data.meta.method && data.meta.method.name) || '').trim();
  return 'الفجر ' + clock(t.Fajr) + ' · الظهر ' + clock(t.Dhuhr) + ' · العصر ' + clock(t.Asr) +
    ' · المغرب ' + clock(t.Maghrib) + ' · العشاء ' + clock(t.Isha) + (method ? ' — ' + method : '');
}

async function settingsPanel(host, ctx) {
  const settings = ctx.model.settings;
  const brand = { ...(settings.brand || {}) };
  const digest = { ...(settings.digest || {}) };
  const location = { ...(settings.location || {}) };
  const line = stateLine('', '');
  const placeLine = stateLine('', '');
  const logoUrl = input({ dir: 'ltr', value: brand.logoUrl || '', oninput: (e) => { brand.logoUrl = e.target.value; } });
  const logoPick = el('input', { type: 'file', accept: 'image/*', style: 'display:none', onchange: async (e) => {
    const file = e.target.files[0];
    if (!file || !ctx.writable()) return;
    setLine2(line, 'جارٍ رفع الشعار…', '');
    try {
      const meta = await api.uploadMedia(file, 'brand');
      brand.logoUrl = meta.url;
      logoUrl.value = meta.url;
      setLine2(line, 'رُفع الشعار — احفظ الإعدادات العامة لتثبيته.', 'ok');
    } catch (error) { setLine2(line, error.message, 'bad'); }
  } });

  host.append(
    card('العلامة', '', [
      el('div', { class: 'grid two' }, [
        field('اسم التطبيق', input({ value: brand.name || '', oninput: (e) => { brand.name = e.target.value; } })),
        field('السطر التحتي', input({ value: brand.tagline || '', oninput: (e) => { brand.tagline = e.target.value; } })),
        field('اللون الأساسي', input({ type: 'color', value: /^#[0-9a-f]{6}$/i.test(String(brand.primaryColor || '')) ? brand.primaryColor : '#2E7D5B', oninput: (e) => { brand.primaryColor = e.target.value; } }), 'يبني التطبيق منه لوحة ألوان Material 3.'),
        field('بريد الدعم', input({ type: 'email', dir: 'ltr', value: brand.supportEmail || '', oninput: (e) => { brand.supportEmail = e.target.value; } }), 'يظهر في التطبيق وفي صفحة الويب.'),
        field('رابط الشعار', logoUrl),
        field('خط مخصص (اختياري)', input({ dir: 'ltr', value: brand.fontFamily || '', placeholder: 'Cairo', oninput: (e) => { brand.fontFamily = e.target.value; } })),
        field('رابط CSS الخط', input({ dir: 'ltr', value: brand.fontUrl || '', oninput: (e) => { brand.fontUrl = e.target.value; } }))
      ]),
      el('div', { class: 'btnrow', style: 'margin-top:10px' }, [
        button('رفع شعار', 'ghost', () => logoPick.click()),
        el('span', { class: 'muted', text: 'PNG أو SVG أو WebP صغير — يُرفع إلى مستودع media ويوضع رابطه هنا.' })
      ]),
      logoPick
    ]),

    card('الملخص اليومي', '', [
      el('div', { class: 'muted', text: 'الموعد الذي يوقظ فيه التطبيق نفسه (WorkManager) والأقسام المضمَّنة افتراضيًا.' }),
      el('div', { class: 'grid three', style: 'margin-top:10px' }, [
        field('الساعة (٠–٢٣)', input({ type: 'number', dir: 'ltr', min: '0', max: '23', value: String(digest.hour ?? 7), oninput: (e) => { digest.hour = Number(e.target.value); } })),
        field('الدقائق', input({ type: 'number', dir: 'ltr', min: '0', max: '59', value: String(digest.minute ?? 30), oninput: (e) => { digest.minute = Number(e.target.value); } }))
      ]),
      el('div', { class: 'grid three', style: 'margin-top:8px' },
        ctx.model.sections.map((section) => checkbox(section.title, (digest.defaultSections || []).includes(section.id), (checked) => {
          const list = (digest.defaultSections || []).filter((id) => id !== section.id);
          if (checked) list.push(section.id);
          digest.defaultSections = list;
        }))
      )
    ]),

    card('موقع القرية (للأقسام الحيّة)', '', [
      el('div', { class: 'muted', text: 'إحداثيات واحدة تحسب منها مواقيت الصلاة والتقويم الهجري، وتُطلب منها حالة الطقس؛ لا يطلب التطبيق موقع هاتفك ولا يستأذن الوصول إلى GPS.' }),
      el('div', { class: 'grid two', style: 'margin-top:10px' }, [
        field('الاسم الظاهر للمستخدم', input({ value: location.name || '', placeholder: 'مركز بيلا، كفر الشيخ', oninput: (e) => { location.name = e.target.value; } })),
        field('المنطقة الزمنية', input({ dir: 'ltr', value: location.timezone || '', placeholder: 'Africa/Cairo', oninput: (e) => { location.timezone = e.target.value; } }), 'اسم منطقة Java مثل Africa/Cairo.'),
        field('خط العرض', input({ type: 'number', step: '0.000001', dir: 'ltr', value: location.latitude ?? '', placeholder: '31.1728', oninput: (e) => { location.latitude = e.target.value === '' ? null : Number(e.target.value); } })),
        field('خط الطول', input({ type: 'number', step: '0.000001', dir: 'ltr', value: location.longitude ?? '', placeholder: '31.2210', oninput: (e) => { location.longitude = e.target.value === '' ? null : Number(e.target.value); } }), 'اتركهما فارغين فيستخدم التطبيق موضع القرية الافتراضي.')
      ]),
      el('div', { class: 'btnrow', style: 'margin-top:10px' }, [
        button('معاينة المواقيت لهذه الإحداثيات', 'ghost', async () => {
          setLine2(placeLine, 'جارٍ السؤال…', '');
          try {
            setLine2(placeLine, 'مواقيت اليوم: ' + (await previewPrayer(location)), 'ok');
          } catch (error) { setLine2(placeLine, 'تعذّرت المعاينة: ' + error.message, 'bad'); }
        }),
        el('span', { class: 'muted', text: 'الهيئة المصرية العامة للمساحة، وعصر شافعي — وهي نفسها التي يقرأها التطبيق.' })
      ]),
      placeLine
    ]),

    card('تنبيه عام', '', [
      field('رسالة تظهر أعلى التطبيق والصفحة (اتركها فارغة لإخفائها)', textarea(settings.notice || '', (v) => { settings.notice = v; }), 'مثال: «نعمل على تحديث الأقسام، قد تتأخر الأخبار.»'),
      line,
      el('div', { class: 'btnrow', style: 'margin-top:10px' }, [
        button('حفظ الإعدادات العامة', '', async () => {
          if (!ctx.writable()) return;
          setLine2(line, 'جارٍ الحفظ…', '');
          try {
            const place = Number.isFinite(location.latitude) && Number.isFinite(location.longitude) ? location : null;
            await api.saveSettings({ brand, digest, location: place, notice: settings.notice || null });
            setLine2(line, 'حُفظ — يصل إلى التطبيق مع ' + AUTO_PUBLISH + '.', 'ok');
            await ctx.refresh();
          } catch (error) { setLine2(line, error.message, 'bad'); }
        })
      ])
    ]),

    card('المحررون المسموح لهم بالدخول', '', [
      editorsCard(ctx),
      el('div', { class: 'muted', style: 'margin-top:8px', text: 'جدول public.admin_emails هو مصدر الصلاحية في RLS. من يُحذف منه لا يستطيع القراءة ولا الكتابة حتى بكلمة مرور صحيحة.' })
    ]),

    card('كيف يصل المحتوى إلى التطبيق؟', '', [
      el('p', { class: 'muted', text: 'كل ما تحفظه هنا يبقى في Supabase، وناشر GitHub Actions يقرأ القاعدة ويكتب ملفات data/ كل ' + api.PUBLISH_EVERY_MINUTES + ' دقائق، ثم تحدّث GitHub Pages التطبيق. لذلك لا تحتاج أي مفتاح GitHub داخل اللوحة: دخولك إلى Supabase هو الصلاحية الوحيدة.' }),
      el('div', { class: 'btnrow', style: 'margin-top:10px' }, [
        el('a', { class: 'btn plain', href: api.PUBLISH_ACTIONS_URL, target: '_blank', rel: 'noopener' }, 'تشغيل النشر يدويًا على GitHub'),
        el('a', { class: 'btn plain', href: 'data/index.json', target: '_blank', rel: 'noopener' }, 'ملفات data/ المنشورة')
      ])
    ])
  );
}

function editorsCard(ctx) {
  const box = el('div');
  const list = el('div');
  const line = stateLine('', '');
  const emailField = input({ type: 'email', dir: 'ltr', placeholder: 'editor@example.com' });
  const labelField = input({ placeholder: 'اسم وصفي (اختياري)' });

  async function reload() {
    if (ctx.demo) { clear(list).append(el('div', { class: 'muted', text: 'غير متاح في وضع الاستعراض.' })); return; }
    try {
      const rows = await api.editors();
      clear(list).append(tableNode(['البريد', 'وصف', 'أُضيف', ''], rows.map((row) => el('tr', {}, [
        td(el('code', { text: row.email })), td(row.label || '—'), td(relTime(row.added_at)),
        td(tiny('سحب الوصول', async () => {
          if (!ask('سحب صلاحية ' + row.email + '؟ لن يستطيع فتح اللوحة.')) return;
          try { await api.removeEditor(row.email); await reload(); } catch (error) { setLine2(line, error.message, 'bad'); }
        }), 'acts')
      ]))));
    } catch (error) { clear(list).append(el('div', { class: 'state bad', text: error.message })); }
  }

  box.append(
    el('div', { class: 'grid three' }, [
      field('البريد', emailField), field('الوصف', labelField),
      el('div', { class: 'btnrow', style: 'align-self:end' }, [
        button('+ إضافة محرر', '', async () => {
          if (!ctx.writable()) return;
          const email = emailField.value.trim();
          if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) { setLine2(line, 'بريد غير صالح.', 'bad'); return; }
          try { await api.addEditor(email, labelField.value); emailField.value = ''; labelField.value = ''; setLine2(line, 'أُضيف.', 'ok'); await reload(); } catch (error) { setLine2(line, error.message, 'bad'); }
        }),
        tiny('تحديث', () => reload())
      ])
    ]),
    line, list
  );
  reload();
  return box;
}

/* ── ٨) سجل النشر ──────────────────────────────────────────────────────────── */
function logPanel(host, ctx) {
  const rows = ctx.model.log || [];
  host.append(
    card(arWord(rows.length, { one: 'آخر تشغيل', two: 'آخر تشغيلين', few: 'آخر ' + rows.length + ' تشغيلات', many: 'آخر ' + rows.length + ' تشغيلًا' }), '', [
      el('p', { class: 'muted', text: 'يكتبها ناشر GitHub Action في جدول publish_log بعد كل جولة تلقائية (كل ' + api.PUBLISH_EVERY_MINUTES + ' دقائق) أو بعد تشغيله يدويًا من المستودع.' }),
      rows.length ? tableNode(['الوقت', 'الحالة', 'النتيجة', 'أقسام', 'عناصر', 'Commit'], rows.map((row) => el('tr', {}, [
        td(relTime(row.created_at) + ' · ' + new Date(row.created_at).toLocaleString('ar-EG')),
        td(tag(row.status, row.status === 'ok' ? 'published' : row.status === 'partial' ? 'draft' : 'archived')),
        td(row.message || '—'),
        td(row.sections_written), td(row.items_written),
        td(row.commit_sha ? el('code', { text: String(row.commit_sha).slice(0, 8) }) : '—')
      ]))) : el('div', { class: 'muted', text: 'لم يُنفَّذ الناشر بعد في هذا المشروع.' })
    ])
  );
}
