<!-- Part of the figma-to-wordpress skill - loaded on demand. The decision spine lives in ../SKILL.md; this file is reference detail, read when relevant. -->

## Figma REST API (asset extraction + connectivity)

The Figma MCP is excellent for spec extraction (CSS, layout, node tree) but has two weaknesses:
1. `get_screenshot` always returns PNG - even for vector icons that should be SVG.
2. No batched asset export - one node per call.

The Figma REST API fills both gaps. Use it whenever the page needs more than ~3 icons, any photographic assets, or you want a deterministic token-extraction step.

This section is **WordPress-editor-agnostic** - the ingest works the same for Divi, Elementor, Bricks, Gutenberg/FSE, classic themes. Only the *output* (where tokens/assets land in the target site) differs per editor.

### Session start: locate an existing token (do this BEFORE asking the user)

A fresh Claude session won't inherit env vars from the user's interactive shell - Bash tool calls run in a non-login, non-interactive Bash that does NOT source `~/.zshrc` / `~/.bashrc` / `.env` files automatically. So `echo $FIGMA_PAT` will look empty even when the user has it set up. **Don't conclude "no token" from that alone.** Run the checks below first.

```bash
# 1. Already in current shell?
[ -n "$FIGMA_PAT" ] && echo "in-env (length ${#FIGMA_PAT})"

# 2. Stored in ~/.zshrc? (most common on macOS - user's interactive shell is zsh by default)
grep -l "FIGMA_PAT" ~/.zshrc ~/.zprofile ~/.bashrc ~/.bash_profile ~/.profile 2>/dev/null

# 3. In a project .env? (search from likely roots - adjust as needed)
grep -rln "FIGMA_PAT" \
  ~/"Local Sites" \
  ~/Documents \
  ~/Projects \
  2>/dev/null | grep -E "\.env(\.[a-z]+)?$" | head

# 4. If found in ~/.zshrc, source it into the current Bash call:
export FIGMA_PAT=$(zsh -c 'source ~/.zshrc 2>/dev/null; echo $FIGMA_PAT')
export FIGMA_PAT_EXPIRES=$(zsh -c 'source ~/.zshrc 2>/dev/null; echo $FIGMA_PAT_EXPIRES')

# 5. If found in a .env, source that instead:
set -a; source /path/to/project/.env; set +a
```

Only fall through to "One-time token setup" below if none of these surfaced anything.

**Persisting in subsequent Bash calls in the same session:** each Bash tool call is a fresh non-interactive shell, so the `export` above does NOT persist between calls. Either:
- Prepend the `export FIGMA_PAT=$(zsh -c ...)` line to every Bash call that needs it (cheap, ~50ms overhead), OR
- Write the token to a session-local file once: `zsh -c 'source ~/.zshrc; echo $FIGMA_PAT' > /tmp/.figma_pat && chmod 600 /tmp/.figma_pat`, then `export FIGMA_PAT=$(cat /tmp/.figma_pat)` in each subsequent call. Delete `/tmp/.figma_pat` at session end if you remember.

### One-time token setup (only if no existing token found)

1. Figma → Avatar (top-left) → Settings → Security → Personal access tokens → Generate new token.
2. **Scopes:** `file_content:read` and `file_metadata:read` only. **Never grant write scopes.**
3. Save the token. Two options:
   - **Per-project `.env`** (preferred for client work): `FIGMA_PAT=figd_xxx` in the project root. Gitignore it.
   - **Global `~/.zshrc`**: `export FIGMA_PAT=figd_xxx`. Use this when running cross-project work frequently.
4. (Optional) Add an expiry tracker line alongside it: `export FIGMA_PAT_EXPIRES=YYYY-MM-DD`. Helps the rotation reminder below trigger before things break.
5. Source it: `source .env` or restart the shell.
6. Also export `FIGMA_FILE_KEY=<key from figma.com/design/<KEY>/...>` for the current project.

### Connectivity check (run once per session)

