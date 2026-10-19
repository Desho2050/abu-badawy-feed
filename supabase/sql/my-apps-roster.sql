-- قسم «تطبيقاتي»: قائمة تطبيقات وألعاب حساب Desho.Co.Ltd في Google Play Console،
-- بمن فيها ما هو قيد الاختبار ولم يصل Production بعد.
--
-- المصدر: appSummaries من Console (عشرون تطبيقًا) + فحص صفحة المتجر العامة لكل حزمة:
-- HTTP 200 يعني منشورًا علنًا، و404 يعني داخل اختبار فقط فلا رابط متجر له.
-- تاريخ «آخر حزمة» هو آخر حزمة رُفعت في Console، لا تاريخ مراجعة المتجر.
--
-- اصطلاحات العنصر مطابقة لـ my-apps-section.sql:
--   الصورة     ← أيقونة التطبيق (lh3 / play-lh، عامة القراءة)
--   رابط خارجي ← صفحة المتجر، للمنشور علنًا فقط — بلا روابط ترفض الزائر
--   fields    ← الحزمة / المطوّر / النوع / الحالة / آخر حزمة
--
-- آمن للتكرار: يحذف سلاسل هذه القائمة ثم يعيد إدخالها، ولا يمسّ المحتوى المكتوب
-- يدويًا لعنصر «القران حياتي» (يرفع ترتيبه وحده).
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).
-- بعده يلتقطه كرون publish.yml ويكتبه في data/sections/my_apps.json خلال خمس دقائق.

begin;

-- 1) حذف عناصر القائمة إن سبق إدخالها (سلاسل هذا الملف وحدها).
delete from public.items
where section_id = 'my_apps'
  and slug in ('com-delocation-app', 'com-seham-zuma', 'com-desho-chickenwar', 'com-medowar-game', 'com-elwahsh-subway', 'net-quran-mihrab', 'com-desho-nearpass', 'com-desho-scanner', 'com-desho-scan_anything', 'com-desho-vpn', 'com-desho-browser', 'com-deshosmart-pos', 'com-aiphoto-editor2027', 'com-desho-medothegladiator', 'com-voidrun-game', 'com-desho-wahshelwhoosh', 'com-medo-webass', 'com-seham-fruits');

