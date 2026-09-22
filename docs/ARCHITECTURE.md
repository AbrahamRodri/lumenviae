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
11. [The admin console](#the-admin-console)

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
│   ├── artwork.ex             value module: licences and framing arithmetic
│   ├── categories.ex          value module: mystery category vocabulary
│   ├── labels.ex              value module: meditation set label vocabulary
│   ├── voices.ex              value module: narration voices and the S3 key layout
│   ├── mysteries.ex           Secondary Context
│   ├── mysteries/mystery.ex   schema
│   ├── meditations.ex
│   ├── meditations/meditation.ex
│   ├── meditation_sets.ex
│   ├── meditation_sets/meditation_set.ex
│   ├── set_memberships.ex
│   ├── set_memberships/set_membership.ex
│   ├── completions.ex
│   ├── completions/completion.ex
│   ├── narrations.ex          one voice's recording of one meditation
│   └── narrations/narration.ex
├── curation/                  batch services over the domain's public API
│   ├── csv_import.ex
│   ├── csv_update.ex          edit shipped meditations in place, re-record
│   ├── audio_regeneration.ex
│   ├── narration_relocation.ex  one-time move into the voices/ layout
│   └── artwork_upload.ex
├── audio/                     ElevenLabs narration
│   ├── eleven_labs.ex
│   ├── pipeline.ex
│   └── tts_text.ex
├── images/inspector.ex        image headers: format and dimensions
├── storage/s3.ex              S3 uploads, pre-signed and public URLs
├── services/geolocation.ex    IP to approximate location
├── central_time.ex            US Central offsets, calculated not looked up
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

`Repo` appears in the Secondary Contexts and nowhere else. If code outside
them needs data, it calls the Primary Context, which calls the Secondary
Context that owns the table.

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

`LumenViae.Rosary.Categories`, `LumenViae.Rosary.Labels`,
`LumenViae.Rosary.Artwork` and `LumenViae.Rosary.Voices` hold controlled
vocabulary and the pure calculations that go with it: no state, no queries,
no schema. Any layer may call them directly, including templates. They are
the single source for their lists, so `Categories.slugs/0` feeds the
changeset validations and `Categories.options/0` feeds the form selects
from the same place.

`Voices` reads the narration voices from application config rather than a
table (a voice is a deploy, not an edit) and is the one place the audio
bucket's layout is spelled out: `Voices.narration_key/2` turns a voice and a
meditation's audio filename into `voices/<slug>/<filename>`. Which voices
have actually recorded a meditation is data, and lives in the `Narrations`
Secondary Context.

`Artwork` also owns the two changesets that write the artwork columns, which
is what keeps the managed fields (`image_key` and the dimensions, written
only after an upload is proved) out of reach of the admin form's changeset.
It sits here rather than in the schema because the same split has to hold
for every future entry point.

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
`LumenViae.Services.Geolocation` is one of these: it turns an address into a
city and country through a third-party provider, owns its own cache, and is
switched off by default so no address leaves a development machine.

`LumenViae.RateLimit` sits alongside them. It is a supervised ETS counter
with no domain knowledge, used by the web layer to cap completion writes.

---

## The Office domain

`LumenViae.Office` is the codebase's second domain: the pre-Vatican II
Divine Office, served through the JSON API. It sits in
`lib/lumen_viae/office/` as a sibling of `rosary/`, follows the same
entry-point rule - nothing outside `lib/lumen_viae/office/` names its
internal modules - and owns **no tables**. That last point is structural,
not incidental: the domain's data source is the open-source Divinum
Officium engine (MIT, github.com/DivinumOfficium/divinum-officium), whose
rubrical logic nobody should reimplement, and whose answers are immutable
per date, so a cache is all the persistence the domain needs. Because it
never touches the Repo, `context_rules_test.exs` holds as written.

```
lib/lumen_viae/office.ex          Primary Context: fetch_hour, fetch_day,
                                  fetch_calendar, vocabulary; validates the
                                  web layer's raw params itself
lib/lumen_viae/office/
├── versions.ex                   value module: version/hour/language slugs
│                                 and their engine spellings - never inline
│                                 these lists
├── divinum_officium.ex           Req client; base_url swappable through
│                                 config :lumen_viae, :office (self-hosted
│                                 engine = one env var, no code change)
├── parser.ex                     the engine's HTML into sections of plain
│                                 text lines, Latin and translation
└── cache.ex                      supervised ETS, month TTL, same recipe as
                                  the geolocation cache
```

The web surface is `LumenViaeWeb.API.OfficeController` + `OfficeJSON`
under the existing unversioned `/api` scope, with `office_unavailable` in
the fallback controller for upstream trouble. See `docs/OFFICE_API.md`
for the endpoint reference.

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
| `Components.ArtworkSection` | artwork upload, framing and provenance | no, called fully qualified |
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

The public site follows the iOS app's design language ("the sanctuary"),
adapted to light backgrounds: two type families only, gold hairlines for
structure, and the app's motifs (lancet arch frames, ornament dividers,
gold capsule CTAs, Roman numerals, colophon quotes).

