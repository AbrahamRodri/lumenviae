# Instructions for Claude Code

## CRITICAL: NO EMOJIS 

**NEVER use emojis in any code, documentation, comments, or communication.**

This is a strict project requirement. Keep all text professional and emoji-free.

NEVER when making PR descriptions on git commits add CO-Author by Claude

## Architecture

**IMPORTANT:** Before making any architectural decisions or creating new LiveViews, components, or modules, **always reference [ARCHITECTURE.md](docs/ARCHITECTURE.md)** for the project's architectural standards and patterns.

The ARCHITECTURE.md document defines:
- The context rules the domain follows (Primary Context, Secondary
  Contexts, schemas) and where a new query or resource goes
- LiveView organization and naming
- Component and template conventions, including the `_partials` pattern
- Design tokens (colors and fonts)

These rules are enforced by `test/lumen_viae/rosary/context_rules_test.exs`,
so breaking them fails the build rather than drifting quietly.

## Development Guidelines

### When Creating New Features

1. **Read docs/ARCHITECTURE.md first** - Understand the established patterns before writing code
2. **Follow the directory structure** - Match module names to file paths as defined in docs/ARCHITECTURE.md
3. **Go through `LumenViae.Rosary`** - It is the domain's only public entry point. Never call a Secondary Context, a schema, or the Repo from outside `lib/lumen_viae/rosary/`
4. **Break up complexity** - Never create monolithic views (see docs/ARCHITECTURE.md for patterns)
5. **Separate concerns** - Queries belong in the Secondary Context that owns the table; presentation-only filtering belongs next to the LiveView

### When Refactoring

1. **Reference docs/ARCHITECTURE.md** - Align existing code with documented patterns
2. **Extract components** - Break large LiveViews into smaller, focused components
3. **Create helper modules** - Move complex logic to dedicated helper files
4. **Fragment templates** - Use private functions for complex template sections

### Code Organization

Follow the patterns documented in docs/ARCHITECTURE.md for:
- LiveView module structure
- Component hierarchy and nesting
- File and directory naming
- Template organization (embedded vs. separate files)
- Public API definitions for complex components

## Project-Specific Notes

This is a Phoenix LiveView application for **Lumen Viae** - a traditional Rosary meditation website.

### Key Features
- Five mystery categories: Joyful, Sorrowful, Glorious, Luminous, and the
  Seven Sorrows of Mary
- Meditation library with flexible curation
- Many-to-many relationship between meditation sets and meditations, with
  the prayer order carried on the join row
- ElevenLabs narration generated at import, stored in S3
- Admin interface for managing meditations and sets
- JSON API consumed by the iOS app
- Traditional Latin Mass aesthetic (Navy/Gold color scheme)

### Database Structure
- `mysteries` - The mysteries of the Rosary, grouped by category
- `meditations` - Individual meditations tied to mysteries
- `meditation_sets` - Curated collections of meditations
- `meditation_set_meditations` - Join table with ordering
- `rosary_completions` - Completion analytics

Every table is reached through `LumenViae.Rosary`. The category vocabulary
lives in `LumenViae.Rosary.Categories` and the set label vocabulary in
`LumenViae.Rosary.Labels` - never inline those lists.

### Styling
- Tailwind CSS v4 with a custom theme in `assets/css/app.css`
- The public site follows the iOS app's design language on light
  backgrounds: Cinzel (headings, tracked-caps labels, buttons) and
  EB Garamond (all body and quotation text) are the only two public
  families. Ovo and Work Sans remain on admin surfaces only.
- Colors: Navy (#003b5c), Gold (#b18b49), Parchment (#fdfaf4),
  Cream (#faf2e6), Brown (#4a3f33). Navy backgrounds are for the page
  hero and at most one accent band per page; everything else stays light.
- Shared vocabulary: `<.gold_cta>`, `<.sacred_divider>`, `<.arch_frame>`,
  `.hairline-card`, `.drop-cap` - see the design tokens section in
  docs/ARCHITECTURE.md.
- Use the Tailwind tokens (`text-navy`, `bg-cream`, `font-cinzel`), never
  raw hex values. See the design tokens table in docs/ARCHITECTURE.md.

### Local Development
Start the server with `./dev.sh`, not `mix phx.server` - it loads `.env`
first, and without the AWS credentials the audio players silently vanish.
The dev server listens on port 8080.

## Meditation CSV Imports

Batch imports run through `LumenViae.Curation.CsvImport` (shared by the
admin upload UI at `/admin/meditations/import`, the `mix lumen_viae.import`
task, and `LumenViae.Release.import_csv/2` for production releases).

**MANDATORY: Always dry-run an import before running it for real.**

```
mix lumen_viae.import path/to/file.csv --dry-run
mix lumen_viae.import path/to/file.csv
```

Never run a real import (with audio generation or DB writes) unless the
dry run completed with zero errors. Audio generation requires
ELEVEN_LABS_API_KEY and AWS credentials in the environment; `--skip-audio`
imports text only. See docs/CSV_IMPORT_GUIDE.md for the CSV format,
including the meditation set columns (set_name, set_category,
set_description, set_labels, order).

Generated import CSVs belong in `priv/repo/imports/` (gitignored -
meditation content stays out of version control).

**When curating meditation content, always follow
docs/MEDITATION_CURATION_GUIDE.md.** Key rules: verbatim public domain
text only; excerpts must stand alone (named subjects and established
scene from the first sentence - never open on a bare "He" or "She");
focus on one aspect of the mystery, going longer when context requires
it; format content with paragraph breaks so it reads and narrates well.

## Remember

**Always check docs/ARCHITECTURE.md before:**
- Adding a query, a field, or a resource to the domain
- Creating new LiveViews or components
- Organizing files and directories
- Structuring complex pages
- Picking a color or a font

Following these architectural patterns ensures consistency, maintainability, and alignment with the codebase standards.
