# Accessibility and mobile baseline, October 2026

Audit of the public Rosary site as it stands on `website/rosary-focus`
(commit 72bda90). Findings only: no code was changed.

## Scope and method

- Pages: `/`, `/mysteries`, `/mysteries/joyful`, `/mysteries/seven_sorrows`,
  `/meditation-sets/26/pray`, `/privacy-policy`.
- Widths: 360, 390 and 1280 CSS px (Chrome, Playwright). The two phone widths
  were run with touch enabled. Every page was also loaded at 320 px as a
  reflow check.
- Automated: axe-core 4.10.0 with the `wcag2a`, `wcag2aa`, `wcag21a`,
  `wcag21aa`, `wcag22aa` and `best-practice` rule sets, on every page at every
  width.
- Scripted checks: horizontal overflow, landmarks, heading outline, controls
  without a name, images without `alt`, tap target size (44 px convention; 24
  px is the WCAG 2.2 AA floor), text under 12 px, and `prefers-reduced-motion:
  reduce` emulation.
- Keyboard-only walk: Tab through each page, recording order, focus indicator
  (outline or box-shadow), off-screen focus and focus hidden behind another
  element. Plus hand checks of the Mysteries dropdown, the mobile menu, the
  category tablist and the prayer page controls.
- Data: dev server on port 8095 against a scratch copy of the dev database.

What this does not cover: a screen reader pass, a real phone, 400% browser
zoom (320 px width stands in for it), the narrated audio itself, and axe's
"incomplete" results (for example text over images). Automated tools find
roughly a third of real problems, so treat a clean row as "no evidence", not
"passes".

The dev-only Tidewave toolbar (`#tidewave-toolbar`) adds a "not in a landmark"
violation and two focus stops on every page. It is excluded from everything
below; it does not exist in production.

### Severity

- **Critical**: a task cannot be done, or an action fires that the user did not
  choose.
- **Serious**: a WCAG A or AA failure that blocks or badly degrades use.
- **Moderate**: a WCAG failure with a workaround, or a clear best-practice gap.
- **Minor**: a convention or AAA item, low impact.

## What already works

- `lang="en"`, a distinct `<title>` per page, and a viewport meta that allows
  zoom.
- One `<h1>` per page and no image without `alt`; every button and link has an
  accessible name.
- A focus indicator on every real tab stop.
- Tab order follows the visual order on every page.
- The category tablist is a correct ARIA tabs widget: roving `tabindex`,
  arrow keys move and select, `aria-controls` points at the panel.
- No horizontal scroll at 360, 390 or 1280, and none at 320 except on `/`.
- Mobile menu links are 44 px tall.

## Shared findings (every page)

These come from the site shell and apply to all six pages unless a page table
says otherwise.

| ID | Issue | WCAG | Severity | Selector or file |
|----|-------|------|----------|------------------|
| S1 | No skip link. A keyboard user passes the logo and the menu (3 stops at 1280, 2 at 360/390) before content; the prayer page is worse (logo, menu, exit, mode toggle, then 5 dots). | 2.4.1 Bypass Blocks (A) | Serious | `lib/lumen_viae_web/components/nav.ex`, `lib/lumen_viae_web/components/layouts/root.html.heex` |
| S2 | No `<main>` landmark on five of six pages. Only `/` has one (`home/index.html.heex:1`). axe reports `landmark-one-main` and `region` on all five, and with no skip link there is then no bypass mechanism at all. | 1.3.1, 2.4.1 | Serious | `html`; live templates under `lib/lumen_viae_web/live/` (mysteries, pray, privacy_policy) |
| S3 | Footer links are 19 px tall at 11.2 px type. They pass the 24 px AA spacing exception but are well under the 44 px convention, and eight of them sit in one row. | 2.5.8 (AA, passes via spacing), 2.5.5 (AAA) | Moderate | `footer nav a.font-cinzel.text-[0.7rem]`, `lib/lumen_viae_web/components/footer.ex:60` |
| S4 | Mobile menu button is 40x40. | 2.5.5 (AAA) | Minor | `button#mobile-menu-button`, `nav.ex:108` |
| S5 | Desktop nav targets are 22 px tall (`Today's Rosary` 139x22, `The Mysteries` 144x22). | 2.5.8 (AA, passes via spacing) | Minor | `button#mysteries-menu-button`, `nav.ex:40` and the link beside it |
| S6 | Neither the Mysteries dropdown nor the mobile menu closes on Escape (`aria-expanded` stays `true`). The dropdown button has no `aria-haspopup`. Open state is otherwise correct and reachable by Enter. | ARIA Authoring Practices (no WCAG SC); related 4.1.2 | Moderate | `#mysteries-menu`, `#mobile-menu`, `nav.ex:73`, `nav.ex:108` |
| S7 | Two `<nav>` landmarks; the header one has no `aria-label` (the footer one is "Footer navigation"), so a screen reader lists two near-identical "navigation" regions. | 1.3.1 (best practice) | Minor | `header nav`, `nav.ex` |
| S8 | `prefers-reduced-motion` is not honoured anywhere (no media query in `assets/css` or `lib`). With `reduce` on, the `rise` entrance (0.9 s and 1.4 s) still plays and the `halo` pulse still loops forever (6 s, infinite). Affects `/` (7 animating elements), `/mysteries` (4), `/mysteries/joyful` (5), `/mysteries/seven_sorrows` (5). The prayer page and privacy page have none. | 2.3.3 (AAA), 2.2.2 (A) for the looping halo | Moderate | `assets/css/app.css:135-160`, `home/index.html.heex:26` (`.animate-halo`), `.animate-rise` users |

