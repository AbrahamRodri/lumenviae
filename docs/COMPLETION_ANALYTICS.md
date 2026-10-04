# Completion analytics

What is recorded when somebody finishes a Rosary, where it comes from, and
what the iOS and Android apps send.

Nothing here prompts anyone for anything. There is no location permission
dialog, no Core Location, and no tracking prompt, on any surface.

---

## What a completion row holds

| Column | Source | Example |
| --- | --- | --- |
| `meditation_set_id`, `completed_at` | The completion itself | `42`, `2026-08-22T19:11:00Z` |
| `source` | The surface it was prayed on | `"web"`, `"ios"`, `"android"` |
| `city`, `region`, `country`, `country_code` | Looked up from `ip_prefix` by a background job | `"Dallas"`, `"Texas"`, `"United States"`, `"US"` |
| `ip_prefix` | The request's address, truncated | `"203.0.113.0"` |
| `time_zone`, `locale` | Reported by a client that sends them; no build of the app does | `"America/Chicago"`, `"en-US"` |
| `prayed_aloud` | Reported by the client: was the spoken Rosary on | `true`, `false`, or `nil` when not reported |

The full IP address is never stored, and never sent to the geolocation
provider. It exists in memory long enough to key the rate limit, and what
is written down is the IPv4 `/24` or the IPv6 `/48`. The place is looked up
afterwards by an Oban job (the completion's `:locate` trigger), whose only
argument is the completion's id; the job reads the stored prefix and asks
the provider about that. Providers keep their data by network block, and
`ipapi.co` reports a /24 as its own record (`"network": "8.8.8.0/24"` for
both `8.8.8.0` and `8.8.8.8`), so the prefix places a completion exactly as
well as the full address would. The job survives a restart, and its
history is at `/admin/jobs`.

A lookup that cannot be made (a timeout, a 429, a 5xx) is retried, three
attempts in all, and then discarded. So the trigger also sweeps, at 23
minutes past every hour (`Completion.LocateScheduler`): it reads the
completions from the **last two days** that have a prefix and no country,
newest first, **at most 25** of them, and queues the lookup for each one
that has none waiting. A completion placed in the meantime drops out of
the read, and one older than two days is never asked about again, so a
provider that answers it cannot place an address is not asked about it
forever. With geolocation off the read is empty and nothing is queued
(`Completion.OnlyWhenLocating`). What is sent is unchanged: the stored
prefix, to the same provider; only the moment can be later.

Nothing on the row links it to any other row. There is no account, device or
install identifier, rotated or otherwise, so two Rosaries prayed on the same
phone cannot be told apart from two prayed by strangers.

---

## The iOS app

`POST /api/completions` takes the set and, since 4.0, whether the spoken
Rosary was on. That is the whole of what any build sends (see
docs/IOS_API_CONTRACT.md, section 6):

```jsonc
POST /api/completions
Content-Type: application/json

{
  "meditation_set_id": 42,
  "prayed_aloud": true              // 4.0 and later; a JSON boolean
}
```

Builds 1.0 to 3.0 send `meditation_set_id` alone and behave exactly as they
always did.

### Two fields the server accepts and no build sends

`time_zone` and `locale` are optional fields of the same body. No build of
the app has ever sent them, so every row the app has written has both as
null, and a timezone is still the better signal of habit (praying at six
in the morning) than a datacentre geolocation is of place. If a build ever
does send them, nothing on the server has to change:

```jsonc
{
  "meditation_set_id": 42,
  "prayed_aloud": true,
  "time_zone": "America/Chicago",   // optional; an IANA name, stored as given
  "locale": "en-US"                 // optional; stored as given, at most 32 characters
}
```

On iOS both would come from settings the person chose
(`TimeZone.current.identifier`, `Locale.current.identifier`): no usage
description in `Info.plist`, no prompt, not Core Location. The server
stores each string as given, bounds its length, and drops a value of the
wrong type rather than failing the completion over it.

The GraphQL mutation `recordCompletion` is the same write with the same
two inputs the app sends, and nothing more; see docs/GRAPHQL.md.

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
| `429` | `rate_limited` | Too many completions from this address this hour (20, counted per machine, and production runs two). Carries a `Retry-After` header, in whole seconds, until the hour ends |

Neither should happen to a real person using the app. If either starts
appearing, something is wrong with the request rather than with the person:
a `403` means the app's `User-Agent` has been set to something that reads as
a bot, and a `429` means many devices are sharing one address — a parish on
one connection, or a carrier-grade NAT. "One address" is the whole address
for IPv4 and the **/64** for IPv6: a phone or a home connection is handed a
whole /64 and, with privacy extensions, changes its address inside it as it
likes, so counting the full address gave such a caller a fresh budget on
every request. Two devices in one /64, a campus say, share a budget.

Failing quietly is the right behaviour for both. A completion that was not
recorded is a missing analytics row, not a missing Rosary, and it is not
worth an error in front of somebody who has just finished praying.

The `429` is the completion action's own rate limit, not something this route
adds: the website, this route and GraphQL's `recordCompletion` all record a
completion through the same `Completion` actions, so all three spend one
budget per address and a client does not double its allowance by using more
than one. The status, the code and the body are unchanged from when the
limit stood in front of the route; the `Retry-After` header is added and is
not read by any build. See "Rate limits" in
[ARCHITECTURE.md](ARCHITECTURE.md).

---

## The Android app

The Android app calls `/api/v2` and nothing else, so it records a
completion with `POST /api/v2/completions`, the same two attributes the
iOS app sends (docs/JSON_API.md, "Recording a completion"):

```jsonc
POST /api/v2/completions
Content-Type: application/vnd.api+json

{"data": {"type": "completion", "attributes": {"meditation_set_id": 42, "prayed_aloud": true}}}
```

Nothing in the body says which app it is. The app identifies itself by
its user agent,

```
LumenViae-Android/<versionName> (Android <release>; <model>)
```

for example `LumenViae-Android/1.0.0 (Android 14; Pixel 8)`, and the
server reads the surface from that (`LumenViae.Rosary.Completion.AppSource`):
an agent containing `Android`, in any case, is recorded as `"android"`, and
anything else, a missing agent included, as `"ios"`, because every app
build before the Android one is an iOS build and the iOS app's CFNetwork
agent names no platform.

**The app must set that agent, and never send its HTTP library's
default.** OkHttp, which Retrofit, Coil and most Android HTTP stacks use,
sends `okhttp/4.12.0`, and `okhttp` is on `LumenViae.BotDetection`'s list
because scripts use it: left at the default, every completion would answer
`403 automated_client`, which a client drops without retrying, and
Android's figures would read zero with nothing saying why. Android's stock
`Dalvik/2.1.0 (Linux; U; Android 14; ...)` would pass and be recorded as
Android, but is not what the app sends. The tests in
`test/lumen_viae_web/bot_detection_test.exs` and the two completion
suites pin all three.

The two responses worth handling, and the reason to fail quietly on both,
are the iOS app's above.

---

## The website

Nothing to do. `LumenViaeWeb.Plugs.PutClientIP` reads `Fly-Client-IP` during
the HTTP request and puts it in the session; the prayer LiveView reads it
from there, reads the user agent from the socket, and records
`source: "web"` when Complete is pressed, with `prayed_aloud` set from the
page's "Pray aloud" switch. The page is rate limited like every other way in,
by the action; a refused completion is simply not written, and the reader is
sent on as usual.

The address cannot be taken from the socket directly - `connect_info` only
carries headers beginning with `x-`, so `Fly-Client-IP` never reaches it,
and `X-Forwarded-For` cannot be read without knowing the proxy layout. An
earlier version guessed at that and attributed every website Rosary to Fly's
own proxy in Chicago.

---

## Where it shows up

The admin dashboard, under **Where Rosaries are prayed** (countries and
cities), **Website or app** (Website, iOS app and Android app, with the aloud-or-silently split under it), and the **From** and **How** columns of
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
key, on a free tier of 1,000 lookups a day. Answers are cached by prefix
for 24 hours, so somebody praying a novena from the same sofa costs one
lookup rather than nine. The cache is per-machine, so with two machines a
prefix can be looked up twice - still far inside the daily allowance at
this volume. The hourly sweep adds at most 25 lookups an hour, 600 a day,
and usually close to none: it finds only rows whose lookup failed or that
the provider could not place, and a prefix the provider could not place is
answered from that machine's cache for a day, so it costs at most one
lookup per machine per day for the two days it is swept.

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
the application as well — a crawler is refused on its user agent
(`LumenViaeWeb.Plugs.GuardCompletions`), and every address is rate limited by
the completion action (`LumenViae.Rosary.Completion.RateLimit`). See the
"Crawlers are kept out of the figures" and "Rate limits" sections of
[ARCHITECTURE.md](ARCHITECTURE.md).
