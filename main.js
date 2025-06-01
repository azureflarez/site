// SPDX-License-Identifier: 0BSD

function isDarkMode() {
  return (
    (localStorage && localStorage.getItem && localStorage.getItem('theme'))
    ? localStorage.getItem('theme') == 'dark'
    : (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches)
  );
}

function toggleDarkMode() {
  localStorage.setItem('theme', isDarkMode() ? 'light' : 'dark');
  updateDarkMode();
}

function updateDarkMode() {
  if (isDarkMode()) {
    document.documentElement.className = document.documentElement.className.replace('light-mode', 'dark-mode');
  } else {
    document.documentElement.className = document.documentElement.className.replace('dark-mode', 'light-mode');
  }
}

function documentLoaded() {
  if (document.body.className) document.body.className += ' ';
  document.documentElement.className += isDarkMode() ? 'dark-mode' : 'light-mode';
  var btn = document.createElement('button');
  btn.addEventListener('click', toggleDarkMode, false);
  btn.className = 'theme-switcher';
  document.getElementsByTagName('footer')[0].appendChild(btn);
}

