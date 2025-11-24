# Web Design Audit

The following audit reviews typography, layout, color, code quality, responsiveness, and conversion for the Lumen Viae web experience.

## typography_01 — Font Choices & Consistency
- **Fonts found**: Roman Uncial Modern (custom @font-face), Ovo, Work Sans, EB Garamond, plus legacy Phoenix sample colors/fonts on `page_html/home.html.heex`.
- **Usage**: Body copy set globally to Work Sans 17px/1.8; headings mix Roman Uncial (h1) and Ovo (h2–h6); components use font utility classes (e.g., Ovo for headings, Garamond for taglines). Navigation uses cinzel-decorative aliasing Roman Uncial.
- **Issues**: Multiple serif families (Ovo, EB Garamond, Roman Uncial) appear in the same sections, risking inconsistency; hero lacks clear CTA despite decorative heading.
- **Recommendations**: Consolidate to one body font (Work Sans) and one primary heading font (Ovo) with Roman Uncial reserved for small ornamental accents (e.g., logo or dividers). Remove legacy Phoenix sample assets and colors from unused scaffolding to avoid leaking extra palettes.

## typography_02 — Type Scale & Readability
| Element | Current sizes (examples) | Current line-height | Proposed scale (base 17px, 1.2 ratio) | Proposed line-height |
| --- | --- | --- | --- | --- |
| Body | 17px (`body`, `.text-meditation`, text-lg ≈ 18px) | 1.8 | 17px (1.0625rem) | 1.6 |
| H1 | text-5xl→48px / md:text-6xl→60px (home hero) | ~1.1–1.2 via Tailwind | 48px | 1.25 |
| H2 | text-4xl→36px (section headers) | ~1.2 | 36px | 1.3 |
| H3 | text-3xl→30px or text-2xl→24px | ~1.25 | 30px | 1.35 |
| H4 | text-2xl→24px | ~1.3 | 24px | 1.4 |
| Meta/eyebrow | text-xs→12px with tracking | 1.2 | 13–14px | 1.4 |
- **Observations**: Sizes jump from 60px hero to 30–24px subheads and 17–18px body without a consistent ratio. Body line-height 1.8 is generous but slightly tall for dense cards.
- **Recommendations**: Normalize headings to a modular scale (17 → 20 → 24 → 30 → 36 → 48) and set body/paragraph line-height to 1.5–1.6. Apply consistent letter-spacing: tighter for body (normal) and small uppercase labels, minimal for display headings.

## typography_03 — Responsive Typography
- **Fixed px usage**: Body and `.text-meditation` set to 17px; `.container-boxed` uses 30px side padding; media query at 1080px fixes content width to 71%. Hero headings rely on large fixed sizes (text-5xl/text-6xl) without fluid scaling.
- **Refactors**: Convert base font to `1.0625rem` (17px) and use rem units for custom utilities. Replace fixed media breakpoint with `clamp()`-based widths. Example:
```css
body { font-size: 1.0625rem; line-height: 1.6; }
.container-boxed { padding-inline: clamp(1rem, 3vw, 2rem); }
.home-hero h1 { font-size: clamp(2.5rem, 4vw + 1rem, 3.75rem); line-height: 1.25; }
```

## layout_01 — Grid & Structure
- **Current**: Pages mix full-width blocks, `max-w-*` wrappers, and ad-hoc grids (e.g., 2-column intro, 3-column mystery cards). Mobile menu toggles via JS with stacked links. The upcoming Seven Sorrows section is a single column with long text blocks.
- **Issues**: No consistent grid tokens (e.g., 12-column) across home, dashboard, and scripture pages; some sections rely on padding and `max-w` rather than shared layout container; CTA blocks and hero lack structured subgrid for image/headline/CTA alignment.
- **Recommendations**: Define a simple 12-column CSS Grid container with `gap` tokens. Example:
```css
.layout-grid { display: grid; grid-template-columns: repeat(12, minmax(0, 1fr)); gap: var(--space-5); }
.hero { grid-column: 2 / span 10; display: grid; grid-template-columns: repeat(12, 1fr); }
.hero__media { grid-column: 2 / span 4; }
.hero__content { grid-column: 6 / span 6; }
```
Apply to hero, intro (image/content split), and card sections for consistent alignment.

