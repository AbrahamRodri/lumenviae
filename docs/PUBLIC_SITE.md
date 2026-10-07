# The public site

Read this before you touch a public page. It says what the pages are, what
is in a prayer link, where each setting is kept, how to check your work in
a browser, and which pages nobody maintains.

The public site is only the Rosary. The console (`/admin`), the APIs
(`/api`) and `/healthz` are not part of it.

## The pages

| Path | Module | What it is |
| --- | --- | --- |
| `/` | `LumenViaeWeb.Live.Home.Index` | The daily hub. Today's mysteries, on the traditional weekly schedule or the modern one, in the visitor's own time zone. The five mysteries and their fruits, the meditation sets for today, the Rosary without a set, and a card for every category. |
| `/mysteries` | `LumenViaeWeb.Live.Mysteries.Scripture` | "Finding the Mysteries in Scripture". Every mystery, with its Douay-Rheims passages, and a note on the Traditional and Modern schedules. |
| `/mysteries/:category` | `LumenViaeWeb.Live.Mysteries.CategoryList` | One category: `joyful`, `sorrowful`, `glorious`, `luminous` or `seven_sorrows`. Its mysteries, "Your Rosary Today" choices, the two ways to pray without a set, and the shelf of meditation sets. |
| `/meditation-sets/:set_id/pray` | `LumenViaeWeb.Live.Pray.Index` | The prayer page, praying one set. |
| `/mysteries/:category/pray` | `LumenViaeWeb.Live.Pray.Index` | The same page, praying a category without a set. |
| `/privacy-policy` | `LumenViaeWeb.Live.PrivacyPolicy.Index` | The privacy policy the App Store listing links to. |

All six are in the `:public` live session in `router.ex`. A set that does
not exist, or is hidden, answers 404, and so does an unknown category.

`priv/static/sitemap.xml` lists `/`, `/mysteries`, the five category pages
and `/privacy-policy`. The prayer pages are not in it, and `robots.txt`
asks crawlers to stay out of `/meditation-sets/`. A crawler that walked the
prayer flow once pressed Complete often enough to leave Rosaries nobody had
prayed; see `docs/COMPLETION_ANALYTICS.md`.

## Archived pages

These pages left the site on 7 October 2026. Their code is in `archive/`,
which is outside `lib/` and `test/`, so it is not compiled and its tests are
not run.

| Old path | Page |
| --- | --- |
| `/dashboard` | Prayer dashboard (folded into the home page) |
| `/app` | The iPhone app |
| `/rosary-methods` | How to Pray the Rosary |
| `/true-devotion` | True Devotion to Mary |
| `/saint-carlo` | St. Carlo Acutis |
| `/feedback` | Feedback |

Each old path answers `301 Moved Permanently` and redirects to `/`, through
`LumenViaeWeb.RedirectController`. The list is the `for path <- ~w(...)`
loop in `router.ex`. The addresses are linked from outside the site, so
keep the redirects.

**Archived pages are not maintained.** Do not fix them, do not update them
when a shared component changes, and do not link to them or add them to the
sitemap. If one has to come back, follow `archive/README.md`: move it out
of `archive/`, take its path out of the redirect list, add its route to
`:public`, link it, and run the tests, because the shared components it uses
may have moved on.

## The prayer page's link

The place and the choices ride in the query string, so a reload, a shared
link and the back button all keep them. `LumenViaeWeb.Live.Pray.Params`
reads and writes them.

| Parameter | Values | Default (left out of the link) |
| --- | --- | --- |
| `mystery` | `opening`, a decade number from `0`, or `closing` | the beginning |
| `step` | the bead on that page, from `0`; used only with `count=screen` | `0` |
| `form` | on a set: `meditation` or `scriptural`. On a category: `scriptural` or `holy` | `meditation` on a set, `scriptural` on a category |
| `count` | `beads` (on your own rosary, a decade a page) or `screen` (a bead at a time) | `beads` |
| `aloud` | `true` | off |
| `voice` | a narration voice's slug | the default voice |

Rules that hold for every link:

- A default is never written, so ordinary links stay short.
- A value that is not allowed is the default. A decade number out of range
  is held to the nearest decade.
- `mobile` is accepted and ignored. Old links carry it.
- The closing prayers, the language and the text size are not in the link.
  They are the browser's (below).

Examples:

```
/meditation-sets/26/pray
/meditation-sets/26/pray?mystery=2&count=screen&step=4
/mysteries/sorrowful/pray?form=holy&count=screen
/mysteries/joyful/pray?aloud=true&voice=male
```

`LumenViaeWeb.Live.Mysteries.CategoryList.PrayLinks` builds the links on the
category and home pages, carrying "Your Rosary Today" choices.

## Where each setting lives

Nothing about a visitor is kept on the server. Every setting is the URL or
this browser's `localStorage`, and a browser that refuses storage simply
starts from the defaults. The one thing the server writes is a completion.

