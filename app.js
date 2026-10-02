/*
 * محرّك صفحة قرية أبو بدوي.
 * مصدر الحقيقة واحد: data/index.json + ملفات الأقسام. الصفحة لا تُخزّن شيئًا،
 * وما يقرأه الإنسان يقرأه التطبيق من نفس السمات (data-ab-*).
 */
(function () {
  'use strict';

  var BASE = new URL('.', window.location.href).href;

  function url(path) {
    return new URL(path, BASE).href;
  }

  function getJson(path) {
    return window.fetch(url(path), { cache: 'no-cache' }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status + ' — ' + path);
      return r.json();
    });
  }

  function el(tag, attrs, children) {
    var node = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (key) {
      if (attrs[key] === null || attrs[key] === undefined || attrs[key] === false) return;
      if (key === 'text') node.textContent = String(attrs[key]);
      else if (key === 'html') node.innerHTML = attrs[key];
      else node.setAttribute(key, attrs[key] === true ? '' : String(attrs[key]));
    });
    (children || []).forEach(function (child) {
      if (child) node.appendChild(child);
    });
    return node;
  }

  function fmtDate(value) {
    if (!value) return '';
    var parsed = new Date(value.length === 4 ? value + '-01-01' : value);
    if (isNaN(parsed.getTime())) return value;
    try {
      return new Intl.DateTimeFormat('ar-EG', { dateStyle: 'medium' }).format(parsed);
    } catch (e) {
      return value;
    }
  }

  function fmtDateTime(value) {
    if (!value) return 'غير معروف';
    var parsed = new Date(value);
    if (isNaN(parsed.getTime())) return value;
    try {
      return new Intl.DateTimeFormat('ar-EG', {
        dateStyle: 'medium', timeStyle: 'short', timeZone: 'Africa/Cairo'
      }).format(parsed);
    } catch (e) {
      return value;
    }
  }

  /* أسماء السمات لا تحتمل مسافات؛ التطبيق يعيد الشرطة إلى مسافة عند العرض. */
  function fieldSlug(key) {
    return String(key).trim().replace(/\s+/g, '-').replace(/[&<>"'=/]/g, '');
  }

  /* رابط قابل للتحويل إلى URL مطلق؛ المُلغى يُتجاهل بدل أن يُسقط العنصر كله. */
  function safeUrl(path) {
    if (!path) return false;
    try { new URL(path, BASE); return true; } catch (e) { return false; }
  }

  /* ── بناء عنصر واحد بالسماة التي يعتمد عليها محلّل التطبيق ───────────── */
  function itemNode(section, item) {
    var attachments = (item.attachments || []).filter(function (a) { return a && safeUrl(a.url); }).map(function (a) {
      return {
        type: a.type || 'image',
        url: url(a.url),
        poster: safeUrl(a.poster) ? url(a.poster) : '',
        label: a.label || '',
        duration: a.duration || ''
      };
    });
    var firstPhoto = attachments.filter(function (a) { return a.type === 'image'; })[0];
    var cover = safeUrl(item.image) ? url(item.image) : (firstPhoto ? firstPhoto.url : '');

    var article = el('article', {
      class: 'ab-item' + (item.pinned ? ' ab-pinned' : '') + (item.breaking ? ' ab-breaking' : ''),
      'data-ab-id': item.id,
      'data-ab-title': item.title || '',
      'data-ab-subtitle': item.subtitle || '',
      'data-ab-image': cover,
      'data-ab-image-credit': item.imageCredit || '',
      'data-ab-link': item.link || '',
      'data-ab-date': item.date || '',
      'data-ab-tags': (item.tags || []).join(','),
      'data-ab-pinned': item.pinned ? 'true' : 'false',
      'data-ab-breaking': item.breaking ? 'true' : 'false',
      'data-ab-source-name': (item.source && item.source.name) || '',
      'data-ab-source-url': (item.source && item.source.url) || item.link || ''
    });

    if (attachments.length) article.setAttribute('data-ab-attachments', JSON.stringify(attachments));

    var image = (cover && cover !== (firstPhoto && firstPhoto.url))
      ? el('img', { class: 'ab-thumb', src: cover, alt: item.title || '', loading: 'lazy' })
      : null;

    var head = el('div', { class: 'ab-head' }, [
      item.breaking ? el('span', { class: 'ab-flag', text: 'عاجل' }) : null,
      el('h3', { class: 'ab-item-title', text: item.title || '' }),
      el('span', { class: 'ab-date', text: fmtDate(item.date) })
    ]);

    var subtitle = item.subtitle ? el('p', { class: 'ab-item-subtitle', text: item.subtitle }) : null;

    // الحقول الإضافية: data-ab-f-<name> تُقرأ في التطبيق كأزواج مفتاح/قيمة
    Object.keys(item.fields || {}).forEach(function (key) {
      article.setAttribute('data-ab-f-' + fieldSlug(key), String(item.fields[key]));
    });

    var body = el('div', { class: 'ab-body', 'data-ab-body': '' });
    body.innerHTML = item.body || '';

    var sourceUrl = (item.source && item.source.url) || item.link || '';
    var footer = el('div', { class: 'ab-foot' }, [
      sourceUrl
        ? el('a', {
            class: 'ab-source',
            href: sourceUrl,
            rel: 'noopener noreferrer nofollow',
            target: '_blank',
            text: 'المصدر: ' + ((item.source && item.source.name) || 'الرابط الأصلي')
          })
        : null,
      item.imageCredit ? el('span', { class: 'ab-credit', text: item.imageCredit }) : null
    ]);

    if (image) article.appendChild(image);
    article.appendChild(head);
    if (subtitle) article.appendChild(subtitle);
    article.appendChild(el('div', { class: 'ab-fields' }, Object.keys(item.fields || {}).map(function (key) {
      return el('span', { class: 'ab-field', text: key + ': ' + item.fields[key] });
    })));
    if ((item.tags || []).length) {
      article.appendChild(el('div', { class: 'ab-tags' }, item.tags.map(function (tag) {
        return el('span', { class: 'ab-tag', text: tag });
      })));
    }
    article.appendChild(body);
    if (attachments.length) {
      article.appendChild(el('div', { class: 'ab-media-wrap' }, attachments.map(function (a) {
        if (a.type === 'video') {
          return el('video', {
            class: 'ab-media', src: a.url, controls: true, preload: 'none',
            playsinline: true, poster: a.poster || undefined
          });
        }
        if (a.type === 'audio') {
          return el('audio', { class: 'ab-media-audio', src: a.url, controls: true, preload: 'none' });
        }
        return el('img', { class: 'ab-media-img', src: a.url, alt: a.label || '', loading: 'lazy' });
      })));
    }
    article.appendChild(footer);
    return article;
  }

  function rateNode(rate) {
    return el('div', { class: 'ab-rate', 'data-ab-f-code': rate.code, 'data-ab-f-value': rate.value }, [
      el('span', { class: 'ab-rate-name', text: rate.name }),
      el('span', { class: 'ab-rate-value', text: rate.value + ' ' + (rate.symbol || '') }),
      rate.change ? el('span', { class: 'ab-rate-change', text: rate.change }) : null
    ]);
  }

  function sectionNode(section, payload) {
    var wrap = el('section', {
      class: 'ab-section',
      id: 'section-' + section.id,
      'data-ab-section': section.id,
      'data-ab-layout': section.layout,
      'data-ab-title': section.title
    });

    wrap.appendChild(el('h2', { class: 'ab-section-title', text: section.title }));
    if (section.subtitle) wrap.appendChild(el('p', { class: 'ab-section-sub', text: section.subtitle }));

    if (payload.kind === 'rates') {
      var table = payload.table;
      wrap.appendChild(el('p', { class: 'ab-updated', text: 'آخر تحديث: ' + fmtDateTime(table.updatedAt) }));
      wrap.appendChild(el('div', { class: 'ab-rates' }, (table.rates || []).map(rateNode)));
      if (table.disclaimer) wrap.appendChild(el('p', { class: 'ab-note', text: table.disclaimer }));
      return wrap;
    }

    var items = payload.items || [];
    if (!items.length) {
      wrap.appendChild(el('p', { class: 'ab-empty', text: 'لا يوجد محتوى في هذا القسم بعد.' }));
      return wrap;
    }
    items.forEach(function (item) {
      // عنصر واحد خاطئ من محرر المحتوى لا يجب أن يُسقط القسم كله
      try {
        wrap.appendChild(itemNode(section, item));
      } catch (e) {
        window.console.error('bad item', section.id, item && item.id, e);
      }
    });
    return wrap;
  }

  /* تحميل محتوى قسم واحد حسب مصدره (json / fx / gold / inline) */
  function loadSection(section, config) {
    if (section.source && section.source.kind === 'fx') {
      return getJson(section.source.url || (config.prices && config.prices.fxUrl) || 'data/prices/fx.json')
        .then(function (table) { return { kind: 'rates', table: table }; });
    }
    if (section.source && section.source.kind === 'gold') {
      return getJson(section.source.url || (config.prices && config.prices.goldUrl) || 'data/prices/gold.json')
        .then(function (table) { return { kind: 'rates', table: table }; });
    }
    if (section.source && section.source.kind === 'rss') {
      // المتصفح يمنع قراءة تغذية موقع آخر (CORS) — التطبيق يقرأها مباشرةً من داخله.
      return Promise.resolve({ kind: 'rss-blocked' });
    }
    if (section.items) return Promise.resolve({ items: section.items });
    if (!section.source || !section.source.url) return Promise.resolve({ items: [] });
    return getJson(section.source.url).then(function (payload) { return { items: payload.items || [] }; });
  }

  function injectJsonLd(config) {
    var ld = {
      '@context': 'https://schema.org',
      '@type': 'WebSite',
      name: config.brand && config.brand.name ? config.brand.name : 'قرية أبو بدوي',
      url: window.location.href,
      inLanguage: 'ar'
    };
    var script = el('script', { type: 'application/ld+json' });
    script.textContent = JSON.stringify(ld);
    document.head.appendChild(script);
  }

  function renderLegal(config) {
    var targets = [
      { key: 'privacy', id: 'legal-privacy', fallback: 'سياسة الخصوصية' },
      { key: 'terms', id: 'legal-terms', fallback: 'شروط الاستخدام' }
    ];
    targets.forEach(function (target) {
      var doc = config.legal && config.legal[target.key];
      var holder = el('section', { class: 'ab-section ab-legal', id: target.id });
      holder.appendChild(el('h2', { class: 'ab-section-title', text: (doc && doc.title) || target.fallback }));
      document.getElementById('content').appendChild(holder);
      if (!doc || !doc.url) return;
      getJson(doc.url).then(function (payload) {
        var body = el('div', { class: 'ab-body', 'data-ab-body': '' });
        body.innerHTML = payload.body || '';
        holder.appendChild(body);
      }).catch(function () {});
    });
  }

  function boot() {
    getJson('data/index.json').then(function (config) {
      var content = document.getElementById('content');
      content.textContent = '';

      if (config.brand) {
        document.getElementById('site-name').textContent = config.brand.name || '';
        if (config.brand.tagline) document.getElementById('site-tagline').textContent = config.brand.tagline;
        document.title = (config.brand.name || 'قرية أبو بدوي') + ' — الصفحة الرسمية';
        if (config.brand.primaryColor) {
          document.documentElement.style.setProperty('--brand', config.brand.primaryColor);
        }
      }

      if (config.notice) {
        content.appendChild(el('div', { class: 'notice', text: config.notice }));
      }

      var sections = (config.sections || [])
        .filter(function (s) { return s.enabled !== false; })
        .sort(function (a, b) { return (a.order || 100) - (b.order || 100); });

      var nav = document.getElementById('section-nav');
      sections.forEach(function (section) {
        nav.appendChild(el('a', { href: '#section-' + section.id, text: section.title }));
      });

      var queue = Promise.resolve();
      sections.forEach(function (section) {
        queue = queue.then(function () {
          return loadSection(section, config)
            .catch(function (error) { return { error: String(error) }; })
            .then(function (payload) {
              if (payload.kind === 'rss-blocked') {
                content.appendChild(el('section', {
                  class: 'ab-section', id: 'section-' + section.id,
                  'data-ab-section': section.id, 'data-ab-layout': section.layout
                }, [el('h2', { class: 'ab-section-title', text: section.title }),
                    el('p', { class: 'ab-note', text: 'هذا القسم يُقرأ من داخل التطبيق عبر التغذية الرسمية.' })]));
                return;
              }
              if (payload.error) {
                window.console.error('load failed', section.id, payload.error);
                return;
              }
              try {
                content.appendChild(sectionNode(section, payload));
              } catch (e) {
                window.console.error('render failed', section.id, e);
              }
            });
        });
      });

      queue.then(function () { renderLegal(config); injectJsonLd(config); });
    }).catch(function (error) {
      var loading = document.getElementById('loading');
      if (loading) loading.textContent = 'تعذّر تحميل البيانات: ' + error;
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
