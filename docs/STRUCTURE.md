# Lumen Viae Application Structure

This document describes the current application structure following the patterns defined in [ARCHITECTURE.md](ARCHITECTURE.md).

## Directory Structure

```
lib/lumen_viae_web/live/
├── rosary/
│   └── list/
│       └── list.ex                    # Home page - lists mystery categories
├── mystery_set/
│   └── list/
│       └── list.ex                    # Lists meditation sets for a mystery
├── meditation_set/
│   └── pray/
│       └── pray.ex                    # Prayer experience
└── admin/
    └── dashboard/
        ├── dashboard.ex               # Admin dashboard
        ├── dashboard.html.heex        # Admin template
        └── meditation_list/
            └── meditation_list.ex     # Meditation list component
```

## Module Naming

All LiveViews follow the pattern: `{WebModule}.Live.{Resource}.{Action}`

- **LumenViaeWeb.Live.Rosary.List** - Lists the three mystery categories (Joyful, Sorrowful, Glorious)
- **LumenViaeWeb.Live.MysterySet.List** - Lists meditation sets for a specific mystery category
- **LumenViaeWeb.Live.MeditationSet.Pray** - Sequential prayer experience through a meditation set
- **LumenViaeWeb.Live.Admin.Dashboard** - Admin interface for managing content

## URL Structure

| URL | LiveView | Purpose |
|-----|----------|---------|
| `/` | Rosary.List | Home page showing mystery categories |
| `/mysteries/:category` | MysterySet.List | Shows sets for joyful/sorrowful/glorious |
| `/meditation-sets/:set_id/pray` | MeditationSet.Pray | Prayer experience |
| `/admin` | Admin.Dashboard | Content management |

### Examples

- `/` - Home page with three mystery categories
- `/mysteries/joyful` - Meditation sets for Joyful Mysteries
- `/mysteries/sorrowful` - Meditation sets for Sorrowful Mysteries
- `/mysteries/glorious` - Meditation sets for Glorious Mysteries
- `/meditation-sets/123/pray` - Pray through meditation set #123
- `/admin` - Admin dashboard

## Resources

The application uses these domain resources:

1. **Rosary** - The rosary as a whole (home page)
2. **MysterySet** - Curated sets of meditations for a mystery category
3. **MeditationSet** - Individual sets that can be prayed through
4. **Admin** - Administrative functions

## Navigation Flow

```
Home (Rosary.List)
  ↓ Choose category (Joyful/Sorrowful/Glorious)
MysterySet.List
  ↓ Choose a meditation set
MeditationSet.Pray
  ↓ Navigate through 5 mysteries sequentially
```

## Components

### Function Components

- **LumenViaeWeb.Live.Admin.Dashboard.MeditationList** - Displays and manages meditations in admin

Located in: `lib/lumen_viae_web/live/admin/dashboard/meditation_list/meditation_list.ex`

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
