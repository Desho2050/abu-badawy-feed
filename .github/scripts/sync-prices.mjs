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

/* مثل publish.mjs: رمز خفي أو مسافة أو مقطع /rest/v1 زائد في السرّ يفسد كل طلب. */
const RAW_URL = String(process.env.SUPABASE_URL || '').replace(/[\s\u0000-\u001f\u200b-\u200f\ufeff]/g, '');
const SUPABASE_URL = RAW_URL ? new URL(RAW_URL).origin : RAW_URL;
const SERVICE_KEY = String(process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || '')
  .replace(/[\s\u0000-\u001f\u200b-\u200f\ufeff]/g, '');
const KIND = (process.argv.find((arg) => arg.startsWith('--kind=')) || '--kind=both').split('=')[1];

const FX_API = 'https://open.er-api.com/v6/latest/USD';
const GOLD_API = process.env.LIVE_GOLD_API || 'https://api.gold-api.com/price/XAU';

/* تُعرض أولًا في التطبيق واللوحة؛ الباقي تأتي تلقائيًا من الواجهة بكل عملاتها. */
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

/* الأسماء العربية من بيانات CLDR التي يحمّلها Node نفسه — بلا جدول أسماء ولا شبكة إضافية. */
const NAMES_AR = new Intl.DisplayNames(['ar'], { type: 'currency' });

function arName(code) {
  try {
    return NAMES_AR.of(code) || code;
  } catch {
    return code;
  }
}

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('\n-- ERROR: ناقص: SUPABASE_URL / SUPABASE_SERVICE_KEY\n');
  process.exit(1);
}

/* عملة تساوِ أقل من جنيه (الدينار العراقي مثلًا) تُعرض بأربعة منازل، وإلا صارت 0.00. */
function money(value) {
  if (!Number.isFinite(value) || value <= 0) return null;
  const digits = value < 1 ? 4 : 2;
  return value.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: digits });
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
    const rates = data.rates || {};
    /* كل ما ترسله الواجهة، لا قائمة مختصرة: المتجر والسائح والوافد يبحثون عن أي عملة. */
    const priced = Object.keys(rates).filter((code) => {
      const perUsd = Number(rates[code]);
      return code !== 'EGP' && Number.isFinite(perUsd) && perUsd > 0;
    });
    const watch = new Map(FX_WATCH.map(([code, name, symbol]) => [code, { name, symbol }]));
    const ordered = [
      ...FX_WATCH.map(([code]) => code).filter((code) => priced.includes(code)),
      ...priced.filter((code) => !watch.has(code)).sort()
    ];
    const rows = ordered.map((code, index) => {
      /* بقسمة سعر الدولار بالجنيه على سعر العملة بالدولار نحصل على جنيه لكل وحدة،
         وهو اتجاه الأرقام الذي يعرضه التطبيق أصلًا. */
      const value = money(egpPerUsd / Number(rates[code]));
      if (!value) return null;
      const curated = watch.get(code);
      return {
        kind: 'fx',
        code,
        name: curated ? curated.name : arName(code),
        symbol: curated ? curated.symbol : null,
        value,
        change: null,
        sort_order: index
      };
    }).filter(Boolean);
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
