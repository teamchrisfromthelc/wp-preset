# wp-project

WordPress plugin. Tooling from WP Preset. See that repository's README for the full
reference.

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
composer test:integration  # integration tests — run inside wp-env, see below
composer check             # would this pass wordpress.org review? Needs Docker
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
  PHPCS enforces the project's prefixes.
- **Classes go in `includes/`, named for the class.** That directory is PSR-4
  autoloaded under the project's class prefix, so `WpProject\Settings` must live
  at `includes/Settings.php` — **not** `class-settings.php`. The WordPress
  filename convention breaks the autoloader, so `phpcs.xml.dist` excludes
  `includes/` from `WordPress.Files.FileName`. Everywhere else still uses the
  WordPress convention. No `require` is needed; the entry point already loads
  `vendor/autoload.php`.
- **Tests:** pure logic goes in `tests/unit/` (WP_Mock, no WordPress); anything
  touching the database, the query loop, or real hooks goes in
  `tests/integration/` (`WP_UnitTestCase`). Run the integration suite inside
  wp-env:
  `npx wp-env run tests-cli --env-cwd=wp-content/plugins/<project-folder> composer test:integration`
  — that path is the directory name, which is not necessarily the slug.
- **Building on another plugin? Install its stubs before writing code.** PHPStan
  ships WordPress core stubs only. Targeting WooCommerce without
  `php-stubs/woocommerce-stubs` means every `wc_*()` call reports as
  `function.notFound` and every class extending a `WC_*` parent reports each
  inherited property as `property.notFound` — a wall of errors that look like
  real bugs but are missing type information. Install the stubs and uncomment
  `scanFiles` in `phpstan.neon.dist`:

    ```bash
    composer require --dev php-stubs/woocommerce-stubs
    ```

    Same for ACF (`php-stubs/acf-pro-stubs`), WP-CLI (`php-stubs/wp-cli-stubs`),
    and others.

## Checking against wordpress.org

`composer check` runs [Plugin Check](https://wordpress.org/plugins/plugin-check/),
the same tool wordpress.org runs during review. It boots WordPress in Docker, so
it takes a minute or two — run it before a release, not on every edit. PHPCS
already covers the sniff-based half of those checks continuously.

It checks the **built zip**, not the working directory. The working tree carries
`tests/`, `.claude/` and `AGENTS.md`, none of which ship, and Plugin Check flags
every one of them. Checking the zip is the difference between a clean run and
fifteen findings about files that were never going to be released.

```bash
composer check                            # table
composer check -- --json > findings.json  # for an agent to read
```

**The output is findings to assess, not a task list.** Plugin Check flags
patterns that are usually wrong and occasionally correct. Working through the
list uncritically makes the code worse. Read each finding, decide whether it
applies here, and pass `--ignore-codes` for the ones you have judged and
rejected. `ERROR` blocks a submission; `WARNING` does not.

Note the command exits 0 whether or not it found anything — that is Plugin
Check's own behaviour, and the exit code only tells you whether the tool ran. In
JSON mode an empty array means clean.

`Tested up to:` in `readme.txt` goes stale on its own. wordpress.org treats a
value behind the current WordPress release as an error and drops the plugin from
search results, so it needs bumping when WordPress ships a major version even if
nothing else changed. `composer check` is what tells you.

## Releasing

1. Bump the version in **all three** places: the `Version:` header and the
   `*_VERSION` constant in the main plugin file, and `Stable tag:` in
   `readme.txt`. `composer build` fails if any of them disagree. The stable tag
   is the one wordpress.org reads to decide which release to serve, so a stale
   one keeps the old version live no matter what was uploaded.
2. `composer lint && composer test`
3. `composer build` → `dist/<slug>-<version>.zip`
4. `composer check` before a wordpress.org submission.

`dist/` and `build/` are gitignored. Never commit either.

## For AI agents without an instructions convention

If your tool reads neither `AGENTS.md` nor `CLAUDE.md` automatically, point it
at this file, or paste the Commands and Conventions sections into its system
prompt. Nothing here is tool-specific.
