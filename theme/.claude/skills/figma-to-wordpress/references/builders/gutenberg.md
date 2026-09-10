<!-- Part of the figma-to-wordpress skill. Applies the never-guess method to the Block editor (Gutenberg) + Full Site Editing. -->

# Builder note: Gutenberg / Block editor

How the method maps to blocks: pull exact values per Figma node, then express them as **block markup** with literal values, ideally wired to **theme.json** design tokens so they're consistent and editable. Verify by measuring the rendered DOM against Figma geometry.

## Where block content lives
- Page/post content is **block markup in `post_content`** - HTML annotated with `<!-- wp:paragraph -->`-style comments. It's human-readable and safe to generate/inject directly (unlike Elementor's JSON), as long as the comment delimiters stay valid.
- Theme-level design tokens live in **`theme.json`** at the active theme's root: color palette, font sizes, font families, spacing scale, layout content/wide widths.
- In a **block theme** (Full Site Editing), headers/footers/templates are HTML files under the theme's `templates/` and `parts/` - editable in **Appearance → Editor**.

## Map Figma tokens → theme.json
This is the highest-leverage step. Translate the Figma palette + type ramp once:
```jsonc
{
  "version": 3,
  "settings": {
    "color":   { "palette": [ { "slug": "brand",   "color": "#307bff", "name": "Brand" } ] },
    "typography": {
      "fontSizes": [ { "slug": "lg", "size": "1.5rem", "name": "Large" } ],
      "fontFamilies": [ { "slug": "body", "fontFamily": "Inter, sans-serif", "name": "Body" } ]
    },
    "spacing": { "spacingSizes": [ { "slug": "40", "size": "2.5rem", "name": "40" } ] }
  }
}
```
Blocks then reference these (`var(--wp--preset--color--brand)` etc.), so the design system is centralized and the client can tweak it in the Styles UI without touching code.

## Field notes
- **Validate block markup** - a malformed `<!-- wp:* -->` comment makes the block show as "This block contains unexpected or invalid content." Generate from known-good shapes; round-trip through the editor once to confirm.
- **Custom fonts:** register them in `theme.json` `fontFace` (or enqueue), then include **all needed weights** - importing only 400 makes a `700` request silently fall back to Regular.
- **Spacing presets over magic numbers:** put Figma's spacing scale in `theme.json` `spacingSizes` so paddings/margins are consistent and themeable.
- **Group block = your layout primitive.** A Figma auto-layout frame maps to a Group with flex/grid layout (`layout` attribute: type, orientation, justifyContent) - set gap/padding from the node, don't eyeball.
- **SVG** still needs Safe SVG (or equivalent) to upload via the Media Library.

## Verification (always)
From the repo's `scripts/`:
```bash
node scripts/overflow-sweep.js http://localhost:PORT/your-page/ 390,430,768,1440,1920
node scripts/dom-measure.js http://localhost:PORT/your-page/ 1440 ".wp-block-group" "h1"
```
Measured box + computed styles vs the Figma node values = your bug list. Verify on the real front end, not the editor canvas.
