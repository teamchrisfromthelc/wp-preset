# WP Preset

This repository **is** the scaffold — it is not a WordPress plugin or theme.
Files here are templates copied into other projects by `setup.sh`.

## Layout

| Path                          | Role                                                                                       |
| ----------------------------- | ------------------------------------------------------------------------------------------ |
| `setup.sh`                    | Copies templates into a target project and renames placeholders                            |
| `bin/build-plugin.sh`         | Release packager, shipped to scaffolded plugins                                            |
| `plugin/`, `theme/`           | Kind-specific templates: entry points, `AGENTS.md`, `CLAUDE.md`                            |
| `tests/`, `phpunit*.xml.dist` | Test templates — they are copied, not run here                                             |
| `skill/`                      | Scaffolding command plus `install.sh`, which installs it for Claude Code, Codex, or Cursor |
| `README.md`                   | User-facing docs. **Never copied into a scaffolded project**, and neither is `skill/`.     |

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
  and only failed on a real install.
- **Both kinds.** Changes touching `setup.sh` need testing with `--plugin` and
  `--theme`.
- **`setup.sh` never overwrites.** Existing files in a target are skipped.
- When adding a file that should reach projects, add it to the copy list _and_
  the rename list in `setup.sh` if it contains placeholders.
