# Instructions for Claude Code

## Architecture

**IMPORTANT:** Before making any architectural decisions or creating new LiveViews, components, or modules, **always reference [ARCHITECTURE.md](ARCHITECTURE.md)** for the project's architectural standards and patterns.

The ARCHITECTURE.md document defines:
- LiveView organization and structure
- Component types (Live Components, Function Components, Page Components)
- Template organization patterns
- Parent-child communication patterns
- Directory structure and naming conventions
- Key architectural patterns and best practices

## Development Guidelines

### When Creating New Features

1. **Read ARCHITECTURE.md first** - Understand the established patterns before writing code
2. **Follow the directory structure** - Match module names to file paths as defined in ARCHITECTURE.md
3. **Choose the right component type** - Use the component decision tree in ARCHITECTURE.md
4. **Break up complexity** - Never create monolithic views (see ARCHITECTURE.md for patterns)
5. **Separate concerns** - Use `data.ex` for queries, `helpers.ex` for business logic

### When Refactoring

1. **Reference ARCHITECTURE.md** - Align existing code with documented patterns
2. **Extract components** - Break large LiveViews into smaller, focused components
3. **Create helper modules** - Move complex logic to dedicated helper files
4. **Fragment templates** - Use private functions for complex template sections

### Code Organization

Follow the patterns documented in ARCHITECTURE.md for:
- LiveView module structure
- Component hierarchy and nesting
- File and directory naming
- Template organization (embedded vs. separate files)
- Public API definitions for complex components

## Project-Specific Notes

This is a Phoenix LiveView application for **Lumen Viae** - a traditional Rosary meditation website.

### Key Features
- Traditional 15 mysteries (Joyful, Sorrowful, Glorious)
- Meditation library with flexible curation
- Many-to-many relationship between meditation sets and meditations
- Admin interface for managing meditations and sets
- Traditional Latin Mass aesthetic (Navy/Gold color scheme)

### Database Structure
- `mysteries` - The 15 traditional mysteries
- `meditations` - Individual meditations tied to mysteries
- `meditation_sets` - Curated collections of meditations
- `meditation_set_meditations` - Join table with ordering

### Styling
- Tailwind CSS v4 with custom theme
- Google Fonts: Cinzel (headings), Crimson Text (body)
- Color scheme: Navy (#1a1a2e), Gold (#d4af37), Cream (#f5f5f0)

## Remember

**Always check ARCHITECTURE.md before:**
- Creating new LiveViews or components
- Organizing files and directories
- Choosing between component types
- Implementing parent-child communication
- Structuring complex pages

Following these architectural patterns ensures consistency, maintainability, and alignment with the codebase standards.
