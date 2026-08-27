# WP Preset

WordPress plugin and theme tooling, installed per project in one command:
PHPCS with WordPress standards, PHPStan, ESLint, Prettier, PHPUnit with WP_Mock
and `WP_UnitTestCase`, `wp-env`, format-on-save, and a release packager.

Everything is standard tooling with standard config files. Nothing depends on
this repo after installation.

## Why

Wiring this up takes a day, and you repeat it on every project. PHPCS needs the
WordPress standards plus a ruleset that knows your text domain and prefixes.
PHPStan needs WordPress stubs and a raised memory limit. PHPUnit needs two
configs, because unit tests must not boot WordPress and integration tests must.

Installing it per project rather than globally means the config is committed
with the code, WordPress rules never reach your Laravel repo, and each project
tunes its own strictness.

## Requirements

PHP 8.0+, Composer 2, Node 20+. Plus `rsync` and `zip` for the release
packager, and Claude Code (optional) for format-on-save.

PHP needs the `mbstring` and XML extensions (`dom`, `simplexml`, `xmlreader`,
`xmlwriter`), which PHPUnit and PHPCS require. macOS and most distro PHP builds
bundle them. A minimal Debian or Ubuntu install does not, and `composer install`
stops with a list of what's missing:

```bash
sudo apt install php-cli php-xml php-mbstring rsync zip
```

## Install

Clone it anywhere. The scripts resolve paths relative to themselves.

```bash
git clone git@github.com:teamchrisfromthelc/wp-preset.git ~/Tools/wp-preset
```

That's the whole install. Scaffolding a project is a separate step, and there
are two ways to do it.

## Scaffolding a project

### With an AI agent

Install the scaffolding command once, which bakes in the path to your checkout:

```bash
./skill/install.sh claude   # ~/.claude/skills/wp-preset/SKILL.md
./skill/install.sh codex    # ~/.codex/prompts/wp-preset.md
./skill/install.sh cursor   # ~/.cursor/rules/wp-preset.mdc
./skill/install.sh print    # plain markdown, for anything else
```

Then ask, in a new empty folder or naming one that doesn't exist yet:

> set up the wp-preset for a plugin
>
> set up the wp-preset for a theme
>
> add WP tooling and tests to this project

The agent runs `setup.sh` for you: it picks `--plugin` or `--theme` from your
wording, derives the slug from the folder name, and runs `composer install` and
`npm install`. It asks first if the folder name is ambiguous, because the slug
is hard to change later.

To choose the slug yourself, say so — an explicit slug always wins over the
folder name:

> set up the wp-preset for a plugin, use the slug my-cool-plugin

Claude Code and Codex also expose it as `/wp-preset`.

### By hand

```bash
./setup.sh [--theme [--block|--classic]] [--plugin] [--prefix <base>] <target-dir> <slug> [Prefix]
```

```bash
./setup.sh ~/Projects/acme-widgets acme-widgets
cd ~/Projects/acme-widgets
composer install && npm install
```

Plugin is the default. The target may be a path that doesn't exist yet, an empty
folder, or `.` when you're already inside one. Both installs are required — the
format hook stays silent until they've run.

### Either way

**The slug must be lowercase-kebab.** It becomes the text domain, package name,
and prefix base for every global, so changing it later is a wide rename.

It does not have to match the folder name:

```bash
./setup.sh ~/Projects/my-test-plugin my-cool-plugin
```

That produces `my-cool-plugin.php`, text domain `my-cool-plugin`, prefix
`my_cool_plugin_`, constants `MY_COOL_PLUGIN_*`, and a release zip containing
`my-cool-plugin/`. The folder name is never used.

One consequence: `wp-env` mounts the folder, so in local development the plugin
directory inside the container is `my-test-plugin` while the slug is
`my-cool-plugin`. WordPress reads the plugin from its headers so this works
fine, but renaming the folder to match avoids the confusion.

