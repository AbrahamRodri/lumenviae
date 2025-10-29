# Lumen Viae Application Structure

This document describes the current application structure following the patterns defined in [ARCHITECTURE.md](ARCHITECTURE.md).

## Directory Structure

```
lib/lumen_viae_web/live/
├── home/                              # Info/marketing pages
│   ├── index.ex                       # Home page (/)
│   ├── feedback/
│   │   └── index.ex                   # Feedback page (/feedback)
│   └── methods/
│       └── index.ex                   # Rosary methods (/rosary-methods)
├── mysteries/                         # Mystery browsing
│   ├── index.ex                       # Browse all mysteries (/mysteries)
│   └── categories/
│       └── list/
│           └── list.ex                # Browse sets by category (/mysteries/:category)
├── meditations/                       # Meditation & set management (admin)
│   ├── list/
│   │   └── list.ex                    # List meditations (admin)
│   ├── new/
│   │   └── new.ex                     # Create meditation (admin)
│   ├── edit/
│   │   └── edit.ex                    # Edit meditation (admin)
│   └── sets/                          # Meditation sets (admin)
│       ├── list/
│       │   └── list.ex                # List sets (admin)
│       ├── new/
│       │   └── new.ex                 # Create set (admin)
│       └── edit/
│           └── edit.ex                # Edit set (admin)
├── pray/                              # Core prayer experience
│   └── index.ex                       # Prayer (/meditation-sets/:set_id/pray)
└── admin/
    └── dashboard/
        ├── dashboard.ex               # Admin dashboard (/admin)
        └── meditation_list/
            └── meditation_list.ex     # Component
```

## Module Organization

### Public/Info Pages (home/)
These pages are grouped under `home/` as they're all part of the informational/marketing side:

- **LumenViaeWeb.Live.Home.Index** - Welcome page with mystery categories and daily recommendations
- **LumenViaeWeb.Live.Home.Feedback.Index** - Feedback and feature request page
- **LumenViaeWeb.Live.Home.Methods.Index** - St. Louis de Montfort's Rosary methods

### Mystery Browsing (mysteries/)
Browse mysteries and select meditation sets by category:

- **LumenViaeWeb.Live.Mysteries.Index** - Browse all 15 mysteries organized by category
- **LumenViaeWeb.Live.Mysteries.Categories.List** - Browse meditation sets for a specific category (joyful, sorrowful, glorious)

### Prayer Experience (pray/)
Core prayer functionality - the main app feature:

- **LumenViaeWeb.Live.Pray.Index** - Main prayer experience with progress persistence, navigation, and meditation display

### Admin Pages (meditations/ & admin/)
Content management for meditations and meditation sets:

- **LumenViaeWeb.Live.Admin.Dashboard** - Admin landing page
- **LumenViaeWeb.Live.Meditations.List/New/Edit** - Manage individual meditations
- **LumenViaeWeb.Live.Meditations.Sets.List/New/Edit** - Manage meditation sets

## URL Structure

| URL | LiveView | Type | Purpose |
|-----|----------|------|---------|
| `/` | Home.Index | Public | Welcome & mystery categories |
| `/feedback` | Home.Feedback.Index | Public | Feedback submission |
| `/rosary-methods` | Home.Methods.Index | Public | Educational content |
| `/mysteries` | Mysteries.Index | Public | Browse all mysteries |
| `/mysteries/:category` | Mysteries.Categories.List | Public | Browse sets for category |
| `/meditation-sets/:set_id/pray` | Pray.Index | App Core | Prayer experience |
| `/admin` | Admin.Dashboard | Admin | Admin landing |
| `/admin/meditations` | Meditations.List | Admin | Manage meditations |
| `/admin/meditations/new` | Meditations.New | Admin | Create meditation |
| `/admin/meditations/:id/edit` | Meditations.Edit | Admin | Edit meditation |
| `/admin/meditation-sets` | Meditations.Sets.List | Admin | Manage sets |
| `/admin/meditation-sets/new` | Meditations.Sets.New | Admin | Create set |
| `/admin/meditation-sets/:id/edit` | Meditations.Sets.Edit | Admin | Edit set |

## Navigation Flow

### Public User Journey
```
Home (/)
  ↓ Choose category or browse all
Mysteries (/mysteries) OR Mystery Category (/mysteries/:category)
  ↓ Choose a meditation set
Prayer Experience (/meditation-sets/:set_id/pray)
  ↓ Navigate through meditations with progress persistence
```

### Admin Journey
```
Admin Dashboard (/admin)
  ↓ Manage content
Meditations (/admin/meditations) OR Sets (/admin/meditation-sets)
  ↓ Create/Edit
Forms for CRUD operations
```

## Key Features & Organization

- **Progress Persistence**: Prayer progress saved to localStorage, expires after 1 hour or on navigation away
- **Organized Home Section**: All info/marketing pages grouped under `home/` (home, feedback, methods)
- **Consolidated Meditations**: All meditation-related features under `meditations/` with sets as a subdirectory
- **Consolidated Mysteries**: Mystery browsing organized under `mysteries/` with categories as a subdirectory
- **Dedicated Prayer**: Core prayer experience in its own top-level `pray/` directory (will expand with future features)
- **Clear Separation**: Public (home, mysteries), core app (pray), and admin (meditations, admin) clearly organized
- **URL-Based State**: All LiveViews manage state through URL parameters

## Alignment with ARCHITECTURE.md

This structure follows all patterns from ARCHITECTURE.md:

✅ **Directory Structure**: Each LiveView in `{resource}/{action}/` format
✅ **Module Naming**: Follows `{WebModule}.Live.{Resource}.{Action}` pattern
✅ **One Resource Per LiveView**: Each LiveView handles one domain resource
✅ **Component Organization**: Components nested under their parent LiveView
✅ **File Names**: Match module names (dashboard.ex, list.ex, pray.ex)
✅ **URL as Source of Truth**: All state managed through URL parameters
✅ **Separation of Concerns**: Template in separate .html.heex file for main LiveView

## Future Considerations

As the application grows, consider:

1. **Helper Modules**: Create `lib/lumen_viae_web/live/{resource}/helpers.ex` for complex business logic
2. **Data Modules**: Create `lib/lumen_viae_web/live/{resource}/data.ex` if adding GraphQL or complex queries
3. **Sub-Components**: Break down complex sections into live components as needed
4. **Modals**: Add modal components following `{resource}/{action}/{modal}_modal/` pattern

## References

- [ARCHITECTURE.md](ARCHITECTURE.md) - Architectural patterns and standards
- [CLAUDE.md](../CLAUDE.md) - Instructions for AI assistants working on this codebase
