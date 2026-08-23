# Completion analytics

What is recorded when somebody finishes a Rosary, where it comes from, and
what the iOS app has to send.

Nothing here prompts anyone for anything. There is no location permission
dialog, no Core Location, and no tracking prompt, on either surface.

---

## What a completion row holds

| Column | Source | Example |
| --- | --- | --- |
| `meditation_set_id`, `completed_at` | The completion itself | `42`, `2026-08-22T19:11:00Z` |
| `source` | The surface it was prayed on | `"web"`, `"ios"` |
| `city`, `region`, `country`, `country_code` | Looked up from the request's address, in the background | `"Dallas"`, `"Texas"`, `"United States"`, `"US"` |
| `ip_prefix` | The request's address, truncated | `"203.0.113.0"` |
| `time_zone`, `locale` | Reported by the client | `"America/Chicago"`, `"en-US"` |

The full IP address is never stored. It exists in memory long enough to do
the geolocation lookup and to key the rate limit, and what is written down
is the IPv4 `/24` or the IPv6 `/48`.

Nothing on the row links it to any other row. There is no account, device or
install identifier, rotated or otherwise, so two Rosaries prayed on the same
phone cannot be told apart from two prayed by strangers.

---

## The iOS app

`POST /api/completions` already works unchanged. Two optional fields have
been added, and a build that sends neither behaves exactly as it does now.

```jsonc
POST /api/completions
Content-Type: application/json

{
  "meditation_set_id": 42,
  "time_zone": "America/Chicago",   // optional
  "locale": "en-US"                 // optional
}
```

### Reading the two values

Both come from settings the person chose. Neither requires a usage
description in `Info.plist`, neither triggers a prompt, and neither is Core
Location.

```swift
// iOS 16+
let timeZone = TimeZone.current.identifier                 // "America/Chicago"
let locale = Locale.current.identifier                     // "en_US"

// If you would rather send the region on its own:
let region = Locale.current.region?.identifier             // "US"
```

Send `TimeZone.current.identifier` verbatim — it is already an IANA name,
which is what the server stores and what the dashboard groups by. For
`locale`, either the full identifier or the bare region is fine; the server
stores the string as given.

### Adding it to the request

Wherever the app currently builds the completion body, add the two keys:

```swift
struct CompletionRequest: Encodable {
    let meditationSetId: Int
    let timeZone: String
    let locale: String

    enum CodingKeys: String, CodingKey {
        case meditationSetId = "meditation_set_id"
        case timeZone = "time_zone"
        case locale = "locale"
    }
}

let body = CompletionRequest(
    meditationSetId: set.id,
    timeZone: TimeZone.current.identifier,
    locale: Locale.current.identifier
)
```

### What the response looks like

Unchanged. Still `201` with the three keys the app already decodes, so no
`Codable` struct needs editing:

```json
{ "data": { "id": 1, "meditation_set_id": 42, "completed_at": "2026-08-22T19:11:00Z" } }
```

### Two responses worth handling

| Status | `error.code` | Meaning |
| --- | --- | --- |
| `403` | `automated_client` | The request's user agent looks like a crawler |
| `429` | `rate_limited` | Too many completions from this address this hour (20 per machine, and production runs two) |

Neither should happen to a real person using the app. If either starts
appearing, something is wrong with the request rather than with the person:
a `403` means the app's `User-Agent` has been set to something that reads as
a bot, and a `429` means many devices are sharing one address — a parish on
one connection, or a carrier-grade NAT.

Failing quietly is the right behaviour for both. A completion that was not
recorded is a missing analytics row, not a missing Rosary, and it is not
worth an error in front of somebody who has just finished praying.

---

## The website

Nothing to do. `LumenViaeWeb.Plugs.PutClientIP` reads `Fly-Client-IP` during
the HTTP request and puts it in the session; the prayer LiveView reads it
from there, reads the user agent from the socket, and records
`source: "web"` when Complete is pressed.

The address cannot be taken from the socket directly - `connect_info` only
carries headers beginning with `x-`, so `Fly-Client-IP` never reaches it,
and `X-Forwarded-For` cannot be read without knowing the proxy layout. An
earlier version guessed at that and attributed every website Rosary to Fly's
own proxy in Chicago.

---

## Where it shows up

The admin dashboard, under **Where Rosaries are prayed** (countries and
cities), **Website or app**, and the **From** and **How** columns of
**Recent completions**.

The location panel states how many completions in the period actually have a
place attached. Read it: the lookup is best-effort, so a ranking may cover a
fraction of the rows, and a country list drawn from a tenth of the
completions looks exactly like one drawn from all of them.

---

## Turning the lookup on and off

Geolocation is **off** by default and off in dev and test, so no address
leaves a development machine. Production turns it on through
`config/runtime.exs`:

| Variable | Default | Effect |
| --- | --- | --- |
| `GEOLOCATION_ENABLED` | `true` | `false` stops every lookup. Completions still record; they just have no place. |
| `GEOLOCATION_PROVIDER` | `ipapi_co` | `ip_api_com` switches provider. |

```bash
fly secrets set GEOLOCATION_ENABLED=false
```

### About the provider

`ipapi.co` is the default because it answers over **HTTPS** without an API
key, on a free tier of 1,000 lookups a day. Answers are cached by address
for 24 hours, so somebody praying a novena from the same sofa costs one
lookup rather than nine. The cache is per-machine, so with two machines an
address can be looked up twice - still far inside the daily allowance at
this volume.

`ip_api_com` is more generous — 45 requests a minute — but its free tier is
**plaintext HTTP only**, which means every visitor's address crosses the
open internet in the clear. It is available and not the default.

If the daily cap is ever reached, lookups return nothing and completions
carry on being recorded without a place. Nothing breaks; the coverage number
on the dashboard drops, which is the point of showing it.

---

## Accuracy, honestly

IP geolocation is roughly city-level at best and frequently only correct to
the country. It commonly reports the location of an internet provider's
exchange rather than the person, and a VPN reports the VPN. It is good
enough to answer "is anyone praying this in the Philippines" and not good
enough to answer anything about an individual — which is the same property
that makes it safe to collect.

---

## Keeping crawlers out

`priv/static/robots.txt` asks well-behaved crawlers away from the prayer
flow, the console and the API, and asks AI-training and SEO crawlers away
entirely.

That file is a request, not a fence, so the completion route is guarded in
the application as well — see `LumenViaeWeb.Plugs.GuardCompletions` and the
"Crawlers are kept out of the figures" section of
[ARCHITECTURE.md](ARCHITECTURE.md).