**Colors**

| Token | Value | Use |
| --- | --- | --- |
| `navy` / `navy-dark` / `navy-light` | `#003b5c` / `#002840` / `#004d75` | headings ink; hero and at most one accent band per page |
| `gold` / `gold-light` / `gold-dark` | `#b18b49` / `#c9a96b` / `#7f6132` | rules and borders (`gold`), gold text on light (`gold-dark`) |
| `parchment` | `#fdfaf4` | the almost-white default page ground |
| `cream` / `cream-dark` | `#faf2e6` / `#f0e5d0` | alternating section backgrounds, inset panels |
| `brown` / `brown-light` | `#4a3f33` / `#6f6353` | body copy, captions |
| `rubric` | `#8b2f23` | admin status accents only; public kickers are gold |

**Fonts**

| Utility | Family | Use |
| --- | --- | --- |
| `font-cinzel` | Cinzel | all headings, tracked-caps kickers and labels, numerals, buttons |
| `font-garamond` | EB Garamond | all body, reading, and quotation text |
| `font-cinzel-decorative` | Cinzel Decorative | the LUMEN VIAE wordmark only |
| `font-ovo` / `font-work-sans` | Ovo / Work Sans | legacy, admin surfaces only |
| `font-roman-uncial` | Roman Uncial Modern | retired from pages |

Shared vocabulary: `.btn-gold` / `<.gold_cta>` (gold capsule CTA, one filled
gold shape per screen region), `<.sacred_divider>` (hairlines, diamonds,
Latin cross), `<.arch_frame>` (lancet-arch image frame for devotional art),
`.hairline-card`, `.ornate-corners`, `.drop-cap`. Quotes are set as centered
colophons between dividers, never as filled bordered panels.

Long passages are set upright, not italic - italics are for short asides,
citations and captions. Keep body measure around 60-65 characters
(`max-w-[60ch]`).

---

## The admin console

Everything under `/admin` is a **console**, and it deliberately does not look
like the site.

The public pages are parchment, Cinzel and EB Garamond, with gold rules
around every panel. That is right for a page someone reads a paragraph of at
a time. A console is scanned, not read: it wants density, alignment, one type
family with tabular figures, and colour reserved for status so that an amber
cell means something. Every gold rule that only decorates is a rule the eye
has to discount before it can find the number it came for.

So the console keeps navy and gold for its navigation and its accents, and
takes a neutral warm-grey ground, hairline rules and Work Sans for everything
else.

**Its own layout.** `layouts/root_admin.html.heex` carries no site header and
no footer - the way out is in the navigation rail. The `:admin_layout`
pipeline in the router selects it for the `/admin` scope and for the login
page.

**Its own tokens**, in `assets/css/app.css` under `--color-admin-*`. Never
reach for a public-site colour inside the console, or a console colour
outside it.

| Token | Use |
| --- | --- |
| `admin-shell` / `admin-shell-raised` | the navigation rail, and its active row |
| `admin-canvas` | the page ground |
| `admin-surface` / `admin-sunken` | panels and tables; table headers, hover rows, insets |
| `admin-hairline` / `admin-hairline-strong` | 1px rules; input and button borders |
| `admin-ink` / `admin-ink-soft` / `admin-ink-faint` | primary, secondary and label text |
| `font-admin` | Work Sans, the console's only family |

