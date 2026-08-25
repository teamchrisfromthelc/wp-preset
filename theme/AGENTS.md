# wp-project

WordPress theme. Tooling from WP Preset. See that repository's README for the full
reference.

Entry points are `style.css` (theme header) and `functions.php`.

## Commands

```bash
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

There is no `composer build` — release packaging is plugin-only. To distribute,
zip the theme directory.

## Conventions

- **Formatting is automatic.** A `PostToolUse` hook runs phpcbf/phpcs on PHP and
  eslint/prettier on JS/CSS after every edit. Don't run formatters by hand for a
  file you just edited — read the hook output instead. It stays silent until
  `composer install` and `npm install` have both run.
- **PHPCS violations reported after an edit are yours to fix.** The hook exits 2
  with the report; those are the ones phpcbf could not fix automatically.
- **Escape on output, sanitize on input.** `WordPress-Extra` enforces this.
- **Prefix every global.** Functions, classes, constants, and option names.
- **Bump the version in `style.css`** and the `*_VERSION` constant in
  `functions.php` together.
- **Tests:** pure logic goes in `tests/unit/` (WP_Mock, no WordPress); anything
  touching the database, the query loop, or real hooks goes in
  `tests/integration/` (`WP_UnitTestCase`).

## For AI agents without an instructions convention

If your tool reads neither `AGENTS.md` nor `CLAUDE.md` automatically, point it
at this file, or paste the Commands and Conventions sections into its system
prompt. Nothing here is tool-specific.