| Setting | Where | Written by |
| --- | --- | --- |
| Where you are, form, counting, praying aloud, voice | the link, above | `Pray.Params` |
| Traditional or modern weekly schedule | `lv:schedule` | the `MysterySchedule` hook, on the home page |
| "Your Rosary Today": aloud, count, voice | `lumenviae:rosary-choices` | the `RosaryChoices` hook, on the category page |
| The place in a Rosary, for "Continue where you left off" | `lv:pray:<key>:<form>`, for example `lv:pray:set:26:meditation` or `lv:pray:mysteries:joyful:scriptural`, holding `{mystery, step, count, at}` | the `PrayerMemory` hook |
| Closing prayers (Pope's intentions, Memorare, St. Michael) | `lv:pray:extras` | `PrayerMemory` |
| Language of the prayers, English or Latin | `lv:pray:language` | `PrayerMemory` |
| Text size | `lv:pray:text-size` | the `PrayerSurface` hook |
| Days in a row | `lv:pray:streak` | the `PrayerStreak` hook |
| Swipe hint already shown | `lv:pray:swipe-hint-seen` | the `SwipeHint` hook |

Details worth knowing:

- The beginning of a Rosary is never saved as a place, so arriving fresh
  does not wipe out the place to offer. A place older than a week is not
  offered. Completing the Rosary clears it.
- Only the prayers change language. Mysteries, Scripture and meditations
  stay in English.
- The hooks live in `assets/js/hooks/`, and each file opens with a comment
  saying what it keeps and why.

## Completions

A completion is recorded only when the reader presses Complete on a set's
prayer page. Reaching the last bead records nothing.

A Rosary prayed without a set (`/mysteries/:category/pray`) records no
completion, because a completion belongs to a meditation set. The days in a
row still count, in the browser. See `docs/UPCOMING_FEATURES.md`.

## Meta tags and images

- A public page calls `LumenViaeWeb.PageMeta.put/3` from `mount/3`. The root
  layout turns the result into the description, canonical link, link
  previews and structured data, in the first server-rendered response.
- A mystery's picture is a woodcut or engraving by Albrecht Durer or
  Gustave Dore, from `priv/static/images/woodcuts/` and its
  `manifest.json`. Show one with `LumenViaeWeb.Components.WoodcutPlate`.
  The manifest lists each plate's source and licence, and `MANIFEST.md` in
  that directory is generated from it. Leave the directory alone unless you
  are adding or replacing a plate.
- Images ship as WebP with a JPEG or PNG fallback: `name-640.webp` beside
  `name.jpg` for plates, and `-320`, `-512` and similar widths for the other
  images. An uploaded painting (of a set, an author, a mystery or a
  category card) is shown from its WebP variants by
  `LumenViaeWeb.Components.ArtworkPicture`. The widths that exist for it are
  recorded in its `image_variant_widths` column, never guessed from the
  size of the original.

## Rules for editing a public page

- Go through `LumenViae.Rosary` and pass the actor
  (`actor: socket.assigns.current_admin`). See `docs/ARCHITECTURE.md`.
- The root layout owns the page's only `<main id="main-content">`. A page
  template never renders another.
- A page that wants the whole screen, as the prayer page does, carries
  `data-layout="focused"`. The header, footer and skip link then step aside.
- Use the design tokens, never raw hex. The "Design tokens" section of
  `docs/ARCHITECTURE.md` is the list.
- No emojis anywhere.
- Keep to the accessibility baseline in `docs/audits/`: labels at least 12
  px, targets at least 44 px, a heading order with no gaps, and a live
  region for anything that changes under the reader.
- If you change a route, a redirect or a page's heading, update the e2e
  test.

## Checking a public page in a browser

The smoke test in `scripts/e2e/` drives the real site in Chrome at a phone
width (390 px) and a desktop width (1280 px). It loads `/`, `/mysteries`,
`/mysteries/joyful`, `/mysteries/seven_sorrows` and `/privacy-policy`, and
checks each one answers 200, has an `h1`, logs no console errors and does
not scroll sideways. It follows the first Pray link on `/mysteries/joyful`
and presses ArrowRight, and checks that the six archived paths redirect to
`/`. It saves a screenshot of each page in `scripts/e2e/out/`, which is
gitignored.

It is not part of CI. Run it before you hand in a change to a public page.

Use a copy of the dev database and a port of your own, never 8080:

```bash
createdb -h localhost -U postgres -T lumen_viae_dev lv_e2e
DEV_DATABASE=lv_e2e PORT=8096 ./dev.sh mix ecto.migrate
DEV_DATABASE=lv_e2e PORT=8096 ./dev.sh
```

Then, from another terminal:

```bash
BASE_URL=http://localhost:8096 scripts/e2e/run.sh
```

The exit code is 0 when every check passes, 1 when any fails, 2 when the
script itself breaks. It needs Node and `npx` (with a network the first
time), Google Chrome, and a seeded database with at least one visible
Joyful set. When you are done, stop the server and drop the copy:

```bash
dropdb -h localhost -U postgres lv_e2e
```

`scripts/e2e/README.md` has the rest. The unit tests are separate:
`MIX_TEST_PARTITION=<name> mix test`, with a partition of your own in a
worktree.

## See also

- `docs/ARCHITECTURE.md`: where code goes, the prayer page's modules, the
  design tokens.
- `docs/SPOKEN_ROSARY.md`: the Rosary's words and the recorded clips the
  prayer page speaks.
- `docs/COMPLETION_ANALYTICS.md`: what a completion records.
- `docs/audits/`: the accessibility baseline and re-audit.
- `archive/README.md`: the retired pages.
