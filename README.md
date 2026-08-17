# Lumen Viae

> *"Light of the Way"* - A traditional Rosary meditation companion

## What is Lumen Viae?

Lumen Viae is a web application dedicated to helping the faithful pray the Rosary with rich, curated meditations. Like the beads of a Rosary guiding your fingers through prayer, Lumen Viae guides your heart through contemplation of the sacred mysteries.

### Features

**Twenty Mysteries, and the Seven Sorrows** - the traditional Joyful, Sorrowful and Glorious mysteries, the Luminous Mysteries, and the Seven Sorrows of Mary

**Guided Meditation** - Carefully curated meditations for each mystery, drawn verbatim from the public domain writings of saints and spiritual writers

**Narrated Prayer** - Meditations can be listened to as well as read, narrated through ElevenLabs

**Prayer Progress** - Your place is saved when you close your phone (life happens during prayer!), auto-clearing after 1 hour or when you complete your Rosary

**Learn Pages** - How to pray the Rosary with the methods of St. Louis de Montfort, his treatise on True Devotion, and the life of St. Carlo Acutis

**iOS App** - A companion app reads the same catalog over a JSON API

**Traditional Aesthetic** - Navy and gold reminiscent of traditional Catholic missals and devotional books

## Tech Stack

Built with:
- **Elixir & Phoenix LiveView** - Real-time, interactive prayer experience
- **PostgreSQL** - Storing our meditation library
- **Tailwind CSS v4** - Traditional yet beautiful styling
- **ElevenLabs & S3** - Narration audio, generated at import and served pre-signed
- **localStorage** - Client-side prayer progress persistence
- **Fly.io** - Production hosting

## Getting Started

### Prerequisites

- Elixir 1.14+
- PostgreSQL
- Node.js (for asset compilation)

### Installation

1. Clone this repository
   ```bash
   git clone https://github.com/AbrahamRodri/lumenviae.git
   cd lumenviae
   ```

2. Install dependencies and setup database
   ```bash
   mix setup
   ```

3. Start the Phoenix server

   Use `./dev.sh` rather than `mix phx.server` directly - it loads `.env`
   first, and without those credentials the narration audio silently
   disappears from the page.

   ```bash
   ./dev.sh
   ```

4. Visit [`localhost:8080`](http://localhost:8080) and begin your Rosary

## Project Structure

```
lib/lumen_viae/
  ├── rosary.ex                 # The domain's public API (Primary Context)
  ├── rosary/                   # One context + schema per resource
  ├── curation/                 # CSV import and audio regeneration
  ├── audio/                    # ElevenLabs narration
  └── storage/                  # S3
lib/lumen_viae_web/
  ├── live/
  │   ├── home/                 # Public informational and learn pages
  │   ├── dashboard/            # Choose today's mysteries
  │   ├── mysteries/            # Browse mysteries and sets by category
  │   ├── pray/                 # The prayer experience
  │   ├── meditations/          # Admin CRUD for meditations and sets
  │   └── admin/                # Admin dashboard, login, CSV import
  ├── controllers/api/          # JSON API for the iOS app
  └── components/               # Shared function components
```

The domain follows a strict set of context rules - see
[ARCHITECTURE.md](docs/ARCHITECTURE.md) before adding a module or a query.

## Documentation

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Context rules, directory layout, component and template conventions, design tokens
- **[MEDITATION_CURATION_GUIDE.md](docs/MEDITATION_CURATION_GUIDE.md)** - Rules for selecting and formatting meditation content
- **[CSV_IMPORT_GUIDE.md](docs/CSV_IMPORT_GUIDE.md)** - The import CSV format and the import workflow
- **[PROD_ACCESS.md](docs/PROD_ACCESS.md)** - Reaching the production database and running release tasks
- **[UPCOMING_FEATURES.md](docs/UPCOMING_FEATURES.md)** - Roadmap for future enhancements
- **[CLAUDE.md](CLAUDE.md)** - Instructions for AI assistants working on this codebase

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

## Acknowledgments

- Built with love for the Church Militant
- Inspired by centuries of Marian devotion
- Dedicated to Our Lady, Mediatrix of All Graces

---

*"The Rosary is the most excellent form of prayer and the most efficacious means of attaining eternal life."* - Pope Leo XIII

**Ad Majorem Dei Gloriam**
