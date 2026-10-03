#!/usr/bin/env node
/*
 * مزامن الأسعار: يجلب الأسعار لحظيًا من واجهات مفتوحة ويكتبها في جدول
 * price_rows في Supabase — وهو مصدر ملفي data/prices/fx.json و gold.json
 * اللذين يقرأهما التطبيق من GitHub Pages (يرندرها scripts/publish.mjs).
 *
 * لماذا لا يكتب هذا السكريبت الملفات مباشرة؟ حتى يبقى مصدر واحد للتعديل:
 * اللوحة والمزامن والنشر كلهم يكتبون/يقرؤون نفس الصفوف، فلا يتصارع ريبو وقاعدة.
 *
 *   node .github/scripts/sync-prices.mjs            # العملات + الذهب
 *   node .github/scripts/sync-prices.mjs --kind=fx  # العملات فقط
 *
 * يعمل بلا اعتماديات على Node 20. المفاتيح من أسرار GitHub Actions.
 */

const SUPABASE_URL = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const KIND = (process.argv.find((arg) => arg.startsWith('--kind=')) || '--kind=both').split('=')[1];

const FX_API = 'https://open.er-api.com/v6/latest/USD';
const GOLD_API = process.env.LIVE_GOLD_API || 'https://api.gold-api.com/price/XAU';

/* ما يعرفه المستخدم المصري: سعر الجنيه مقابل الجنيه المصري. */
const FX_WATCH = [
  ['USD', 'دولار أمريكي', '$'],
  ['EUR', 'يورو', '€'],
  ['SAR', 'ريال سعودي', '﷼'],
  ['AED', 'درهم إماراتي', 'د.إ'],
  ['KWD', 'دينار كويتي', 'د.ك'],
  ['GBP', 'جنيه إسترليني', '£'],
  ['TRY', 'ليرة تركية', '₺']
];

const GRAM = 31.1034768;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('\n-- ERROR: ناقص: SUPABASE_URL / SUPABASE_SERVICE_KEY\n');
  process.exit(1);
}

function money(value) {
  if (!Number.isFinite(value) || value <= 0) return null;
  return value.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

async function getJson(url) {
  const res = await fetch(url, { signal: AbortSignal.timeout(30000), headers: { 'User-Agent': 'AbuBadawyWebPage/1.0 (content sync job)' } });
  if (!res.ok) throw new Error(url + ' → HTTP ' + res.status);
  return res.json();
}

/** upsert عبر PostgREST: دمج على (kind, code). */
async function upsert(rows) {
  if (!rows.length) return 0;
  /* عمود النزاع يُمرَّر استعلامًا (on_conflict=)، لا في ترويسة Prefer؛
     وإلا صار الدمج على المفتاح الأساسي وألقى 409 على أول تكرار. */
  const res = await fetch(SUPABASE_URL + '/rest/v1/price_rows?on_conflict=kind,code', {
    method: 'POST',
    headers: {
      apikey: SERVICE_KEY,
      Authorization: 'Bearer ' + SERVICE_KEY,
      'Content-Type': 'application/json',
      Prefer: 'resolution=merge-duplicates',
      Accept: 'application/json'
    },
    body: JSON.stringify(rows),
    signal: AbortSignal.timeout(45000)
  });
  if (!res.ok) throw new Error('price_rows upsert → HTTP ' + res.status + ': ' + (await res.text()).slice(0, 300));
  return rows.length;
}

const wanted = (['fx', 'gold', 'both'].includes(KIND) ? (KIND === 'both' ? ['fx', 'gold'] : [KIND]) : ['fx', 'gold']);
let written = 0;

if (wanted.includes('fx')) {
  try {
    const data = await getJson(FX_API);
    const egpPerUsd = Number(data?.rates?.EGP);
    if (!Number.isFinite(egpPerUsd) || egpPerUsd <= 0) throw new Error('لا سعر EGP في الرد');
    const rows = [];
    FX_WATCH.forEach(([code, name, symbol], index) => {
      const perUsd = Number(data.rates[code]);
      /* بقسمة سعر الدولار بالجنيه على سعر العملة بالدولار نحصل على جنيه لكل وحدة،
         وهو اتجاه الأرقام الذي يعرضه التطبيق أصلًا. */
      const value = code === 'EGP' ? money(egpPerUsd) : money(egpPerUsd / perUsd);
      if (value) rows.push({ kind: 'fx', code, name, symbol, value, change: null, sort_order: index });
    });
    written += await upsert(rows);
    console.log('✓ fx ← ' + rows.length + ' عملة (دولار = ' + money(egpPerUsd) + ' ج.م)');
  } catch (error) {
    console.log('-- NOTICE: تعذّر تحديث العملات، تُترك القيم السابقة: ' + error.message);
  }
}

if (wanted.includes('gold')) {
  try {
    const [ounce, fx] = await Promise.all([getJson(GOLD_API), getJson(FX_API)]);
    const ounceUsd = Number(ounce?.price ?? ounce?.data?.price ?? ounce?.USD);
    const egpPerUsd = Number(fx?.rates?.EGP);
    if (!Number.isFinite(ounceUsd) || ounceUsd <= 0) throw new Error('لا سعر أوقية في الرد');
    if (!Number.isFinite(egpPerUsd) || egpPerUsd <= 0) throw new Error('لا سعر EGP في الرد');
    const gram24 = (ounceUsd / GRAM) * egpPerUsd;
    const rows = [
      ['24', 'جرام ذهب عيار 24', gram24],
      ['22', 'جرام ذهب عيار 22', (gram24 * 22) / 24],
      ['21', 'جرام ذهب عيار 21', (gram24 * 21) / 24],
      ['18', 'جرام ذهب عيار 18', (gram24 * 18) / 24],
      ['SOV', 'جنيه ذهب (8 جرام عيار 21)', ((gram24 * 21) / 24) * 8],
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
    written += await upsert(rows);
    console.log('✓ gold ← ' + rows.length + ' صف (عيار 24 = ' + money(gram24) + ' ج.م)');
  } catch (error) {
    console.log('-- NOTICE: تعذّر تحديث الذهب، تُترك القيم السابقة: ' + error.message);
  }
}

if (!written) {
  console.error('\n-- ERROR: لم تُحدَّث أي صفوف — تحقق من الواجهات المفتوحة ومن المفتاحين.\n');
  process.exit(1);
}
console.log('\nتمت مزامنة ' + written + ' صف أسعار في price_rows.');
