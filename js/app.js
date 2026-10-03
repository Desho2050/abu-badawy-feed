/* نقطة الإقلاع: بوابة الدخول، التنقل بين اللوحات، والنشر الفوري.
   لا تُحمَّل أي لوحة قبل أن يكون هناك نموذج (Supabase أو ملفات منشورة). */

import { el, clear, toast, field, input, stateLine } from './dom.js';
import { icon } from './icons.js';
import * as api from './db.js';
import { PANELS, ui, setLinkPreviews } from './panels.js';

const NAV = [
  ['overview', 'نظرة عامة', 'grid'],
  ['sections', 'الأقسام', 'list'],
  ['items', 'العناصر', 'article'],
  ['media', 'الوسائط', 'image'],
  ['prices', 'الأسعار', 'currency'],
  ['legal', 'القوانين', 'info'],
  ['settings', 'المظهر والإعدادات', 'settings'],
  ['log', 'سجل النشر', 'history']
];

const state = { model: null, panel: 'overview', user: null, busy: false, railMin: false };

const ctx = {
  get model() { return state.model; },
  get demo() { return !!(state.model && state.model.demo); },
  get user() { return state.user; },
  go(panel) { location.hash = '#' + panel; },
  async refresh() { await loadModel(); await renderPanel(); },
  writable() {
    if (!ctx.demo) return true;
    toast('وضع الاستعراض للقراءة فقط — سجّل الدخول إلى Supabase للتحرير.', 4000);
    return false;
  },
  banner(kind, text, actions = []) { renderBanner(kind, text, actions); }
};

/* ── البوابة ───────────────────────────────────────────────────────────────── */
function gate() {
  const host = document.getElementById('gate');
  clear(host);
  return host;
}

function renderConnect(message) {
  const saved = api.savedConnection();
  const url = input({ dir: 'ltr', placeholder: api.PROJECT_URL, autocomplete: 'off' }, saved.url || api.PROJECT_URL);
  const anon = input({ dir: 'ltr', placeholder: 'anon public key (eyJ…)', autocomplete: 'off' }, saved.anon);
  const line = stateLine(message || '', message ? 'bad' : '');
  const status = stateLine('اترك الحقلين فارغين إذا أردت مجرد استعراض النسخة المنشورة.');

  const connect = el('button', {
    class: 'btn',
    onclick: async () => {
      const u = url.value.trim();
      const a = anon.value.trim();
      const isLocal = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?\/?$/.test(u);
      if (!isLocal && !/^https:\/\/.+\..+/.test(u)) { setLine(line, 'العنوان يجب أن يبدأ بـ https:// — أو http://localhost:PORT للتجربة المحلية.', 'bad'); return; }
      if (a.length < 20) { setLine(line, 'مفتاح anon قصير أو ناقص.', 'bad'); return; }
      setBusy(connect, true);
      try {
        api.saveConnection(u, a);
        api.connect(u, a);
        const user = await api.currentUser();
        if (user) { state.user = user; await openAdmin(); return; }
        renderLogin();
      } catch (error) {
        setLine(line, 'تعذّر الاتصال: ' + error.message, 'bad');
      } finally {
        setBusy(connect, false);
      }
    }
  }, 'اتصال وتسجيل دخول');

  const explore = el('button', { class: 'btn plain', onclick: () => enterDemo() }, 'استعراض النسخة المنشورة (قراءة فقط)');

  gate().append(
    el('h2', {}, 'لوحة تحكم محتوى قرية أبو بدوي'),
    el('p', { class: 'muted', text: 'تُخزَّن البيانات في مشروع Supabase الخاص بك، ثم ينشرها GitHub Action كملفات JSON يقرأها التطبيق. لا تغادر مفاتيحك هذا المتصفح.' }),
    field('رابط المشروع', url, 'SUPABASE_URL من Settings ← API'),
    field('مفتاح anon العام', anon, 'SUPABASE_ANON_KEY — لا تكتب service key هنا، فهو للمنفّذ الخلفي فقط.'),
    line,
    el('div', { class: 'btnrow' }, [connect, explore]),
    status
  );
}

