# Lumen Viae

> *"Light of the Way"* - A traditional Rosary meditation companion

## What is Lumen Viae?

Lumen Viae is a web application dedicated to helping the faithful pray the Rosary with rich, curated meditations. Like the beads of a Rosary guiding your fingers through prayer, Lumen Viae guides your heart through contemplation of the sacred mysteries.

Pray it at [www.lumenviae.org](https://www.lumenviae.org), or carry it with you in [Lumen Viae for iPhone](https://apps.apple.com/us/app/lumen-viae-rosary-meditations/id6760320749). This repository is the website, and the server that the iPhone app reads its meditations, narration and Divine Office from.

### What you can do

- **Pray today's mysteries** - The home page proposes the mysteries for the day in your own time zone, on the traditional weekly schedule or the modern one (Luminous on Thursday), and takes you straight into prayer
- **Pray the whole Rosary, bead by bead** - From the Sign of the Cross to the last Amen. Count on your own rosary, a decade a page, or on the screen, a bead at a time: tap, swipe or press Space for each Hail Mary
- **Choose how to pray it** - With a meditation from the saints for each mystery, as the Scriptural Rosary (a verse of Scripture before every Hail Mary), or with the prayers alone
- **Pray in Latin** - Set the prayers in English or Latin; add the Pope's intentions, the Memorare or the Saint Michael Prayer at the end
- **Pray aloud** - Every prayer and mystery announcement is said in a voice you choose, so a whole Rosary can be prayed with nothing to read
- **Listen to the meditations** - Meditations can be read or listened to, in a choice of narration voices recorded through ElevenLabs
- **Find your place again** - Your place is kept in the page's address and in your browser, so a locked phone or a reload never loses it, and "Continue where you left off" offers it for a week
- **Keep a streak** - A finished Rosary shows the days in a row you have prayed, with the Church's milestones: a triduum, a faithful week, a novena, and on to a year
- **Twenty mysteries, and the Seven Sorrows** - The Joyful, Sorrowful, Glorious and Luminous Mysteries and the Seven Sorrows of Mary, each with its days, fruits and a woodcut by Albrecht Durer or Gustave Dore
- **Every mystery in Scripture** - The Douay-Rheims passages for each mystery, and how the traditional and modern schedules differ
- **Curated meditations** - Drawn verbatim from the public domain writings of saints and spiritual writers
- **Nothing asked of you** - No account and no sign-up to pray. A finished Rosary is counted with an approximate place, and never a full address; see the [privacy policy](https://www.lumenviae.org/privacy-policy)

### What else is here

- **The Divine Office** - The traditional Office, under the 1960 rubrics by default or any of ten other versions from 1570 on, the monastic among them, assembled by the open-source Divinum Officium engine and served to the iPhone app
- **The Rosary's content** - The prayers in English and Latin, the mysteries with their fruits and verses, the order a Rosary is said in, the day's mysteries and the How to Pray course, served as one versioned document so an app prays with no connection
- **iOS and Android** - The companion iPhone app reads the same meditation catalog, narration and Office from this server. An Android app, not yet released, is built against `/api/v2` and the Rosary's content document ([ANDROID_API.md](docs/ANDROID_API.md))
- **A curation console** - Admins manage meditations, sets, authors and paintings, check the spoken Rosary, and read the completion figures

### Pages

The public site is only the Rosary:

- **Home** (`/`) - The daily hub: today's mysteries, the sets for them, and every category
- **The Mysteries in Scripture** (`/mysteries`) - Every mystery with its passages
- **A category** (`/mysteries/joyful`, `/mysteries/sorrowful`, `/mysteries/glorious`, `/mysteries/luminous`, `/mysteries/seven_sorrows`) - "Your Rosary Today": the two ways to pray without a set, and the shelf of meditation sets
- **The prayer page** (`/meditation-sets/:id/pray`, and `/mysteries/:category/pray` without a set)
- **Privacy Policy** (`/privacy-policy`)

The dashboard, the iPhone app page, How to Pray, True Devotion, St. Carlo Acutis and Feedback pages are retired to [`archive/`](archive/README.md) and no longer maintained. Their old addresses answer with a permanent redirect to the home page. See [PUBLIC_SITE.md](docs/PUBLIC_SITE.md).

## Tech Stack

Built with:
- **Elixir & Phoenix LiveView** - The public site and the admin console
- **Ash Framework** - The domain: resources, actions, policies, version history, and the APIs generated from them
- **PostgreSQL 17** - The meditation library and completion analytics
- **Oban** - Background jobs, such as recording narration and looking up a completion's approximate place
- **Tailwind CSS v4** - Traditional yet beautiful styling
- **ElevenLabs & S3** - Narration and the spoken Rosary, recorded once per voice and served pre-signed
- **Divinum Officium** - The rubrical engine behind the Office API, self-hosted
- **Fly.io** - Production hosting, deployed from GitHub Actions once CI passes

### What the server serves

| Path | What it is |
| --- | --- |
| `/` | The public site: the home page and the pages above |
| `/admin` | The curation console, for signed-in admins only. `/admin/data` browses every resource (AshAdmin), `/admin/jobs` shows the background jobs (Oban Web), `/admin/system` the release, database, queues and third parties, `/admin/live` the running VM (Phoenix LiveDashboard, with Ecto Stats), `/admin/admins` the admin accounts, and `/admin/completions` every completion figure, filtered |
| `/healthz` | Up, which release, and whether the database answers: 200, or 503 when it does not. For an uptime monitor |
| `/api` | The REST API the iPhone app reads. Frozen: every installed build depends on its shape |
| `/api/office` | The Divine Office: a day, an hour, or a month |
| `/api/v2` | A versioned JSON:API with an OpenAPI document, for generated Swift and Kotlin clients: the Android app's API, and the Rosary's content document |
| `/api/graphql` | GraphQL over the same actions |

## Getting Started

### Prerequisites

- Elixir 1.15+ (production builds with Elixir 1.18 on OTP 27)
- PostgreSQL 17

Tailwind and esbuild are fetched by Mix, so Node.js is not needed.

### Installation

1. Clone this repository
   ```bash
   git clone https://github.com/AbrahamRodri/lumenviae.git
   cd lumenviae
   ```

2. Install dependencies, create and migrate the database, build the assets and seed it
   ```bash
   mix setup
   ```

3. Put credentials in a `.env` file at the root. The site runs without
   them, but the narration and the spoken Rosary need `AWS_ACCESS_KEY_ID`,
   `AWS_SECRET_ACCESS_KEY` and `AWS_REGION`, and recording new audio needs
   `ELEVEN_LABS_API_KEY`.

4. Start the Phoenix server

   Use `./dev.sh` rather than `mix phx.server` directly - it loads `.env`
   first, and without those credentials the narration audio silently
   disappears from the page.

   ```bash
   ./dev.sh
   ```

   `./dev.sh iex` starts it inside IEx, `./dev.sh doctor` checks the
   checkout (below), and `./dev.sh mix ...` runs any mix command with
   `.env` loaded. `PORT=8081 ./dev.sh` moves the server, so two worktrees
   can each run one.

5. Visit [`localhost:8080`](http://localhost:8080) and begin your Rosary. In
   development, [`/admin`](http://localhost:8080/admin) opens without a
   password, signed in as the seeded development admin.

### Checking a checkout

```bash
./dev.sh doctor
```

`mix lumen_viae.doctor` checks the toolchain against the Dockerfile's,
`.env` and the credentials in it, the database and its pending
migrations, the dev server's port, the test partition in a worktree, and
the audio bucket, the Office engine, geolocation and ElevenLabs. Each line
says `ok`, `warn` or `FAIL` and what to do; it never writes anything.

### Tests

```bash
mix test
```

`mix check` runs CI's blocking checks in the order that fails fastest: a
forced compile with warnings as errors, `ash.codegen --check`, formatting
of the files this branch changed against `origin/main`, and the whole
suite with warnings as errors. It runs in the test environment, so set
`MIX_TEST_PARTITION` in a worktree.

### Checking the public site in a browser

```bash
BASE_URL=http://localhost:8096 scripts/e2e/run.sh
```

A Playwright smoke test of the public pages, at phone and desktop widths. It
needs its own server on a copy of the dev database; see
[PUBLIC_SITE.md](docs/PUBLIC_SITE.md) for the steps.

### Jobs

`mix lumen_viae.jobs` shows the queues by state; `failures`, `schedule`,
`retry --id/--queue/--worker`, `cancel --id` and `run WORKER` (a crontab
worker, now) act on them locally. The console's `/admin/system` shows the
same, and `LumenViae.Release` has the same acts for production
(docs/PROD_ACCESS.md).

Every checkout shares the `lumen_viae_dev` database. To run a branch
against its own copy, create one with
`createdb -h localhost -U postgres -T lumen_viae_dev <name>` and start the server with
`DEV_DATABASE=<name>`. Give each checkout its own `MIX_TEST_PARTITION`
when running tests side by side.

## Project Structure

```
lib/lumen_viae/
  ├── rosary.ex                 # The Rosary domain: its only public entry point
  ├── rosary/                   # Its Ash resources and vocabularies
  ├── office.ex                 # The Divine Office domain
  ├── office/                   # Divinum Officium client, parser and cache
  ├── accounts.ex               # Admin accounts
  ├── ops.ex                    # The Ops domain: the app looking at itself
  ├── ops/                      # Health, the database, the queues, the probes, Maintenance
  ├── curation/                 # CSV import, re-recording, the spoken Rosary, jobs
  ├── audio/                    # ElevenLabs narration
  ├── storage/                  # S3
  └── release.ex                # Production tasks without Mix
lib/lumen_viae_web/
  ├── live/
  │   ├── home/                 # The home page: today's mysteries and every category
  │   ├── mysteries/            # Mysteries in Scripture, the category pages; admin editing
  │   ├── pray/                 # The prayer page
  │   ├── privacy_policy/       # The privacy policy
  │   ├── meditations/          # Admin: meditations, sets and authors
  │   └── admin/                # Console dashboard, sign-in, CSV import, spoken Rosary, System
  ├── controllers/api/          # The REST API for the iPhone app
  ├── graphql/                  # The GraphQL pipeline and its guards
  ├── json_api/                 # The v2 OpenAPI document
  └── components/               # Shared function components
lib/mix/tasks/                  # Import, update, audio recording, doctor and jobs tasks
archive/                        # Retired public pages, not compiled (archive/README.md)
scripts/e2e/                    # The browser smoke test for the public site
```

Code outside a domain reaches it only through the domain module
(`LumenViae.Rosary`, `LumenViae.Office`, `LumenViae.Accounts`,
`LumenViae.Ops`), and tests
enforce the architecture rules - see
[ARCHITECTURE.md](docs/ARCHITECTURE.md) before adding a module, a query or
a page.

## Documentation

Working on the code:
- **[PUBLIC_SITE.md](docs/PUBLIC_SITE.md)** - The public pages, the prayer page's link, where each setting is kept, the browser smoke test, and the archived pages
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - The Ash domains, who may do what, background jobs, the web layer, components, design tokens and the admin console
- **[USAGE_RULES.md](docs/USAGE_RULES.md)** - The Ash packages' own guidance, generated from the dependencies
- **[CI.md](docs/CI.md)** - What CI checks, and how a merge to `main` deploys
- **[DEV_TOOLS.md](docs/DEV_TOOLS.md)** - Tidewave, LiveDebugger and the Ecto Stats page, for development
- **[CLAUDE.md](CLAUDE.md)** - Instructions for AI assistants working on this codebase

The APIs:
- **[IOS_API_CONTRACT.md](docs/IOS_API_CONTRACT.md)** - What every installed iPhone build depends on in the REST API
- **[ANDROID_API.md](docs/ANDROID_API.md)** - What the Android app calls, how, and what it keeps on the device
- **[JSON_API.md](docs/JSON_API.md)** - The v2 JSON:API, the Rosary's content document, and how to generate the Swift and Kotlin clients
- **[GRAPHQL.md](docs/GRAPHQL.md)** - The GraphQL API and its committed schema
- **[OFFICE_API.md](docs/OFFICE_API.md)** - The Divine Office API and the Divinum Officium engine

Content and audio:
- **[MEDITATION_CURATION_GUIDE.md](docs/MEDITATION_CURATION_GUIDE.md)** - Rules for selecting and formatting meditation content
- **[CSV_IMPORT_GUIDE.md](docs/CSV_IMPORT_GUIDE.md)** - The import CSV format and the import workflow
- **[SPOKEN_ROSARY.md](docs/SPOKEN_ROSARY.md)** - The Rosary's words and order, and recording and serving the spoken Rosary
- **[MYSTERY_PAINTINGS.md](docs/MYSTERY_PAINTINGS.md)** - The mysteries' paintings: provenance, and the steps to publish them
- **[COMPLETION_ANALYTICS.md](docs/COMPLETION_ANALYTICS.md)** - What is recorded when somebody finishes a Rosary
- **[audits/](docs/audits/)** - The accessibility and mobile audits of the public site

Running it:
- **[PROD_ACCESS.md](docs/PROD_ACCESS.md)** - Reaching production, running release tasks and making an admin

Plans and records:
- **[ASH_ROADMAP.md](docs/ASH_ROADMAP.md)** - An audit of the Ash domains and the packages to adopt next
- **[ASH_MIGRATION.md](docs/ASH_MIGRATION.md)** - The record of moving the domain to Ash
- **[API_EXPANSION_PLAN.md](docs/API_EXPANSION_PLAN.md)** - The August 2026 plan for expanding the API
- **[ANDROID_BACKEND_PLAN.md](docs/ANDROID_BACKEND_PLAN.md)** - The October 2026 plan that made the server ready for an Android app, and what was done
- **[UPCOMING_FEATURES.md](docs/UPCOMING_FEATURES.md)** - Roadmap for future enhancements

## Contributing

Contributions are welcome! Whether you want to:
- Add new meditations from the saints and doctors of the Church
- Improve the prayer experience
- Fix bugs
- Enhance the traditional aesthetic

Please open an issue or submit a pull request.

## Development Philosophy

This project embraces:
- **Tradition**: Honoring the timeless prayers and meditations of the Church
- **Beauty**: Creating a dignified, reverent digital space for prayer
- **Simplicity**: Removing distractions so the faithful can focus on Christ
- **Accessibility**: Making rich spiritual content available to all

## License

This project is open source and available for the greater glory of God.

---

*"The Rosary is the most excellent form of prayer and the most efficacious means of attaining eternal life."* - Pope Leo XIII

**Ad Majorem Dei Gloriam**
