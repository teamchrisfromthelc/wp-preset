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
"$WP_PRESET"/setup.sh [--theme|--plugin] <target-dir> <slug> [Prefix]
```

Always use `setup.sh`. Do **not** `cp -R` the directory — the script renames
placeholders throughout, and a plain copy leaves `wp-project` / `wp_project` /
`WpProject` / `WP Project` in every config and test file.

- `--theme` / `--plugin` — project kind. **Plugin is the default.**
- `<target-dir>` — project root. `.` is fine when already inside it.
- `<slug>` — lowercase-kebab, e.g. `acme-widgets`. This becomes the text
  domain, package names, and the prefix base. The script rejects anything else.
- `[Prefix]` — class prefix. Defaults to StudlyCase of the slug.

### Pick the kind from what the user said

| They say | Use |
|----------|-----|
| "a theme", "block theme", "child theme" | `--theme` |
| "a plugin", or nothing about kind | `--plugin` (default) |

The flag handles everything kind-specific — entry points, `composer.json` type,
and how wp-env mounts the project. Don't edit those by hand afterwards.

| | `--plugin` | `--theme` |
|---|---|---|
| Entry points | `<slug>.php` | `style.css` + `functions.php` |
| `composer.json` type | `wordpress-plugin` | `wordpress-theme` |
| `.wp-env.json` mounts as | `plugins` | `themes` |

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
composer test      # unit tests — expect OK (8 tests)
composer phpcs     # expect no output
composer phpstan   # expect [OK] No errors
```

A fresh install passes all three. If any fails, fix it before telling the user
the preset is installed.

## Releasing a plugin

```bash
composer build   # -> dist/<slug>-<version>.zip
```

Version comes from the `Version:` header in the main plugin file. Bump it there
(and any `*_VERSION` constant — the build warns if they disagree) before
building. Plugins only; themes have no packaging step.

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
