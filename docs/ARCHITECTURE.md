# Lumen Viae Architecture

How this codebase is organized, and the rules that keep it that way. Read
this before adding a module, a query, or a page.

## Contents

1. [The shape of the app](#the-shape-of-the-app)
2. [The domain: context rules](#the-domain-context-rules)
3. [Composing across resources](#composing-across-resources)
4. [Value modules](#value-modules)
5. [Services above the domain](#services-above-the-domain)
6. [The web layer](#the-web-layer)
7. [Components](#components)
8. [Templates and partials](#templates-and-partials)
9. [Where does this go?](#where-does-this-go)
10. [Design tokens](#design-tokens)

---

## The shape of the app

Three layers, and dependencies only ever point downward:

```
lib/lumen_viae_web/     LiveViews, controllers, JSON views, components
lib/lumen_viae/         domain (Rosary), services, infrastructure
lib/mix/tasks/          command-line entry points
```

```
lib/lumen_viae/
├── rosary.ex                  Primary Context - the domain's only public API
├── rosary/
│   ├── categories.ex          value module: mystery category vocabulary
│   ├── labels.ex              value module: meditation set label vocabulary
│   ├── mysteries.ex           Secondary Context
│   ├── mysteries/mystery.ex   schema
│   ├── meditations.ex
│   ├── meditations/meditation.ex
│   ├── meditation_sets.ex
│   ├── meditation_sets/meditation_set.ex
│   ├── set_memberships.ex
│   ├── set_memberships/set_membership.ex
│   ├── completions.ex
│   └── completions/completion.ex
├── curation/                  batch services over the domain's public API
│   ├── csv_import.ex
│   ├── audio_regeneration.ex
│   └── artwork_upload.ex
├── audio/                     ElevenLabs narration
│   ├── eleven_labs.ex
│   ├── pipeline.ex
│   └── tts_text.ex
├── images/inspector.ex        image headers: format and dimensions
├── storage/s3.ex              S3 uploads, pre-signed and public URLs
├── services/geolocation.ex    IP to approximate location
├── liturgical_calendar.ex     which mysteries are prayed today
└── release.ex                 production tasks without Mix
```

---

## The domain: context rules

The Rosary domain follows the context rules proposed in
[A Proposal for Context Rules](https://www.devonestes.com/a-proposal-for-context-rules).
The point is that there is never a question about where a piece of code
goes, and never two places doing the same query.

Three kinds of module, three levels of privacy:

| Layer | Module | May call | Called by |
| --- | --- | --- | --- |
| Primary Context | `LumenViae.Rosary` | Secondary Contexts, services | everything outside the domain |
| Secondary Context | `LumenViae.Rosary.Meditations` | its own schema, the Repo | the Primary Context only |
| Schema | `LumenViae.Rosary.Meditations.Meditation` | nothing | its own Secondary Context only |

### Rule 1: schemas hold only the schema

A schema file contains the `schema` block, its associations, and its
changeset functions. Nothing else - no queries, no `Repo`, no predicates,
no business logic. Every public function returns an `%Ecto.Changeset{}`.

A schema is private to its Secondary Context. The one exception is that
schemas name each other in Ecto associations, because `belongs_to` and
`many_to_many` have to name the other module.

Schemas are tested through their Secondary Context, not directly - see
`test/lumen_viae/rosary/meditations_test.exs`.

### Rule 2: every schema has a Secondary Context

One per resource, named for the plural, in the file above the schema's
directory. It owns every read and write of that one table: CRUD, the
queries, the aggregates. Its functions return records, lists of records,
changesets, aggregates, or ids - never a rendered or presentational shape.

Functions are named for the resource they already belong to, so they read
without stuttering: `Meditations.list/0`, not
`Meditations.list_meditations/0`.

### Rule 3: only Secondary Contexts touch the Repo

`Repo` appears in exactly five files. If code outside them needs data, it
calls the Primary Context, which calls the Secondary Context that owns the
table.

A Secondary Context may preload its own schema's associations, since the
associations are part of the schema definition. It may **not** hand-write a
join, subquery, or `where` against another resource's table - that is the
Primary Context's job (see below).

### Rule 4: the Primary Context is the only way in

`LumenViae.Rosary` is the domain's public API. LiveViews, controllers, mix
tasks, the release module and the curation services all talk to it and
nothing deeper. Nothing outside `lib/lumen_viae/rosary/` names a Secondary
Context or a schema.

Most of its functions are `defdelegate` pass-throughs. The code it actually
contains is cross-resource composition.

### These rules are tested

`test/lumen_viae/rosary/context_rules_test.exs` checks all of the above by
reading the source tree. A rule that is only written down survives as long
as everyone remembers it; this one fails the build.

---

## Composing across resources

Because a Secondary Context never queries another table, anything spanning
resources is assembled in `LumenViae.Rosary` from id-shaped pieces. Three
things work this way:

**Visibility.** A meditation set is hidden from the public site and the iOS
API when any of its meditations is archived. Archiving one meditation
therefore hides every set containing it, while the admin keeps seeing
everything.

```elixir
def hidden_meditation_set_ids do
  Meditations.list_archived_ids()             # which meditations are archived
  |> SetMemberships.list_set_ids_containing() # which sets hold them
  |> MapSet.new()
end

def list_visible_meditation_sets do
  MeditationSets.list(exclude_ids: hidden_meditation_set_ids())
end
```

**Prayer order.** A set's order lives on the join row, not on the
meditations, so the membership context supplies ordered ids and the
meditations context fetches the records:

```elixir
def list_meditations_in_set(set_id) do
  set_id
  |> SetMemberships.list_meditation_ids_in_set()  # ordered ids
  |> Meditations.list_by_ids()                    # records, in that order
end
```

**Reporting.** `meditation_set_stats/0`, `get_completions_by_set/0` and
`get_recent_completions/1` each ask two contexts for id-keyed data and fold
it together in Elixir.

This trades one hand-written join for two indexed queries plus a fold. On
this dataset that is free, and the aggregation becomes ordinary testable
Elixir instead of SQL. If a composition ever does become a bottleneck, the
fix is a documented, measured exception - not a quiet join.

---

## Value modules

`LumenViae.Rosary.Categories` and `LumenViae.Rosary.Labels` hold controlled
vocabulary: no state, no queries, no schema. Any layer may call them
directly, including templates. They are the single source for their lists,
so `Categories.slugs/0` feeds the changeset validations and
`Categories.options/0` feeds the form selects from the same place.

Add a value module when a list of allowed values is needed in more than one
layer. Do not add one for anything that reads the database.

---

## Services above the domain

`LumenViae.Curation.CsvImport`, `LumenViae.Curation.AudioRegeneration` and
`LumenViae.Curation.ArtworkUpload` orchestrate many domain and
infrastructure calls on the domain's behalf. They sit *outside* the domain
and consume `LumenViae.Rosary` exactly like a LiveView does, which is why
they live in `lib/lumen_viae/curation/` rather than under `rosary/`.

They are shared entry points, so the admin upload UI, `mix lumen_viae.*`,
and `LumenViae.Release` all drive the same code and behave identically.
`CsvImport` and `AudioRegeneration` return `{:ok | :warning | :error,
message}` lists and accept a `:progress` function; `ArtworkUpload` handles
one file at a time and returns `{:ok, fields} | {:error, message}`.

`audio/`, `images/`, `storage/` and `services/` are infrastructure: they
wrap an external API or a file format and know nothing about the domain.

---

## The web layer

```
lib/lumen_viae_web/
├── components/          shared function components
├── controllers/api/     JSON API for the iOS app
├── live/                LiveViews, grouped by domain area
├── plugs/               canonical host, admin authentication
└── router.ex
```

LiveViews are grouped by **area of the site**, not by resource:

| Directory | Contents |
| --- | --- |
| `live/home/` | public informational pages (home, methods, true devotion, saint carlo, feedback, app) |
| `live/mysteries/` | public mystery browsing, plus admin mystery CRUD |
| `live/dashboard/` | the prayer dashboard, where a set is chosen |
| `live/pray/` | the prayer experience itself |
| `live/meditations/` | admin CRUD for meditations and sets |
| `live/admin/` | admin dashboard, login, CSV import |
| `live/privacy_policy/` | App Store privacy policy |

### Module names match file paths

- `LumenViaeWeb.Live.Meditations.Sets.List` is
  `live/meditations/sets/list/list.ex`
- `LumenViaeWeb.Live.Home.TrueDevotion.Index` is
  `live/home/true_devotion/index.ex`

A LiveView with sub-components gets a directory per component:

```
live/meditations/list/
├── list.ex                      the LiveView
├── list.html.heex               its template
├── row/row.ex                   LumenViaeWeb.Live.Meditations.List.Row
└── filters_panel/filters_panel.ex
```

### View-model helpers

Filtering and sorting an already-loaded admin list is presentation, not
domain, so it lives next to the LiveView:
`LumenViaeWeb.Live.Meditations.Filtering` and
`LumenViaeWeb.Live.Meditations.Sets.Filtering`. They take a list of records
and a map of filters from the URL query string and return a narrowed list.
They never query.

The dividing line: "which meditations match these filter controls" is
presentation; "how many meditations should a Seven Sorrows set have" is
domain, and lives in `LumenViae.Rosary`.

---

## Components

Everything in this codebase is a **function component**. There are currently
no live components; if you reach for one, first check whether the parent
LiveView can own the state and pass it down, which is what every interactive
page here does today.

Shared components live in `components/`. Four of them are imported into
every template by `html_helpers/0` in `lib/lumen_viae_web.ex`, so they are
called bare (`<.nav />`); the rest are called by their full module name.

| Module | Purpose | Imported? |
| --- | --- | --- |
| `LumenViaeWeb.CoreComponents` | inputs, buttons, flash, modal, table | yes |
| `Components.Nav` | site navigation | yes |
| `Components.AudioPlayer` | meditation narration player | yes |
| `Components.Admin` | admin page chrome | yes |
| `Components.Footer` | site footer | no, used by the layout |
| `Components.MeditationFilters` | shared filter controls | no, called fully qualified |
| `LumenViaeWeb.Layouts` | root and app layouts | aliased |

If you add a component that most pages will use, add it to
`html_helpers/0`. Otherwise leave it fully qualified at the call site -
that keeps the global namespace small and the dependency visible.

Page-specific components live with their page and are declared with
`attr/3` so the compiler checks their call sites:

```elixir
defmodule LumenViaeWeb.Live.Meditations.List.Row do
  use LumenViaeWeb, :html

  attr :meditation, :map, required: true
  attr :sets, :list, default: []

  def row(assigns) do
    ~H"""
    ...
    """
  end
end
```

---

## Templates and partials

**A LiveView's template goes in a sibling `.html.heex` file**, never in an
inline `render/1`:

```
live/pray/index.ex
live/pray/index.html.heex
```

**Long informational pages split into partials.** Put the sections in
`_partials/` and pull them in with `embed_templates`; each file becomes a
function component named after itself:

```elixir
defmodule LumenViaeWeb.Live.Home.TrueDevotion.Index do
  use LumenViaeWeb, :live_view

  embed_templates "_partials/*"
end
```

```heex
<.devotion_comparison devotion_tab={@devotion_tab} true_marks={@true_marks} />
```

Partials receive everything they need as assigns - they read `@assigns`
passed at the call site, not the LiveView's socket. The learn pages
(`home/methods/`, `home/true_devotion/`, `home/saint_carlo/`,
`mysteries/`) all use this pattern.

---

## Where does this go?

**A new query.** Into the Secondary Context that owns the table. If it
spans tables, split it and compose in `LumenViae.Rosary`.

**A new field.** Migration, then the schema's `cast`/`validate`, then
whatever reads it.

**A new resource.** Secondary Context plus schema plus a directory, then
delegate its public functions from `LumenViae.Rosary`, then extend
`context_rules_test.exs`'s `@secondary_contexts`.

**A new page.** Pick the `live/` area from the table above, create
`{action}/{action}.ex` and `{action}.html.heex`, add the route. Break out
sub-components into their own directories as it grows; split a long
informational page into `_partials/`.

**A new piece of shared UI.** `components/` if more than one area uses it;
next to the page if not.

**Presentation logic.** Next to the LiveView that needs it. If it is a rule
about the domain rather than about the screen, it belongs in the domain
instead.

---

## Design tokens

Defined in `assets/css/app.css` and consumed as Tailwind v4 utilities.
Never hardcode a hex value in a template.

**Colors**

| Token | Value | Use |
| --- | --- | --- |
| `navy` / `navy-dark` / `navy-light` | `#003b5c` / `#002840` / `#004d75` | headings, dark panels |
| `gold` / `gold-light` / `gold-dark` | `#b18b49` / `#c9a96b` / `#8f6e38` | rules, borders, accents |
| `cream` / `cream-dark` | `#faf2e6` / `#f0e5d0` | page and section backgrounds |
| `brown` / `brown-light` | `#4a3f33` / `#7c6f5e` | body copy, captions |
| `rubric` | `#8b2f23` | chapter eyebrows, in the manuscript sense |

**Fonts**

| Utility | Family | Use |
| --- | --- | --- |
| `font-roman-uncial` | Roman Uncial Modern | display headings and the wordmark |
| `font-ovo` | Ovo | section and card headings |
| `font-work-sans` | Work Sans | body copy and UI |
| `font-garamond` | EB Garamond | quotations and captions |
| `font-cinzel` | Cinzel | small-caps eyebrows and labels |

Long passages are set upright, not italic - italics are for short asides,
citations and captions. Keep body measure around 60-65 characters
(`max-w-[60ch]`).
