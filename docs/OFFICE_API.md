# Divine Office API

The pre-Vatican II Divine Office (Breviarium Romanum), served as JSON for
the iOS app and any future client. Private in the sense that nothing
advertises it; technically it is as open as the rest of `/api`, read-only,
unauthenticated, and safe to cache.

## Where the texts come from

The rubrical engine is the [Divinum Officium
Project](https://github.com/DivinumOfficium/divinum-officium) (MIT
license): the same engine behind divinumofficium.com, which assembles each
day's office - psalms, antiphons, lessons, commemorations, precedence -
under a chosen edition of the rubrics. This codebase deliberately does not
reimplement any of that logic. `LumenViae.Office` fetches the assembled
page, parses it into structured data, caches it (the office of a given
date never changes), and serves it.

Every hour response carries a `source` object crediting the project and
linking the page it was read from. Keep that attribution.

By default the fetch goes to the public site with an identifying
User-Agent. To take their server out of the request path, run the
project's Docker image (`ghcr.io/divinumofficium/divinum-officium`)
anywhere - a small Fly app beside this one works - and set
`DIVINUM_OFFICIUM_BASE_URL` to it. Nothing else changes.

## Endpoints

All under the existing `/api` scope. No versioned prefix, per the API
contract policy in `contract_test.exs`: keys may be added, never removed
or retyped.

### GET /api/office/versions

The vocabulary: valid `version`, `hour` and `language` slugs with display
labels, and the defaults. Clients should read this rather than hardcode
lists.

### GET /api/office/calendar/:year/:month

The liturgical calendar for one month. Each day carries `date`,
`celebration` (`title` + `rank`, null on empty ferias), `detail` (the
engine's second column verbatim: label "Tempora" with the season, or a
commemoration label and text), `note` (occasional rubric notes such as
"Vespera de sequenti; nihil de praecedenti") and `letter` (the ferial
letter column).

### GET /api/office/:date

One day's calendar entry, same shape as a calendar day plus the `version`
slug. Fetches (and caches) the whole month behind the scenes, so a month
of day lookups is one upstream request.

### GET /api/office/:date/:hour

The full text of one canonical hour. `:date` is ISO 8601; `:hour` is one
of `matutinum`, `laudes`, `prima`, `tertia`, `sexta`, `nona`, `vesperae`,
`completorium`.

```
{"data": {
  "date": "2026-08-24",
  "hour": "laudes",
  "version": "rubrics-1960",
  "language": "english",
  "celebration": {"title": "S. Bartholomaei Apostoli", "rank": "II. classis"},
  "tempora": "Feria Secunda infra Hebdomadam XIII post Octavam Pentecostes ...",
  "sections": [
    {"latin": {"title": "Incipit", "note": null, "lines": ["...", "..."]},
     "vernacular": {"title": "Start", "note": null, "lines": ["...", "..."]}},
    ...
  ],
  "source": {"name": "The Divinum Officium Project", "url": "https://www.divinumofficium.com/..."}
}}
```

Sections mirror the engine's own rows: a titled section per liturgical
unit ("Incipit", "Psalmi", "Oratio"...), untitled sections for the
individual psalms and for standalone rubric rows ("Preces Feriales
{omittitur}"). `note` holds the small rubric printed after a title, braces
and all. Lines are plain text with the traditional glyphs kept
(the versicle and response marks, the cross). When the requested
`language` is `latin`, the engine prints a single column and `vernacular`
is null throughout.

## Query parameters

Every content endpoint takes:

- `version` - rubrical edition slug, default `rubrics-1960` (the 1962
  books). Others include `divino-afflatu-1954`, `reduced-1955`,
  `tridentine-1570/1888/1906`, the monastic editions and
  `ordo-praedicatorum-1962`; the versions endpoint is authoritative.
- `language` - translation slug, default `english`. Latin is always the
  left column regardless.

## Errors

The standard envelope from `ErrorJSON`:

- `400 bad_request` - malformed date, unknown slug; the message names the
  valid values.
- `404 not_found` - a day absent from its month (does not arise in
  practice).
- `503 office_unavailable` - the engine is unreachable, answered non-200,
  or answered markup the parser no longer recognizes. Retryable; the
  distinction is in the server log. Failures are never cached.

## Caching

Successful responses carry `cache-control: public, max-age=86400`.
Server-side, parsed offices live in `LumenViae.Office.Cache` (ETS, 30-day
TTL, per machine), so each distinct (version, language, hour, date) is one
upstream fetch per machine per month. The 256MB production database is
deliberately not involved.

## Testing

The suite never touches the network: `config/test.exs` routes the client
through `Req.Test`, and the parser is pinned against real saved pages in
`test/support/fixtures/divinum_officium/` (a two-column hour, the longest
hour, a single-column Latin office, and a month calendar). If the engine
ever reshapes its markup, refresh those fixtures to see exactly what
changed.
