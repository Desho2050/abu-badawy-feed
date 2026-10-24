-- توسيعُ قيدِ التخطيطِ ليقبلَ 'quranRead' (قسم «قراءةُ القرآن الكريم»).
--
-- ⛔ لا تُشغّلْ هذا من اللوحة: drop constraint يُفعِّل حرّاسَ اللوحة التدميريةَ فيُبطلُ
--    التشغيلَ بصمت، فتظنُّ أنك وسّعتَ القيدَ وهو لم يتغيّر. شغّلْهُ في Supabase ← SQL
--    Editor ← الصق ← Run، ثم اقرأ آخرَ سطرَينِ من الناتجِ للتأكد.
--
-- لماذا لا تُدرَجُ القائمةُ الجديدةُ هنا حرفيًّا؟ لأنَّ أيَّ نسخةٍ محفوظةٍ منها أقدمُ من
-- نسخةِ القاعدةِ الحيّةِ: مَن يُلصقْ قائمةً جاهزةً يُسقِطْ ما زادَتْ عليهِ القاعدةُ (وهكذا
-- ضاع 'jobs' و'fixes' مرةً من قبلُ). فهذا الملفُ يقرأُ تعريفَ القيدِ من pg_constraint
-- ويُلحِقُ 'quranRead' بنهايةِ قائمةِ ARRAY الحيّةِ دونَ أن يلمسَ عنصرًا منها، فإن لم يجدْ
-- صيغةً يفهمُها توقّفَ ورفعَ تحذيرًا ولم يُسقطْ شيئًا.
--
-- آمنٌ للتكرار: إن كانَ القيدُ قد قبلَ quranRead لم يُلغِ ولم يُضِفْ وخرجَ بملاحظةٍ واحدة.
-- لا يمسُّ بياناتِ الأقسامِ ولا أيَّ قيدٍ آخر. وقيدُ supabase-setup.sql في مشروعٍ جديدٍ
-- موسَّعٌ في المستودعِ نفسِه فلا يحتاجُ هذا.
--
-- ترتيبُ التشغيلِ معَ غيرِه: هذا أولًا، ثم quran-reader-section.sql (الإدراجُ بـ
-- layout=quranRead يرفضُهُ القيدُ غيرُ الموسَّعِ كلَّه).

begin;

do $$
declare
  live_def   text;
  new_def    text;
  n_bracket  integer;
begin
  select pg_get_constraintdef(oid) into live_def
    from pg_constraint
   where conrelid = 'public.sections'::regclass
     and conname  = 'sections_layout_check';

  if live_def is null then
    raise notice 'NOTICE: لا قيدَ sections_layout_check على public.sections — لا توسيعَ مطلوبًا.';
    return;
  end if;

  if position('quranRead' in live_def) > 0 then
    raise notice 'NOTICE: القيدُ يقبلُ quranRead بالفعل — لا تغيير.';
    return;
  end if;

  -- الصيغةُ الوحيدةُ المفهومةُ هنا قيدٌ على عمودٍ نصيٍّ بقائمةِ نصٍّ واحدة:
  --   CHECK ((layout = ANY (ARRAY['richArticle'::text, ..., 'hadith'::text])))
  -- فإشارةٌ واحدةٌ إلى «]» شرطٌ في التوسيعِ الآليِّ؛ غيرها يرفعُ التحذيرَ ولا يعبث.
  n_bracket := length(live_def) - length(replace(live_def, ']', ''));
  if n_bracket <> 1 then
    raise warning 'WARNING: تعريفُ القيدِ ليسَ قائمةً واحدةً (% من «]») — لا توسيعَ آليًّا.', n_bracket;
    raise warning 'WARNING: التعريفُ الحيُّ: %', live_def;
    raise exception 'QUIT: لم يُلغَ شيءٌ ولم يُضَفْ شيء.';
  end if;

  new_def := replace(live_def, ']', ', ''quranRead''::text]');

  execute 'alter table public.sections drop constraint sections_layout_check';
  execute 'alter table public.sections add constraint sections_layout_check ' || new_def;

  raise notice 'NOTICE: وُسِّعَ القيدُ بإلحاقِ quranRead بالقائمةِ الحيّةِ.';
end $$;

commit;

-- تدقيقٌ (قراءةٌ فقط): التعريفُ بعدَ التوسيعِ — هو البرهانُ، بلا صفٍّ وهميٍّ ولا حذف.
do $$
declare def text;
begin
  select pg_get_constraintdef(oid) into def
    from pg_constraint where conname = 'sections_layout_check';
  if def is null then
    raise warning 'WARNING: لا قيدَ sections_layout_check — أُلغِيَ ولم يُعَدْ إنشاءُهُ.';
  elsif position('quranRead' in def) > 0 then
    raise notice 'NOTICE: القيدُ يقبلُ quranRead الآن.';
  else
    raise warning 'WARNING: القيدُ لا يقبلُ quranRead بعدُ — أبطَلَ التشغيلَ حارسُ اللوحة.';
  end if;
end $$;

select pg_get_constraintdef(oid) as sections_layout_check
  from pg_constraint where conname = 'sections_layout_check';