The status families (`positive`, `caution`, `notice`, `danger`) are shared
with the site and keep their meaning here.

**Its own vocabulary**, in `LumenViaeWeb.Components.Admin`, imported globally:

| Component | Use |
| --- | --- |
| `<.admin_page>` | the shell: rail, sticky page header, canvas |
| `<.panel>` | every card; `flush` for one whose body is a table |
| `<.metric>` | one figure in a metric row, with an optional delta |
| `<.admin_badge>` / `<.category_badge>` | status pills |
| `<.field>` / `<.form_actions>` | one labelled control; the row that closes a form |
| `<.callout>` | a standing note about why a record is not behaving as expected |
| `<.filter_select>` / `<.filter_search>` / `<.filter_summary>` | filter controls and the bar under them |
| `<.day_chart>` / `<.bar_list>` | the two charts, both inline SVG and CSS - no chart library |
| `<.empty_state>` | a list with no rows |

CSS classes for the pieces that are not components: `.admin-btn` with
`-primary`, `-secondary`, `-ghost`, `-danger`; `.admin-input` and
`.admin-textarea` for forms, `.admin-field` for the shorter filter controls;
`.admin-table`; `.admin-eyebrow` for tracked-caps labels; `.admin-figure`.

### Two rules the console screens follow

**Lists default to what the public is being served.** The meditation sets
list starts on live sets, the meditations list on active meditations. The
curator's normal question is about what is in circulation; the archive is one
select away and is counted in the metric row above the table. Defaults are
left out of the query string, so a URL carries what differs from the default
view rather than the whole form.

**Every number is a link.** A count with no way through to the rows it counts
is trivia. Each metric tile and each dashboard health row lands on the admin
list already filtered to exactly those rows - which means a health check and
a list filter have to be added together, or the link goes nowhere useful.

### Health reports on live content only

The dashboard's checklist counts problems with content the public can reach.
A set hidden because one of its meditations is archived is **one** problem,
listed once under its own heading - not counted again under "no artwork",
"incomplete" and "no labels". Rows that read zero are dropped entirely, so
"nothing outstanding" means the list is genuinely empty.

The cross-resource part of that lives in the Primary Context
(`Rosary.public_meditation_ids_missing_audio/0`), and the set-shaped part is
computed in the LiveView from the already-loaded list, which is presentation
filtering in the sense described above.

### Completions are recorded on a press, never on a view

`Rosary.record_completion/2` is called from exactly two places: the
`"complete"` event in `live/pray/index.ex`, fired by the button at the end of
the last mystery, and the iOS app's `POST /api/completions`. It used to fire
when the last mystery came into view, which anything crawling the site got
for free - so the analytics counted crawlers as people who had prayed a
Rosary. Do not reattach it to navigation.

### What a completion records about where it came from

A completion carries an approximate place, the surface it was prayed on, and
the timezone and locale the client reported. None of it requires asking
anyone for anything: the place is derived from the address the request
arrives on, and on iOS the timezone and locale are read from
`TimeZone.current` and `Locale.current`, neither of which prompts. Core
Location is deliberately not used.

Four rules hold this together, and breaking any of them changes what the
published privacy policy promises:

1. **The address is truncated before it is stored.**
   `Geolocation.anonymize/1` keeps the IPv4 `/24` or the IPv6 `/48` and
   `ip_prefix` holds only that. The full address exists in memory long
   enough to do the lookup and to key the rate limit, and is never written
   down.
2. **Nothing links two completions.** No account, device or install
   identifier, however rotated. Two Rosaries from the same phone are
   indistinguishable from two prayed by strangers.
3. **The lookup never runs on the request path.**
   `record_completion/2` writes the row and fills the place in from a
   background task under `LumenViae.TaskSupervisor`. A third party being
   slow must not be felt as a slow Rosary, and a third party being down
   must not fail a completion. The cost is that a row is briefly placeless,
   and stays so for good if the lookup fails - which is why the dashboard
   shows how many rows in the period actually have a place.
