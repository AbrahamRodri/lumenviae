# Browser smoke test

An end-to-end check of the Rosary-only website, driven by Playwright in the
installed Chrome. It adds no mix or npm dependency: `run.sh` fetches
Playwright through `npx`.

At 390x844 (mobile) and 1280x800 (desktop) it:

- loads `/`, `/mysteries`, `/mysteries/joyful`, `/mysteries/seven_sorrows`
  and `/privacy-policy`, and checks each answers 200 with an h1 and no
  console errors;
- checks no page scrolls sideways (`scrollWidth <= innerWidth`);
- follows the first Pray link on `/mysteries/joyful` to
  `/meditation-sets/:id/pray` and presses ArrowRight;
- checks `/dashboard`, `/app`, `/rosary-methods`, `/true-devotion`,
  `/saint-carlo` and `/feedback` redirect to `/`;
- saves a full-page screenshot of every page to `scripts/e2e/out/`
  (gitignored).

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

## Needs

- Node and `npx`, with network the first time (Playwright is cached after).
- Google Chrome installed (the script launches `--channel chrome`).
- A server with the database seeded: the Pray flow needs at least one
  visible meditation set in Joyful.