function renderLogin(message) {
  const saved = api.savedConnection();
  const email = input({ type: 'email', dir: 'ltr', placeholder: 'admin@…', autocomplete: 'username' });
  const pass = input({ type: 'password', dir: 'ltr', placeholder: 'كلمة المرور', autocomplete: 'current-password' });
  const line = stateLine(message || '', message ? 'bad' : '');

  const enter = el('button', {
    class: 'btn',
    onclick: async () => {
      if (!email.value.trim() || !pass.value) { setLine(line, 'اكتب البريد وكلمة المرور.', 'bad'); return; }
      setBusy(enter, true);
      try {
        api.connect(saved.url, saved.anon);
        await api.signIn(email.value, pass.value);
        state.user = await api.currentUser();
        await openAdmin();
      } catch (error) {
        setLine(line, 'لم يتم الدخول: ' + error.message + (
          /row-level|not authorized|invalid/i.test(error.message) ? '' : ' — تأكد أن البريد مضاف في public.admin_emails.'
        ), 'bad');
      } finally {
        setBusy(enter, false);
      }
    }
  }, 'دخول');

  gate().append(
    el('h2', {}, 'تسجيل دخول المدير'),
    el('div', { class: 'muted', text: saved.url }),
    field('البريد', email),
    field('كلمة المرور', pass),
    line,
    el('div', { class: 'btnrow' }, [
      enter,
      el('button', { class: 'btn plain', onclick: () => enterDemo() }, 'استعراض القراءة فقط'),
      el('button', { class: 'btn ghost', onclick: () => renderConnect() }, 'تغيير الاتصال')
    ])
  );
}

async function enterDemo() {
  const host = gate();
  clear(host).append(el('h2', {}, 'جارٍ قراءة الملفات المنشورة…'));
  try {
    state.model = await api.loadDemoModel();
    state.user = null;
    await openAdmin();
  } catch (error) {
    renderConnect('لا يمكن قراءة data/index.json (' + error.message + '). افتح الصفحة من مستوى المستودع نفسه.');
  }
}

async function loadModel() {
  const host = gate();
  clear(host).append(el('h2', {}, 'جارٍ تحميل البيانات…'));
  try {
    state.model = await api.loadModel();
    setLinkPreviews(state.model.previews);
    clear(host);
  } catch (error) {
    state.model = null;
    renderConnect('فشل التحميل من Supabase: ' + error.message);
    throw error;
  }
}

async function openAdmin() {
  if (!ctx.demo) await loadModel();
  clear(gate());
  renderShell();
  if (!ctx.demo) {
    const last = (state.model.log || [])[0];
    renderBanner('info', 'التعديلات تُنشر تلقائيًا كل ' + api.PUBLISH_EVERY_MINUTES + ' دقائق' +
      (last && last.created_at ? ' — آخر نشر: ' + new Date(last.created_at).toLocaleString('ar-EG') : '.') +
      ' لا حاجة لأي مفتاح GitHub داخل اللوحة؛ دخول Supabase يكفي.', [
      el('button', { class: 'iconbtn', onclick: () => { clear(document.getElementById('banner')); } }, 'إخفاء')
    ]);
  }
  await renderPanel();
}

/* ── الهيكل: العلامة، القائمة، من نحن ──────────────────────────────────────── */
function renderBanner(kind, text, actions = []) {
  const host = document.getElementById('banner');
  if (!host) return;
  clear(host);
  if (!text) return;
  host.append(el('div', { class: 'banner ' + kind }, [el('span', { text }), ...actions]));
}

