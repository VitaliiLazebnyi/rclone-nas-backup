# rclone-nas-backup site

The home page (`index.html`) and privacy policy (`privacy.html`) of rclone-nas-backup, a personal backup tool. The
site is static HTML and CSS with no JavaScript.

## Checks

Every push to `main` and every pull request runs the [CI workflow](.github/workflows/ci.yml). Every check must
report zero findings: there are no warning-only levels, no inline suppressions and no switched-off rules.

- **HTML**: [html-validate][] (`recommended` and `document` presets plus every opt-in rule) and the
  [W3C Nu validator][vnu] with `--Werror` on the HTML, CSS and SVG.
- **Lint**: [Prettier][] on CSS, JSON, YAML and Markdown, [Stylelint][] (`stylelint-config-standard`) and
  [markdownlint][].
- **Accessibility and Lighthouse**: [pa11y][] with axe-core (WCAG 2.0, 2.1 and 2.2 A and AA, best practices) and
  with HTML_CodeSniffer (WCAG 2 AA), warnings included; [Lighthouse][] must score 100 for accessibility, best
  practices and SEO on both pages.
- **Links**: [lychee][] checks every internal link and `#anchor` and every external link.
- **Spelling**: [typos][].
- **Secret scanning**: [gitleaks][] over the full history.
- **Workflows and scripts**: [actionlint][] and [ShellCheck][] with every optional check enabled.
- **Policy**: `script/forbidden_suppressions.sh` (no inline suppression comment of any tool, no switched-off rule,
  no tool ignore file) and `script/no_javascript.sh`.
- **Dependencies**: `npm audit` (no advisory of any severity) and `npm outdated` (every package on its latest
  version).
- **Warning gate**: `script/warning_gate.sh` fails if the log of any other job contains a warning or a deprecation.

Actions are pinned by commit SHA, and downloaded binaries are verified against a SHA-256 before they are run.

Notes:

- Prettier does not format the HTML pages: it always writes void elements as `<meta … />`, which the Nu validator
  reports. html-validate enforces the void element, quoting and doctype style instead.
- There is no JavaScript, so there is no ESLint, unit test or mutation testing (Stryker) job: there is no code to
  lint, test or mutate. `script/no_javascript.sh` fails the build if a script file, `<script>` element or inline
  event handler appears; add those gates together with any JavaScript.
- The `style.css` link carries a Subresource Integrity hash. After changing the stylesheet, update it with
  `openssl dgst -sha384 -binary style.css | openssl base64 -A`; a stale hash blocks the stylesheet and fails
  Lighthouse.

## Running the checks locally

```sh
npm ci
node_modules/.bin/html-validate --max-warnings 0 '*.html'
java -jar node_modules/vnu-jar/build/dist/vnu.jar --Werror --also-check-css --also-check-svg *.html *.css *.svg
node_modules/.bin/prettier --check .
node_modules/.bin/stylelint --max-warnings 0 '**/*.css'
node_modules/.bin/markdownlint-cli2 '**/*.md'
script/forbidden_suppressions.sh
script/no_javascript.sh
```

[actionlint]: https://github.com/rhysd/actionlint
[gitleaks]: https://github.com/gitleaks/gitleaks
[html-validate]: https://html-validate.org/
[lighthouse]: https://github.com/GoogleChrome/lighthouse
[lychee]: https://github.com/lycheeverse/lychee
[markdownlint]: https://github.com/DavidAnson/markdownlint-cli2
[pa11y]: https://github.com/pa11y/pa11y
[prettier]: https://prettier.io/
[shellcheck]: https://www.shellcheck.net/
[stylelint]: https://stylelint.io/
[typos]: https://github.com/crate-ci/typos
[vnu]: https://validator.github.io/validator/
