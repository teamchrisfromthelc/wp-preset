---
name: wp-preset
description: Scaffold WordPress plugin/theme tooling into a project — PHPCS with WP rules, PHPStan, ESLint, Prettier, PHPUnit with WP_Mock and WP_UnitTestCase, wp-env, format-on-save, and a release packager. Use when starting a new WordPress plugin or theme, when the user asks to "set up the preset" / "set up the wp-preset" or "add WP tooling/linting/standards/tests" to a project, or says "use PHPCS/ESLint/Prettier/PHPStan with WordPress rules" in a project that has no config yet. Once a project is scaffolded its own CLAUDE.md documents the day-to-day commands; this skill is for setting one up.
---

# wp-preset

Installs the WordPress tooling preset from `$WP_PRESET/`
into a project. All tooling is installed per project rather than globally, so
WordPress rules never reach a repo that did not ask for them.

## Where this is installed

Replace `$WP_PRESET` below with the path to your WP Preset checkout,
e.g. `~/Tools/wp-preset`.

## Run it

```bash
"$WP_PRESET"/setup.sh [--theme [--block|--classic]] [--plugin] \
  [--prefix <base>] <target-dir> <slug> [Prefix]
```

Always use `setup.sh`. Do **not** `cp -R` the directory — the script renames
placeholders throughout, and a plain copy leaves `wp-project` / `wp_project` /
`WpProject` / `WP Project` in every config and test file.

- `--theme` / `--plugin` — project kind. **Plugin is the default.**
- `--block` / `--classic` — which kind of theme. **Required with `--theme`**
  when running non-interactively, which is always the case for you: the
  script errors rather than guess. Both imply `--theme`, so `--classic` alone
  is enough.
- `<target-dir>` — project root. `.` is fine when already inside it.
- `<slug>` — lowercase-kebab, e.g. `acme-widgets`. This becomes the text
  domain, package names, and the default prefix base. The script rejects
  anything else.
- `[Prefix]` — class prefix. Defaults to StudlyCase of the slug.
- `--prefix <base>` — function and constant prefix, independent of the slug.
  Defaults to the slug with dashes as underscores. Must be lowercase snake_case.

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
composer test      # unit tests — expect OK (10 tests)
composer phpcs     # expect no output
composer phpstan   # expect [OK] No errors
```

A fresh install passes all three. If any fails, fix it before telling the user
the preset is installed.

## Releasing

```bash
composer build   # -> dist/<slug>-<version>.zip
```

Version comes from the `Version:` header in the main plugin file. Bump it there
(and any `*_VERSION` constant — the build fails if they disagree) before
building. Works for both plugins and themes.

## What lands

`composer.json`, `package.json`, `phpcs.xml.dist`, `phpstan.neon.dist`,
`phpunit.xml.dist` + `phpunit-integration.xml.dist`, `tests/` (bootstraps and
worked examples), `eslint.config.mjs`, `.prettierrc.js`, `.editorconfig`,
`.gitignore`, `.wp-env.json`, `<slug>.php`, `AGENTS.md` + `CLAUDE.md`
(kind-specific project context for future sessions), and `.claude/`
(format-on-save hook plus tool permissions).

Nothing is overwritten — re-running is safe and picks up files you skipped.

## After installing

- **Existing codebase?** PHPStan is at level 8 and PHPCS includes
  `WordPress-Docs`. On legacy code expect a large first run — offer to baseline
  PHPStan or drop the level rather than mass-editing.

Full detail, tuning notes, and the testing guide: `$WP_PRESET/README.md`
