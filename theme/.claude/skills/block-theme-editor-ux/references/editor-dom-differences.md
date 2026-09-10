# Known editor DOM and CSS differences

Tested against: WordPress 7.1 (bundled Gutenberg). Every entry below is a
Gutenberg internal. When the site runs a different major version, measure
before applying the fix, and update the version line and the entry if it
changed. Add new findings at the bottom with the version they were seen on.

All fixes go in `assets/css/editor.css`, never `style.css`.

## Block gap margins lose to an editor rule

The editor emits
`.wp-container-content-X.wp-container-content-X > * { margin-block-start: 0 }`
at specificity (0,2,0). The front end uses `:where()` for the same rule, so any
single-class margin rule in the theme wins there and loses in the editor.

Fix: repeat each affected rule at (0,3,0):

```css
.wp-block.foo.foo { margin-top: var(--wp--preset--spacing--40); }
```

Derive the list mechanically from `style.css`: every bare `.class` selector
that sets `margin*`.

## `position: absolute` on a block

The wrapper rule `.block-editor-block-list__block { position: relative }`
at (0,2,0) overrides the theme's positioning.

Fix: re-declare at (0,3,0), scoped to the parent:

```css
.parent > .foo.foo { position: absolute; }
```

## Navigation block class placement

The front end echoes the block `className` onto the inner `<ul>`; the editor
does not.

Fix: target `.foo .wp-block-navigation__container` instead of `ul.foo`.

## List item bullets drop to their own line

Each list item's text becomes a block-level rich-text element in the editor,
so a `li::before` bullet wraps.

```css
li > .block-editor-rich-text__editable { display: inline; }
```

## Excerpt block "more" placeholder

The editor previews an empty `.wp-block-post-excerpt__more-text` paragraph
that the front end omits. Hide it:

```css
.wp-block-post-excerpt__more-text:empty { display: none; }
```

## Editor overlays hijack `::after`

The editor draws its own `::after` on every block wrapper (selection and
disabled overlay, `inset: 0`). Anything the theme draws with `::after` on a
block element breaks when that block is selected: a section wedge anchored to
the bottom jumps to the top; a Read More chevron paints at the anchor's
top-left.

Fix: in the editor, give `::after` back to Gutenberg (`background: none;
height: auto`) and redraw on `::before`. For the chevron, `float: right` on a
`width: fit-content` anchor. If `::before` is already in use (a watermark),
move that one to a `background-image` layer on the block itself; remember
`background-position` percentages are relative to (box − image).

## Cover block inner container z-index

WordPress 7.1 applies a legacy `z-index: 1` to the inner container unless the
markup order is: image, background span, inner container. Wrong order also
shows up as clipped absolute children. Fix the markup order in the template
if it doesn't change front-end output (verify with the baseline diff); if it
does, flag it.

## Pattern title overrides root `metadata.name`

Pattern resolution replaces the root block's `metadata.name` with the pattern
file's `Title`. Name the pattern what the section should be called in List
View.

## Pattern header cache

Pattern file headers are cached in a `wp_theme_files_patterns*` transient
until the theme version changes. After editing headers:

```bash
wp transient delete --all
```

or delete the specific key with `wp transient list --search='wp_theme_files_patterns*'`.

## Legacy (non-iframed) post editor

If any registered block is `apiVersion` 2 or lower, the post editor drops the
iframe and renders in the legacy mode. Editor styles then get wrapped in
`.editor-styles-wrapper` with different specificity and layout, and none of
the measurements above hold. Find the offending block with:

```js
wp.blocks.getBlockTypes().filter( b => ( b.apiVersion ?? 1 ) < 3 ).map( b => b.name )
```

Report it; don't try to patch around it in CSS.

## Adding entries

Format: heading, what the editor does differently, the fix, and the WP
version you observed it on. Keep the (specificity) values when they matter to
the fix.
