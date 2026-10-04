-- قسم «أخبار كفر الشيخ»: كل ما يُنشر عن المحافظة من مصادر يُسمح بها برنامجيًا.
--
-- لا DDL هنا: التخطيط (list) والمصدر (json) والأعمدة كلها مستخدمة فعلًا، فالقيد
-- sections_layout_check وsections_source_kind_check لا يحتاجان تعديلًا. القسم يُكتب
-- في جدول items، فيولّد منه publish.mjs الملف data/sections/local_news.json تلقائيًا
-- في جولة */5 القادمة — والتطبيق يقرأ الأقسام من index.json، فلا حاجة لنسخة APK جديدة.
--
-- من أين يأتي المحتوى (كلها واجهات مفتوحة مُصمَّمة للجلب الآلي، لا استخراج من صفحات):
--   1) البوابة الرسمية للمحافظة kfs.gov.eg — robots.txt عندها «Disallow:» فارغة، أي
--      أن الموقع يأذن لكل زائر بالوصول، ونحن نأخذ العنوان والرابط والصورة المصغّرة
--      والتاريخ فقط من صفحة القائمة، ونترك القارئ يفتح الخبر في مصدره.
--   2) موجز NewsAPI بكلمات مفتاحية المحافظة — واجهة رسمية بمفتاح، ومرجعها مذكور مع
--      كل بطاقة مع رابط للمقال الأصلي، وهو ما تطلبه شروط خدمتهم.
--   3) الخلاصات العربية المستخدمة أصلًا (بي بي سي عربي، فرانس 24، سكاي نيوز، الجزيرة،
--      سبوتنيك) — تُمرَّر على فلتر كلمات المحافظة، فيظهر خبرها عن كفر الشيخ هنا أيضًا.
--
-- سياسة الحقوق: لا يُنقل متن الخبر كاملًا أبدًا. البطاقة عنوانٌ + ملخّص قصير (يصل من
-- التغذية نفسها أو من مقتطف البوابة الرسمية) + اسم المصدر + زر «افتح المصدر».
--
-- آمن للتكرار: insert ... on conflict (id)، والعناصر الآلية يديرها sync-news.mjs وحده
-- (بادئة الslug «rss-» + القيد الفريد items_rss_slug_key)، فإضافة مدير عنصرًا يدويًا من
-- اللوحة لا تُمسح، وتثبيت خبر أو تعليمه عاجلًا يبقى بعد كل جولة.
--
-- الترتيب 45: بعد «أخبار القرية» (40) وقبل «أخبار عالمية» (50)، ليكون المحلّي جنب القرية.
-- نفّذه في Supabase ← SQL Editor (مشروع DeshoStore)، أو عبر جولة النشر ثم شغّل
-- workflow «مزامنة الأخبار» من Actions لملء القسم.

-- 1) القسم
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, items_source, note)
values
  ('local_news', 'أخبار كفر الشيخ',
   'أخبار المحافظة: البوابة الرسمية وخلاصات الوكالات، مع ذكر المصدر لكل خبر', 'place', 'list', 'json', 45,
   true, true, false, true, 'admin',
   'يملؤه .github/scripts/sync-news.mjs آليًا: البوابة الرسمية kfs.gov.eg + بحث NewsAPI بكلمات المحافظة + فلتر على الخلاصات العربية الموجودة. البطاقة عنوان وملخّص قصير ورابط للمصدر، لا متن منقول. العناصر الآلية يبدأ slug بالبادئة rss-؛ العناصر اليدوية لا يمسّها المزامن.')
on conflict (id) do update
  set title         = excluded.title,
      subtitle      = excluded.subtitle,
      icon          = excluded.icon,
      layout        = excluded.layout,
      source_kind   = excluded.source_kind,
      sort_order    = excluded.sort_order,
      enabled       = excluded.enabled,
      show_on_home  = excluded.show_on_home,
      notify_default = excluded.notify_default,
      allow_breaking = excluded.allow_breaking,
      note          = excluded.note;

-- 2) فحص: القسم موجود بالقيم الصحيحة، ولا صراع مع أسماء قائمة.
select id, title, layout, source_kind, sort_order, enabled, show_on_home, allow_breaking, items_source
  from public.sections
 where id = 'local_news';

-- 3) عدد العناصر الآلية في القسم (يكون صفرًا قبل أول جولة مزامنة).
select count(*) as عناصر_آلية
  from public.items
 where section_id = 'local_news' and slug like 'rss-%';
