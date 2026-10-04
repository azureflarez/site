# Azure Flare — personal website

Site: https://azureflarez.github.io/site/

## Structure

- `index.html` — home page and profile photo.
- `about.html` — biography.
- `links.html` — links.
- `languages/en.js`, `ru.js`, `uk.js` — page texts, one file per language.
- `main.js` — language selection, saved preference and translation.
- `theme.js` — light/dark mode and saved preference.
- `style.css` — entry point connecting the three shared stylesheets.
- `styles/themes.css` — colors and theme variables.
- `styles/base.css` — original shared typography and HTML element styles.
- `styles/profile.css` — compact profile, avatar, navigation and responsive rules.
- `sitemap.xml` — public page addresses.

## Edit content

Change a text value in each language file, keeping the keys identical.
HTML elements marked `data-i18n="key"` use that translation.
Edit link addresses and avatar URLs directly in the relevant HTML page.
English HTML is the fallback when JavaScript is unavailable.

## Add a page

Copy an existing HTML page to a new file in the root.
Keep its stylesheet and script tags in the same order.
Set `body data-page="newPage"`; add a `newPage` title key to all language files.
Give new translated elements their own keys in those files.
Add the page to the navigation in the three existing pages and to sitemap.xml.
No directory reorganization or build tool is required.

## Edit appearance

Change colors in themes.css, shared rules in base.css and profile layout in profile.css.
All pages use the same files.
After updating files, increment their `?v=` version in HTML and style.css to refresh browser caches.

## Publish

Commit to main. GitHub Pages publishes automatically.

## Blog

- `blog/index.html` — list of posts.
- `blog/_template.html` — editable post template (not a published post).
- Copy the template to `blog/my-post.html`.
- Replace the title in both `<title>` and `<h1>`, the date and article paragraphs.
- Set `<article lang="ru">`, `en` or `uk` to match the article language.
- Add `<li><a href="./my-post.html">Your title</a></li>` to the post list.
- Remove the `blogEmpty` paragraph after publishing your first post.
- Add the post URL to sitemap.xml.
- Personal article text is not auto-translated. The shared menu still supports three languages.
- Biography sections are in about.html; their translated texts are in languages/.

## Biography draft
The biography is an abstract draft requested by the owner, not verified personal facts. Replace its values in the three language files and the English fallback paragraphs in about.html.
