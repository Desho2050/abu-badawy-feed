-- ─────────────────────────────────────────────────────────────────────────────
-- بذر محتوى قرية أبو بدوي في Supabase — مولّد تلقائيًا، لا تعديله يدويًا.
-- أعد التوليد: node tools/gen-seed-sql.mjs
-- نفّذه بعد supabase/sql/supabase-setup.sql. التكرار آمن (on conflict do nothing/update).
-- تاريخ التوليد: 2026-10-02T18:43:06.241Z
-- المصدر: web/data/index.json + sections/*.json + legal/*.json + prices/*.json
-- ─────────────────────────────────────────────────────────────────────────────

begin;

-- 1) الإعدادات العامة (تُملأ فقط إن لم تكن محررة بعد)
insert into public.app_settings (id, schema_version, brand, digest, prices, notice)
values (1, 1, '{"name":"قرية أبو بدوي","tagline":"أخبار القرية ومعالمها وأهلها بأسلوب بسيط","logoUrl":"assets/logo.svg","supportEmail":"example@abubadawy.local","primaryColor":"#00696E","fontUrl":"https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700&display=swap","fontFamily":"Cairo"}'::jsonb, '{"defaultSections":["village_news"],"hour":7,"minute":30}'::jsonb, '{"fxUrl":"data/prices/fx.json","goldUrl":"data/prices/gold.json","liveFxApi":"https://open.er-api.com/v6/latest/EGP","liveGoldApi":"https://api.gold-api.com/price/XAU","fxDisclaimer":"أسعار تقديرية للاسترشاد فقط","goldDisclaimer":"أسعار تقديرية للاسترشاد فقط — اعتمد على الصائغ المحلي"}'::jsonb, null)
on conflict (id) do update set
  schema_version = case when public.app_settings.schema_version = 1 then excluded.schema_version else public.app_settings.schema_version end,
  brand  = case when public.app_settings.brand  = '{}'::jsonb then excluded.brand  else public.app_settings.brand  end,
  digest = case when public.app_settings.digest = '{}'::jsonb then excluded.digest else public.app_settings.digest end,
  prices = case when public.app_settings.prices = '{}'::jsonb then excluded.prices else public.app_settings.prices end,
  notice = case when public.app_settings.notice is null then excluded.notice else public.app_settings.notice end;

-- 2) الأقسام (11)
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('about', 'التعريف بالقرية', null, 'info', 'richArticle', 'json', null, null, '{}'::jsonb, 10, true, false, false, true, 'admin', null)
on conflict (id) do nothing;
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('landmarks', 'معالم القرية', 'مساجد، مدارس، آثار وأماكن عامة', 'landmark', 'cards', 'json', null, null, '{}'::jsonb, 20, true, true, false, true, 'admin', null)
on conflict (id) do nothing;
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('figures', 'شخصيات بارزة', null, 'person', 'profiles', 'json', null, null, '{}'::jsonb, 30, true, false, false, true, 'admin', null)
on conflict (id) do nothing;
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('village_news', 'أخبار القرية', null, 'newspaper', 'list', 'json', null, null, '{}'::jsonb, 40, true, true, true, true, 'admin', null)
on conflict (id) do nothing;
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('world_news', 'أخبار عالمية', null, 'public', 'list', 'json', null, null, '{}'::jsonb, 50, true, false, false, true, 'admin', 'هذا القسم يُكتب ملخصًا أصليًا باللغة العربية مع رابط المصدر، لا نقلًا حرفيًا. أو يُحوَّل إلى RSS عبر تغيير source.kind في index.json (راجع README).')
on conflict (id) do nothing;
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('sports', 'أخبار الرياضة', null, 'trophy', 'list', 'json', null, null, '{}'::jsonb, 60, true, false, false, true, 'admin', null)
on conflict (id) do nothing;
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('currency', 'أسعار العملات', null, 'currency', 'rates', 'fx', null, null, '{}'::jsonb, 70, true, true, false, true, 'file', null)
on conflict (id) do nothing;
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('gold', 'أسعار الذهب', null, 'gold', 'rates', 'gold', null, null, '{}'::jsonb, 80, true, true, false, true, 'file', null)
on conflict (id) do nothing;
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('offers', 'عروض ومنتجات', null, 'sell', 'offers', 'json', null, null, '{}'::jsonb, 90, true, true, false, true, 'admin', null)
on conflict (id) do nothing;
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('ads', 'إعلانات القرية', null, 'campaign', 'ads', 'json', null, null, '{}'::jsonb, 100, true, false, false, true, 'admin', null)
on conflict (id) do nothing;
insert into public.sections (id, title, subtitle, icon, layout, source_kind, feed_url, item_selector,
                             headers, sort_order, enabled, show_on_home, notify_default, allow_breaking, items_source, note)
values ('obituaries', 'العزاء والوفيات', null, 'history', 'list', 'json', null, null, '{}'::jsonb, 110, false, false, false, true, 'admin', null)
on conflict (id) do nothing;

-- 3) العناصر (17) — كلها بحالة published لتحافظ على ما يراه المستخدمون
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('3e75ab17-f401-7c7f-bcfa-c555b493a788', 'about', 'about-1', 'قرية أبو بدوي', 'موقعها، تاريخها، وأهلها — صيغة جاهزة للتعبئة ببيانات القرية الحقيقية', '<h2>الموقع</h2><p>تقع القرية على … (اكتب هنا: أقرب مدينة، الطريق الرئيسي، المسافة، حدود القرية).</p><h2>الاسم والنسبة</h2><p>يُنسب الاسم إلى … (اكتب الرواية الموثّقة، ومصدرها).</p><h2>العمران والخدمات</h2><p>عدد العائلات تقريبًا: … — الخدمات: مسجد، مدرسة إعدادية، وحدة صحية، خزان مياه.</p><h2>الاقتصاد</h2><p>الزراعة هي الحرفة الأولى: … (محاصيل موسمية)، وتليها التجارة والمهن الحرفية.</p><h2>المناسبات</h2><p>موسم الحصاد، العزاء الجماعي، والعيد في ساحة القرية.</p>', 'assets/village.svg', 'تصميم توضيحي — حر الاستخدام (CC0)', null, null, null, '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, false, false, 'published', null, null, 1)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('cd4dd497-b063-e096-1952-dadfc52f5130', 'landmarks', 'lm-mosque', 'مسجد القرية الجامع', 'مركز التجمّع اليومي ومصلى العيد', '<p>تفاصيل عن تاريخ المسجد، إمامه، والخدمات الملحقة به (مكتبة، حلقة تحفيظ).</p>', 'assets/place-mosque.svg', 'رسم توضيحي — CC0', null, null, null, '["ديني","أثر"]'::jsonb, '{"الموقع":"وسط القرية","السنة":"أُعيد بناؤه عام …"}'::jsonb, '[]'::jsonb, true, false, 'published', '2026-09-01', '2026-09-01T00:00:00.000Z'::timestamptz, 3)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('0ec68762-3033-12fe-7fb3-6d7d65690d04', 'landmarks', 'lm-school', 'المدرسة الإعدادية', 'أقدم مدرسة في المنطقة', '<p>تاريخ الإنشاء، أبرز خريجيها، ومرافقها الحالية.</p>', 'assets/place-school.svg', 'رسم توضيحي — CC0', null, null, null, '["تعليم"]'::jsonb, '{"المرحلة":"إعدادي","عدد الفصول":"…"}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-08-20', '2026-08-20T00:00:00.000Z'::timestamptz, 2)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('f2b5f269-5dcb-a881-5743-cb754788fc87', 'landmarks', 'lm-water', 'خزان المياه', 'شريان القرية', '<p>معلومات عن شبكة المياه والصيانة الدورية.</p>', 'assets/place-water.svg', 'رسم توضيحي — CC0', null, null, null, '["خدمات"]'::jsonb, '{"السعة":"…","التغذية":"…"}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-08-11', '2026-08-11T00:00:00.000Z'::timestamptz, 1)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('575a85f5-607e-f133-1195-6ee980117ed3', 'figures', 'fg-1', 'الاسم الكامل للشخصية', 'دوره في القرية (معلم، مزارع، تاجر، طبيب…)', '<p>سيرة موجزة بمصادر واضحة: من روى هذه المعلومة؟ ومتى؟</p>', 'assets/avatar.svg', 'صورة توضيحية — CC0', null, null, null, '["تعليم"]'::jsonb, '{"المولد":"…","أبرز العطاءات":"…"}'::jsonb, '[]'::jsonb, false, false, 'published', '1950', null, 2)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('d8c86ed7-f57f-62ff-d88d-04aae3e24088', 'figures', 'fg-2', 'شخصية ثانية', 'وصف قصير يظهر تحت الاسم في القائمة', '<p>نص السيرة.</p>', 'assets/avatar.svg', 'صورة توضيحية — CC0', null, null, null, '["خدمة عامة"]'::jsonb, '{}'::jsonb, '[]'::jsonb, false, false, 'published', '1968', null, 1)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('f38d6a32-fa0b-00ab-1ab2-f84771f403b4', 'village_news', 'vn-1', 'عنوان خبر القرية', 'ملخص من سطرين يظهر في القائمة', '<p>متن الخبر: ماذا حدث؟ أين؟ متى؟ من الجهة المسؤولة؟</p><ul><li>تفصيلة أولى</li><li>تفصيلة ثانية</li></ul>', 'assets/news.svg', 'صورة توضيحية — CC0', null, null, null, '["خدمات"]'::jsonb, '{"التواصل":"…"}'::jsonb, '[{"type":"image","url":"assets/village.svg","label":"منظر عام"},{"type":"image","url":"assets/news.svg","label":"البوابة"}]'::jsonb, false, true, 'published', '2026-09-27', '2026-09-27T00:00:00.000Z'::timestamptz, 3)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('3d985f45-7402-d8de-b342-c6b438aa4ebe', 'village_news', 'vn-2', 'خبر ثانٍ عن أعمال الصيانة', 'مثال على خبر غير عاجل', '<p>نص الخبر.</p>', 'assets/news.svg', 'صورة توضيحية — CC0', null, null, null, '["أعمال عامة"]'::jsonb, '{}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-09-24', '2026-09-24T00:00:00.000Z'::timestamptz, 2)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('e8754205-b0a0-d5e2-7339-d72424de8b7b', 'village_news', 'vn-3', 'نتيجة طلاب القرية في الشهادة', 'مناسبات اجتماعية تُفرح القرية', '<p>نص الخبر.</p>', null, null, null, null, null, '["تعليم"]'::jsonb, '{}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-09-18', '2026-09-18T00:00:00.000Z'::timestamptz, 1)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('ee818953-c8bb-3516-020c-d5499c937b9a', 'world_news', 'wn-1', 'عنوان الخبر العالمي بصياغة القرية', 'ملخص من سطرين نكتبه بأسلوبنا، لا نسخة من المصدر', '<p>ملخص تحريري خاص بالقرية، ويظهر في التطبيق مع زر «فتح المصدر».</p>', null, null, 'https://example.com/original-story', 'اسم المصدر الأصلي', 'https://example.com/original-story', '["عالمي"]'::jsonb, '{}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-09-28', '2026-09-28T00:00:00.000Z'::timestamptz, 2)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('d37b1e9f-0990-d8c6-68a2-549e66e78f1f', 'world_news', 'wn-2', 'خبر ثانٍ مع مصدر موثّق', 'مثال على التوثيق', '<p>نص الملخص.</p>', null, null, 'https://example.com/another-story', 'اسم المصدر', 'https://example.com/another-story', '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-09-27', '2026-09-27T00:00:00.000Z'::timestamptz, 1)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('ff36c6fe-13a1-af51-e93b-87fd0be5a272', 'sports', 'sp-1', 'فريق القرية يفوز في دوري المنطقة', 'ملخص المباراة والأهداف بأسلوب محلي', '<p>التشكيلة، الأهداف، والكلمات المفتاحية التي يحبها جمهور القرية.</p>', 'assets/sport.svg', 'رسم توضيحي — CC0', null, null, null, '["دوري","محلي"]'::jsonb, '{}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-09-26', '2026-09-26T00:00:00.000Z'::timestamptz, 2)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('d764cd12-9af9-d79d-adaa-5fe1d325e533', 'sports', 'sp-2', 'نقل مباراة نهائي الكأس على شاشة الساحة', 'فعالية اجتماعية', '<p>تفاصيل الفعالية والمكان.</p>', null, null, 'https://example.com/match-info', 'المصدر', 'https://example.com/match-info', '[]'::jsonb, '{}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-09-22', '2026-09-22T00:00:00.000Z'::timestamptz, 1)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('546b37e8-376d-9e7a-5bdf-a1167fa39eaf', 'offers', 'of-1', 'تمور البلدية — درجة أولى', 'من مزرعة أم محمد، توصيل داخل القرية', '<p>الكمية المتاحة وطريقة الحجز.</p>', 'assets/product-dates.svg', 'صورة المنتج ملك لصاحب العرض', null, null, null, '["أغذية"]'::jsonb, '{"السعر":"… ج.م / كيلو","تواصل":"01xxxxxxxxx"}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-09-25', '2026-09-25T00:00:00.000Z'::timestamptz, 2)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('94c53480-31c9-4e50-6aa5-9ecd572bba2d', 'offers', 'of-2', 'خيالة موسمية', 'قطع بتفصيل المقاس', null, 'assets/product-craft.svg', null, null, null, null, '["حرف"]'::jsonb, '{"السعر":"…","تواصل":"…"}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-09-20', '2026-09-20T00:00:00.000Z'::timestamptz, 1)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('1e4b705a-e0a4-031c-df40-945ce5650515', 'ads', 'ad-1', 'افتتاح مخبز آلي جديد', 'بجوار المسجد — افتتاح تجريبي هذا الأسبوع', '<p>تفاصيل العنوان ومواعيد العمل.</p>', 'assets/ad-bakery.svg', null, null, null, null, '[]'::jsonb, '{"الموقع":"الشارع الرئيسي","تواصل":"01xxxxxxxxx"}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-09-26', '2026-09-26T00:00:00.000Z'::timestamptz, 2)
on conflict (id) do nothing;
insert into public.items (id, section_id, slug, title, subtitle, body, image, image_credit, link,
                          source_name, source_url, tags, fields, attachments, pinned, breaking,
                          status, event_date, published_at, sort_order)
values ('f3dd9db8-8423-9991-3ba8-e8a77b43693e', 'ads', 'ad-2', 'دروس تقوية مجانية لمدة أسبوع', 'لطلبة الثالث الإعدادي', '<p>المكان والمواعيد ورقم التواصل.</p>', null, null, null, null, null, '[]'::jsonb, '{"تنتهي":"2026-10-05"}'::jsonb, '[]'::jsonb, false, false, 'published', '2026-09-23', '2026-09-23T00:00:00.000Z'::timestamptz, 1)
on conflict (id) do nothing;

-- 4) القوانين
insert into public.legal_docs (key, title, body)
values ('privacy', 'سياسة الخصوصية', '<h2>ما لا نجمعه</h2><p>لا يسجل التطبيق حسابات، ولا يجمع اسمك أو رقم هاتفك أو موقعك الجغرافي، ولا يستخدم أي شبكة إعلانية أو أداة تتبع.</p><h2>ملفات الصور والفيديو</h2><p>تُستضاف وسائط الأخبار على خدمة تخزين ملفات عامة. عند فتح صورة أو مقطع يطلبها جهازك مباشرة من تلك الخدمة، فتحصل على عنوان IP الخاص بك كما يفعل أي موقع تزوره. لا يُرسل التطبيق اسمك ولا رقمك ولا أي معرّف جهاز، ولا يرفع أي ملف من جهازك إطلاقًا — التطبيق للعرض فقط.</p><h2>ما يُخزَّن على جهازك</h2><p>يحفظ التطبيق نسخة مؤقتة من المحتوى لتعمل الأقسام دون إنترنت. يمكنك حذفها في أي وقت من: الإعدادات ثم البيانات ثم تفريغ ذاكرة المحتوى.</p><h2>الإشعارات</h2><p>لا تصل أي إشعارات قبل موافقتك الصريحة. تختار الأقسام التي تريد متابعتها، ويصلك ملخص يومي واحد بدل إشعار لكل منشور.</p><h2>الاتصال بالإنترنت</h2><p>يطلب التطبيق ملفات بيانات عامة من صفحة القرية على GitHub Pages. قد يسجل مزود الاستضافة عنوان IP بشكل عام لأغراض التشغيل والأمان وفق سياسة المزود، ولا يملك التطبيق تحكمًا في ذلك.</p><h2>الأطفال</h2><p>التطبيق محتوى عام غير تفاعلي، ولا يجمع بيانات أي مستخدم بأي عمر.</p>')
on conflict (key) do update set
  title = case when public.legal_docs.body = '' then excluded.title else public.legal_docs.title end,
  body  = case when public.legal_docs.body = '' then excluded.body  else public.legal_docs.body  end;
insert into public.legal_docs (key, title, body)
values ('terms', 'شروط الاستخدام', '<h2>طبيعة المحتوى</h2><p>يُقدَّم المحتوى لأغراض إعلامية ومجتمعية خاصة بأهالي القرية. إدارة القرية غير ملزمة بنشر كل ما يرد إليها، ولها حق تعديل أو حذف أي محتوى.</p><h2>الملكية الفكرية</h2><p>المقالات والصور المنشورة في قسم أخبار القرية والمعالم والشخصيات هي ملك لأصحابها أو للقرية، ويُنسب كل عمل إلى صاحبه. يُمنع إعادة نشر المحتوى الخارجي داخل التطبيق دون إذن، ويُعرض ملخصه مع رابط المصدر الأصلي.</p><h2>الأسعار</h2><p>أسعار العملات والذهب تقديرية وتتغير لحظة بلحظة، وتُعرض للاسترشاد فقط ولا تُبنى عليها نصيحة مالية.</p><h2>الإعلانات والعروض</h2><p>ما يُنشر في قسمي العروض والإعلانات هو مسؤولية صاحبه. التطبيق وسيط عرض فقط ولا ضمان للسلع أو الخدمات.</p><h2>إنهاء الخدمة</h2><p>قد يتوقف التطبيق عن العمل مؤقتًا عند صيانة الصفحة أو تحديثها، دون أن يترتب على ذلك أي التزام على مشغّل التطبيق.</p>')
on conflict (key) do update set
  title = case when public.legal_docs.body = '' then excluded.title else public.legal_docs.title end,
  body  = case when public.legal_docs.body = '' then excluded.body  else public.legal_docs.body  end;

-- 5) جداول الأسعار (11 صفًا)
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('fx', 'USD', 'دولار أمريكي', '$', '…', '…', 0)
on conflict (kind, code) do nothing;
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('fx', 'EUR', 'يورو', '€', '…', '…', 1)
on conflict (kind, code) do nothing;
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('fx', 'SAR', 'ريال سعودي', '﷼', '…', '…', 2)
on conflict (kind, code) do nothing;
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('fx', 'AED', 'درهم إماراتي', 'د.إ', '…', '…', 3)
on conflict (kind, code) do nothing;
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('fx', 'KWD', 'دينار كويتي', 'د.ك', '…', '…', 4)
on conflict (kind, code) do nothing;
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('fx', 'GBP', 'جنيه إسترليني', '£', '…', '…', 5)
on conflict (kind, code) do nothing;
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('gold', '24', 'جرام ذهب عيار 24', 'ج.م', '…', '…', 0)
on conflict (kind, code) do nothing;
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('gold', '22', 'جرام ذهب عيار 22', 'ج.م', '…', '…', 1)
on conflict (kind, code) do nothing;
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('gold', '21', 'جرام ذهب عيار 21', 'ج.م', '…', '…', 2)
on conflict (kind, code) do nothing;
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('gold', '18', 'جرام ذهب عيار 18', 'ج.م', '…', '…', 3)
on conflict (kind, code) do nothing;
insert into public.price_rows (kind, code, name, symbol, value, change, sort_order)
values ('gold', 'XAU', 'أوقية الذهب عالميًا', '$', '…', '…', 4)
on conflict (kind, code) do nothing;

commit;

-- تحقّق:
--   select (select count(*) from public.sections) as sections,
--          (select count(*) from public.items)     as items,
--          (select count(*) from public.price_rows) as prices,
--          (select count(*) from public.legal_docs) as legal;