| Placeholder   | With slug `acme-widgets`                    |
| ------------- | ------------------------------------------- |
| `wp-project`  | `acme-widgets` — text domain, package names |
| `wp_project`  | `acme_widgets` — function prefix            |
| `WP_PROJECT_` | `ACME_WIDGETS_` — constants                 |
| `WpProject`   | `AcmeWidgets` — class prefix                |
| `WP Project`  | `Acme Widgets` — header name                |

Plugin is the default; `--theme` changes the entry points (`style.css` +
`functions.php` instead of `<slug>.php`), the composer type, and how `wp-env`
mounts the project. Don't hand-edit those afterwards.

### Block or classic themes

WordPress only recognises a directory as a theme if it carries
`templates/index.html` or `index.php`, so `--theme` asks which you want:

```
Which kind of theme?
  1) block   — theme.json, templates/, Site Editor (WordPress 5.9+)
  2) classic — index.php, header.php, footer.php, PHP templates
```

Pass `--block` or `--classic` to skip the question. One of the two is
**required** when stdin isn't a terminal — scripts and agents get an error
rather than a silently wrong theme.

|                | `--block`                                                        | `--classic`                             |
| -------------- | ---------------------------------------------------------------- | --------------------------------------- |
| Templates      | `templates/index.html`, `parts/header.html`, `parts/footer.html` | `index.php`, `header.php`, `footer.php` |
| Global styles  | `theme.json` (colors, typography, layout)                        | CSS in `style.css`                      |
| Editing        | Site Editor                                                      | PHP + Customizer                        |
| Theme supports | mostly implicit from `theme.json`                                | registered in `functions.php`           |

Both get `style.css`, `functions.php`, `includes/`, and the full tooling. The
choice is a wide rewrite later, so it's worth a moment now.

### Shorter prefixes with `--prefix`

By default the function and constant prefixes come from the slug, which is fine
until the slug has to be long. A directory listing wants
`cartrules-one-tag-in-cart-for-woocommerce`, but nobody wants to type
`cartrules_one_tag_in_cart_for_woocommerce_get_settings()`.

`--prefix` sets that base independently:

```bash
./setup.sh --prefix cartrules_otic ~/Projects/otic cartrules-one-tag-in-cart-for-woocommerce
```

| Placeholder   | Result                                      |
| ------------- | ------------------------------------------- |
| `wp-project`  | `cartrules-one-tag-in-cart-for-woocommerce` |
| `wp_project`  | `cartrules_otic` — function prefix          |
| `WP_PROJECT_` | `CARTRULES_OTIC_` — constants               |
| `WpProject`   | `CartrulesOneTagInCartForWoocommerce`       |

Useful for a family of sibling plugins sharing one brand prefix plus a short
per-plugin code. Combine it with the positional `[Prefix]` to shorten the class
prefix too.

The text domain always stays the slug — WordPress requires it to match the
directory. For the same reason option, transient, and meta keys should stay
slug-derived, so PHPCS is configured with **both** prefixes and accepts either.

`setup.sh` never overwrites an existing file, so re-running is safe.

Adding it to a project that already has a `composer.json` or `package.json` is a
partial install: the config files land, but your manifests are left alone, so
none of the dev dependencies are added. Merge the `require-dev` and `scripts`
blocks from this repo's versions, then `composer install && npm install`.

## Verify

A fresh scaffold passes all of these. If it doesn't, that's a bug — please open
an issue.

```bash
composer test && composer phpcs && composer phpstan
npm run lint:js && npm run lint:css && npm run format:check
```

## Commands

```bash
composer phpcbf            # autofix PHP
composer phpcs             # report what phpcbf could not fix
composer phpstan           # static analysis, level 8
composer lint              # phpcs + phpstan
composer test              # unit tests — fast, no WordPress
composer test:integration  # integration tests — needs wp-env running
composer build             # dist/<slug>-<version>.zip
composer check             # wordpress.org Plugin Check — plugins only, needs Docker

npm run build              # compile src/ -> build/
npm run start              # same, in watch mode
npm run lint:js            # ESLint          (:fix to autofix)
npm run lint:css           # stylelint       (:fix to autofix)
npm run format             # Prettier, write
npm run format:check       # Prettier, check only
npm run env:start          # local WordPress (env:stop, env:destroy)
npm run packages-update    # bump @wordpress/* packages
```

