<!-- Part of the figma-to-wordpress skill. Applies the never-guess method to Divi 4 + drop-in shortcode templates. -->

# Builder note: Divi

How the method maps to Divi: pull exact values per Figma node, then emit `[et_pb_*]` **shortcodes** carrying those literal values. Divi stores a page as shortcodes in `post_content`, so you can build in the Visual Builder OR inject shortcodes via SQL. Verify by measuring the rendered DOM against Figma geometry.

## Where Divi stores things
- **Page layout** = `[et_pb_*]` shortcodes in `wp_posts.post_content`. Safe to generate and inject.
- **Theme Options Custom CSS** lives in a dedicated `wp_posts` row (its ID varies per install - find it, don't hardcode). Page-scoped responsive CSS is stored as `body.page-id-N ...` (see gotcha #56 in `references/gotchas-general.md` - `!important` does NOT beat that higher specificity).
- **Caches:** after DB edits, clear Divi's static CSS cache (Divi → Theme Options → Builder → Advanced → Static CSS, or delete `wp-content/et-cache/`) or your change stays invisible.
- **Inline `<script>` survives** `wpautop` inside `[et_pb_code]` (keep it one line, wrap in an IIFE) - unlocks JS UI without a plugin. Inline `<style>` does NOT survive; put CSS in Theme Options.

## Field notes
- **Use relative asset URLs** (`/wp-content/...`), never `http://sitename.local` - LocalWP's random port may not resolve.
- **Custom button icons:** layer a `background-image` via `custom_css_main_element` and hide Divi's default arrow with `custom_css_after="display:none !important;"`. Never collapse into a `background:` shorthand - it nukes the icon (gotcha #20).
- **Map module needs no API key** if you use a plain Google Maps `<iframe>` inside `[et_pb_code]` instead of Divi's Map module.
- **Find a nav menu's `menu_id`** (its term_id) before placing `[et_pb_menu]`.

## Drop-in shortcode templates

**Section + row + 3-column:**
```
[et_pb_section fb_built="1" admin_label="Header" _builder_version="4.3.3" background_color="#0c2d4c" custom_padding="15px||15px||true|false"]
  [et_pb_row column_structure="1_5,2_5,2_5" use_custom_gutter="on" gutter_width="1" _builder_version="4.3.3" width="90%" max_width="1440px" custom_css_main_element="display: flex !important;||align-items: center !important;"]
    [et_pb_column type="1_5" _builder_version="4.3.3"] <!-- modules --> [/et_pb_column]
    [et_pb_column type="2_5" _builder_version="4.3.3"] <!-- modules --> [/et_pb_column]
    [et_pb_column type="2_5" _builder_version="4.3.3" custom_css_main_element="display: flex !important;||justify-content: flex-end !important;||align-items: center !important;||gap: 20px !important;"] <!-- modules --> [/et_pb_column]
  [/et_pb_row]
[/et_pb_section]
```
Structures: `1_2,1_2`, `1_3,2_3`, `2_3,1_3`, `3_5,2_5`, `2_5,3_5`, `1_5,2_5,2_5`, `1_3,1_3,1_3`, `1_4,1_4,1_4,1_4`, etc.

**Text module** (`text_font` = `family|weight|italic|uppercase|underline|strike|tt|letter_spacing|line_style`):
```
[et_pb_text _builder_version="4.3.3" text_text_color="#307BFF" text_font="|700||on|||0.6px|" text_font_size="15.45px" text_line_height="18px" custom_margin="0|0|18px|0|false|false"]
CONTACT US
[/et_pb_text]
```

**Image** (relative URL):
```
[et_pb_image src="/wp-content/uploads/figma-assets/logo.png" align="left" _builder_version="4.3.3" max_width="89px" custom_margin="0||0||true|false" /]
```

**Button with custom icon:**
```
[et_pb_button button_text="+370 600 00000" button_url="tel:+37060000000" button_alignment="right" custom_button="on" button_bg_color="#307bff" button_text_color="#ffffff" button_border_width="0" button_border_radius="44" button_font="|700|||||||" button_font_size="14px" _builder_version="4.3.3" custom_padding="11px|24px|11px|48px|false|false" custom_css_main_element="background-image: url('/wp-content/uploads/figma-assets/phone-icon.svg') !important;||background-color: #307bff !important;||background-repeat: no-repeat !important;||background-position: 22px center !important;||background-size: 16px 16px !important;" custom_css_after="display: none !important;"][/et_pb_button]
```

**Menu** (`menu_id` = the nav menu's term_id):
```
[et_pb_menu menu_id="2" active_link_color="#307bff" background_color="rgba(0,0,0,0)" _builder_version="4.3.3" menu_font="|600||on|||0.35px|" menu_text_color="#ffffff" menu_font_size="14px" show_search_icon="on" /]
```
```sql
SELECT t.term_id, t.name FROM wp_terms t
INNER JOIN wp_term_taxonomy tt ON t.term_id = tt.term_id
WHERE tt.taxonomy = 'nav_menu';
```

**Contact form:**
```
[et_pb_contact_form email="info@example.com" title="" button_text="Send message" _builder_version="4.3.3" form_field_background_color="#ffffff" form_field_text_color="#7E8697" form_field_font_size="18px" border_radii_fields="on|8px|8px|8px|8px" border_width_all_fields="1px" border_color_all_fields="#ffffff"]
  [et_pb_contact_field field_id="Name" field_title="Name" _builder_version="4.3.3" /]
  [et_pb_contact_field field_id="Email" field_title="Email" field_type="email" _builder_version="4.3.3" /]
  [et_pb_contact_field field_id="Subject" field_title="Subject" _builder_version="4.3.3" /]
  [et_pb_contact_field field_id="Message" field_title="Message" field_type="text" fullwidth_field="on" _builder_version="4.3.3" /]
[/et_pb_contact_form]
```

**Map (iframe in a Code module, no API key):**
```
[et_pb_code _builder_version="4.3.3" custom_css_main_element="max-width: 1242px !important;||margin: 0 auto !important;||border-radius: 16px !important;||overflow: hidden !important;||display: block !important;"]
<iframe src="https://www.google.com/maps/embed?pb=YOUR_LONG_PB_URL" width="100%" height="358" style="border:0; border-radius:16px; display:block;" allowfullscreen loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe>
[/et_pb_code]
```

## Verification (always)
```bash
node scripts/overflow-sweep.js http://localhost:PORT/your-page/ 390,430,768,1440,1920
node scripts/dom-measure.js http://localhost:PORT/your-page/ 1440 ".et_pb_text" "h1"
```
Measured box + computed styles vs the Figma node values = your bug list. Verify on the real front end.
