/* أيقونات SVG مرسومة هنا فقط: مسارات ثابتة لا تأتي من محتوى المحرر،
   فلا خطر حقن رغم استخدام innerHTML. الاسم نص في جدول الأقسام، لذا
   أي قسم جديد يظهر بأيقونة معروفة دون تعديل اللوحة. */

const PATHS = {
  info: '<circle cx="12" cy="12" r="8.6"/><path d="M12 11.4v5"/><path d="M12 7.8h.01"/>',
  article: '<path d="M5 5.5h11v13.5H5z"/><path d="M16 9.5h3.2v9.5H16"/><path d="M7.6 8.8h6M7.6 12h6M7.6 15.2h4"/>',
  list: '<path d="M9 6.5h11M9 12h11M9 17.5h11"/><path d="M5 6.5h.01M5 12h.01M5 17.5h.01"/>',
  grid: '<rect x="4.5" y="4.5" width="6.2" height="6.2" rx="1.6"/><rect x="13.3" y="4.5" width="6.2" height="6.2" rx="1.6"/><rect x="4.5" y="13.3" width="6.2" height="6.2" rx="1.6"/><rect x="13.3" y="13.3" width="6.2" height="6.2" rx="1.6"/>',
  image: '<rect x="4" y="5.5" width="16" height="13" rx="2.4"/><circle cx="9.2" cy="10.2" r="1.5"/><path d="M5.4 17 10 12.6l3.4 3 2.6-2.2 3 3.6"/>',
  currency: '<circle cx="12" cy="12" r="8.6"/><path d="M12 7.4v9.2"/><path d="M14.6 9.6c-.6-.8-1.6-1.2-2.6-1.2-1.6 0-2.6.8-2.6 1.9 0 2.4 5.2 1.3 5.2 3.7 0 1.2-1.2 2-2.8 2-1.1 0-2.1-.4-2.7-1.2"/>',
  diamond: '<path d="M8.4 4.2h7.2l3.9 5.1L12 19.8 4.5 9.3z"/><path d="M4.5 9.3h15M9.3 9.3 12 4.2l2.7 5.1L12 19.8"/>',
  trophy: '<path d="M8 4.5h8v3.8a4 4 0 0 1-8 0z"/><path d="M8 6H5.4v1.6A3 3 0 0 0 8 10.4M16 6h2.6v1.6A3 3 0 0 1 16 10.4"/><path d="M12 12.4v3.4M8.8 19.6h6.4"/>',
  settings: '<circle cx="12" cy="12" r="2.8"/><path d="M12 4.4v2.2M12 17.4v2.2M4.4 12h2.2M17.4 12h2.2M6.6 6.6l1.6 1.6M15.8 15.8l1.6 1.6M17.4 6.6l-1.6 1.6M8.2 15.8l-1.6 1.6"/>',
  history: '<circle cx="12" cy="12" r="8.6"/><path d="M12 7.6V12l3.2 2"/>',
  person: '<circle cx="12" cy="9" r="3.4"/><path d="M5.6 19.4c1-3.2 3.4-4.8 6.4-4.8s5.4 1.6 6.4 4.8"/>',
  landmark: '<path d="M12 4 4.6 8.2h14.8z"/><path d="M4.6 19.8h14.8M6.8 17.6V10.4M11 17.6v-7.2M13 17.6v-7.2M17.2 17.6v-7.2"/>',
  pin: '<path d="M12 20.4s6.6-6 6.6-10.4a6.6 6.6 0 1 0-13.2 0c0 4.4 6.6 10.4 6.6 10.4z"/><circle cx="12" cy="10" r="2.4"/>',
  campaign: '<path d="M4.4 10.4v3.2h2.8l6.8 3.8V6.6L7.2 10.4z"/><path d="M16.8 9.4a3.8 3.8 0 0 1 0 5.2"/><path d="M6 13.6v4.4"/>',
  sell: '<path d="M20 12.6 12.6 20a1.9 1.9 0 0 1-2.7 0L4 14.1V4h10.1z"/><path d="M8.6 8.6h.01"/>',
  shop: '<path d="M4.4 9.2 6 4.4h12l1.6 4.8"/><path d="M5.6 9.2v10.4h12.8V9.2"/><path d="M9.6 19.6v-5.4h4.8v5.4"/>',
  drop: '<path d="M12 4.2l5.8 8.1a5.8 5.8 0 0 1-11.6 0z"/>',
  collapse: '<path d="M14.6 6.4 9 12l5.6 5.6"/><path d="M19 6.4 13.4 12 19 17.6"/>'
};

const ALIAS = {
  about: 'info', news: 'article', newspaper: 'article', profile: 'person', figure: 'person',
  group: 'person', people: 'person', world: 'article', globe: 'article', public: 'article',
  money: 'currency', exchange: 'currency', gold: 'diamond', jewelry: 'diamond',
  offer: 'sell', sale: 'sell', product: 'sell', ads: 'campaign', announce: 'campaign',
  mosque: 'landmark', building: 'landmark', place: 'pin', location: 'pin', map: 'pin',
  farm: 'drop', water: 'drop', palm: 'drop', agriculture: 'drop', menu: 'grid', more: 'grid',
  config: 'settings', legacy: 'history', video: 'image', photo: 'image', media: 'image'
};

/** يُرجِع عنصر span يحمل الأيقونة، مع ارتداد إلى أيقونة المقال. */
export function icon(name, size = 18) {
  const key = String(name || '').trim().toLowerCase().replace(/[-_]/g, '');
  const glyph = PATHS[key] || PATHS[ALIAS[key]] || PATHS.article;
  return el(`
    <svg viewBox="0 0 24 24" width="${size}" height="${size}" aria-hidden="true" focusable="false"
      fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"
      stroke-linejoin="round">${glyph}</svg>
  `);
}

/* يبني عنصراً من وسوم ثابتة مصدرها هذا الملف فقط. */
function el(markup) {
  const host = document.createElement('span');
  host.className = 'ic';
  host.innerHTML = markup;
  return host;
}