function renderShell() {
  fillBrand();
  renderNav();
  wireRail();
  renderRail();
  renderWho();
  renderTopActions();
  if (ctx.demo) {
    renderBanner('info', 'وضع الاستعراض: تُعرض الملفات المنشورة في data/ كما يراها التطبيق، والتحرير معطَّل.', [
      el('button', { class: 'iconbtn', onclick: () => renderLogin('') }, 'دخول للتحرير')
    ]);
  }
}

function fillBrand() {
  const brand = (state.model && state.model.settings && state.model.settings.brand) || {};
  document.getElementById('brandName').textContent = brand.name || 'قرية أبو بدوي';
  document.getElementById('brandTagline').textContent = brand.tagline || 'لوحة التحكم بالمحتوى';
  const logo = document.getElementById('brandLogo');
  const url = brand.logoUrl || brand.logo;
  if (url) logo.src = String(url);
  const color = String(brand.seedColor || brand.primaryColor || '');
  if (/^#[0-9a-f]{6}$/i.test(color)) {
    document.documentElement.style.setProperty('--brand', color);
    document.documentElement.style.setProperty('--brand-soft', 'color-mix(in srgb, ' + color + ' 16%, transparent)');
  }
}

function counts() {
  const m = state.model;
  if (!m) return {};
  return {
    sections: m.sections.length,
    items: m.items.length,
    media: m.media.length,
    prices: m.prices.length
  };
}

function renderNav() {
  const host = document.getElementById('nav');
  const c = counts();
  clear(host).append(...NAV.map(([id, label, iconName]) => el('button', {
    dataset: { panel: id },
    class: id === state.panel ? 'active' : '',
    title: label,
    onclick: () => { location.hash = '#' + id; }
  }, [
    el('span', { class: 'icell' }, [icon(iconName, 17)]),
    el('span', { class: 'ct', text: label }),
    c[id] !== undefined ? el('span', { class: 'n', text: c[id] }) : null
  ])));
}

/* ── شريط الأقسام الجانبي: يعمل كمرشّح للقائمة كما في المتاجر ─────────────── */
const RAIL_KEY = 'abu-badawy-rail-min';
let railWired = false;

function selectSection(id) {
  ui.items.section = id;
  ui.items.editing = null;
  if (state.panel === 'items' && (location.hash || '#items') === '#items') {
    renderPanel();
    renderRail();
  } else {
    ctx.go('items');
  }
}

function applyRailMode() {
  const shell = document.getElementById('shell');
  const toggle = document.getElementById('railToggle');
  if (!shell || !toggle) return;
  shell.classList.toggle('railmin', state.railMin);
  toggle.setAttribute('aria-expanded', String(!state.railMin));
  toggle.title = state.railMin ? 'تكبير الأقسام' : 'تصغير الأقسام';
  toggle.setAttribute('aria-label', state.railMin ? 'تكبير الأقسام' : 'تصغير الأقسام');
  clear(toggle).append(icon('collapse', 17));
}

function wireRail() {
  if (!railWired) {
    railWired = true;
    try { state.railMin = localStorage.getItem(RAIL_KEY) === '1'; } catch (error) { state.railMin = false; }
    document.getElementById('railToggle').addEventListener('click', () => {
      state.railMin = !state.railMin;
      try { localStorage.setItem(RAIL_KEY, state.railMin ? '1' : '0'); } catch (error) { /* التخزين اختياري */ }
      applyRailMode();
    });
  }
  applyRailMode();
}

