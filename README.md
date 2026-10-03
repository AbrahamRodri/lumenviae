# Lumen Viae

> *"Light of the Way"* - A traditional Rosary meditation companion

## What is Lumen Viae?

Lumen Viae is a web application dedicated to helping the faithful pray the Rosary with rich, curated meditations. Like the beads of a Rosary guiding your fingers through prayer, Lumen Viae guides your heart through contemplation of the sacred mysteries.

Pray it at [www.lumenviae.org](https://www.lumenviae.org), or carry it with you in [Lumen Viae for iPhone](https://apps.apple.com/us/app/lumen-viae-rosary-meditations/id6760320749). This repository is the website, and the server that the iPhone app reads its meditations, narration and Divine Office from.

### Features

**Twenty Mysteries, and the Seven Sorrows** - the traditional Joyful, Sorrowful and Glorious mysteries, the Luminous Mysteries, and the Seven Sorrows of Mary

**Guided Meditation** - Carefully curated meditations for each mystery, drawn verbatim from the public domain writings of saints and spiritual writers

**Today's Mysteries** - The prayer dashboard proposes the mysteries for the day and takes you straight into prayer with any set of meditations for them

**Narrated Prayer** - Meditations can be listened to as well as read, in a choice of narration voices recorded through ElevenLabs

**The Spoken Rosary** - Turn on "Pray aloud" and every prayer and mystery announcement is said in your chosen voice, so a whole Rosary can be prayed aloud, bead by bead. The iPhone app adds a Scriptural verse for every Hail Mary

**Prayer Progress** - Your place is kept in the page's address, so a locked phone or a reload never loses it (life happens during prayer!)

**Learn Pages** - How to pray the Rosary with the methods of St. Louis de Montfort, his treatise on True Devotion, the life of St. Carlo Acutis, and every mystery found in Scripture

**The Divine Office** - The traditional Office, under the 1960 rubrics by default or any of ten other versions from 1570 on, the monastic among them, assembled by the open-source Divinum Officium engine and served to the iPhone app

**iOS App** - The companion iPhone app reads the same meditation catalog, narration and Office from this server

**Nothing Asked of You** - No account and no sign-up to pray. A finished Rosary is counted with an approximate place, and never a full address; see the [privacy policy](https://www.lumenviae.org/privacy-policy)

**Traditional Aesthetic** - Navy and gold reminiscent of traditional Catholic missals and devotional books

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
| `/` | The public site |
| `/admin` | The curation console, for signed-in admins only. `/admin/data` browses every resource (AshAdmin) and `/admin/jobs` shows the background jobs (Oban Web) |
| `/api` | The REST API the iPhone app reads. Frozen: every installed build depends on its shape |
| `/api/office` | The Divine Office: a day, an hour, or a month |
| `/api/v2` | A versioned JSON:API with an OpenAPI document, for a generated Swift client |
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

5. Visit [`localhost:8080`](http://localhost:8080) and begin your Rosary. In
   development, [`/admin`](http://localhost:8080/admin) opens without a
   password, signed in as the seeded development admin.

### Tests

```bash
mix test
```

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
  ├── curation/                 # CSV import, re-recording, the spoken Rosary, jobs
  ├── audio/                    # ElevenLabs narration
  ├── storage/                  # S3
  └── release.ex                # Production tasks without Mix
lib/lumen_viae_web/
  ├── live/
  │   ├── home/                 # Home, learn pages, the iPhone app page, feedback
  │   ├── dashboard/            # Today's mysteries
  │   ├── mysteries/            # Mysteries by category and in Scripture; admin editing
  │   ├── pray/                 # The prayer experience
  │   ├── meditations/          # Admin: meditations, sets and authors
  │   └── admin/                # Console dashboard, sign-in, CSV import, spoken Rosary
  ├── controllers/api/          # The REST API for the iPhone app
  ├── graphql/                  # The GraphQL pipeline and its guards
  ├── json_api/                 # The v2 OpenAPI document
  └── components/               # Shared function components
lib/mix/tasks/                  # Import, update and audio recording tasks
```

Code outside a domain reaches it only through the domain module
(`LumenViae.Rosary`, `LumenViae.Office`, `LumenViae.Accounts`), and tests
enforce the architecture rules - see
[ARCHITECTURE.md](docs/ARCHITECTURE.md) before adding a module, a query or
a page.

## Documentation

Working on the code:
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - The Ash domains, who may do what, background jobs, the web layer, components, design tokens and the admin console
- **[USAGE_RULES.md](docs/USAGE_RULES.md)** - The Ash packages' own guidance, generated from the dependencies
- **[CI.md](docs/CI.md)** - What CI checks, and how a merge to `main` deploys
- **[CLAUDE.md](CLAUDE.md)** - Instructions for AI assistants working on this codebase

The APIs:
- **[IOS_API_CONTRACT.md](docs/IOS_API_CONTRACT.md)** - What every installed iPhone build depends on in the REST API
- **[JSON_API.md](docs/JSON_API.md)** - The v2 JSON:API, and how to generate the Swift client
- **[GRAPHQL.md](docs/GRAPHQL.md)** - The GraphQL API and its committed schema
- **[OFFICE_API.md](docs/OFFICE_API.md)** - The Divine Office API and the Divinum Officium engine

Content and audio:
- **[MEDITATION_CURATION_GUIDE.md](docs/MEDITATION_CURATION_GUIDE.md)** - Rules for selecting and formatting meditation content
- **[CSV_IMPORT_GUIDE.md](docs/CSV_IMPORT_GUIDE.md)** - The import CSV format and the import workflow
- **[SPOKEN_ROSARY.md](docs/SPOKEN_ROSARY.md)** - Recording and serving the spoken Rosary
- **[COMPLETION_ANALYTICS.md](docs/COMPLETION_ANALYTICS.md)** - What is recorded when somebody finishes a Rosary

Running it:
- **[PROD_ACCESS.md](docs/PROD_ACCESS.md)** - Reaching production, running release tasks and making an admin

Plans and records:
- **[ASH_ROADMAP.md](docs/ASH_ROADMAP.md)** - An audit of the Ash domains and the packages to adopt next
- **[ASH_MIGRATION.md](docs/ASH_MIGRATION.md)** - The record of moving the domain to Ash
- **[API_EXPANSION_PLAN.md](docs/API_EXPANSION_PLAN.md)** - The August 2026 plan for expanding the API
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