## `/`

| Issue | WCAG | Severity | Selector or file | Widths |
|-------|------|----------|------------------|--------|
| Step numerals "01", "02", "03" are 36 px gold at 60% opacity on white: contrast 1.9:1 (large text needs 3:1). | 1.4.3 (AA) | Serious | `span.text-gold\/60`, `home/index.html.heex:253,263,273` | all |
| Badge text navy on `bg-gold/90` at 10.4 px: contrast 4.29:1 (needs 4.5:1 at that size). | 1.4.3 (AA) | Serious | `.bg-gold\/90`, `home/index.html.heex:192` | all |
| Page scrolls sideways at 320 px (scroll width 345 vs 320) and at 390 px with root text at 200% (690 vs 390). Culprits include the weekday strip (`Sat`, `Sun` labels at `tracking-[0.2em]`) and the halo (`.bg-halo.-inset-10`). Real 400% zoom was not run; 320 px is the stand-in. | 1.4.10 Reflow (AA), 1.4.4 | Serious | `div.flex.flex-col.items-center` in the bead week strip, `home/index.html.heex:75-90`; `div.bg-halo.absolute.-inset-10` | 320 (also 200% text) |
| Giant decorative numerals (144 px, navy at 5%) are real text at contrast 1.09:1 and are read aloud. If decorative they should be hidden from assistive tech; as text they fail. | 1.4.3, 1.3.1 | Moderate | `.-top-6.right-2.text-\[9rem\]`, `home/index.html.heex:185` | all |
| Heading outline jumps: H1, then H3 x3, then H2. | 1.3.1 (best practice) | Minor | `h3` at `home/index.html.heex:201,255,265` | all |
| Text under 12 px: 10.4 px labels (`text-[0.65rem]`) and 11.2 px link text. | 1.4.4 (readability) | Minor | `span.font-cinzel.text-[0.65rem]`, `home/index.html.heex` | all |
| Shared: S1, S3, S4, S5, S6, S7, S8 apply. S2 does not (the page has a `<main>`). | | | | |

## `/mysteries`

| Issue | WCAG | Severity | Selector or file | Widths |
|-------|------|----------|------------------|--------|
| The five mysteries in the open panel are not headings. The only heading on the page is the H1, so heading navigation finds nothing inside the tab panel. | 1.3.1 (A) | Moderate | `#category-panel`, `lib/lumen_viae_web/live/mysteries/_partials/*.html.heex` | all |
| Category tabs at phone width wrap to a second row and the last two are 35 px tall (`Luminous` 101x35, `Seven Sorrows` 140x35). | 2.5.5 (AAA), passes 2.5.8 | Minor | `button#category-tab-luminous`, `button#category-tab-seven_sorrows`, `scripture.html.heex:35-50` | 360, 390 |
| "Read the Scripture (...)" disclosure rows are 16 px tall (one wraps to 32). Full width, so easy to hit sideways, but a thin vertical target in a dense list. The "Traditional vs Modern" summary is 28 px. | 2.5.5 (AAA) | Minor | `details > summary.font-cinzel.text-xs`, `lib/lumen_viae_web/live/mysteries/_partials/*.html.heex` (for example `glorious.html.heex:45`) | all |
| Shared: S1 to S8 apply. | | | | |

## `/mysteries/joyful`

| Issue | WCAG | Severity | Selector or file | Widths |
|-------|------|----------|------------------|--------|
| Heading outline: H1 then six H3 author cards, no H2. | 1.3.1 (best practice) | Minor | `a.group.relative h3`, `category_list/category_list.html.heex:153` | all |
| "Return to All Mysteries" link is 19 px tall. | 2.5.5 (AAA) | Minor | `div.mt-14.text-center > a.inline-flex`, `category_list.html.heex:197` | all |
| Text under 12 px: 10.4 px author-card tags, 11.2 px "read" links. | 1.4.4 (readability) | Minor | `span.inline-flex.items-center`, `category_list.html.heex:159` | all |
| Shared: S1 to S8 apply. | | | | |

## `/mysteries/seven_sorrows`

