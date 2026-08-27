---
name: wp-preset
description: Scaffold WordPress plugin/theme tooling into a project — PHPCS with WP rules, PHPStan, ESLint, Prettier, PHPUnit with WP_Mock and WP_UnitTestCase, wp-env, format-on-save, and a release packager. Use when starting a new WordPress plugin or theme, when the user asks to "set up the preset" / "set up the wp-preset" or "add WP tooling/linting/standards/tests" to a project, or says "use PHPCS/ESLint/Prettier/PHPStan with WordPress rules" in a project that has no config yet. Once a project is scaffolded its own CLAUDE.md documents the day-to-day commands; this skill is for setting one up.
---

# wp-preset

Installs the WordPress tooling preset from `$WP_PRESET/`
into a project. All tooling is installed per project rather than globally, so
WordPress rules never reach a repo that did not ask for them.

## The WP Preset checkout

`$WP_PRESET` in the commands below is the WP Preset checkout. `install.sh`
resolves it to a real path as it installs this file, so if that reads as an
absolute path there is nothing to substitute.

## Run it

```bash
"$WP_PRESET"/setup.sh [--theme [--block|--classic]] [--plugin] \
  [--prefix <base>] <target-dir> <slug> [Prefix]
```

Always use `setup.sh`. Do **not** `cp -R` the directory — the script renames
placeholders throughout, and a plain copy leaves `wp-project` / `wp_project` /
`WpProject` / `WP Project` in every config and test file.

- `--theme` / `--plugin` — project kind. **Plugin is the default.**
- `--block` / `--classic` — which kind of theme. **Always pass one with
  `--theme`.** Given a terminal on both stdin and stdout the script prompts;
  otherwise it errors rather than guess, and a tool-driven run usually lacks
  one. Both imply `--theme`, so `--classic` alone is enough.
- `<target-dir>` — project root. `.` is fine when already inside it.
- `<slug>` — lowercase-kebab, e.g. `acme-widgets`. This becomes the text
  domain, package names, and the default prefix base. The script rejects
  anything else: uppercase, spaces, underscores, a leading digit, a trailing
  hyphen, or a double hyphen. It is sed'd into PHP identifiers, so there is no
  latitude here.
- `[Prefix]` — class prefix. Defaults to StudlyCase of the slug.
- `--prefix <base>` / `--prefix=<base>` — function and constant prefix,
  independent of the slug. Defaults to the slug with dashes as underscores.
  Lowercase snake_case, optionally leading underscore, never leading digit.
  The space form consumes whatever follows it, so `--prefix ~/Projects/thing`
  silently takes the path as the prefix and then fails on the missing slug.
  Prefer `--prefix=<base>` when building the command programmatically.

All flags go **before** `<target-dir>`. The script rejects one placed after it
rather than reading it as a positional argument.

### When to use `--prefix`

Only when the user asks for a short prefix, or the slug is long enough that the
derived prefix would be unwieldy. A slug has to stay long for the wordpress.org
listing and the text domain, but nobody wants to type
`cartrules_one_tag_in_cart_for_woocommerce_get_settings()`.

```bash
"$WP_PRESET"/setup.sh --prefix cartrules_otic ~/Projects/otic \
  cartrules-one-tag-in-cart-for-woocommerce
```

Gives `cartrules_otic_*` functions and `CARTRULES_OTIC_*` constants, while the
text domain stays `cartrules-one-tag-in-cart-for-woocommerce`. WordPress
requires the text domain to match the directory, so it never follows `--prefix`.

Ask before choosing a short prefix — like the slug, it is a wide rename later.
Don't invent one when the user hasn't asked.

### Pick the kind from what the user said

| They say                                            | Use                  |
| --------------------------------------------------- | -------------------- |
| "a block theme", "full site editing", "Site Editor" | `--block`            |
| "a classic theme", "PHP templates", "child theme"   | `--classic`          |
| "a theme", with no hint which kind                  | **ask** — see below  |
| "a plugin", or nothing about kind                   | `--plugin` (default) |

### Choosing between a block and a classic theme

`--theme` on its own fails for you. The script prompts a human at a terminal,
but errors when stdin is not one, and it never guesses. So decide before you
run it.

|               | `--block`                          | `--classic`                             |
| ------------- | ---------------------------------- | --------------------------------------- |
| Templates     | `templates/*.html`, `parts/*.html` | `index.php`, `header.php`, `footer.php` |
| Global styles | `theme.json`                       | CSS in `style.css`                      |
| Edited in     | Site Editor                        | PHP + Customizer                        |