## layout_02 — Spacing System
- **Values observed**: `py-20` (80px), `px-8` (32px), `py-16` (64px), `gap-12` (48px), `p-8` (32px), `p-6` (24px), `px-6` (24px), `px-4`/`py-6` (16px/24px), `mb-6/8/12` (24/32/48px), `border-b-3` (3px), `.container-boxed` padding 30px.
- **Assessment**: Spacing values approximate an 8px-derived scale but include outliers (30px padding, 3px borders). Utilities are duplicated per section instead of tokenized.
- **Proposed scale**: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80px. Map current values: 30px→32px, 3px border→2px or 4px depending on emphasis.
- **Refactor**: Introduce CSS variables/utilities (e.g., `--space-2: 8px`, `--space-5: 20px`, `--space-8: 32px`) and replace inline padding/margin with semantic classes like `.section-padding`, `.card-gap`, `.eyebrow-spacing`.

## layout_03 — Visual Hierarchy & Grouping
- **Home**: Hero lacks CTA; intro bullets blend with paragraphs; “The Fifteen Mysteries” cards use similar weights for schedule and body copy, reducing hierarchy.
- **Dashboard**: Mystery cards compress headings and metadata with small size contrast; CTA to methods sits at bottom with same weight as secondary links.
- **Scripture page**: Long accordion intro uses similar sizes/weights for subheads and body, making scan-ability harder; category pills have strong contrast but content blocks use dense paragraphs.
- **Recommendations**: Add primary CTA button and subheadline in hero; emphasize headings with bolder weight and spacing before sections; use distinct weights for metadata vs body; group bullets with consistent spacing and background panels for readability.