```bash
curl -s -H "X-Figma-Token: $FIGMA_PAT" \
  "https://api.figma.com/v1/files/$FIGMA_FILE_KEY" \
  | jq '{name, lastModified, pages: [.document.children[].name]}'
```

If this returns the file name and page list, the token works. If 401/403/404, fix that before touching anything else (see error table below).

### Batch SVG export - replaces `get_screenshot` for vector icons

```bash
# Comma-separated node IDs of vector layers (chevrons, logos, illustrations, etc.)
IDS="123:456,123:457,123:458"

curl -s -H "X-Figma-Token: $FIGMA_PAT" \
  "https://api.figma.com/v1/images/$FIGMA_FILE_KEY?ids=$IDS&format=svg" \
  | jq -r '.images | to_entries[] | "\(.key) \(.value)"' \
  | while read id url; do
      safe=$(echo "$id" | tr ':' '_')
      curl -sL "$url" -o "$ASSETS/icon_${safe}.svg"
    done
```

Rules:
- If the API returns `null` for a node ID, that node is a flattened bitmap (no vector source). Re-request that specific ID with `format=png&scale=2`.
- Sanitize filenames after download (designers name layers things like `Chevron down / 24`).
- Prefer inline SVG in HTML/shortcodes (one fewer HTTP request, works in any WP editor's Code/HTML block).

### Batch image-fill download - product photos, hero images, food photography

When a designer drops a photo into Figma, it's stored as an "image fill" referenced by hash. The REST API returns every photo in the file at original resolution in one call:

```bash
curl -s -H "X-Figma-Token: $FIGMA_PAT" \
  "https://api.figma.com/v1/files/$FIGMA_FILE_KEY/images" \
  | jq -r '.meta.images | to_entries[] | "\(.key) \(.value)"' \
  | while read hash url; do
      curl -sL "$url" -o "$ASSETS/img_${hash:0:12}.png"
    done
```

To map each downloaded image back to the Figma layer it came from, cross-reference the file's node tree - image fills have an `imageRef` field that matches these hash keys.

### Error table

| Status | Cause | Fix |
|---|---|---|
| 401 (first call this session) | Missing or malformed token header | Confirm `X-Figma-Token` header is set and `$FIGMA_PAT` is exported in current shell |
| 401 (was working, now failing) | **Token expired** - Figma PATs can have expiry dates (7 / 30 / 90 days / no expiry) | Tell the user the token expired and they need to rotate it: Figma → Settings → Security → Personal access tokens → revoke old, generate new with same scopes, update `~/.zshrc` or `.env` |
| 403 | Token lacks file access | Regenerate token with `file_content:read` scope; confirm the Figma account owns or was shared the file |
| 404 | Wrong fileKey | Re-extract fileKey from the Figma URL (`figma.com/design/<KEY>/...`) |
| 429 | Rate limit | Honor `Retry-After` header; back off ~30s |
| `null` in `/v1/images` response | Node is a flattened bitmap | Re-request that ID with `format=png&scale=2` instead of `svg` |

### Token rotation

Figma personal access tokens can be set with expiry dates (7 / 30 / 90 days / no expiry). If the user picked an expiry, when this skill encounters a 401 on a previously-working setup, **assume token expiry first** before debugging anything else. Walk the user through revoking the old one and generating a new one with the same scopes (`file_content:read` + `file_metadata:read`). The skill should never silently retry - token rotation is a human-in-the-loop step.

### When to use MCP vs REST API

| Task | Tool |
|---|---|
| CSS / dimensions / layout for one node | Figma MCP `get_design_context` |
| Visual confirmation of one node | Figma MCP `get_screenshot` |
| Variables / design tokens | MCP `get_variable_defs` first; fall back to REST `/v1/files/:key/styles` if empty |
| Batched vector icons (>3) | REST `/v1/images?format=svg` |
| All raster photos in the file | REST `/v1/files/:key/images` |
| Session-start connectivity check | REST `/v1/files/:key` with `jq` |

**Rule of thumb:** MCP for one-node specs, REST API for batched assets and connectivity verification.
