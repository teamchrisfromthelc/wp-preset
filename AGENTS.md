# WP Preset

This repository **is** the scaffold — it is not a WordPress plugin or theme.
Files here are templates copied into other projects by `setup.sh`.

## Layout

| Path                          | Role                                                                                          |
| ----------------------------- | --------------------------------------------------------------------------------------------- |
| `setup.sh`                    | Copies templates into a target project and renames placeholders                               |
| `bin/build.sh`                | Release packager, shipped to scaffolded projects                                              |
| `bin/check.sh`                | `composer check` — wordpress.org Plugin Check. Shipped to plugins only                        |
| `plugin/`                     | Plugin templates: `AGENTS.md`, `CLAUDE.md`, `readme.txt`                                      |
| `theme/`                      | Theme templates: `style.css`, `functions.php`, docs, plus `block/` and `classic/` subtrees    |
| `includes/`, `wp-project.php` | Entry point and PSR-4 example, copied into every project                                      |
| `tests/`, `phpunit*.xml.dist` | Test templates — they are copied, not run here                                                |
| `.claude/`                    | Format-on-save hook and tool permissions, copied into every project                           |
| `.github/workflows/`          | CI. Scaffolds into a temp dir and runs every gate — the only verification that means anything |
| `skill/`                      | Scaffolding command plus `install.sh`, which installs it for Claude Code, Codex, or Cursor    |
| `README.md`                   | User-facing docs. **Never copied into a scaffolded project**, and neither is `skill/`.        |

## Placeholders

Templates use these, and `setup.sh` rewrites them. Order matters in the sed
chain — uppercase and StudlyCase before the lowercase forms.

`wp-project` · `wp_project` · `WP_PROJECT_` · `WpProject` · `WP Project`

## Working on this repo

- **Don't run the linters here.** `composer.json` and `phpcs.xml.dist` are
  templates for scaffolded projects; this repo has no `vendor/`.
- **Verify by scaffolding.** Any change to a template must be checked by running
  `setup.sh` into a temp dir, installing, and running every gate:
  `composer test`, `phpcs`, `phpstan`, `npm run lint:js`, `lint:css`,
  `format:check`, and `composer build`. Several past bugs passed a syntax check
  and only failed on a real install. `.github/workflows/scaffold.yml` does all
  of this on every push, across macOS and Linux — read it before adding a check
  by hand, and add new assertions there rather than to a throwaway script.
- **`composer check` needs Docker**, so CI asserts its wiring rather than
  running it. Run it by hand against a scaffolded plugin when touching
  `bin/check.sh`, `bin/build.sh`, or `plugin/readme.txt`.
- **Three kinds, not two.** `--theme` alone is not runnable non-interactively:
  it prompts on a TTY and exits otherwise. Test `--plugin`, `--theme --block`,
  and `--theme --classic` — which is what CI's matrix does.
- **`setup.sh` never overwrites.** Existing files in a target are skipped.
- When adding a file that should reach projects, add it to the copy list in
  `setup.sh`, the rename list too if it contains placeholders, and an exclude in
  `bin/build.sh` if it must not ship in a release zip. That rsync list is, in
  the script's own words, the single source of truth for what ships — a new dev
  file lands in every user's release without one.