4. **The privacy policy is part of the feature.**
   `live/privacy_policy/index.ex` describes all of the above, names the
   geolocation provider, and is edited in the same change as the code. It is
   also the App Store listing's policy, so it cannot be allowed to drift.

Client-supplied strings (`time_zone`, `locale`) come from a request body and
are length-bounded in the changeset. Anything that is not a string is
dropped by the controller rather than allowed to fail the completion.

### Crawlers are kept out of the figures

Two layers, guarding different things, and only the second is load-bearing.

`LumenViaeWeb.BotDetection` matches user agents. It is hygiene, not
security - an agent string is whatever the caller says it is - and it
catches the crawlers that announce themselves honestly. Its generic match is
bounded on the left so `Cubot` and its relatives are not read as bots; a new
crawler that runs a word into `bot` has to be named in `@named_agents`. A
*missing* agent is treated as unknown rather than as a bot, because the iOS
app's agent is set outside this repo and refusing a blank one would take the
app's analytics silently to zero.

`LumenViae.RateLimit` caps completions per address per hour, and is the part
that still holds when the agent string is a lie. It is keyed on the full
address, not the stored prefix, because telling neighbours apart is the
whole job. It is per-machine ETS, and production runs two machines,
so the real ceiling is twice the configured number. That is fine for what
the limit is for - stopping a script, not metering - but it is not a precise
quota. Making it exact needs a shared store, not a smaller number.

`LumenViaeWeb.ClientIP` finds the address, and reads only `Fly-Client-IP`
and the socket peer. `X-Forwarded-For` is deliberately not read from either
end.

That is the correction to a bug worth keeping in mind. The header was read
rightmost-first, on the reasoning that Fly appends the client's address so
the left of it - which is caller-supplied and spoofable - could be ignored.
Fly appends *its own* address. The first Rosary recorded in production came
from `2a09:8280:1::`, which is `FLYIO-V6-ANYCAST`, and was duly reported as
prayed in Chicago. Every completion would have agreed with every other, and
the figures would have looked entirely plausible.

The general lesson is that which entry in `X-Forwarded-For` is the client
depends on the proxy layout, which this module cannot know. So it reads the
two unambiguous things instead. **Moving off Fly, or putting a CDN in front
of it, means revisiting this module** - `Fly-Client-IP` would stop arriving
and every request would be attributed to the peer, which behind a proxy is
the proxy.

A LiveView cannot see `Fly-Client-IP` at all, because `connect_info`'s
`:x_headers` collects only headers beginning with `x-`. So
`LumenViaeWeb.Plugs.PutClientIP` reads it during the ordinary HTTP request
and puts it in the session, which is signed and therefore not editable by
the caller, and the prayer LiveView reads it from there.

`priv/static/robots.txt` asks well-behaved crawlers away from the prayer
flow, the console and the API, and asks the AI-training and SEO crawlers
away entirely. It is a request, not a fence, which is why the two layers
above exist.

### Analytics are reported in Central time

Days on the dashboard start and end in `America/Chicago`, not in UTC - a
Rosary prayed at nine in the evening in Texas belongs to that evening.
`LumenViae.CentralTime` computes the two US daylight-saving rules rather than
taking on a timezone database, and Postgres groups by local day using the
zone name from the same module, so the two halves cannot disagree.

`completed_at` is `timestamp without time zone`, which makes the Postgres
side easy to get backwards: for a naive timestamp, `AT TIME ZONE zone` means
"this value is already in `zone`" and converts *out* of it. A single
conversion therefore shifted every row the wrong way by the offset and filed
each Rosary prayed between seven in the evening and midnight Central under
the following day. The query stamps the value as UTC first and only then
converts - `(? AT TIME ZONE 'UTC') AT TIME ZONE ?` - and the doubled clause
is load-bearing.

### Signing in locally

`config/dev.exs` sets `:skip_admin_auth`, and
`LumenViaeWeb.Plugs.RequireAdmin` marks the session authenticated instead of
skipping the check - so the LiveView mount hook, the logout form and
`@is_admin` all behave exactly as they do in production. No other config file
sets the flag and `runtime.exs` never reads it.