function renderRail() {
  const host = document.getElementById('secnav');
  const total = document.getElementById('railTotal');
  if (!host || !state.model) return;
  const m = state.model;
  const perSection = {};
  m.items.forEach((item) => { perSection[item.section_id] = (perSection[item.section_id] || 0) + 1; });
  const sections = m.sections.slice().sort((a, b) => (a.sort_order - b.sort_order) || String(a.title).localeCompare(String(b.title), 'ar'));
  const onItems = state.panel === 'items' && !ui.items.editing;

  const row = (id, label, iconName, count) => el('button', {
    type: 'button',
    class: 'sec' + (onItems && ui.items.section === id ? ' active' : ''),
    dataset: { section: id },
    title: label + ' — ' + count,
    onclick: () => selectSection(id)
  }, [
    el('span', { class: 'icell' }, [icon(iconName, 17)]),
    el('span', { class: 'ct', text: label }),
    el('span', { class: 'n', text: String(count) })
  ]);

  clear(host).append(
    row('', 'كل الأقسام', 'grid', m.items.length),
    ...sections.map((section) => row(
      section.id,
      section.title || section.id,
      section.icon || 'article',
      perSection[section.id] || 0
    ))
  );
  if (total) total.textContent = String(sections.length);
}

function renderWho() {
  const host = document.getElementById('who');
  const kids = [el('b', { text: state.user ? state.user.email : 'زائر (قراءة فقط)' })];
  if (state.user) {
    kids.push(el('div', { class: 'btnrow' }, [
      el('button', {
        class: 'btn plain', onclick: async () => {
          await api.signOut();
          state.user = null;
          state.model = null;
          clear(document.getElementById('panel'));
          clear(document.getElementById('banner'));
          clear(document.getElementById('topActions'));
          clear(document.getElementById('nav'));
          renderLogin('تم تسجيل الخروج.');
        }
      }, 'خروج'),
      el('button', { class: 'iconbtn', onclick: () => renderConnect() }, 'مشروع آخر')
    ]));
  } else {
    kids.push(el('button', { class: 'btn plain', onclick: () => renderLogin('') }, 'دخول للتحرير'));
  }
  clear(host).append(...kids);
}

function renderTopActions() {
  const host = document.getElementById('topActions');
  clear(host).append(
    el('button', { class: 'btn plain', onclick: () => ctx.refresh() }, 'تحديث'),
    el('a', {
      class: 'btn ghost',
      href: api.PUBLISH_ACTIONS_URL,
      target: '_blank',
      rel: 'noopener',
      title: 'النشر يعمل تلقائيًا كل ' + api.PUBLISH_EVERY_MINUTES + ' دقائق — هنا يمكن تشغيله فورًا من مستودع الملفات.'
    }, 'نشر فوري (GitHub)')
  );
}

/* ── اللوحة الحالية ────────────────────────────────────────────────────────── */
async function renderPanel() {
  const id = decodeURIComponent((location.hash || '').replace('#', ''));
  if (PANELS[id]) state.panel = id;
  const def = PANELS[state.panel];
  if (!def) return;
  document.getElementById('panelTitle').textContent = def.title;
  document.getElementById('panelSub').textContent = def.sub;
  const host = document.getElementById('panel');
  clear(host).append(el('div', { class: 'muted', text: '…' }));
  try {
    clear(host);
    await def.render(host, ctx);
  } catch (error) {
    clear(host).append(el('div', { class: 'state bad', text: 'تعذّر عرض اللوحة: ' + error.message }));
  }
  renderNav();
  renderRail();
}

function setLine(node, message, kind) {
  node.className = 'state ' + (kind || '');
  node.textContent = message;
}

function setBusy(button, busy) {
  if (!button) return;
  state.busy = busy;
  button.disabled = !!busy;
  if (!busy) return;
  setTimeout(() => { button.disabled = false; }, 20000);
}

window.addEventListener('hashchange', () => { if (state.model) renderPanel(); });
document.addEventListener('ab:section-filter', () => renderRail());

/* إن وُجدت جلسة محفوظة من زيارة سابقة نُفتح مباشرة، وإلا تظهر البوابة. */
async function boot() {
  const saved = api.savedConnection();
  if (saved.url && saved.anon) {
    api.connect(saved.url, saved.anon);
    const user = await api.currentUser().catch(() => null);
    if (user) {
      state.user = user;
      await openAdmin();
      return;
    }
    renderLogin();
    return;
  }
  renderConnect();
}

boot();
