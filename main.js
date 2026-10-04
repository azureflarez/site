(function () {
  var translations = {"en":{"home":"Home","about":"About me","links":"Links","nav":"Main navigation","language":"Language","description":"Azure Flare’s personal website. Profile and projects on GitHub.","personal":"Personal website","welcome":"Welcome to my website.","find":"You can find my GitHub profile and projects here.","myGithub":"My GitHub ↗","project":"Project","thisSite":"This website","source":"The source code for this website is available in the site repository.","openRepo":"Open repository →","bio":"You can find me on GitHub as azureflarez.","bioStart":"This is my personal website. My public projects are available on ","bioLink":"my GitHub profile","where":"Where to find me","profile":"Profile azureflarez ↗","code":"Website source","repo":"Repository site ↗","light":"Light theme","dark":"Dark theme"},"ru":{"home":"Главная","about":"Обо мне","links":"Ссылки","nav":"Основная навигация","language":"Язык","description":"Личный сайт Azure Flare. Профиль и проекты на GitHub.","personal":"Личный сайт","welcome":"Добро пожаловать на мой сайт.","find":"Здесь можно найти мой профиль и проекты на GitHub.","myGithub":"Мой GitHub ↗","project":"Проект","thisSite":"Этот сайт","source":"Исходный код сайта доступен в репозитории site.","openRepo":"Открыть репозиторий →","bio":"В GitHub меня можно найти под именем azureflarez.","bioStart":"Это мой личный сайт. Мои публичные проекты доступны в ","bioLink":"профиле GitHub","where":"Где меня найти","profile":"Профиль azureflarez ↗","code":"Код сайта","repo":"Репозиторий site ↗","light":"Светлая тема","dark":"Тёмная тема"},"uk":{"home":"Головна","about":"Про мене","links":"Посилання","nav":"Основна навігація","language":"Мова","description":"Особистий сайт Azure Flare. Профіль і проєкти на GitHub.","personal":"Особистий сайт","welcome":"Вітаю на моєму сайті.","find":"Тут можна знайти мій профіль і проєкти на GitHub.","myGithub":"Мій GitHub ↗","project":"Проєкт","thisSite":"Цей сайт","source":"Вихідний код сайту доступний у репозиторії site.","openRepo":"Відкрити репозиторій →","bio":"На GitHub мене можна знайти під ім’ям azureflarez.","bioStart":"Це мій особистий сайт. Мої публічні проєкти доступні в ","bioLink":"профілі GitHub","where":"Де мене знайти","profile":"Профіль azureflarez ↗","code":"Код сайту","repo":"Репозиторій site ↗","light":"Світла тема","dark":"Темна тема"}};
  var root = document.documentElement;
  function read(key) { try { return localStorage.getItem(key); } catch (_) { return null; } }
  function save(key, value) { try { localStorage.setItem(key, value); } catch (_) {} }
  var language = read('language');
  if (!Object.prototype.hasOwnProperty.call(translations, language)) language = 'en';
  var theme = read('theme');
  if (theme === 'light' || theme === 'dark') root.dataset.theme = theme;
  var button = document.getElementById('theme-toggle');
  var select = document.getElementById('language-select');
  function isDark() { return root.dataset.theme ? root.dataset.theme === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches; }
  function themeLabel() { if (button) button.textContent = translations[language][isDark() ? 'light' : 'dark']; }
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
    themeLabel();
  }
  applyLanguage(language);
  if (select) {
    select.closest('label').hidden = false;
    select.addEventListener('change', function () { applyLanguage(select.value); save('language', language); });
  }
  if (button) {
    button.hidden = false;
    button.addEventListener('click', function () {
      root.dataset.theme = isDark() ? 'light' : 'dark';
      save('theme', root.dataset.theme);
      themeLabel();
    });
  }
  var media = window.matchMedia('(prefers-color-scheme: dark)');
  if (media.addEventListener) media.addEventListener('change', themeLabel);
})();
