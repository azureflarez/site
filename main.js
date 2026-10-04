// Language selection and page translation.
(function () {
  var translations = window.siteTranslations;
  var root = document.documentElement;
  function read(key) {
    try {
      return localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }
  function save(key, value) {
    try {
      localStorage.setItem(key, value);
    } catch (_) {}
  }
  var language = read('language');
  if (!Object.prototype.hasOwnProperty.call(translations, language)) language = 'en';
  var select = document.getElementById('language-select');
  function applyLanguage(value) {
    if (!Object.prototype.hasOwnProperty.call(translations, value)) value = 'en';
    language = value;
    root.lang = value;
    var words = translations[value];
    document.querySelectorAll('[data-i18n]').forEach(function (element) {
      var text = words[element.dataset.i18n];
      if (typeof text === 'string') element.textContent = text;
    });
    document.title = words[document.body.dataset.page] + ' — Azure Flare';
    document.querySelector('meta[name="description"]').content = words.description;
    document.querySelector('nav').setAttribute('aria-label', words.nav);
    if (select) select.value = value;
    document.dispatchEvent(new Event('site-language-change'));
  }
  applyLanguage(language);
  if (select) {
    select.closest('label').hidden = false;
    select.addEventListener('change', function () {
      applyLanguage(select.value);
      save('language', language);
    });
  }
})();
