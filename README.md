# Lumen Viae

> *"Light of the Way"* - A traditional Rosary meditation companion

## What is Lumen Viae?

Lumen Viae is a web application dedicated to helping the faithful pray the traditional 15-decade Rosary with rich, curated meditations. Like the beads of a Rosary guiding your fingers through prayer, Lumen Viae guides your heart through contemplation of the sacred mysteries.

### Features

**Traditional 15 Mysteries** - Joyful, Sorrowful, and Glorious mysteries in the timeless tradition

**Guided Meditation** - Carefully curated meditations for each mystery, drawing from the wisdom of saints and spiritual writers

**Prayer Progress** - Your place is saved when you close your phone (life happens during prayer!), auto-clearing after 1 hour or when you complete your Rosary

**Traditional Aesthetic** - Navy and gold color scheme reminiscent of traditional Catholic missals and devotional books

## Tech Stack

Built with:
- **Elixir & Phoenix LiveView** - Real-time, interactive prayer experience
- **PostgreSQL** - Storing our meditation library
- **Tailwind CSS v4** - Traditional yet beautiful styling
- **localStorage** - Client-side prayer progress persistence

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
   ```bash
   mix phx.server
   ```

4. Visit [`localhost:4000`](http://localhost:4000) and begin your Rosary

## Project Structure

```
lib/lumen_viae/rosary/          # Core domain models (Mysteries, Meditations, Sets)
lib/lumen_viae_web/live/        # LiveView pages
  ├── home/                     # Homepage with daily mystery recommendations
  ├── mysteries/                # Browse mysteries by category
  ├── meditation_set/
      ├── list/                 # Browse meditation sets
      └── pray/                 # The prayer experience
```

## Documentation

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Architectural patterns, component types, and coding standards
- **[STRUCTURE.md](docs/STRUCTURE.md)** - Current application structure and module organization
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