`npm run build` compiles assets. `composer build` packages a release.

No `src/` is scaffolded — create it when you have assets to compile. Until then
`composer build` skips the asset step rather than running it, so the zip carries
no `build/` directory. Once `src/` exists it compiles first, provided
`node_modules` is installed. `composer build -- --dev` skips it.

## Where code goes

`includes/` is PSR-4 autoloaded under your class prefix, wired through
`composer.json`:

```json
"autoload": { "psr-4": { "AcmeWidgets\\": "includes/" } }
```

The entry point already requires `vendor/autoload.php`, so a class in
`includes/` loads with no `require`:

```php
namespace AcmeWidgets;

class Settings {}      // includes/Settings.php
```

**Filenames there follow PSR-4, not the WordPress convention.** The file must
match the class name — `Settings.php`, not `class-settings.php` — or the
autoloader won't find it. `phpcs.xml.dist` excludes `includes/` from
`WordPress.Files.FileName` for exactly this reason; every other directory still
gets the WordPress rule.

A scaffold ships `includes/Example.php` and a test asserting it autoloads.
Delete both once you have real classes. If you'd rather not use the autoloader,
drop the `autoload` block and `require` your files by hand.

## Testing

**Unit** (`tests/unit/`) — no WordPress, no database, milliseconds. WP functions
are mocked with WP_Mock; extend `WP_Mock\Tools\TestCase`.

```php
WP_Mock::userFunction( 'get_option' )->once()->with( 'mode' )->andReturn( 'live' );
WP_Mock::expectActionAdded( 'init', 'acme_widgets_register_cpt' );
```

WP_Mock verifies in `tearDown()`, so a test asserting only on hooks needs an
explicit `$this->assertHooksAdded()` or PHPUnit marks it risky.

**Integration** (`tests/integration/`) — boots real WordPress, extends
`WP_UnitTestCase`, gives you factories and transaction rollback.

```php
$post_id = self::factory()->post->create( array( 'post_title' => 'Test Item' ) );
```

Run `npm run env:start` first. On the host instead, point `WP_TESTS_DIR` at a
`wordpress-develop` checkout's `tests/phpunit`.

Pure logic goes in unit tests; anything touching the database, the query loop,
or real core behaviour goes in integration.

## Checking against wordpress.org