## color_01 — Palette Extraction & Cleanup
- **Current colors**: Navy `#003b5c`, navy-dark `#002840`, navy-light `#004d75`; Gold `#b18b49`, gold-light `#c9a96b`, gold-dark `#8f6e38`; Cream `#faf2e6`, cream-dark `#f0e5d0`, white `#ffffff`; Body text `#42403e`; Legacy Phoenix sample colors (#EE7868, #FF9F92, #FA8372, #E96856, #C42652, #A41C42, #FD4F00).
- **Issues**: Legacy bright reds/oranges clash with the traditional palette; multiple gold shades used interchangeably; lack of defined neutral grays.
- **Proposed core palette**: Base background `#faf2e6`, surface `#ffffff`, primary text `#1f1b18` (darker neutral), primary accent navy `#003b5c`, secondary accent gold `#b18b49`, subtle accent gold-light `#c9a96b` for borders only.
- **Mapping**: Replace legacy reds with navy/gold gradients or photography; map all gold usages to primary gold; reserve gold-light for borders/hover; use cream for sections and white for cards.

## color_02 — Color Roles & Consistency
- **Current usage**: Navy backgrounds with gold text/buttons; cream backgrounds with brown/gold text; cards white with gold/brown text; CTA buttons navy with gold text; accent dividers use black variant.
- **Inconsistencies**: Multiple gold shades across text, borders, and icons; brown text color undefined in palette; CTA styles vary between pages (nav links vs inline buttons).
- **Role system**:
  - `--color-bg-primary: #faf2e6`
  - `--color-bg-surface: #ffffff`
  - `--color-text: #1f1b18`
  - `--color-text-muted: #5a5148`
  - `--color-accent-primary: #003b5c`
  - `--color-accent-secondary: #b18b49`
  - `--color-border: #c9a96b`
  - `--color-link: #003b5c`
  - `--color-cta-bg: #003b5c`, `--color-cta-text: #faf2e6`
- **Refactor**: Declare roles in `:root` and replace `text-gold`/`text-brown`/mixed borders with variables. Ensure buttons and links reference role tokens for hover/active states.

## color_03 — Contrast & Accessibility
- **Pairs**:
  - Gold text `#b18b49` on cream `#faf2e6` (hero/meta labels) likely ~3:1 — below 4.5:1 for body text; darken gold or switch to navy for small text.
  - Gold-light `#c9a96b` on cream/white (cards, dividers) likely <3:1 — reserve for borders only.
  - Navy text on cream (`#003b5c` on `#faf2e6`) ≈7:1 — passes.
  - Gold text on navy (`#b18b49` on `#003b5c`) ≈2.8:1 — insufficient for body; use lighter cream text or darken navy for small text.
- **Fixes**: Use navy or dark neutral for small body copy; keep gold for large headings or icons; introduce `--color-text-contrast` variant (e.g., `#f5f0e8`) for text on navy backgrounds; add focus styles with clear outlines.

## code_01 — Semantic HTML Structure
- **Findings**: Pages rely on `<div>` containers without `<main>`/`<section>` landmarks; hero headings are `<h2>` while page title should be `<h1>`; feature lists use spans instead of list semantics; CTA buttons rendered as links without clear aria labels.
- **Refactors**: Wrap page content in `<main>`; use `<section aria-labelledby="...">` for hero, intro, mysteries, and methods; promote hero heading to `<h1>` with `<p>` subheadline and `<a role="button">` or `<button>` for primary CTA; convert bullet clusters to `<ul>`/`<li>` for screen readers.

## code_02 — CSS Organization & Reusability
- **Issues**: Custom fonts and colors defined in CSS but spacing/typography utilities live inline via Tailwind classes; repeated padding/margin/typography combinations across sections; legacy Phoenix CSS persists.
- **Recommendations**: Create component-level classes (`.section`, `.card`, `.eyebrow`, `.cta-primary`) using CSS variables for spacing, radius, and typography; remove unused Phoenix sample styles; centralize font stacks and letter-spacing into utilities instead of per-element classes.

## code_03 — Responsive Behavior & Units
- **Findings**: Fixed pixel values in base CSS (17px text, 30px padding) and 1080px breakpoint for 71% width; hero images use fixed widths with single breakpoint; cards rely on grid/flex but lack tablet-specific adjustments.
- **Recommendations**: Adopt breakpoints at 640px, 960px, 1280px. Use fluid typography via `clamp()`, responsive padding via `clamp()`, and percent-based columns (`grid-template-columns: repeat(auto-fit, minmax(18rem, 1fr))`). Ensure nav/menu uses semantic `<nav>` with focus-visible styles.

## conversion_01 — Page Goals & Primary CTA
- **Home**: Goal should be “start praying a mystery set.” Hero currently lacks CTA; recommended set card appears below the fold. Add primary CTA “Pray Today’s Mystery” near hero with supporting subheadline.
- **Dashboard**: Goal appears to be resuming/starting a set; recommended set CTA is clear; consider adding secondary CTA for “Continue where you left off.”
- **Scripture page**: Informational; primary goal is category selection. Ensure hero includes “Browse by category” CTA aligned with tabs.

## conversion_02 — CTA Placement & Clarity
- **Home**: Only visible CTA is near methods section; mystery cards are navigable but not framed as CTAs. Add hero CTA and mid-page reminder after introductory paragraphs; cap primary CTAs to hero, recommended set card, and methods button.
- **Dashboard**: One primary CTA (recommended set), multiple secondary links; acceptable but ensure consistent button styling.
- **Scripture**: Category buttons act as CTAs; no mid-page prompt to start reading/praying—add anchor/button to scroll to selected category content.

## conversion_03 — Trust & Proof Elements
- **Home**: Rich narrative but lacks testimonials, origin story, or clergy endorsements; add a short “About Lumen Viae” block with mission and author credibility plus a testimonial carousel beneath the mystery grid.
- **Dashboard**: Utility-focused; consider a small “Daily intention” tip or reassurance about saved progress near the header.
- **Scripture**: Add brief explanation of sources and translation for Scripture references, plus a note on ecclesiastical approvals if applicable.