| Issue | WCAG | Severity | Selector or file | Widths |
|-------|------|----------|------------------|--------|
| Badge text navy on `bg-gold/90` at 10.4 px: contrast 4.29:1, on both cards in the first row (`Scripture + Short Meditation`, `Meditation + Prayer`). | 1.4.3 (AA) | Serious | `a.group.relative > .mb-4 > .bg-gold\/90`, `category_list.html.heex:158-159` | all |
| Heading outline: H1 then H3 cards, no H2. | 1.3.1 (best practice) | Minor | `a.group.relative h3`, `category_list.html.heex:116,153` | all |
| "Return to All Mysteries" link is 19 px tall. | 2.5.5 (AAA) | Minor | `div.mt-14.text-center > a.inline-flex`, `category_list.html.heex:197` | all |
| Text under 12 px: 10.4 px tags, 11.2 px "read" links on all four cards. | 1.4.4 (readability) | Minor | `span.inline-flex.items-center` | all |
| Shared: S1 to S8 apply. | | | | |

## `/meditation-sets/26/pray`

| Issue | WCAG | Severity | Selector or file | Widths |
|-------|------|----------|------------------|--------|
| In mobile mode the "Previous" and "Next" tap zones are `fixed`, each 50% wide and 50% tall, over the bottom half of the screen. They sit on top of the content: hit-testing the centre of the Play audio button at 390 px returns "Next mystery", so tapping Play can advance the mystery instead. The page is 1427 px tall with no bottom padding, so content can never be scrolled clear of the zones. The 50% navy gradient also dims any text under it. Keyboard: Play audio is reported as obscured when focused. | 2.4.11 Focus Not Obscured (AA), 1.4.3 for the dimmed text; no exact SC for pointer interception | Critical | `button[aria-label="Next mystery"]`, `button[aria-label="Previous mystery"]`, `button[aria-label="Complete rosary"]`, `lib/lumen_viae_web/live/pray/index.html.heex:366-430` | 360, 390 |
| Progress dots are 10x10 (the active one 14x14), 12 px apart. axe `target-size` fails four of them. | 2.5.8 Target Size Minimum (AA) | Serious | `button[phx-value-index]`, `pray/index.html.heex:90-110` | all |
| Changing mystery announces nothing: no `aria-live` or `role="status"` region on the page, so a screen reader user pressing Next hears no change. | 4.1.3 Status Messages (AA) | Moderate | mystery body, `pray/index.html.heex` | all |
| "Toggle mobile mode" has a fixed name and no `aria-pressed`; the current state lives only in `title` ("Switch to full view"). The control is 28x28. | 4.1.2 Name, Role, Value (A) | Moderate | `button[aria-label="Toggle mobile mode"]`, `pray/index.html.heex:50-57` | 360, 390 |
| Text under 12 px: the "Pray aloud" label (10.4 px), a 10.4 px caption and, at 1280, a 9.6 px label. | 1.4.4 (readability) | Minor | `p.font-cinzel.tracking-[0.25em]`, `span.hidden.md:block`, `pray/index.html.heex` | all |
| Small controls: Exit prayer 28x28, "Pray aloud" 133x28, voice select 168x26. | 2.5.5 (AAA), pass 2.5.8 | Minor | `a[aria-label^="Exit prayer"]`, `select#narration-voice`, `pray/index.html.heex:30-40,145` | all |
| Shared: S1 to S7 apply. S8 does not (the page has no animation). | | | | |

## `/privacy-policy`

| Issue | WCAG | Severity | Selector or file | Widths |
|-------|------|----------|------------------|--------|
| No page-specific failures found. Heading outline is clean (H1, nine H2), the one link has a visible underline and a focus ring, and nothing overflows at 320. | | | | |
| Shared: S1 to S7 apply. S8 does not (the page has no animation). | | | | |

## Top ten, in the order to fix

1. Pray page tap zones sit over the content and intercept taps on Play audio.
   (Critical)
2. No `<main>` landmark on five pages, and no skip link anywhere: S1 and S2.
   (Serious; one change in the layout fixes most of it)
3. Home: "01 02 03" numerals at 1.9:1 contrast. (Serious)
4. Badge text at 4.29:1 on `/` and on both Seven Sorrows cards. (Serious; one
   class)
5. Home overflows sideways at 320 px and at 200% text. (Serious)
6. Pray page progress dots are 10 px targets. (Serious)
7. Pray page announces nothing when the mystery changes. (Moderate)
8. `prefers-reduced-motion` is ignored; the halo loops forever. (Moderate)
9. Menus do not close on Escape. (Moderate)
10. Mystery names inside the `/mysteries` panel are not headings. (Moderate)

## Re-running this audit

The checks are scripted, so the numbers above can be reproduced after the four
shell, home, category and prayer branches land. Re-run the same pages and
widths, and compare the shared table (S1 to S8) first: most per-page rows
disappear when those are fixed.