`composer check` runs [Plugin Check](https://wordpress.org/plugins/plugin-check/)
— the tool wordpress.org runs during review — against your built zip.

```bash
composer check                            # table
composer check -- --json > findings.json  # for an agent
```

It needs Docker, boots WordPress through wp-env, and takes a minute or two. Run
it before a submission. PHPCS covers the sniff-based half of those checks on
every save already, which is why this is a separate command rather than part of
`composer lint`.

**It checks the zip, not your working directory.** That is deliberate. Your
working tree has `tests/`, `.claude/`, `AGENTS.md` and other tooling that never
ships, and Plugin Check flags all of it. On a freshly scaffolded plugin that is
fifteen findings against the source tree and zero against the zip.

A fresh scaffold passes clean. `readme.txt` ships with the current WordPress
version stamped in at scaffold time, and whenever the zip carries a `vendor/`
directory, `composer.json` ships beside it so a reviewer can tell what the
bundled code is. Drop the `autoload` block and take on no runtime dependencies
and neither ships, which is also fine — there is then nothing to explain.

Two things to know about the output:

- **The exit code is always 0.** That is Plugin Check's own behaviour — it tells
  you the tool ran, not whether the plugin passed. In JSON mode an empty array
  means clean.
- **These are findings to assess, not a task list.** Plugin Check flags patterns
  that are usually wrong and sometimes correct for a particular plugin. Fixing
  each one without reading it makes the code worse. `--ignore-codes` is for the
  ones you have judged and rejected. `ERROR` blocks a submission, `WARNING`
  does not.

Themes get no equivalent — Plugin Check has no theme code path, so the command
is not scaffolded for them.

### Keeping `Tested up to` current

`readme.txt` is stamped with the current WordPress version when the project is
scaffolded. It goes stale on WordPress's schedule rather than yours: once a new
major ships, wordpress.org treats the old value as an error and drops the plugin
out of search results. Bump it and re-run `composer check`. Major version only —
`7.1`, not `7.1.2`.

## Releasing

### With an AI agent

The project's `AGENTS.md` documents the release steps, so this works without any
extra setup:

> release version 0.2.0

> build the release zip

The agent bumps the version everywhere it lives, runs
`composer lint && composer test`, then `composer build`. Ask it to confirm the
version it used. Any disagreement between them fails the build, so a wrong
version never ships.

### By hand

```bash
composer build           # dist/<slug>-<version>.zip
composer build -- --dev  # skip the asset build
```

Bump the version in **all three** places — the `Version:` header, the
`*_VERSION` constant, and `Stable tag:` in `readme.txt`. The build fails if any
of them disagree. The stable tag is what wordpress.org reads to decide which
release to serve, so a stale one keeps serving the old version regardless of
what was uploaded.

The zip contains a single top-level `<slug>/` directory, named from the plugin's
`Text Domain` header. It ships the main file, `includes/`, compiled `build/`
assets, and `vendor/` reinstalled with `--no-dev`. It excludes `src/`, `tests/`,
`bin/`, `.claude/`, `.github/`, `dist/`, `node_modules/`, the agent files, and
all lint config. The rsync exclude list in `bin/build.sh` is the full account.

**The exclude list is a denylist**, so a stray directory at the project root will
ship. Check `unzip -l dist/*.zip` before releasing.

Themes package the same way. The build detects plugin or theme from the headers
(`Plugin Name:` in a PHP file, `Theme Name:` in `style.css`) and applies the same
exclude rules, so a theme zip carries `style.css`, `functions.php`, `includes/`,
and whichever templates the theme kind uses — `theme.json` with `templates/` and
`parts/` for a block theme, or `index.php`, `header.php` and `footer.php` for a
classic one. None of the tests, lint config, or build tooling ships.

## AI agents

Scaffolded projects carry their own instructions, so any agent knows the
commands and conventions without being told:

- `AGENTS.md` — Cursor, Codex, Zed, Aider, Copilot
- `CLAUDE.md` — Claude Code; a two-line file importing `AGENTS.md`

One source of truth, nothing to keep in sync. Both are excluded from release
zips. Treat the generated file as a starting point and add your own conventions.

With Claude Code, a `PostToolUse` hook also runs `phpcbf`/`phpcs` on PHP and
`eslint`/`prettier` on JS and CSS after every edit, feeding anything unfixable
back to the agent. Not using Claude Code? Delete `.claude/`.

## Tuning

- **Docblocks too strict?** Comment out `<rule ref="WordPress-Docs"/>` in
  `phpcs.xml.dist`.
- **PHPStan level 8 too noisy on legacy code?** Drop to 5, or baseline it:
  `vendor/bin/phpstan analyse --generate-baseline --memory-limit=1G`
- **PHPStan doesn't know what `WC()` is?** It ships WordPress core stubs only.
  For a plugin built on WooCommerce (or ACF, WP-CLI, and the rest), install that
  project's stubs and uncomment the `scanFiles` block in `phpstan.neon.dist`:

    ```bash
    composer require --dev php-stubs/woocommerce-stubs
    ```

    Without them every `wc_*()` call reports as `function.notFound`, and a class
    extending an unresolved `WC_*` parent turns each inherited property into a
    `property.notFound` that reads exactly like a real bug.

- `phpcs.xml` and `phpstan.neon` (no `.dist`) are gitignored for local
  overrides.

## Version pins

- **PHPCS 3.x** — WPCS 3.4 doesn't support PHPCS 4.
- **PHPUnit 9.6** — required by the WordPress core test suite and WP_Mock 1.1.
- **Prettier is a direct dependency** — `wp-scripts format` demands the
  `wp-prettier` fork, so the scripts call `prettier` directly.
- **`tests/` is exempt from WP filename rules** — PHPUnit wants
  `ClassNameTest.php`, WPCS wants `class-name.php`.

## License

GPL-2.0-or-later
