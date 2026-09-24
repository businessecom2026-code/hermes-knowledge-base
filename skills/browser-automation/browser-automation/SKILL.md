---
name: browser-automation
description: "Use when automating web forms securely via browser_exec."
---

# Browser Automation & browser_exec Patterns

## Filling Specialized Form Inputs

Generic `fill_input()` calls can fail or produce bizarre values on strictly formatted input types (e.g. typing `2026-09-23` character-by-character into an `<input type="date">` may be interpreted as the year `60923`).

**Pitfall**: Do not use `fill_input` for `<input type="date">` or `<select>`.
**Fix**: Use raw JavaScript property setters inside `js()` to trigger the appropriate `input`/`change` events.

```javascript
/* Setting an <input type="date"> safely */
const set = (sel, v) => {
  const el = document.querySelector(sel);
  if (!el) return;
  Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set.call(el, v);
  el.dispatchEvent(new Event('input', {bubbles: true}));
  el.dispatchEvent(new Event('change', {bubbles: true}));
};
set('input[name=originatedAt]', '2026-09-23');

/* Changing a <select> dropdown */
const s = document.querySelector('select[name=installmentCount]');
if (s) {
  s.value = '2';
  s.dispatchEvent(new Event('change', {bubbles: true}));
}
```
