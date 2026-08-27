# wp-project

WordPress theme. Tooling from WP Preset. See that repository's README for the full
reference.

Entry points are `style.css` (theme header) and `functions.php`.

**Check which kind of theme this is before editing templates.** WordPress needs
one of these to recognise the directory as a theme at all, and the two are
edited differently:

| If the project has | It is a       | Templates live in                                 |
| ------------------ | ------------- | ------------------------------------------------- |
| `theme.json`       | block theme   | `templates/*.html`, `parts/*.html` (block markup) |
| `index.php`        | classic theme | `index.php`, `header.php`, … (PHP)                |

Don't mix them. Adding `index.php` to a block theme, or `templates/index.html`
to a classic one, changes how WordPress resolves the template and is almost
never what's wanted. For a block theme, global colors, typography and layout
belong in `theme.json`, not in `style.css`.

## Commands

`build` means two different things here — check which one is wanted:

| Command          | Does                                                                         |
| ---------------- | ---------------------------------------------------------------------------- |
| `npm run build`  | Compiles `src/` → `build/` (wp-scripts). This is "build the assets".         |
| `composer build` | Packages `dist/<slug>-<version>.zip` for install. This is "build a release". |

No `src/` is scaffolded — create it when you have assets to compile. Until then
`npm run build` has nothing to do, and `composer build` skips it rather than
running it, so a release zip carries no `build/` directory. Once `src/` exists,
`composer build` compiles it first, provided `node_modules` is installed.
`composer build -- --dev` skips that step for faster iteration.

```bash
composer build             # package dist/<slug>-<version>.zip
npm run build              # compiles src/ -> build/ (wp-scripts)
composer phpcbf            # autofix PHP
composer phpcs             # report what phpcbf could not fix
composer phpstan           # static analysis, level 8
composer lint              # phpcs + phpstan
composer test              # unit tests — fast, no WordPress
composer test:integration  # integration tests — needs wp-env running first
npm run lint:js            # ESLint
npm run format             # Prettier
npm run env:start          # local WordPress
```

## Conventions

- **Formatting is automatic, for edits made with Write or Edit.** A `PostToolUse`
  hook runs phpcbf then phpcs on PHP, eslint on JS/TS, and prettier on
  JS/TS/CSS/SCSS/JSON/Markdown/YAML. Don't run formatters by hand for a file you
  just edited — read the hook output instead. Each toolchain stays quiet until
  its own install has run, so PHP is still linted with only `composer install`
  done.
- **A file changed any other way is not formatted.** The hook matches `Write` and
  `Edit` only, so anything written through a shell command — a heredoc, `sed -i`
  — skips it. Run the formatter yourself after those.
- **`lint:css` is not part of the hook.** Prettier formats CSS, but stylelint
  runs only when you invoke `npm run lint:css`.
- **PHPCS and ESLint violations reported after an edit are yours to fix.** The
  hook exits 2 with the report; those are the ones autofix could not resolve.
- **Escape on output, sanitize on input.** PHPCS fails the build on either.
  Every superglobal read needs `wp_unslash()` and a `sanitize_*()` call, plus an
  `isset()` guard — a nonce check alone does not make the value safe.
- **Prefix every global.** Functions, classes, constants, and option names.
- **Bump the version in `style.css`** and the `*_VERSION` constant in
  `functions.php` together.
- **Keep `Tested up to:` in `style.css` current.** Nothing checks this for a
  theme, so looking is the only way it gets caught. **Worth checking now** if
  you have not before: themes scaffolded from older versions of the preset
  carry a hardcoded `6.9`, and scaffolding that could not reach wordpress.org
  left the template's value too. Compare it against the current WordPress
  release:

    ```bash
    curl -s https://api.wordpress.org/core/version-check/1.7/ \
      | grep -o '"current":"[^"]*"' | head -1
    ```

    Then edit the line if it is behind. Major version only — `7.1`, not
    `7.1.2`. It goes stale again on WordPress's schedule rather than yours, so
    bump it whenever WordPress ships a major version, even in a release that
    changes no code. Nothing reads this at runtime; it is what wordpress.org
    shows in the directory listing and what triggers the "untested with your
    version" warning.

- **Classes go in `includes/`, named for the class.** That directory is PSR-4
  autoloaded under the project's class prefix, so `WpProject\Settings` must live
  at `includes/Settings.php` — **not** `class-settings.php`. The WordPress
  filename convention breaks the autoloader, so `phpcs.xml.dist` excludes
  `includes/` from `WordPress.Files.FileName`. Everywhere else still uses the
  WordPress convention. No `require` is needed; `functions.php` already loads
  `vendor/autoload.php`.
- **Tests:** pure logic goes in `tests/unit/` (WP_Mock, no WordPress); anything
  touching the database, the query loop, or real hooks goes in
  `tests/integration/` (`WP_UnitTestCase`).

## Releasing

1. Bump the version in **both** places: the `Version:` header in `style.css` and
   the `*_VERSION` constant in `functions.php`. `composer build` fails if they
   disagree.
2. `composer lint && composer test`
3. `composer build` → `dist/<slug>-<version>.zip`

`dist/` and `build/` are gitignored. Never commit either.

There is no `composer check` here. Plugin Check is plugin-only — it resolves
everything through the plugin registry and has no theme code path — so the
scaffold does not ship it for themes.

## For AI agents without an instructions convention

If your tool reads neither `AGENTS.md` nor `CLAUDE.md` automatically, point it
at this file, or paste the Commands and Conventions sections into its system
prompt. Nothing here is tool-specific.
