# WP AI Scaffold

Opinionated WordPress plugin/theme tooling that an AI coding agent can install
and then actually use: PHPCS with WordPress standards, PHPStan, ESLint,
Prettier, PHPUnit with both WP_Mock and `WP_UnitTestCase`, `wp-env`,
format-on-save, and a release packager.

Every default here was verified by scaffolding a project, installing it, and
running the tools — not by copying a blog post.

## Why this exists

Claude Code's global config can run linters on every file edit. That sounds
useful until you edit a Laravel or Python repo and get WordPress rules applied
to it, or a plugin that never asked for docblock enforcement starts failing on
every save.

So the global config does **nothing** on edit. All tooling is per project, and
this repo is what you drop into a project that wants it.

## Requirements

| | |
|---|---|
| PHP | 8.0+ (CLI) |
| Composer | 2.x |
| Node | 20+ |
| Git, rsync, zip | for the release packager |
| Claude Code | optional — for the skill and format-on-save hook |

## Install

Clone anywhere; the scripts resolve paths relative to themselves.

```bash
git clone git@github.com:teamchrisfromthelc/WP-AI-Scaffold.git ~/Tools/wp-ai-scaffold
```

### Optional: the Claude Code skill

Copy `skill/wp-blueprint/` into `~/.claude/skills/` so you can scaffold by
asking, rather than remembering the path:

```bash
cp -R skill/wp-blueprint ~/.claude/skills/
```

Then edit the path at the top of `~/.claude/skills/wp-blueprint/SKILL.md` to
wherever you cloned this. After that:

> `/wp-blueprint set up the blueprint for a plugin`
> `/wp-blueprint set up the blueprint for a theme`

## Usage

```bash
./setup.sh [--theme|--plugin] <target-dir> <slug> [Prefix]
```

Plugin is the default. `.` is a valid target when you're already in the folder.

```bash
./setup.sh ~/Projects/acme-widgets acme-widgets          # plugin
./setup.sh --theme ~/Projects/acme-theme acme-theme      # theme

cd ~/Projects/acme-widgets
composer install && npm install
```

Both installs are required. The format-on-save hook stays silent until they've
run, which otherwise looks like a broken hook.

### The slug matters

`<slug>` must be lowercase-kebab. It becomes the text domain, the package name,
and the prefix base for every global — so changing it later is a wide rename.
Pick deliberately.

| Placeholder | With slug `acme-widgets` | Used for |
|---|---|---|
| `wp-project` | `acme-widgets` | text domain, package names |
| `wp_project` | `acme_widgets` | function/global prefix |
| `WP_PROJECT_` | `ACME_WIDGETS_` | constants |
| `WpProject` | `AcmeWidgets` | class prefix |
| `WP Project` | `Acme Widgets` | plugin/theme header name |

`[Prefix]` overrides the class prefix if StudlyCase of the slug isn't what you
want.

### Plugin vs theme

| | `--plugin` | `--theme` |
|---|---|---|
| Entry points | `<slug>.php` | `style.css` + `functions.php` |
| `composer.json` type | `wordpress-plugin` | `wordpress-theme` |
| `.wp-env.json` mounts as | `plugins` | `themes` |
| Release packaging | `composer build` | none — zip the directory |

The flag handles all of it. Don't hand-edit those afterwards.

### Re-running

`setup.sh` never overwrites an existing file. Re-run it to pull in files you
skipped, or after updating this repo — though note that files you already have
stay as they are, so compare manually if you want upstream fixes.

## Verify

A fresh scaffold passes everything out of the box:

```bash
composer test         # OK (8 tests, 9 assertions)
composer phpcs        # no output
composer phpstan      # [OK] No errors
npm run lint:js       # exit 0
npm run lint:css      # exit 0
npm run format:check  # exit 0
```

If any of these fail on a fresh install, that's a bug in this repo — please open
an issue.

## What you get

| File | Purpose |
|---|---|
| `composer.json` | WPCS 3.4, PHPStan 2.2 + phpstan-wordpress, PHPCompatibilityWP, PHPUnit, WP_Mock |
| `phpcs.xml.dist` | WordPress-Core + Extra + Docs, text domain, prefixes, PHP 8.0+ / WP 6.5+ |
| `phpstan.neon.dist` | Level 8 with WordPress stubs |
| `package.json` | `@wordpress/scripts`, `eslint-plugin`, `prettier-config`, `wp-env` |
| `eslint.config.mjs` | Flat config (ESLint 9+), WP rules, `wp`/`jQuery` globals |
| `.prettierrc.js` | `@wordpress/prettier-config` |
| `phpunit.xml.dist` | Unit suite — WP_Mock, no database |
| `phpunit-integration.xml.dist` | Integration suite — real WP via `WP_UnitTestCase` |
| `tests/` | Bootstraps and worked examples for both tiers |
| `.wp-env.json` | Local WordPress with `WP_DEBUG` on |
| `.editorconfig` | Tabs for PHP/JS/CSS, spaces for YAML |
| `wp-project.php`, `theme/` | Entry point templates |
| `bin/build-plugin.sh` | Release packaging (plugins) |
| `plugin/CLAUDE.md`, `theme/CLAUDE.md` | Per-project agent context, kind-specific |
| `.claude/` | Format-on-save hook + tool permissions |

