// Theme preference is optional; the site also works without JavaScript.
(function () {
  var root = document.documentElement;
  var saved;
  try { saved = localStorage.getItem('theme'); } catch (_) {}
  if (saved === 'light' || saved === 'dark') root.dataset.theme = saved;
  var button = document.getElementById('theme-toggle');
  if (!button) return;
  function isDark() { return root.dataset.theme ? root.dataset.theme === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches; }
  function label() { button.textContent = isDark() ? 'Светлая тема' : 'Тёмная тема'; }
  button.hidden = false;
  label();
  button.addEventListener('click', function () {
    root.dataset.theme = isDark() ? 'light' : 'dark';
    try { localStorage.setItem('theme', root.dataset.theme); } catch (_) {}
    label();
  });
})();
