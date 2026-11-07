# rclone-nas-backup site

The home page (`index.html`) and privacy policy (`privacy.html`) of rclone-nas-backup, a personal backup tool. The
site is static HTML and CSS with no JavaScript.

## Checks

Every pull request and every push to `main` runs the workflows below. Every check must report zero findings: there
are no warning-only levels, no inline suppressions, no switched-off rules and no tool ignore files, and each
workflow ends with a warning gate that fails if the log of any of its jobs contains a warning or a deprecation.

**CI** ([ci.yml](.github/workflows/ci.yml)):

- **Lint**: [Prettier][] (CSS, JSON, YAML, Markdown), [Stylelint][] (`stylelint-config-standard` plus the opt-in
  rules, see [.stylelintrc.yaml](.stylelintrc.yaml)), [markdownlint][] (every rule), [yamllint][] (`--strict`,
  every rule), [ShellCheck][] (`--enable=all --severity=style`), [shfmt][], [editorconfig-checker][] (every tracked
  file), [typos][], `script/forbidden_suppressions.sh` (no suppression comment of any tool, no switched-off or
  lowered rule, no weakened tool option, no tool ignore file), `script/no_javascript.sh` and
  `script/check_integrity.sh` (the Subresource Integrity hash of the stylesheet).
- **HTML**: [html-validate][] (`recommended` and `document` presets plus every opt-in rule) and the
  [W3C Nu validator][vnu] with `--Werror` on the HTML, CSS and SVG.
- **Accessibility and Lighthouse** (`script/browser_audit.sh`, on every page): [pa11y][] with axe-core (WCAG 2.0,
  2.1 and 2.2 A and AA, best practices) and with HTML_CodeSniffer (WCAG 2 AA), warnings and notices included; every
  [Lighthouse][] category (performance, accessibility, best practices, SEO, agentic browsing) must score 100.
- **Links**: [lychee][] checks every internal link and `#anchor` and every external link.

**Workflow lint** ([workflow-lint.yml](.github/workflows/workflow-lint.yml)): [actionlint][], which runs
ShellCheck with every optional check on each `run:` block, and [zizmor][] with the pedantic persona, including its
online audits.

**Security** ([security.yml](.github/workflows/security.yml), also weekly): `npm audit` (no advisory of any
severity), `npm audit signatures` (registry signatures and provenance), `script/check_lockfile.sh` (the lockfile is
current and resolves every package from registry.npmjs.org), `npm outdated` and `script/outdated_tools.sh` (every
dependency, tool, Node.js and Java on its newest release), [gitleaks][] over the full history, and on pull
requests GitHub's dependency review (fails on a vulnerability of any severity in any scope).

**CodeQL** ([codeql.yml](.github/workflows/codeql.yml)) analyzes the workflows (`actions`, the only CodeQL
language present) with the `security-extended` and `security-and-quality` suites. **OpenSSF Scorecard**
([scorecard.yml](.github/workflows/scorecard.yml)) runs on `main` and weekly.

Supply chain and runners:

- Every action is pinned by commit SHA. Every downloaded tool is pinned by version and SHA-256
  ([tools/releases.txt](tools/releases.txt): actionlint, editorconfig-checker, gitleaks, lychee, npm, shfmt), the
  Python linters by hash ([tools/requirements.txt](tools/requirements.txt): ShellCheck, typos, yamllint, zizmor),
  and the npm packages by `package-lock.json`. Dependabot proposes updates for the actions, npm and pip, after a
  seven-day cooldown.
- Every job starts with [harden-runner][] with `egress-policy: block` and an explicit list of allowed endpoints;
  sudo and containers are disabled except where a job needs them (the browser job lifts the Chrome sandbox
  restriction with sudo; Scorecard is a container action).
- Every job has least-privilege permissions (nothing is writable by default), a timeout, and runs with
  `NODE_OPTIONS=--throw-deprecation` where Node.js runs.

### Rules left off, and why

- **Stylelint**: the rules that only enforce a project vocabulary (allow/disallow lists and naming patterns) have
  no meaningful setting for this one-file stylesheet; [.stylelintrc.yaml](.stylelintrc.yaml) lists them. Every
  other rule is on.
- **html-validate**: `svg-focusable` requires the IE-only `focusable` attribute on inline SVG, which is not valid
  HTML, so it contradicts the Nu validator.
- **Prettier** does not format the HTML pages: it always writes void elements as `<meta … />`, which the Nu
  validator reports. html-validate enforces the void element, quoting and doctype style instead.
- **Lighthouse**: the categories must score 100. Zero-weight insight audits that describe the local test server
  (cache headers) or the single stylesheet (render-blocking, dependency tree) are printed but do not fail.
- **No ESLint, unit tests, coverage or mutation testing (Stryker)**: there is no JavaScript to lint, test or
  mutate. `script/no_javascript.sh` fails the build if a script file, `<script>` element or inline event handler
  appears; add those gates together with any JavaScript.
- **No OpenSSF Scorecard threshold for each npm dependency**: the checked dependencies are development tools
  (Lighthouse, pa11y with Puppeteer, Stylelint, html-validate, markdownlint, Prettier) whose transitive trees
  include many small packages without a Scorecard; dependency review, `npm audit` and `npm audit signatures`
  cover them instead.

## Running the checks locally

`script/check.sh` runs the checks of the CI, Workflow lint and Security workflows with the same settings (the
GitHub-hosted dependency review, CodeQL, Scorecard and warning gates aside); its header lists what it needs.
`script/check.sh --fast` runs the offline static checks; enable it as the pre-commit hook with
`git config core.hooksPath .githooks`.

```sh
npm ci
script/check.sh
```

The `style.css` link carries a Subresource Integrity hash: after changing the stylesheet, update both pages with
the hash that `script/check_integrity.sh` prints.

[actionlint]: https://github.com/rhysd/actionlint
[editorconfig-checker]: https://github.com/editorconfig-checker/editorconfig-checker
[gitleaks]: https://github.com/gitleaks/gitleaks
[harden-runner]: https://github.com/step-security/harden-runner
[html-validate]: https://html-validate.org/
[lighthouse]: https://github.com/GoogleChrome/lighthouse
[lychee]: https://github.com/lycheeverse/lychee
[markdownlint]: https://github.com/DavidAnson/markdownlint-cli2
[pa11y]: https://github.com/pa11y/pa11y
[prettier]: https://prettier.io/
[shellcheck]: https://www.shellcheck.net/
[shfmt]: https://github.com/mvdan/sh
[stylelint]: https://stylelint.io/
[typos]: https://github.com/crate-ci/typos
[vnu]: https://validator.github.io/validator/
[yamllint]: https://github.com/adrienverge/yamllint
[zizmor]: https://github.com/zizmorcore/zizmor
