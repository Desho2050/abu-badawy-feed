/* أدوات DOM صغيرة: كل النصوص تمر عبر textContent، فلا احتمال لحقن HTML من المحتوى.
   خاصية html تُستخدم فقط لكتل ثابتة يكتبها هذا الملف نفسه. */

export function el(tag, props = {}, children = []) {
  const node = document.createElement(tag);
  Object.entries(props).forEach(([key, value]) => {
    if (value === null || value === undefined || value === false) return;
    if (key === 'class') node.className = value;
    else if (key === 'text') node.textContent = String(value);
    else if (key === 'html') node.innerHTML = value;
    else if (key === 'dataset') Object.assign(node.dataset, value);
    else if (key.startsWith('on') && typeof value === 'function') node.addEventListener(key.slice(2), value);
    else if (value === true) node.setAttribute(key, '');
    else node.setAttribute(key, String(value));
  });
  (Array.isArray(children) ? children : [children]).forEach((child) => {
    if (child === null || child === undefined || child === false) return;
    node.append(child && child.nodeType ? child : document.createTextNode(String(child)));
  });
  return node;
}

export function clear(node) {
  while (node && node.firstChild) node.removeChild(node.firstChild);
  return node;
}

export function toast(message, ms = 2800) {
  const host = document.getElementById('toastHost');
  if (!host) return;
  clear(host).append(el('div', { class: 'toast', role: 'status', text: message }));
  setTimeout(() => clear(host), ms);
}

/** حقل بتسمية: يستقبل العنصر الجاهز (input/select/textarea). */
export function field(label, control, hint) {
  return el('div', {}, [
    el('label', { text: label }),
    control,
    hint ? el('div', { class: 'muted', text: hint, style: 'margin-top:5px' }) : null
  ]);
}

/* props.value إن وُجد يسبق القيمة الموضع الافتراضية. */
export function input(props = {}, value = '') {
  return el('input', { value, ...props });
}

export function checkbox(label, checked, onChange) {
  const box = el('input', { type: 'checkbox', checked: !!checked });
  box.addEventListener('change', () => onChange(box.checked));
  return el('label', { class: 'check' }, [box, label]);
}

export function select(options, value, onChange, extra = {}) {
  const node = el('select', extra);
  options.forEach((option) => {
    const [raw, label] = Array.isArray(option) ? option : [option, option];
    node.append(el('option', { value: raw, selected: String(raw) === String(value), text: label || raw }));
  });
  node.value = String(value);
  if (onChange) node.addEventListener('change', () => onChange(node.value));
  return node;
}

export function card(title, count, children) {
  const kids = Array.isArray(children) ? children : [children];
  return el('section', { class: 'card' }, [
    title ? el('h2', {}, [title, count ? el('span', { class: 'n', text: count }) : null]) : null,
    ...kids
  ]);
}

export function stateLine(initial = '', kind = '') {
  return el('div', { class: 'state ' + kind, text: initial });
}

export function ask(message) {
  return window.confirm(message);
}