-- 2) العناصر: المنشور على المتجر أولًا (sort_order أعلى = يُرتَّل أولًا في الناشر)،
--    ثم تطبيقات الاختبار وألعابها.
insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   fields, status, sort_order, published_at, event_date)
values
  ('my_apps', 'com-delocation-app', 'دي لوكيشن', 'انتقل بموقعك إلى أي مكان! احمِ خصوصيتك واختبر التطبيقات بموقع GPS وهمي.', null, 'https://lh3.googleusercontent.com/7xXqW0hcLncZAaSon7Th39ufsjBiLzdvSJ00mavqlAQVchXKA1QhzSk-Ybnzn-qw3OidQrpqUri7-Rm2JLPO=w192-h192-rw', 'https://play.google.com/store/apps/details?id=com.delocation.app&hl=ar', 'Google Play', 'https://play.google.com/store/apps/details?id=com.delocation.app&hl=ar', '{"الحزمة":"com.delocation.app","المطوّر":"Desho.Co.Ltd","النوع":"تطبيق","الحالة":"منشور على متجر Google Play","آخر حزمة":"2026-10-18"}'::jsonb, 'published', 290, now(), '2026-10-18'),
  ('my_apps', 'com-seham-zuma', 'Seham', 'لعبة إطلاق الكرات الرخامية العربية! قم بمطابقة 3، وتكوين سلاسل متتالية، ومسح كل مسار ملون.', null, 'https://lh3.googleusercontent.com/mpKpSYywqcXlbKQ67Aujc0ucCDINqCbhe3hbFJLuPX71VVc0WzdA6xvc9soLdeAPWzBRduorEdbEcGJ_Wkg1hG4=w192-h192-rw', 'https://play.google.com/store/apps/details?id=com.seham.zuma&hl=ar', 'Google Play', 'https://play.google.com/store/apps/details?id=com.seham.zuma&hl=ar', '{"الحزمة":"com.seham.zuma","المطوّر":"Desho.Co.Ltd","النوع":"لعبة","الحالة":"منشور على متجر Google Play","آخر حزمة":"2026-10-18"}'::jsonb, 'published', 280, now(), '2026-10-18'),
  ('my_apps', 'com-desho-chickenwar', 'Chicken War', 'انطلق عبر 50 مستوى من دجاج الفضاء باستخدام المجموعات والقدرات الإضافية والزعماء.', null, 'https://lh3.googleusercontent.com/z0CibZqb9_sNQc-D7dM3Jsl39z7aW3d5A3DycMbF7N09BboX8o89p0dVcWXvsbCcqCS0U9vYFGgGkhVhxzb9hA=w192-h192-rw', 'https://play.google.com/store/apps/details?id=com.desho.chickenwar&hl=ar', 'Google Play', 'https://play.google.com/store/apps/details?id=com.desho.chickenwar&hl=ar', '{"الحزمة":"com.desho.chickenwar","المطوّر":"Desho.Co.Ltd","النوع":"لعبة","الحالة":"منشور على متجر Google Play","آخر حزمة":"2026-10-18"}'::jsonb, 'published', 270, now(), '2026-10-18'),
  ('my_apps', 'com-medowar-game', 'Medo-War', 'قم ببناء مملكة من القرون الوسطى، ودرب جيشاً، واسحق معسكرات العدو في الوقت الفعلي.', null, 'https://lh3.googleusercontent.com/Lndf5AI_aAn3pEjrjB3YYEoBgE9QelnXoixS3KDodrx-dSE0xHvQHdarbQixwbXuZnX8bmeqadHlcJ2bltwja3k=w192-h192-rw', 'https://play.google.com/store/apps/details?id=com.medowar.game&hl=ar', 'Google Play', 'https://play.google.com/store/apps/details?id=com.medowar.game&hl=ar', '{"الحزمة":"com.medowar.game","المطوّر":"Desho.Co.Ltd","النوع":"لعبة","الحالة":"منشور على متجر Google Play","آخر حزمة":"2026-10-18"}'::jsonb, 'published', 260, now(), '2026-10-18'),
  ('my_apps', 'com-elwahsh-subway', 'El-Wahsh Subway', 'تفادى القطارات والحواجز في نفق مترو القاهرة في هذه اللعبة التي تعتمد على إبهام واحد.', null, 'https://lh3.googleusercontent.com/Bob6bZRqhVXqRmTW5MK0DU4QcHRfE_4wjm1tmmxA_JouE4d2qt2RVK8y9CHYyYZB0Gqf3qRxENp87K-yHkfOUQ=w192-h192-rw', 'https://play.google.com/store/apps/details?id=com.elwahsh.subway&hl=ar', 'Google Play', 'https://play.google.com/store/apps/details?id=com.elwahsh.subway&hl=ar', '{"الحزمة":"com.elwahsh.subway","المطوّر":"Desho.Co.Ltd","النوع":"لعبة","الحالة":"منشور على متجر Google Play","آخر حزمة":"2026-10-18"}'::jsonb, 'published', 250, now(), '2026-10-18'),
  ('my_apps', 'net-quran-mihrab', 'محراب — مصاحف بأصوات القرّاء', 'تطبيق قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/WZuhsBiWPfpnLDcsEHEpwszKsFqPRaHuj44VJ5RRvvKvmoYnJGwGI-uTbJ03gE9Bnm1TyDsadqNVoR2XYVxEoG4=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"net.quran.mihrab","المطوّر":"Desho.Co.Ltd","النوع":"تطبيق","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-19"}'::jsonb, 'published', 240, now(), '2026-10-19'),
  ('my_apps', 'com-desho-nearpass', 'Nearpass M0: Transfer Test', 'تطبيق قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/8hvdTz-sU2gJinWKnX4tZJ9YATtro08lqUPDMOaE1faMraF8tt_2tgkrYNeE360i_EClXZIpvRpD3n3SvjFuJe0=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.desho.nearpass","المطوّر":"Desho.Co.Ltd","النوع":"تطبيق","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-18"}'::jsonb, 'published', 230, now(), '2026-10-18'),
  ('my_apps', 'com-desho-scanner', 'Desho-Scanner', 'تطبيق قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/lghI2Jc5sQ_mtWeYIQ-epttAX4Z1TSCI3-Mt4I6_fix26frFnzcB_wHZ7ar2dprWgg2mg1Wo-Mu3BmId70lI=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.desho.scanner","المطوّر":"Desho.Co.Ltd","النوع":"تطبيق","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-18"}'::jsonb, 'published', 220, now(), '2026-10-18'),
  ('my_apps', 'com-desho-scan_anything', 'Scan Anything', 'تطبيق قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/wr7hq49_BLj49l1mGB_xpaRJ8FqMOkVWHeCsrwc9UgmBSyEbVMFgz1TfI5AncY51026019bFl8eos_LiROdb=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.desho.scan_anything","المطوّر":"Desho.Co.Ltd","النوع":"تطبيق","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-17"}'::jsonb, 'published', 210, now(), '2026-10-17'),
  ('my_apps', 'com-desho-vpn', 'Desho VPN', 'تطبيق قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/PcXYy8-hdRKIy5rRrTZ4WoRn7J4usPL6LWO0GkVb89RTcq294inTVcgT-3cvw9fzaydGmox2ExxF2D8saE2agw=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.desho.vpn","المطوّر":"Desho.Co.Ltd","النوع":"تطبيق","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-17"}'::jsonb, 'published', 200, now(), '2026-10-17'),
  ('my_apps', 'com-desho-browser', 'Desho.Browser', 'تطبيق قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/MWW1LV5Kaw-1hJtenitKmyADVzAfs9n4SqMl2V2FqjmUCco6qm8ljpSkexrMO8QyIPcP9Tabjtuo7CjX1UW8o8k=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.desho.browser","المطوّر":"Desho.Co.Ltd","النوع":"تطبيق","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-17"}'::jsonb, 'published', 190, now(), '2026-10-17'),
  ('my_apps', 'com-deshosmart-pos', 'DeshoSmart POS', 'تطبيق قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/oG0B9MQvbjKlZZEGGVDA0jfc5WKuzJEnL_-hTnt2B5Uk2ux0wnRRJ7F_9NBYsnO5wmPyUnYFP7arPg29vLKRWw=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.deshosmart.pos","المطوّر":"Desho.Co.Ltd","النوع":"تطبيق","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-17"}'::jsonb, 'published', 180, now(), '2026-10-17'),
  ('my_apps', 'com-aiphoto-editor2027', 'AI Photo 2027: On-Device Edit', 'تطبيق قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/WNekBu_5OZJLkDKoaR06YZC5__7yvjJVrT0FZEgn8HFAgYDoC2TSX0Ef2uqOFKuciHAkpO0SPet2RcOP2GMX=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.aiphoto.editor2027","المطوّر":"Desho.Co.Ltd","النوع":"تطبيق","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-09"}'::jsonb, 'published', 170, now(), '2026-10-09'),
  ('my_apps', 'com-desho-medothegladiator', 'Medo The Gladiator', 'لعبة قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/IlKsj6UabFj-2WX9K7AbmKM5sgUv2MFhqESf67ZkNLHC3m5KhMThioWgvwliyVNo9advjLIgwLpvaOy0HuXy=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.desho.medothegladiator","المطوّر":"Desho.Co.Ltd","النوع":"لعبة","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-13"}'::jsonb, 'published', 160, now(), '2026-10-13'),
  ('my_apps', 'com-voidrun-game', 'VOIDRUN', 'لعبة قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/ttmZaGeERDbGaERDD-vQvrHSAlZjDafrCc76yEOmfJ9FgPQ5lGKDr2_R03cFgEPycIMsRPgpnbGvV9zCkXcNWM4=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.voidrun.game","المطوّر":"Desho.Co.Ltd","النوع":"لعبة","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-17"}'::jsonb, 'published', 150, now(), '2026-10-17'),
  ('my_apps', 'com-desho-wahshelwhoosh', 'Wahsh ElWhoosh Tower Defense', 'لعبة قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/xcqeJmCpjzz0OxrtHAh89_eYc0LT_v0nAxpWQ0v_ZZ82tUpPj6rUH41zl0sw5-uoRMAdiOQTQVnE2_5w37dnGQ=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.desho.wahshelwhoosh","المطوّر":"Desho.Co.Ltd","النوع":"لعبة","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-17"}'::jsonb, 'published', 140, now(), '2026-10-17'),
  ('my_apps', 'com-medo-webass', 'Medowebass - Voxel World', 'لعبة قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/auzO8XUgLOReRlM74u6uoRv_-qaBgBAhfTzpnvLygwxAmcD68EkxS1YjO27rXI0ihgyxSyPU3FZlHRV9TodjZn0=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.medo.webass","المطوّر":"Desho.Co.Ltd","النوع":"لعبة","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-17"}'::jsonb, 'published', 130, now(), '2026-10-17'),
  ('my_apps', 'com-seham-fruits', 'Seham Fruits', 'لعبة قيد الاختبار — لم يصل صفحة المتجر العامة بعد', null, 'https://lh3.googleusercontent.com/eQkyR4VXCmDNLHp5dD4vPjgoUQkheBWhl58jPfmSrroy5a3arVVG-hiur3iYVTz9c6qaJe_acU8jqtIm3s8i83A=w192-h192-rw', null, 'Desho.Co.Ltd', null, '{"الحزمة":"com.seham.fruits","المطوّر":"Desho.Co.Ltd","النوع":"لعبة","الحالة":"قيد الاختبار — لم يُنشر علنًا على المتجر بعد","آخر حزمة":"2026-10-17"}'::jsonb, 'published', 120, now(), '2026-10-17')
;

-- 3) تقديم عنصر «القران حياتي» إلى رأس القائمة دون تغيير نصّه.
update public.items set sort_order = 300, updated_at = now()
where section_id = 'my_apps' and slug = 'ketabu-raby';

commit;

-- 4) فحص: ما سيُنشر فعليًا (يجب أن يكون تسعة عشر عنصرًا).
select sort_order as ترتيب, slug as المعرّف, title as العنوان,
       fields->>'النوع' as نوع, fields->>'الحالة' as حالة,
       (link is not null) as له_رابط
from public.items
where section_id = 'my_apps' and status = 'published'
order by sort_order desc;