If the user hasn't said, **ask them**, the same way you would for an ambiguous
slug. Switching later means rewriting every template. When they have no
preference, block is the reasonable default for new work — it is where
WordPress theme development has gone, and the preset targets 6.5+ — but say
that you are choosing it rather than deciding silently.

The flag handles everything kind-specific — entry points, `composer.json` type,
and how wp-env mounts the project. Don't edit those by hand afterwards.

|                          | `--plugin`         | `--theme`                                 |
| ------------------------ | ------------------ | ----------------------------------------- |
| Entry points             | `<slug>.php`       | `style.css` + `functions.php` + templates |
| `composer.json` type     | `wordpress-plugin` | `wordpress-theme`                         |
| `.wp-env.json` mounts as | `plugins`          | `themes`                                  |

If the kind is genuinely unclear and the folder gives no hint, ask. Scaffolding
a theme as a plugin means it never appears under Appearance → Themes.

An explicit slug always wins: "use the slug my-cool-plugin" means pass
`my-cool-plugin`, whatever the folder is called. The folder name is only a
fallback.

Otherwise derive the slug from the folder name, converting to lowercase-kebab
(`Acme Widgets` → `acme-widgets`). If the folder name is ambiguous or
non-descriptive, ask rather than guess — the slug is baked into the text domain
and every global prefix, and changing it later means a wide rename.

### Then

```bash
cd <target-dir>
composer install && npm install
```

Both are required. The format-on-save hook stays silent until they've run, which
looks like a broken hook.

## Verify before reporting done

```bash
composer test          # unit tests — expect OK (10 tests)
composer phpcs         # progress bar, then no violations. Judge by exit code
composer phpstan       # expect [OK] No errors
npm run lint:js        # ESLint
npm run lint:css       # stylelint
npm run format:check   # Prettier
```

`phpcs` prints `........ 8 / 8 (100%)` and a timing line even on a clean run —
that is success, not output to fix. Go by the exit code.

A fresh install passes all six. If any fails, fix it before telling the user the
preset is installed. CI runs these same gates on every push
(`.github/workflows/scaffold.yml`).

## Releasing

```bash
composer build   # -> dist/<slug>-<version>.zip
```

Version comes from the `Version:` header — in the main plugin file for a plugin,
in `style.css` for a theme. Bump it there, along with the `*_VERSION` constant
(the main file for a plugin, `functions.php` for a theme) and, for a plugin,
`Stable tag:` in `readme.txt`. The build fails if they disagree.

Plugins also get `composer check`, which runs wordpress.org's Plugin Check
against the built zip. It needs Docker and takes a minute or two, so it belongs
before a submission rather than in the normal edit loop. `composer check --
--json` writes findings an agent can read. The output is findings to assess, not
a task list — Plugin Check flags patterns that are sometimes correct, and its
exit code is 0 either way. Themes get no equivalent; Plugin Check has no theme
code path.

## What lands

Every project gets `composer.json`, `package.json`, `phpcs.xml.dist`,
`phpstan.neon.dist`, `phpunit.xml.dist` + `phpunit-integration.xml.dist`,
`tests/` (bootstraps and worked examples), `includes/Example.php` (the PSR-4
class the autoload test asserts on), `eslint.config.mjs`, `.prettierrc.js`,
`.prettierignore`, `.editorconfig`, `.gitignore`, `.wp-env.json`, `bin/build.sh`,
`AGENTS.md` + `CLAUDE.md` (kind-specific project context for future sessions),
and `.claude/` (format-on-save hook plus tool permissions).

A **plugin** also gets `<slug>.php`, `readme.txt`, and `bin/check.sh`. A
**theme** gets `style.css` + `functions.php` instead, plus either `theme.json`
and `templates/`/`parts/` for a block theme or `index.php`/`header.php`/
`footer.php` for a classic one.

Both kinds carry a `Tested up to` header — a plugin's in `readme.txt`, a theme's
in `style.css`. `setup.sh` stamps it with the current WordPress version fetched
from wordpress.org. If that fetch fails — offline, no curl or php, or the API
changes shape — it warns on stderr and leaves the template's value, which will
be behind. Watch for that warning and set the header by hand when you see it.

Nothing is overwritten — re-running is safe and picks up files you skipped.

## After installing

- **Existing codebase?** PHPStan is at level 8 and PHPCS includes
  `WordPress-Docs`. On legacy code expect a large first run — offer to baseline
  PHPStan or drop the level rather than mass-editing.

Full detail, tuning notes, and the testing guide: `$WP_PRESET/README.md`