This README, `skill/`, and the repo's own `CLAUDE.md` are **not** copied into
scaffolded projects.

## Commands

```bash
composer phpcbf            # autofix PHP
composer phpcs             # report what phpcbf could not fix
composer phpstan           # static analysis (--memory-limit=1G baked in)
composer lint              # phpcs + phpstan
composer test              # unit tests — fast, no WordPress
composer test:integration  # integration tests — needs wp-env running
composer build             # package dist/<slug>-<version>.zip (plugins only)

npm run build              # compile src/ -> build/
npm run lint:js            # ESLint
npm run lint:css           # Stylelint
npm run format             # Prettier write
npm run format:check       # Prettier check
npm run env:start          # local WordPress
```

Note that `build` means two different things: `npm run build` compiles assets,
`composer build` packages a release (and runs the asset build first).

## Format-on-save

`.claude/settings.json` registers a Claude Code `PostToolUse` hook so every
Edit/Write runs:

- **PHP** — `phpcbf` autofixes; `phpcs` reports the rest and exits 2, which
  feeds the violations back to the agent to fix immediately.
- **JS/TS** — `eslint --fix`, then `prettier --write`.
- **CSS/SCSS/JSON/MD/YAML** — `prettier --write`.

Skips `vendor/`, `node_modules/`, `build/`, `dist/`, `*.min.*`, `*.asset.php`.
Tooling is resolved by walking up from the edited file, so it works regardless
of the agent's working directory.

Not using Claude Code? Delete `.claude/` — everything else works the same, you
just run the linters yourself.

## Testing

Two tiers, deliberately separate.

**Unit** (`tests/unit/`) — no WordPress, no database, milliseconds. WP functions
are mocked with WP_Mock:

```php
WP_Mock::userFunction( 'get_option' )->once()->with( 'mode' )->andReturn( 'live' );
WP_Mock::expectActionAdded( 'init', 'acme_widgets_register_cpt' );
WP_Mock::onFilter( 'acme_widgets_title' )->with( 'raw' )->reply( 'filtered' );
```

Extend `WP_Mock\Tools\TestCase`. WP_Mock verifies expectations in `tearDown()`,
so a test asserting only on hooks needs an explicit `$this->assertHooksAdded()`
or PHPUnit marks it risky.

**Integration** (`tests/integration/`) — boots real WordPress and extends
`WP_UnitTestCase`, giving you factories, real hooks, and transaction rollback:

```php
$post_id = self::factory()->post->create( array( 'post_title' => 'Test Item' ) );
$this->assertInstanceOf( WP_Post::class, get_post( $post_id ) );
```

Integration tests need the WordPress test library:

```bash
npm run env:start
composer test:integration
```

On the host instead, point `WP_TESTS_DIR` at a `wordpress-develop` checkout's
`tests/phpunit`. Without either, the bootstrap exits with instructions rather
than a fatal error.

Rule of thumb: pure logic goes in unit tests; anything touching the database,
the query loop, or real core behaviour goes in integration.

## Releasing a plugin

```bash
composer build           # dist/<slug>-<version>.zip
composer build -- --dev  # skip the asset build
```

1. Bump the version in **both** places in the main file — the `Version:` header
   and the `*_VERSION` constant. The build warns if they disagree.
2. `composer lint && composer test`
3. `composer build`

The zip contains a single top-level `<slug>/` directory, which is what
WordPress requires when installing from a file. The slug comes from the plugin's
`Text Domain` header, not the folder name.

Ships: the main file, `includes/`, compiled `build/` assets, and `vendor/`
reinstalled with `--no-dev` (dropped entirely if there are no runtime deps).
Excluded: `src/`, `tests/`, `bin/`, `.claude/`, `CLAUDE.md`, and all lint/test
config.

**The exclude list is a denylist, not an allowlist.** A stray directory at the
project root will ship. Check `unzip -l dist/*.zip` before releasing.

## Tuning

- **Docblocks too strict?** Comment out `<rule ref="WordPress-Docs"/>` in
  `phpcs.xml.dist`.
- **PHPStan level 8 too noisy on legacy code?** Drop to 5 and raise as you clean
  up, or baseline it:
  `vendor/bin/phpstan analyse --generate-baseline --memory-limit=1G`
- **Author/vendor defaults** — `composer.json` uses a placeholder vendor name,
  and the entry point templates carry a placeholder author. Change both.
- `phpcs.xml` and `phpstan.neon` (without `.dist`) are gitignored, so you can
  override locally without touching committed config.

## Version pins, and why

- **PHPCS 3.x** — WPCS 3.4 doesn't support PHPCS 4 yet.
- **PHPUnit 9.6** — required by both the WordPress core test suite and WP_Mock
  1.1. `failOnNotice` is PHPUnit 10+ and is deliberately absent from the config.
- **Prettier is a direct dependency** — `wp-scripts format` demands the
  `wp-prettier` fork, so the scripts call `prettier` directly instead.
- **`tests/` is exempt from WP filename rules** — PHPUnit requires
  `ClassNameTest.php`, which conflicts with WPCS's `class-name.php`.

## License

GPL-2.0-or-later, matching WordPress.
