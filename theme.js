// Theme selection is independent of page content.
(function () {
  var root = document.documentElement;
  var button = document.getElementById('theme-toggle');
  var media = window.matchMedia('(prefers-color-scheme: dark)');
  var saved;

  try {
    saved = localStorage.getItem('theme');
  } catch (_) {}

  if (saved === 'light' || saved === 'dark') {
    root.dataset.theme = saved;
  }

  function isDark() {
    return root.dataset.theme
      ? root.dataset.theme === 'dark'
      : media.matches;
  }

  function updateLabel() {
    if (!button) return;
    var words = window.siteTranslations[root.lang] || window.siteTranslations.en;
    button.textContent = words[isDark() ? 'light' : 'dark'];
  }

  if (button) {
    button.hidden = false;
    button.addEventListener('click', function () {
      root.dataset.theme = isDark() ? 'light' : 'dark';
      try {
        localStorage.setItem('theme', root.dataset.theme);
      } catch (_) {}
      updateLabel();
    });
  }

  document.addEventListener('site-language-change', updateLabel);
  if (media.addEventListener) {
    media.addEventListener('change', updateLabel);
  }
  updateLabel();
})();
