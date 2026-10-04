// Use the current GitHub avatar for the profile and browser tab.
// This stable user ID follows avatar changes; no API token is required.
(function () {
  var avatarUrl = 'https://avatars.githubusercontent.com/u/141839719';
  var refresh = Date.now();

  document.querySelectorAll('.profile-avatar').forEach(function (image) {
    image.src = avatarUrl + '?s=288&refresh=' + refresh;
  });

  var favicon = document.getElementById('site-favicon');
  if (favicon) {
    favicon.href = avatarUrl + '?s=64&refresh=' + refresh;
  }
})();
