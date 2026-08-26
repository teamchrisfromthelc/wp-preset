# wp-project

WordPress plugin. Tooling from WP Preset. See that repository's README for the full
reference.

## Commands

`build` means two different things here — check which one is wanted:

| Command          | Does                                                                                                   |
| ---------------- | ------------------------------------------------------------------------------------------------------ |
| `npm run build`  | Compiles `src/` → `build/` (wp-scripts). This is "build the assets".                                   |
| `composer build` | Packages `dist/<slug>-<version>.zip` for install. This is "build a release". Runs the npm build first. |

```bash
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

- **Formatting is automatic.** A `PostToolUse` hook runs phpcbf/phpcs on PHP and
  eslint/prettier on JS/CSS after every edit. Don't run formatters by hand for a
  file you just edited — read the hook output instead. It stays silent until
  `composer install` and `npm install` have both run.
- **PHPCS violations reported after an edit are yours to fix.** The hook exits 2
  with the report; those are the ones phpcbf could not fix automatically.
- **Escape on output, sanitize on input.** `WordPress-Extra` enforces this and
  will fail the build if you don't.
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
  `tests/integration/` (`WP_UnitTestCase`).
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

## Releasing

1. Bump the version in **both** places in the main plugin file: the `Version:`
   header and the `*_VERSION` constant. `composer build` fails if they disagree.
2. `composer lint && composer test`
3. `composer build` → `dist/<slug>-<version>.zip`

`dist/` and `build/` are gitignored. Never commit either.

## For AI agents without an instructions convention

If your tool reads neither `AGENTS.md` nor `CLAUDE.md` automatically, point it
at this file, or paste the Commands and Conventions sections into its system
prompt. Nothing here is tool-specific.
