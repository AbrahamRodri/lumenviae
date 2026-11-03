# Browser smoke test

An end-to-end check of the Rosary-only website, driven by Playwright in the
installed Chrome. It adds no mix or npm dependency: `run.sh` fetches
Playwright through `npx`.

At 320x568 (narrow), 390x844 (mobile) and 1280x800 (desktop) it:

- loads `/`, `/mysteries`, `/mysteries/joyful`, `/mysteries/seven_sorrows`,
  `/privacy-policy`, `/app`, `/prayers` (and a search), a topic of the
  Prayer Book, two prayers (one in Both), an order of prayer and a step
  of praying it in Both, `/chant` (and a search), a section's shelf,
  a chant's page, Sets of Chants and a sung set, `/true-devotion` and a
  chapter, `/hours`, today's
  Vespers in Both, this month's Hours calendar, `/missal`, a day's
  Mass in Both, the Order of Mass and this month's Missal calendar,
  `/explore` and a search there, and checks each
  answers 200 with an h1 and no console errors;
- checks no page scrolls sideways (`scrollWidth <= innerWidth`);
- follows the first Pray link on `/mysteries/joyful` to
  `/meditation-sets/:id/pray` and presses ArrowRight;
- on `/app`, checks every App Store link goes to the listing and every
  screenshot loads;
- checks `/dashboard`, `/rosary-methods`, `/saint-carlo` and `/feedback`
  redirect to `/`;
- on `/true-devotion` (which answers 200 now, no longer a redirect),
  presses Begin reading (the Introduction opens) and Next chapter, chooses
  a paragraph by its number and bookmarks it, then checks the title page
  offers Continue reading at that chapter, and that an unknown chapter
  answers 404;
- on the category page, chooses the whole Rosary aloud (Counting
  disappears and the Pray links gain `aloud=true`), then counting on the
  screen (the Pray links gain `count=screen`), and checks both survive a
  reload;
- on a prayer page counting on the screen, advances with Space, ArrowDown
  and the Next bead button (the live region text changes), opens and closes
  the settings pane with Enter, closes it with Escape, and checks the text
  size survives a reload;
- on `/mysteries/sorrowful/pray?form=scriptural&count=screen`, checks a
  verse shows before the first counted Hail Mary;
- loads the set-less holy form, and checks an unknown category and an
  unknown set answer 404;
- on `/prayers`, types "memorare" in the search (the link gains
  `?q=memorare` and the Memorare is found), opens it, chooses Both (the link
  gains `lang=both`); on `/prayers/orders/morning` presses Pray (the
  first prayer opens) and Next (the link gains `step=2`); and checks an
  unknown prayer, topic and order answer 404;
- on `/chant`, types "salve regina" in the search (the link gains `q=`
  and the Salve Regina is found); on `/chant/sections/mass` checks Play
  all and the rows; on `/chant/salve_regina_simple` checks the recording's
  address on the site's bucket and the lines, presses play and waits for
  a line after the first to light (this fetches the recording, so it needs
  a network), chooses English (the link gains `words=english`); on `/chant/sets`
  checks the six sets; on `/chant/sets/benediction` checks the notes in
  red, presses Play all and waits for the first chant to sound and its row
  to light; and checks an unknown chant, section and set answer 404;
- on `/explore`, checks the five devotions and the header's Explore
  link, types "Salve" (the link gains `q=` and both the Salve Regina's
  prayer and chant are found), checks "ave maria" and "PÂTER" each find
  the prayer and the chant (accents and case aside), and that
  "annunciation" finds the mystery, whose card opens `/mysteries/joyful`;
- on `/hours`, follows Pray to the hour now, chooses Both (the link gains
  `lang=both`) and waits for the hour's text or its "could not be reached"
  state: the Divinum Officium engine may not answer a dev machine, so
  either passes and the log says which it was (and what the day's feast
  was); an unknown hour, a bad date and month 13 answer 404;
- on `/missal`, waits for today's Mass or its "could not be reached from
  Missale Meum" state (the server fetches it, and Missale Meum may not
  answer a dev machine, so either passes and the log says which, and the
  feast), chooses Both (the link gains `lang=both`), steps to the next day
  (`/missal/<date>?lang=both`), opens the Order of Mass from the day's
  foot when the text came (or by its address), and the month from the
  date pill; a bad date and month 13 answer 404;
- on `/`, checks Today's Prayer shows its four rows once the browser has
  spoken (the Consecration inviting a plan, the hour's order of prayer,
  Today's Mass, the Hours of Prayer's hour now), follows each row's link to its page, then
  keeps a plan begun four days ago in localStorage and checks the
  Consecration's row opens Day 5, marked prayed;
- jumps to `mystery=closing`, presses Complete and checks the completion
  screen shows (once, at the mobile width);
- saves a full-page screenshot of the main pages to `scripts/e2e/out/`
  (gitignored).

Every flow runs in a fresh browser context, so saved choices never leak from
one to the next. The completion press writes a row to the server's database
unless the visit looks like a crawler, and headless Chrome does, so run the
test against a copy.

Selectors are roles and text, not CSS classes, so the pages can be
redesigned without touching the script.

## Run it

Use a copy of the dev database and a port of your own, never 8080:

```bash
createdb -h localhost -U postgres -T lumen_viae_dev lv_e2e
DEV_DATABASE=lv_e2e PORT=8096 ./dev.sh mix ecto.migrate   # only if the copy is behind
DEV_DATABASE=lv_e2e PORT=8096 ./dev.sh
```

Then, from another terminal:

```bash
scripts/e2e/run.sh
```

`BASE_URL` picks the server (default `http://localhost:8096`):

```bash
BASE_URL=http://localhost:8081 scripts/e2e/run.sh
```

The exit code is 0 when every check passes, 1 when any fails (the failures
are listed at the end), 2 when the script itself breaks.

When you are done, stop the server and drop the copy:

```bash
dropdb -h localhost -U postgres lv_e2e
```

## Counting queries

The dev server does not log SQL. To count the queries a page runs, load a
small Elixir file that attaches to `[:lumen_viae, :repo, :query]` and
appends each query to a file, start the server with
`elixir -r that_file.exs -S mix phx.server`, and load one page at a time.
Tidewave re-fetches the page after every URL change in dev; block requests
carrying an `x-tidewave-diagnostic` header (Playwright `context.route`) or
those fetches are counted too.

## Needs

- Node and `npx`, with network the first time (Playwright is cached after).
- Google Chrome installed (the script launches `--channel chrome`).
- A server with the database seeded: the Pray flow needs at least one
  visible meditation set in Joyful.
