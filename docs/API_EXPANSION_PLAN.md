# Lumen Viae API expansion — implementation plan

*Prepared 19 August 2026. Every file path, count and code fact below was read out of the two repositories or queried from `lumen_viae_dev`, not assumed.*

---

## Decisions taken

Recorded 19 August 2026. Section 6 below sets out the reasoning; these are
the answers, and they override any recommendation stated there.

| # | Decision | Consequence |
| --- | --- | --- |
| 1 | Separate `lumenviae-images` bucket | Must be created by hand with a public-read policy before Stage 1 lands. The audio bucket keeps its block-public settings untouched. |
| 2 | Traditional schedule throughout | Glorious on Saturday, Joyful on Thursday. `LiturgicalCalendar`, the site copy, iOS `ScheduleService` and all 27 `days_prayed` rows change together. This visibly flips Saturday's home screen for existing users. |
| 3 | No `Marian` or `Vocation` labels | Both are subject matter and belong on the intentions axis. The four fixtures in `SelectMeditationView.swift` that advertise them are corrected instead. |
| 4 | Ship the three CC BY tracks, credited discreetly | Attribution lives in ONE unobtrusive but reachable place, not on the player. iOS: Account > About > Acknowledgements. Web: a `/credits` page linked from the footer. CC BY 4.0 section 3(a)(2) permits this - the notice must be reasonable for the medium, not prominent. Two things are not optional: it must stay reachable by a user (a source comment or a checked-in file does not satisfy the licence), and every string must say "edited", because the pipeline loops, normalizes and folds to mono, which section 3(a)(1)(B) counts as an adaptation. No organist commissioned for now. |
| 5 | Voices: plumbing only, generate nothing | Schema, `Voices` value module, API fields and admin UI ship with the existing default voice alone. Zero ElevenLabs spend; coverage can be turned on per set later. |
| 6 | No abandonment events | Completion analytics stay descriptive. Nothing that identifies a device or traces a user who stopped praying. |

**S3 key scheme.** Descriptive keys, not meditation ids:
`narration/<voice>/<category>_<author>_<n>.mp3`. The bucket stays readable
when browsed, at the cost of a key that has to be rewritten if a set is
renamed or a meditation re-attributed. The rename runs **before** any second
voice is generated - 143 files now rather than 570 later - copy-first, verify,
then delete the old keys after the presigned window has drained.

---


## Status

Updated 19 August 2026. Read this before picking up any stage: the stages
are not being worked in order, and one of them is half done.

**Nothing below is deployed.** Every code change is local; production is
still running the old API. `audio_expires_at` is absent from the live
response, which is the correct way to check.

### Stage 0 - DONE

`test/lumen_viae_web/controllers/api/contract_test.exs` holds the shipped-key
lists for all five endpoints and was verified in both directions: removing
`description` from the set summary fails with the field named, adding
`image_url` passes. The exact-map-equality assertion in
`meditation_set_controller_test.exs` was replaced with field-by-field checks.

### Stage 1 - DONE

Done, outside the repo:

* `lumenviae-images` created in account 536691528861, us-east-2. Bucket
  policy allows `s3:GetObject` and nothing else; public ACLs blocked so the
  policy is the only grant; AES256 default encryption. Verified from
  outside AWS: anonymous GET 200, anonymous LIST 403, anonymous PUT 403,
  and `lumenviae-audio` still 403.
* Both IAM users scoped to the two buckets with an explicit `Deny` on
  bucket policies, ACLs, public-access-block and bucket create/delete. See
  `docs/PROD_ACCESS.md`.

Done, in the repo:

* `config/runtime.exs` - `:aws_s3_public_bucket` and `:public_asset_base_url`
* `.env` - `AWS_S3_PUBLIC_BUCKET`. No Fly secret is needed; `runtime.exs`
  defaults to `lumenviae-images`.
* `S3.public_url/1` and `S3.upload_public/3`. The public URL is
  **path-style** - `https://s3.us-east-2.amazonaws.com/lumenviae-images/<key>`
  - because it is derived from the same `ExAws.Config` the presigner uses
  and that config carries no `%{bucket}` placeholder. A test asserts the
  two builders agree about bucket addressing, so neither can drift alone.
* `lib/lumen_viae/images/inspector.ex` - JPEG and PNG header parsing, no
  dependency, checked against the two real images already in
  `priv/static/`. It refuses a frame segment cut short of its own declared
  length rather than reporting plausible dimensions for a truncated file.
* `lib/lumen_viae/curation/artwork_upload.ex` - the rules (12 MB, JPEG,
  short side at least 1200px, long side at most 4000px, no CMYK) and the
  content-addressed key. `prepare/3` is public so the rules and the naming
  can be tested without a network round trip; nothing in the suite reaches
  S3.

### Stage 2 - DONE

Migration `20260820120000_add_artwork_to_meditation_sets.exs`,
`LumenViae.Rosary.Artwork` with the two changeset builders, the four
`MeditationSets` functions, the `Rosary` delegates and `artwork_url/1`, and
`ArtworkJSON` merged into both the summary and the detail. `"artwork"` is
in `@value_modules` and `docs/ARCHITECTURE.md` names it in both the
directory tree and the "Value modules" section. The migration has run
locally only.

Two behaviours to know before Stage 4 builds the form:

* Ecto replaces an empty value with the field's **default**, so a blank
  focal input reads as "centred", not "leave it alone". The form has to
  render the stored value into the input, or saving an otherwise untouched
  form quietly recentres the painting.
* The publish gate lives in `ArtworkJSON`, not in the changeset. A set with
  a key but no alt text and no licence saves fine and serves
  `image_url: null` - which is the intended behaviour, and is why the first
  upload on a bare set is not deadlocked.

### Stage 3 - DONE

Migration `20260820120100_add_attribution_to_meditation_sets.exs`, the
virtual `derived_author` and `derived_source`,
`Meditations.list_attribution_by_ids/1`, `Rosary.resolve_attribution/1`
wrapped around the three visible-set reads, the JSON fallback, and
`set_summary/1` and `set_detail/2` promoted to public. `set_author` and
`set_source` are in `@known_columns`, create-only like `set_description`.

`docs/CSV_IMPORT_GUIDE.md` had no meditation set columns in it at all,
despite CLAUDE.md saying it documented them. It now has a Meditation Set
Columns section covering all seven, including the create-only rule and the
fact that a CSV cannot carry artwork.

### Stage 4 - DONE

`ArtworkSection` under `live/meditations/sets/edit/`, the `FocalPoint` hook,
five handlers on `edit.ex`, and a "Sets without artwork" stat on the admin
dashboard. Verified in a browser against a real painting: the crosshair sits
on the stored focal point, and all three crops frame from it at the right
aspect ratios (393/470, 11/10, 1/1).

Two deviations from the stage as written:

* **Author and Source went into the Set Details card, not the artwork
  details form.** They are the set's byline, edited by the set changeset;
  the artwork form edits the painting's own title, artist, year, source and
  licence through a different changeset. One form spanning two changesets
  would have needed extra machinery to say something the layout says for
  free - and putting "who wrote these meditations" next to "who painted
  this picture" invites a curator to confuse them.
* **No `artwork=missing` filter on the sets list.** The dashboard stat links
  to the unfiltered list. Adding the filter would have meant a new
  dimension in `Sets.Filtering`, four call sites in `list.ex` and a select
  in the filter bar, which is more surface than one stat justifies.

The focal point debounces at 150ms in the hook and the crosshair is moved
client-side, so dragging does not produce a burst of writes whose replies
land out of order. `nudge_focal` uses `Float.parse/1`; a test feeds it
`delta="1"` because `String.to_float/1` would have raised on it and taken
the LiveView down.

### Stage 6 - PARTLY DONE

Done: `:audio_url_ttl_seconds` (86400, was 3600), `Rosary.audio_url_ttl/0`,
`Rosary.fetch_meditation_audio/1`, `GET /api/meditations/:id/audio` with its
controller and route, `MeditationJSON.audio/1`, `audio_expires_at` on the set
detail, `Cache-Control: private, no-store` on both responses carrying
presigned URLs, and tests.

Still to do: the single error envelope (`error_json.ex`, plus fallback
clauses for `:not_found`, `{:bad_request, message}`, changesets, **and a
catch-all** - `PrayerController.audio` returns `{:error, reason}` verbatim
from S3, so `{:error, :missing_credentials}` raises `FunctionClauseError`
today), and `Rosary.fetch_visible_meditation_set/1`.

### Content and infrastructure changes not in any stage

* The ten orphaned Liguori discursive meditations were deleted from
  production (149 meditations to 139) at the owner's request. A snapshot
  taken immediately before is in `priv/repo/snapshots/`.
* `joyful_liguori_disc_2.mp3` deleted from S3 (147 objects to 146). The
  catalogue now reconciles cleanly: every meditation with an `audio_url`
  resolves to a real object, and nothing dangles.
* Three unreferenced objects remain and were deliberately left:
  `Glorious-Annunciation-Intro-1.mp3`, `Glorious-Ascension-Intro-2.mp3`,
  `Sorrowful-Scrupulous-1.mp3`.
* `sync_prod_db.sh` refreshes the local database from a production
  snapshot, one way only.

### Where to start next

The server side of the iOS request is complete and none of it is deployed.
The next move is a deploy, because everything after this needs it: the
migrations have run locally only, `lumenviae-images` is empty, and all 27
sets answer `image_url: null` until somebody uploads paintings through the
admin form.

After that, either Stage 5 (the iOS hero and byline, in the app repo) or the
rest of Stage 6 (the single error envelope, which is the last thing in the
API that can still raise a `FunctionClauseError` at a client).

The S3 rename (descriptive keys, see Decisions taken) should happen before
any second narration voice is generated, but is independent of the artwork
work and can go either side of it.

---

## 1. What the API is today

The API is five endpoints and about 200 lines of code: `GET /api/meditation-sets` (summary list, optionally by category), `GET /api/meditation-sets/:id` (detail with ordered meditations and freshly presigned audio), `GET /api/mysteries`, `POST /api/completions`, and `GET /api/prayers/:id/audio` for four consecration chants whose S3 keys are hardcoded as a module attribute inside `lib/lumen_viae_web/controllers/api/prayer_controller.ex`. Controllers are thin, every response is `{"data": ...}`, and the whole thing is backed by `LumenViae.Rosary` as the domain's only entry point. It works, and it says very little: a set summary carries `id`, `name`, `category`, `description`, `labels` and nothing else.

The iOS side has filed a written request — `/Users/abrahamrodri/Developer/ios/app/API_REQUEST_MEDITATION_SET_DETAIL.md` — because the meditation picker was rebuilt in August 2026 and tapping a set now opens a **set detail** screen with a full-bleed painting. Everything on that screen comes from the API except the artwork, which today borrows the mystery category's bundled canvas. The request asks, in priority order: (1) set artwork on both endpoints, served from a **stable public cacheable URL, not a presigned one**, because `OfflineContentService` caches images to disk; (2) per-meditation artwork later; (3) `author` and `source` at the set level so a byline can render from the summary; (4) a ruling on two label words the picker's previews assume; and (5) an `intentions` field, explicitly marked *do not build yet*.

Two things in the current implementation are actually broken rather than merely thin. Meditation `audio_url` presigns for **3600 seconds** (`S3.generate_presigned_url/2`'s default), while `OfflineContentService.downloadAll` collects roughly 150 URLs in stage one and downloads them serially in stage two — and on retry it re-reads `audio_url` out of `sets/<id>.json` written hours earlier, which is always dead. And there are three sources of truth for what to pray on Saturday: `LumenViae.LiturgicalCalendar.recommended_mysteries/1` says Glorious, the iOS `ScheduleService` says Joyful, and the seeded `mysteries.days_prayed` strings put Glorious on Thursday, which is neither schedule.

---

## 2. The plan in order

Fourteen stages. Each is independently shippable and each is one commit. Stage 0 is a prerequisite for everything after it.

---

### Stage 0 — Rewrite the API contract test

**Delivers:** a test that fails when a shipped key disappears and passes when a key is added. Without this, the first additive change lands red.

`test/lumen_viae_web/controllers/api/meditation_set_controller_test.exs` currently asserts exact map equality (verified, around line 67):

```elixir
assert summary == %{
         "id" => set.id,
         "name" => "Shape Check",
         "category" => "joyful",
         "description" => "A description",
         "labels" => []
       }
```

Every stage below breaks this. Replace it, and add a new `test/lumen_viae_web/controllers/api/contract_test.exs` holding the shipped-key lists for all five endpoints:

```elixir
@shipped_summary_keys ~w(id name category description labels)
@shipped_detail_keys  ~w(id name category description labels meditations)
@shipped_meditation_keys ~w(id title content author source audio_url mystery)
@shipped_mystery_keys ~w(id name category order days_prayed description scripture_reference)

test "the shipped summary keys are never removed or retyped", %{conn: conn} do
  set = create_set(%{name: "Shape Check", description: "A description"})
  [summary] = conn |> get(~p"/api/meditation-sets?category=joyful") |> json_response(200) |> Map.fetch!("data")

  for key <- @shipped_summary_keys, do: assert Map.has_key?(summary, key)
  assert is_integer(summary["id"]) and summary["id"] == set.id
  assert summary["labels"] == [] and is_list(summary["labels"])
end
```

That file **is** the versioning policy, enforced. No `/api/v1`.

**Migrations:** none. **Unblocks:** everything.

---

### Stage 1 — Public asset bucket, S3 module, image inspector

**Delivers:** somewhere to put images and a way to validate them. No API change, nothing user-visible.

**AWS, done by hand once.** Create a **separate bucket** `lumenviae-images` (us-east-2), not a public prefix on `lumenviae-audio`. The research argued for the prefix; the review found the inventory behind that argument was wrong — `lumenviae-audio` is not flat, it carries a `prayers/` prefix (four objects, verified in `prayer_controller.ex`) alongside root-level MP3s. A second bucket makes the blast radius of a policy mistake zero, uses the same IAM credentials, and costs one config line. Bucket policy grants `s3:GetObject` to `*` on the whole bucket, because there is nothing private in it.

Before touching anything, inventory the real audio bucket so the record is accurate:

```
aws s3 ls s3://lumenviae-audio --recursive | awk -F/ '{print $1}' | sort -u
```

**Config** (`config/runtime.exs`, next to the existing `:aws_s3_bucket` line):

```elixir
config :lumen_viae, :aws_s3_public_bucket, System.get_env("AWS_S3_PUBLIC_BUCKET") || "lumenviae-images"

# Where public assets are read from. Defaults to the bucket's own endpoint;
# set PUBLIC_ASSET_BASE_URL to a CloudFront distribution to move artwork
# behind a CDN without touching the database - only S3 keys are stored.
config :lumen_viae, :public_asset_base_url, System.get_env("PUBLIC_ASSET_BASE_URL")

config :lumen_viae, :audio_url_ttl_seconds,
  String.to_integer(System.get_env("AUDIO_URL_TTL_SECONDS") || "86400")
```

**`lib/lumen_viae/storage/s3.ex`** — three additions. Note `public_base_url/0` derives its host from the same `ExAws.Config` the presigner uses, rather than hardcoding a virtual-hosted template; the existing `config :ex_aws, :s3, host:` has no `%{bucket}` placeholder, and two builders that disagree about bucket addressing will drift the first time that host changes.

```elixir
@doc "Uploads a binary to the public assets bucket. Never sets an object ACL."
@spec upload_public(binary, String.t(), keyword) :: {:ok, String.t()} | {:error, term}
def upload_public(binary, key, opts \\ [])

@doc """
Stable, unsigned, cacheable URL for an object in the public assets bucket.

Unlike `generate_presigned_url/2` this signs nothing and expires never:
artwork lives in a public bucket so the client can cache it for offline
prayer. Returns nil for a nil or empty key.
"""
@spec public_url(String.t() | nil) :: String.t() | nil
def public_url(key)
```

Upload headers are fixed: `content_type: "image/jpeg"`, `cache_control: "public, max-age=31536000, immutable"`. Keys are content-addressed (below), so an immutable year-long cache needs no invalidation story.

**`lib/lumen_viae/images/inspector.ex`** — new infrastructure directory beside `audio/` and `storage/`, knows nothing about the domain. The production image carries **no image library** (verified: the Dockerfile runner installs only `libstdc++6 openssl libncurses5 locales ca-certificates`), so nothing can be resized or re-encoded server-side. What is actually needed is validation, and that comes out of the JPEG header in about sixty lines of pattern matching with no dependency:

```elixir
@type info :: %{format: :jpeg | :png, width: pos_integer, height: pos_integer, components: pos_integer}

@spec inspect(binary) :: {:ok, info} | {:error, :unsupported_format | :malformed}
```

Frame headers `SOF0..SOF15` carry the dimensions; `0xC4`, `0xC8` and `0xCC` share that range and are not frames. `components == 4` means CMYK, which iOS renders with shifted colour, so it is rejected. Drop the `icc_profile?` field the research proposed — it was computed, threaded through the parser, and then read by nothing.

**`lib/lumen_viae/curation/artwork_upload.ex`** — sits above the domain like `CsvImport`, so the admin LiveView and any future entry point validate and name objects identically:

```elixir
@spec upload(binary, :set | :meditation, pos_integer) :: {:ok, map} | {:error, String.t()}
def upload(binary, scope, id)
```

Rules: max 12 MB, JPEG only, short side ≥ 1200px, long side ≤ 4000px, no CMYK. Key shape `sets/27/8f21c4d9e0b3a7f6.jpg` where the hex is the first 16 characters of `sha256(bytes)`. Replacing a painting writes a new key, so the URL changes and every cache in the chain — S3, CDN, `URLCache`, the iOS offline manifest — invalidates itself with no purge. Returns `%{"image_key" => key, "image_width" => w, "image_height" => h, "image_updated_at" => ts}`.

Superseded objects are **not** deleted. A client holding the old URL that has not fetched it yet would 404 and drop to the bundled painting. Orphans are a few megabytes; delete them by hand if it ever matters. No sweep task.

**Files:** `lib/lumen_viae/storage/s3.ex`, `lib/lumen_viae/images/inspector.ex`, `lib/lumen_viae/curation/artwork_upload.ex`, `config/runtime.exs`, `test/lumen_viae/images/inspector_test.exs`, `test/lumen_viae/curation/artwork_upload_test.exs`, `docs/ARCHITECTURE.md` (add `images/inspector.ex` to the directory tree).

**Unblocks:** nothing on its own. This is the floor for Stage 2.

---

### Stage 2 — Set artwork: columns, framing, API fields

**Delivers:** the thing the iOS set-detail screen is waiting on.

**Migration** `priv/repo/migrations/20260820120000_add_artwork_to_meditation_sets.exs`:

```elixir
def change do
  alter table(:meditation_sets) do
    add :image_key, :string                              # S3 key, never a URL
    add :image_width, :integer
    add :image_height, :integer
    add :image_focal_x, :float, null: false, default: 0.5
    add :image_focal_y, :float, null: false, default: 0.5
    add :image_alt, :text
    add :image_title, :string
    add :image_artist, :string
    add :image_year, :string                             # string: "c. 1505", "1601-02"
    add :image_source_url, :string
    add :image_license, :string
    add :image_updated_at, :utc_datetime
  end

  create constraint(:meditation_sets, :image_focal_x_in_range,
           check: "image_focal_x >= 0.0 AND image_focal_x <= 1.0")

  create constraint(:meditation_sets, :image_focal_y_in_range,
           check: "image_focal_y >= 0.0 AND image_focal_y <= 1.0")
end
```

**Why a normalized focal point rather than the point offset you asked for.** The app renders the same painting at three crop sizes — a 470pt hero, a 160pt home card, a 40pt mini-player thumbnail — and `MysteryCategory.cardImageOffset` (-48pt for the Pietà) was tuned against exactly one of them. Take a 1200×1800 canvas in the 176×160 card: fill scale 0.1467, drawn 176×264, vertical overflow 104pt, so -48 is nearly half of it. The same painting in the 393×470 hero overflows 119.5pt with a completely different relationship to the subject, and in the 40pt thumbnail it overflows 20pt, so -48 pushes the subject clean out of frame. A focal point of `(0.5, 0.24)` means "the faces are 24% down the canvas" and is true at every size, in every future crop, and in CSS `object-position` — so the admin preview and the phone agree by construction. Given crop frame `F`, intrinsic `I`, focal `f`:

```
scale  = max(F.w / I.w, F.h / I.h)
drawn  = (I.w * scale, I.h * scale)
offset = ((0.5 - f.x) * (drawn.w - F.w), (0.5 - f.y) * (drawn.h - F.h))
```

`f = 0.5` reproduces today's centred `.fill` exactly; `f.y = 0` reproduces `.top`; everything between is reachable, which the nine SwiftUI alignments are not.

**`image_zoom` is deliberately not here.** The research proposed it; nothing has demonstrated a painting a focal point cannot frame, and it costs a column on two tables, a constraint, a validation, an API key on two endpoints, a Swift property on two structs, a form input and a multiplication in the crop formula. Dropping it before the migration lands is free.

**Flat columns, not a jsonb embed.** `context_rules_test.exs` asserts each Secondary Context owns exactly one file under its directory, so an `embeds_one` at `rosary/meditation_sets/artwork.ex` fails the build.

**`lib/lumen_viae/rosary/artwork.ex`** — value module beside `categories.ex` and `labels.ex`: the licence vocabulary and the framing arithmetic, needed by the schema validations, the admin selects and the JSON view. **Two changeset builders, not one** — this is the correction that matters:

```elixir
# Written only by ArtworkUpload, which has just proved the object exists in S3.
@managed_fields ~w(image_key image_width image_height image_updated_at)a

# Written by the admin form.
@editable_fields ~w(image_focal_x image_focal_y image_alt image_title
                    image_artist image_year image_source_url image_license)a

@licenses ~w(public_domain cc0 cc_by cc_by_sa licensed unknown)

def cast_upload(struct, attrs)     # casts @managed_fields ++ @editable_fields
def cast_metadata(struct, attrs)   # casts @editable_fields only

@doc """
The coarse "top" | "center" | "bottom" the iOS request asked for, derived
from image_focal_y rather than stored beside it, so the two can never
disagree.
"""
def alignment(focal_y)
```

Without the split, `handle_event("update_artwork_meta", %{"artwork" => params}, ...)` forwards raw params into a changeset that casts `image_key` and `image_width`, so a crafted post can point a set at an arbitrary key or desync the dimensions the iOS hero uses to reserve its crop.

**Alt text and licence are a publish gate, not a save gate.** The research put `validate_required([:image_alt, :image_license])` in the changeset whenever `image_key` is present. That deadlocks: `ArtworkUpload.upload/3` returns only the four managed fields, so the very first upload on a set that has never had artwork is invalid and the curator can never get past it. Instead the changeset requires neither, and `ArtworkJSON.data/1` returns the absent block unless `image_alt` **and** `image_license` are both present. Artwork with no description and no provenance simply is not served — which is the actual rule you want, and it protects any future entry point too.

**Schema** `lib/lumen_viae/rosary/meditation_sets/meditation_set.ex` — add the twelve fields plus:

```elixir
def artwork_changeset(set, attrs), do: Artwork.cast_upload(set, attrs)
def artwork_metadata_changeset(set, attrs), do: Artwork.cast_metadata(set, attrs)
```

`changeset/2` is left alone: artwork is not castable there, for the same reason `archived_at` is not castable on `Meditation`.

**Secondary Context** `lib/lumen_viae/rosary/meditation_sets.ex`: `update_artwork/2`, `update_artwork_metadata/2`, `change_artwork/2`, `count_missing_artwork/0`. No index on `image_key` — the table holds 27 rows, so the planner would never choose one.

**Primary Context** `lib/lumen_viae/rosary.ex`:

```elixir
defdelegate update_meditation_set_artwork(set, attrs), to: MeditationSets, as: :update_artwork
defdelegate update_meditation_set_artwork_metadata(set, attrs), to: MeditationSets, as: :update_artwork_metadata
defdelegate change_meditation_set_artwork(set, attrs \\ %{}), to: MeditationSets, as: :change_artwork
defdelegate count_meditation_sets_missing_artwork(), to: MeditationSets, as: :count_missing_artwork

@doc "Stable public URL for a set's or a meditation's artwork, or nil."
def artwork_url(%{image_key: key}), do: S3.public_url(key)
def artwork_url(_), do: nil
```

**Shared renderer** `lib/lumen_viae_web/controllers/api/artwork_json.ex`, following the existing `*_json.ex` convention. Both `set_summary/1` and `set_detail/1` in `meditation_set_json.ex` gain one `Map.merge(ArtworkJSON.data(set))`. No controller change — building an artwork URL is pure string work with no signing and no I/O, so it belongs in the view.

**Required companion edits, in the same commit or the build fails:** add `"artwork"` to `@value_modules` in `test/lumen_viae/rosary/context_rules_test.exs` (the web layer may only name `LumenViae.Rosary` plus the value modules), and add `artwork.ex` to both the directory tree **and** the "Value modules" section of `docs/ARCHITECTURE.md` — the doc names Categories and Labels in two places and leaving one stale on day one is the drift this plan is trying to avoid.

**Resulting JSON:**

```json
{
  "data": [
    {
      "id": 27,
      "name": "Blessed Fulton J. Sheen",
      "category": "sorrowful",
      "description": "Meditations on the Sorrowful Mysteries from Bishop Fulton J. Sheen",
      "labels": ["Considerations"],
      "image_url": "https://s3.us-east-2.amazonaws.com/lumenviae-images/sets/27/8f21c4d9e0b3a7f6.jpg",
      "image_alignment": "top",
      "image_focal_x": 0.5,
      "image_focal_y": 0.24,
      "image_width": 1600,
      "image_height": 2400,
      "image_alt": "Christ falls beneath the cross on the road out of the city.",
      "image_attribution": {
        "title": "Christ Carrying the Cross",
        "artist": "El Greco",
        "year": "c. 1580",
        "source_url": "https://www.metmuseum.org/art/collection/search/436574",
        "license": "public_domain"
      }
    },
    {
      "id": 30,
      "name": "St. Alphonsus Liguori - Short",
      "category": "sorrowful",
      "description": null,
      "labels": ["Saints", "Considerations"],
      "image_url": null,
      "image_alignment": null,
      "image_focal_x": null,
      "image_focal_y": null,
      "image_width": null,
      "image_height": null,
      "image_alt": null,
      "image_attribution": null
    }
  ]
}
```

Every key is null when the set has no artwork, so the client branches on `image_url` alone and a partially populated catalogue degrades exactly as the request document describes.

**Unblocks:** §1 of the iOS request — the set-detail hero.

---

### Stage 3 — Set author and source

**Delivers:** §3 of the iOS request. A byline on the shelf and the hero, before any set is loaded.

**Migration** `priv/repo/migrations/20260820120100_add_attribution_to_meditation_sets.exs`:

```elixir
alter table(:meditation_sets) do
  add :author, :string
  add :source, :text
end
```

**Columns plus derivation, not either alone.** Derivation alone (all-meditations-agree wins, else nil) is free to curate and never stale, but produces nothing for the common case of four Emmerich passages and one Liguori — precisely where a curator wants to write "Bl. Anne Catherine Emmerich". Columns alone go stale when a meditation's attribution is corrected. Do both: the column always wins, the derivation fills the gap.

**Critical correction:** the derivation must **not** be written into the persisted fields. The research wrote `%{set | author: set.author || unanimous(...)}`, which means any later `Rosary.change_meditation_set/2` on that struct — an admin form prefilled from a public reader, a re-save — persists the derivation as an explicit override, which is exactly the staleness the design exists to avoid. Use virtual fields:

```elixir
# in the schema
field :derived_author, :string, virtual: true
field :derived_source, :string, virtual: true
```

```elixir
# lib/lumen_viae/rosary/meditations.ex - new id-shaped query
@spec list_attribution_by_ids([integer()]) :: %{integer() => %{author: String.t() | nil, source: String.t() | nil}}
def list_attribution_by_ids(ids)

# lib/lumen_viae/rosary.ex - composition, two queries for any number of sets
@doc """
Fills in each set's derived byline. An explicit author/source on the set
always wins; otherwise it is derived from the set's meditations, and only
when every meditation agrees - a mixed set gets nil rather than a
misleading name. Writes only the virtual fields.
"""
@spec resolve_attribution([struct()] | struct()) :: [struct()] | struct()
def resolve_attribution(sets)
```

Wrap it around `list_visible_meditation_sets/0`, `list_visible_meditation_sets_by_category/1` and `get_visible_meditation_set_with_ordered_meditations!/1`. The JSON renders `set.author || set.derived_author`.

**Also in this commit:** promote `set_summary/1` and `set_detail/1` in `meditation_set_json.ex` from `defp` to `def` with a `@doc` naming them the canonical set shapes. They are currently private, and two later stages need to reuse them.

**CSV:** add `set_author` and `set_source` to `@known_columns` in `lib/lumen_viae/curation/csv_import.ex` (create-only, like `set_description`) and document them in `docs/CSV_IMPORT_GUIDE.md`. Do **not** add `set_image_filename` — a CSV cannot carry the bytes, so the column could only name an object someone uploaded by other means, and it would be silently ignored on rows two through five.

```json
{
  "id": 30,
  "name": "St. Alphonsus Liguori - Short",
  "category": "sorrowful",
  "author": "St. Alphonsus Liguori",
  "source": "The Glories of Mary",
  "labels": ["Saints", "Considerations"]
}
```

**Unblocks:** the detail byline, in the same iOS change as the hero.

---

### Stage 4 — Admin: artwork and attribution on the set form

**Delivers:** the only way artwork actually gets into the catalogue.

**New component** `lib/lumen_viae_web/live/meditations/sets/edit/artwork_section/artwork_section.ex`, module `LumenViaeWeb.Live.Meditations.Sets.Edit.ArtworkSection`, mirroring the `labels_section` directory already there. Rendered from `edit.html.heex` directly under the labels card.

Layout, in design tokens only (`bg-cream`, `border-gold`, `text-navy`, `text-brown`, `font-cinzel`, `font-ovo`, `font-work-sans` — the existing set-edit template uses `font-crimson`, which is not in `assets/css/app.css` and not in the ARCHITECTURE.md token table; do not propagate it):

- **Left:** the whole painting at `max-h-[28rem]` inside `<div id="focal-target" phx-hook="FocalPoint" class="relative cursor-crosshair">`, with a gold crosshair absolutely positioned at `left: focal_x*100%; top: focal_y*100%`.
- **Right:** three live crops, each `<img class="w-full h-full object-cover" style={"object-position: #{x*100}% #{y*100}%"}>` — `aspect-[393/470]` "Set detail hero", `aspect-[11/10]` "Home card", `aspect-square` "Mini player". CSS `object-position` takes the same normalized pair the API returns and SwiftUI consumes, so what the curator sees is what the phone renders.
- **Upload:** the file input must sit inside a form carrying both bindings, matching the shape already used in `live/admin/meditations_import/import/import.html.heex`:

```heex
<.form for={%{}} phx-change="validate_artwork" phx-submit="upload_artwork" phx-drop-target={@uploads.artwork.ref}>
  <.live_file_input upload={@uploads.artwork} class="hidden" />
</.form>
```

- **Details form** (`phx-submit="update_artwork_meta"`): alt text (textarea, "Describe what is shown, for readers using VoiceOver"), painting title, artist, year (free text), source URL, licence select, plus Author and Source for the set itself.

**LiveView** `edit.ex` gains `allow_upload(:artwork, accept: ~w(.jpg .jpeg), max_entries: 1, max_file_size: 12_000_000)` and five handlers. Two details the research got wrong:

- `nudge_focal` must use `Float.parse/1`, not `String.to_float/1` — the latter raises `ArgumentError` on any integer-looking string, so a template emitting `delta="1"` crashes the LiveView.
- The focal-point hook must **debounce**. Every click currently writes to the database and re-renders; a curator dragging the crosshair produces a burst of `Repo.update` calls and the socket re-assigns from whichever reply lands last. Either debounce the `pushEvent` to ~150ms, or hold the focal point in socket assigns and persist on an explicit Save. Debounce is simpler and keeps the "what you see is persisted" property.

**Hook** `assets/js/hooks/focal_point.js`, registered in `assets/js/hooks/index.js` beside `AudioPlayer`: clamp `(clientX - box.left) / box.width` to 0-1, three decimals, debounced push.

**Admin dashboard:** add a "Sets without artwork" stat beside the existing missing-audio count. Note the file is `lib/lumen_viae_web/live/admin/dashboard/dashboard.ex` plus `dashboard.html.heex` — the markup change goes in the `.heex`.

**Unblocks:** nothing on the client; this is what makes stages 2 and 3 usable.

---

### Stage 5 — iOS: hero, byline, offline artwork

**Delivers:** the screen. This is the client half of stages 2-4.

**`app/Models/MeditationSet.swift`** — both structs. Three corrections on the research, each of which is a real defect:

1. **Write the detail struct's `CodingKeys` explicitly and include `meditations`.** `MeditationSet` has no `CodingKeys` today and relies on synthesis. Adding an enum and omitting `case meditations` does not throw — the property is optional, so it silently decodes to `nil`, `meditationCount` becomes 0, `hasAudio` becomes false, and the prayer screen has nothing to show.

2. **`imageUrl` is `String?`, not `URL?`.** `Meditation.audioUrl` is `String?` and `OfflineContentService.download(with:from:)` takes a `String` and does `URL(string:)` itself. `decodeIfPresent(URL.self, ...)` on a present-but-unparseable string throws `DecodingError` and fails the **entire response** — one bad artwork key would break the whole set list.

3. **No `UnitPoint` in the model.** `MeditationSet.swift` imports only `Foundation`, and the structs are declared `nonisolated Codable` specifically so offline reads decode off the main actor. Keep `imageFocalX`/`imageFocalY` as `Double?` and put the `UnitPoint` conversion on the view side, or on the `artwork` value the detail view model exposes.

```swift
struct MeditationSetSummary: nonisolated Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let category: String
    let description: String?
    let labels: [String]?

    // Artwork. Nil for a set with no painting: fall back to the category's
    // bundled canvas exactly as before.
    let imageUrl: String?
    let imageFocalX: Double?
    let imageFocalY: Double?
    let imageWidth: Int?
    let imageHeight: Int?
    let imageAlt: String?
    let author: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, description, labels, author, source
        case imageUrl = "image_url"
        case imageFocalX = "image_focal_x"
        case imageFocalY = "image_focal_y"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
        case imageAlt = "image_alt"
    }
}
```

`MeditationSet` takes the same properties plus `case meditations` in its enum.

**`FocalFill`** — a small view replacing the `.overlay(alignment:)` + `.offset(y:)` pair in `MeditationSetDetailView.hero(height:)`, `MysteryCard` and `MiniPlayerPill`, implementing the three-line formula from Stage 2. `image_width`/`image_height` let `intrinsic` be known before the bytes arrive, so the hero reserves the right crop and does not jump when the download lands. `MysteryCategory.cardImageOffset` can then be retired in favour of a per-category focal point (the Pietà becomes roughly `UnitPoint(x: 0.5, y: 0.30)`), so bundled fallbacks and API artwork obey one rule.

**Offline** — `OfflineContentService` gains `images/set_<id>.jpg` beside `sets/` and `audio/`. Because the S3 key carries a hash of the file, "is my copy stale" is a string comparison, never a HEAD request. **Decide explicitly** whether an existing offline set is treated as stale by this change: it must not be, or every user re-downloads a full audio library to get a few hundred KB of images. Gate on the image being absent, not on the manifest version.

**Fallback chain, in one place:** meditation image → set image (with the set's focal point) → `category.cardImageName`.

**Unblocks:** ship it. §1 and §3 of the iOS request are done.

---

### Stage 6 — Audio URL lifetime, per-meditation audio endpoint, one error envelope

**Delivers:** repair of a live failure, plus a consistent error shape while the code is open.

`get_meditation_audio_url/1` calls `S3.generate_presigned_url!/1` with no opts, so meditation URLs expire in **3600 seconds** while `/api/prayers/:id/audio` already uses `86_400`. Raise the meditation TTL to the shared config key from Stage 1, using `Application.get_env/3` — **not** `compile_env/3`, because every other AWS setting lives in `runtime.exs` and the moment this one moves there a `compile_env` read raises at boot.

**Be honest about what this fixes.** There are three callers, one of which the research missed:

| Caller | Effect of the TTL change |
| --- | --- |
| `lib/lumen_viae_web/controllers/api/meditation_set_controller.ex:29` | offline download survives a long serial run |
| `lib/lumen_viae_web/live/pray/index.ex:16` | the public web prayer page now emits 24-hour URLs too — decide if that is wanted |
| the `Components.AudioPlayer` path | same |

And the **resume** path is not fixed by the server at all. `OfflineContentService` lines 175-183 read the stored `MeditationSet` off disk and reuse `meditation.audioUrl` without touching the API; a URL written hours ago is dead whether its TTL was one hour or twenty-four. The server change is necessary but not sufficient — pair it with the client change, or the only thing shipped is a wider leak window.

**New endpoint** so the client has somewhere to go on a 403:

```elixir
# lib/lumen_viae_web/controllers/api/meditation_controller.ex
get "/meditations/:id/audio", MeditationController, :audio
```

```json
{
  "data": {
    "id": 126,
    "audio_url": "https://lumenviae-audio.s3.us-east-2.amazonaws.com/sheen_sorrowful_1.mp3?X-Amz-Expires=86400&...",
    "expires_at": "2026-08-20T14:02:12Z"
  }
}
```

`expires_at` is added to `/api/prayers/:id/audio` too (additive; `PrayerAudioResponse` decodes only `id` and `audio_url`, so shipped builds are unaffected).

**One error envelope.** There are two shapes today and neither is consumed — `APIService.send` reads only the status code — so this is a free window. New `lib/lumen_viae_web/controllers/api/error_json.ex`, and `fallback_controller.ex` grows clauses for `:not_found`, `{:bad_request, message}`, changesets, **and a catch-all**. The catch-all is not cosmetic: `PrayerController.audio` returns `{:error, reason}` verbatim from S3, so `{:error, :missing_credentials}` matches neither existing clause and raises `FunctionClauseError` today.

```json
{ "error": { "code": "not_found", "message": "Not found" } }
{ "error": { "code": "audio_unavailable", "message": "Audio temporarily unavailable" } }
{ "error": { "code": "validation_failed", "message": "The request could not be processed",
             "details": { "meditation_set_id": ["does not exist"] } } }
```

Also add `Rosary.fetch_visible_meditation_set/1` (result-shaped sibling of the bang function) so a missing set goes through the fallback rather than 404ing by exception, and set `Cache-Control: private, no-store` on every response that embeds a presigned URL.

**Unblocks:** an offline download that can actually resume.

---

### Stage 7 — `GET /api/catalog` and `GET /api/catalog/version`

**Delivers:** the offline download in one request instead of 28, and a way to ask "has anything changed".

Counted from `OfflineContentService.downloadAll`: one `fetchMeditationSets` per category (5) plus one `fetchMeditationSet` per summary (27 sets today) — **32 JSON round trips** to a Fly machine that sleeps, before a single byte of audio moves. `APIService` sets a 15s timeout with one retry precisely because the first request to a cold machine often times out.

**Measured, not estimated.** All current set-detail payloads together are 196,141 bytes uncompressed, including roughly 70 KB of presigned query strings — about 125 KB of text, 30-40 KB gzipped. The Fly proxy already gzips. This is why the research's ETag plug, `stale-while-revalidate`, and text-only catalog variant are **cut**: a 304 that saves 35 KB while still paying the cold start is ceremony, and a text-only variant with `has_audio: true` and no `audio_url` silently defeats the shipped Swift model (`Meditation.hasAudio` is computed as `audioUrl != nil && !audioUrl.isEmpty`, and `downloadAll` gates on exactly that, so every meditation would report no audio and stage two would download nothing).

Ship two endpoints and nothing else:

- **`GET /api/catalog`** — every visible set with its ordered meditations and freshly presigned `audio_url`, plus every mystery. `Cache-Control: private, no-store`, no ETag. The existing `Meditation` Swift type decodes it unchanged.
- **`GET /api/catalog/version`** — a fingerprint the client polls once a day.

```elixir
# lib/lumen_viae/rosary.ex - three queries regardless of catalog size
@spec catalog() :: %{sets: [struct()], mysteries: [struct()]}
def catalog

@doc """
A short opaque token that changes whenever any published content changes.

Count plus newest timestamp per table covers inserts, updates and deletes -
archiving is an update, so it moves the token and correctly invalidates the
visibility of every set containing that meditation.
"""
@spec catalog_version() :: %{version: String.t(), updated_at: DateTime.t() | nil, counts: map()}
def catalog_version
```

Each Secondary Context gains `max_updated_at/0`; `SetMemberships` also needs `count/0`. Every JSON resource gains `updated_at`, rendered as UTC (`timestamps()` is naive, so the JSON module must convert — the iOS decoder uses `.iso8601` and a naive string has no `Z`).

```json
{
  "data": {
    "version": "9f2c1a7be04d5511",
    "updated_at": "2026-08-11T09:12:00Z",
    "counts": { "mysteries": 27, "meditation_sets": 27, "meditations": 149, "set_memberships": 149 }
  }
}
```

**Unblocks:** an offline download that starts in one round trip, and `MeditationSetResolver` dropping its "content changes only with a release" memoization, which is not true — content changes on every CSV import.

---

### Stage 8 — Per-meditation artwork

**Delivers:** §2 of the iOS request. Emmerich's visions carrying different paintings from Sheen's on the prayer screen.

Identical columns and constraints on `meditations`, identical value module, identical renderer. `MeditationJSON.data/1` gains the same one-line `Map.merge`. `Rosary.artwork_url/1` already covers it — it matches `%{image_key: key}` and both structs carry the field.

**Migration** `20260820130000_add_artwork_to_meditations.exs` — same twelve columns, same two check constraints.

Admin: extract the artwork panel to take a generic subject (`attr :subject`, `attr :scope, :atom`) so it serves both forms, and mount the same `allow_upload` and handlers in `live/meditations/edit/edit.ex`. The crop previews differ: the prayer-screen artwork and the mini-player thumbnail, not the home card.

**Sharing caveat, stated so nobody is surprised:** meditations are many-to-many with sets, so a meditation reused across two sets carries one painting into both. That is right when a meditation is an author's text on one mystery, which is the case for all 149 today. If it ever matters, the image belongs on the `meditation_set_meditations` join row, which already carries the prayer order.

**Unblocks:** the prayer screen's per-mystery art.

---

### Stage 9 — Mystery metadata

**Delivers:** the scripture passage the app has a reference for and nothing to render under it.

**Migration** `20260820140000_add_metadata_to_mysteries.exs`:

```elixir
alter table(:mysteries) do
  add :subtitle, :string          # "The Incarnation"
  add :scripture_text, :text      # the passage itself, Douay-Rheims
  add :fruit, :string             # "Humility"
  add :image_key, :string         # public bucket key, nullable, populated later
end
```

`scripture_text` is the real gap and the foundation of the Scriptural Rosary stretch goal; Douay-Rheims is public domain, matching the project's content conventions. `subtitle` and `fruit` add nothing to iOS — `MysteryData.traditionalFruits` already carries all 27 correctly — but Phoenix hardcodes the fruits again as prose in `live/home/index.ex` and again on the mysteries learn pages, so the database becomes the one source.

**Seed the fruits with the exact bundle strings.** The research's example wrote `"Love of Neighbour"`; `app/Data/MysteryData.swift:309` has `"joyful_2": "Love of Neighbor"`. Since the app keeps its bundled map forever, a spelling divergence means the same mystery shows two different fruits depending on which source the screen read. Deliver as `priv/repo/data/mystery_metadata.exs` plus `mix lumen_viae.seed_mystery_metadata` — a task rather than a data migration, because the content will be revised and re-running a task is normal.

**Join key for the client:** production mystery ids are 47, 51, 56… while bundled iOS ids are 1-5, so a client merges API and bundled data on `"<category>_<order>"` — the key `traditionalFruits` already uses.

Not building a per-mystery `audio_url`: nobody asked, narration belongs to meditations, and it would duplicate the ElevenLabs spend for text the user never sees alone.

---

### Stage 10 — Background music catalog, bundled cues and reminder sounds

**Delivers:** a music bed, a decade chime, and a reminder picker that sounds like a church.

**The delivery split is settled by Apple, not by preference.** A custom `UNNotificationSound` must already be on device — app bundle or `<container>/Library/Sounds` — in aiff/wav/caf carrying Linear PCM, MA4, µLaw or aLaw, **under 30 seconds** or the system silently substitutes the default. So reminder sounds and prayer cues are bundled (tens of KB each); background music, at 4-16 MB per track and seasonal, is served by the API.

**`lib/lumen_viae/audio/catalog.ex`** — infrastructure beside `eleven_labs.ex` and `pipeline.ex`, **not** under `rosary/`. The context-rules test only constrains `LumenViae.Rosary.*` names and `Repo.*`, so this placement is clean and it is not bound by the domain value-module rule. It also gives `PrayerController`'s inline `@prayers` map a home, so there is one list of S3 keys in the app.

Track shape: `slug`, `title`, `kind` (`:music | :cue | :chant`), **`delivery`** (`:remote | :bundled`), `s3_key`, `duration_ms`, `byte_size`, `content_type`, `loopable`, `seasons`, `license`, `license_url`, `attribution`, `attribution_url`. Everything but `slug`, `kind` and `delivery` is optional.

Four corrections that each turn a 500 into working code:

1. **`delivery: :bundled` entries are never presigned.** The research presigned the whole list including cues that live in the app bundle. S3 presigning never checks object existence, so the API would hand out perfectly valid signatures for objects that were never uploaded, and the client would get a 200-looking URL that 404s. `presign_all/2` skips bundled entries and `AudioJSON.track/1` uses `Map.get/2` throughout so a partially specified entry renders nulls instead of raising on `DateTime.to_iso8601(nil)`.
2. **No `String.to_existing_atom(kind)`.** Map it explicitly and return 400 on anything else; `alias` does not load a module, so the atom is not guaranteed to exist under Mix's interactive code loading.
3. **Season is atoms, and only three of them.** `LiturgicalCalendar.season/1` returns `:advent | :lent | :ordinary`. Normalize at the boundary with `to_string/1`, and cut the `seasons` vocabulary to exactly those three — `"easter"` and `"christmas"` are values the server can never select, so a track keyed only to them is dead data.
4. **Prayer keys verbatim.** Two of the four do not match their slug: `ave_maris_stella` → `prayers/ave_maris_stella.mp4` (mp4) and `glory_be` → `prayers/gloria_patri.mp3`. Preserve `expires_in: 86_400`. Default the index to `kind in [:music, :cue]` and require an explicit `?kind=chant`, so this refactor does not change what the public catalog advertises.

**Routes** (inside the existing `/api` scope):

```elixir
get "/audio/tracks", AudioController, :index
get "/audio/tracks/:id", AudioController, :show
```

```json
{
  "data": {
    "version": "2026-08-19",
    "tracks": [
      {
        "slug": "organ_meditation",
        "title": "Music for Funeral Home, Part 11",
        "kind": "music",
        "duration_ms": 453000,
        "byte_size": 3612000,
        "content_type": "audio/mp4",
        "loopable": true,
        "seasons": ["ordinary", "lent", "advent"],
        "license": "CC BY 4.0",
        "license_url": "https://creativecommons.org/licenses/by/4.0/",
        "attribution": "Music for Funeral Home - Part 11 by Kevin MacLeod (incompetech.com), edited, licensed under Creative Commons: By Attribution 4.0",
        "attribution_url": "https://incompetech.com/",
        "url": "https://lumenviae-audio.s3.us-east-2.amazonaws.com/tracks/organ_meditation.m4a?X-Amz-Algorithm=...",
        "url_expires_at": "2026-08-19T15:08:24Z"
      },
      {
        "slug": "cue_decade",
        "title": "Decade chime",
        "kind": "cue",
        "duration_ms": 1200,
        "loopable": false,
        "license": "CC0 1.0",
        "attribution": null,
        "attribution_url": "https://freesound.org/people/tec_studio/sounds/99625/",
        "url": null,
        "url_expires_at": null
      }
    ]
  }
}
```

**Reminder sounds — the compatibility trap.** `UserSettings.swift:87` is `static let default = all[0]`. The default is **positional**, and no `userSettings.reminderSound` key is written until a user taps a row. Reordering the array silently switches every untouched user's sound. And `reminderSound` resolves as `all.first { $0.fileName == reminderSoundFile } ?? .default`, so removing `harp.caf` and `songbird.caf` from `.all` does **not** preserve them for people who chose them — those users fall through to the default. Therefore:

- Keep `church_bell.caf` at index 0, and replace the positional default with `static let default = all.first { $0.fileName == "church_bell.caf" }!` so ordering is never load-bearing again.
- Keep harp and songbird in `.all` with a `legacy: Bool` flag, filtered out of the picker unless they are the user's current selection.
- Three proposed icons do not exist in `app/Assets.xcassets/Icons` (103 imagesets; `ph-hand-waving`, `ph-bell-simple`, `ph-music-notes` are absent, and `AppIcon.swift` has no fallback, so those rows render blank). Either vendor the Phosphor light imagesets (MIT) or reuse `ph-hands-praying`, `ph-bell`, `ph-music-note`.

**Prayer cues:** a soft chime at each decade turn, one sustained chord at the end of the Rosary, and an optional struck bowl at the start of a meditation. Bundled, played through a second `AVAudioPlayer` at ~0.5 volume over speech at 1.0. Do **not** add `.duckOthers` — it ducks other apps, not your own narration. Note that `.playback` ignores the hardware mute switch, so design the suppression rule before shipping: suppress cues while narration is paused.

**Pipeline:** `ffmpeg` is not installed on this machine (`brew install ffmpeg`); `/usr/bin/afconvert` is. `build.sh` must carry a hard duration guard — a notification sound over 30 seconds fails **silently**, and two verified sources are already over the line as downloaded.

---

### Stage 11 — Multiple narration voices

**Delivers:** a second voice, on the sets you choose, without breaking a single shipped build.

**Migration** `20260820150000_create_meditation_narrations.exs`:

```elixir
create table(:meditation_narrations) do
  add :meditation_id, references(:meditations, on_delete: :delete_all), null: false
  add :voice_slug, :string, null: false
  add :s3_key, :text, null: false
  add :duration_ms, :integer
  add :byte_size, :integer
  add :character_count, :integer
  add :model_id, :string
  add :eleven_labs_voice_id, :string
  add :generated_at, :utc_datetime
  timestamps()
end

create unique_index(:meditation_narrations, [:meditation_id, :voice_slug])
create index(:meditation_narrations, [:voice_slug])
create index(:meditation_narrations, [:s3_key])
```

**`s3_key` is a plain index, not unique.** The research made it unique and its risk note claimed the backfill's `ON CONFLICT ... DO NOTHING` would swallow a collision. It would not: `ON CONFLICT` names one arbiter index, and a violation of a *different* unique index raises and rolls the whole migration back. Duplicate `audio_url` values are a permitted state — `csv_import.ex:301` emits a *warning*, not an error, when an audio filename already belongs to an existing meditation — so uniqueness on `s3_key` is not a real invariant and would abort the deploy.

**Backfill** `20260820150100_backfill_default_narrations.exs` — raw SQL, mirroring the existing labels backfill, inserting one `voice_slug = 'default'` row per meditation whose `audio_url` is set. All 149 qualify. `duration_ms` and `byte_size` are left NULL, so any Swift model must declare them `Int?`.

**`meditations.audio_url` is untouched** — not dropped, not renamed. It stays the canonical S3 key of the default voice, `get_meditation_audio_url/1` keeps its exact signature, and the API's `audio_url` field keeps its exact meaning. The default voice is *additionally* mirrored into `meditation_narrations` so every voice shares one bookkeeping shape.

**`lib/lumen_viae/rosary/narrations.ex`** — Secondary Context. **`lib/lumen_viae/rosary/voices.ex`** — value module holding slug, display name, description, position and default flag. ElevenLabs voice ids live in `config/runtime.exs`, not in the value module and not in the database: they name voices inside one ElevenLabs account, they rotate independently of content, and they belong beside the API key.

**Split the availability predicate — this is the correction that prevents a silent outage.** The research keyed both generation and serving on whether a voice id is configured, which means a voice with 300 fully generated, paid-for narrations vanishes from the picker the moment `ELEVEN_LABS_VOICE_MATERNAL` is unset in whatever environment serves the API. Availability of audio to *play* has nothing to do with whether this box can call ElevenLabs:

```elixir
def generatable?(slug)   # config-driven; gates --voice and VoiceGeneration
def resolve(slug)        # playback; narrows to `slug in slugs()`, never consults config
```

`/api/voices` lists voices where `Rosary.voice_coverage()[slug].narrated > 0`.

**Wire `?voice=` through — it is currently a no-op.** The research resolved the voice in the controller and then called `Rosary.list_set_audio(set.id)` with no voice argument, so `audio_url` could only ever be the default. And pass the **already-loaded meditations**, not the set id: `get_visible_meditation_set_with_ordered_meditations!/1` already runs `list_meditations_in_set/1`, so re-deriving them takes set detail from 2 queries to 5 on the app's hottest endpoint.

```elixir
def list_set_audio(meditations, opts \\ []) when is_list(meditations)
```

called as `Rosary.list_set_audio(set.meditations, voice: voice)`. Missing functions the research referenced but never defined: `Narrations.total_bytes_by_voice/0` and `Meditations.count_active/0`.

```json
{
  "data": {
    "id": 27,
    "name": "Blessed Fulton J. Sheen",
    "voice": "maternal",
    "meditations": [
      {
        "id": 126,
        "content": "...",
        "audio_url": "https://lumenviae-audio.s3.us-east-2.amazonaws.com/voices/maternal/sheen_sorrowful_1.mp3?X-Amz-...",
        "audio_voice": "maternal",
        "audio": [
          { "voice": "default",  "name": "Contemplative", "url": "https://...", "duration_ms": 71000, "byte_size": 1136000 },
          { "voice": "maternal", "name": "Maternal",      "url": "https://...", "duration_ms": 74000, "byte_size": 1184000 }
        ]
      }
    ]
  }
}
```

`url` inside `audio` can be **null** — `generate_presigned_url!/2` returns nil on failure — so either declare it nullable and use `String?` on the client, or filter nil entries out of the array. Do not ship a non-optional Swift `url`.

**Cost, corrected.** The research's "66 meditations, 46,227 characters" figures are wrong by roughly 3x. The real dev catalogue is **149 meditations and 141,707 characters** of content, all 149 with audio. With the `<break>` tags `TtsText` inserts at paragraph breaks, budget ~147,000 characters per full pass per voice — roughly **$32 per voice** at the quoted Creator rate, and ~160 MB of offline audio per voice. Those per-1k rates are *unverified* against ElevenLabs' current pricing and are subscription quota rates rather than marginal prices, so the practical constraint is credits per month, not dollars per run. Put the rate in `config :lumen_viae, :eleven_labs_cost_per_1k_chars` so the estimate can be corrected without a code change.

Three cost controls: the default stays one voice; every dry run prints the character total and the estimate; `--limit N` exists so a voice can be auditioned on five meditations for pennies. `--all` requires `--yes`, unconditionally — the research's "refuses `--all` without a prior `--dry-run` in the same shell" is not implementable, since a Mix task cannot know what ran earlier in the operator's shell.

Also: thread `output_format` alongside `model_id` through `Pipeline.generate_and_upload/4`. `Duration.estimate_ms/2` is built entirely on the 16,000 bytes-per-second assumption that `mp3_44100_128` implies, so letting one change without the other is exactly the drift the module warns about.

**Required companion edits, same commit:** `@secondary_contexts` gains `narrations`, `@value_modules` gains `voices`. Split them out and the build fails with a message pointing at the web layer rather than at the test.

Nothing deletes the S3 object when a narration row goes. Either add `Rosary.delete_meditation_narration/2` that deletes both, or document that objects are never deleted and add a reporting task.

---

### Stage 12 — `GET /api/today` and the rotation reconciliation

**Delivers:** one source of truth for the line at the top of the home screen.

The disagreement is real and user-visible: `LiturgicalCalendar.recommended_mysteries/1` returns `:glorious` for Saturday (day 6, verified), the website says the same, iOS `ScheduleService` returns `.joyful`, and production `mysteries.days_prayed` puts The Resurrection on "Wednesdays, Thursdays, and Sundays" — Glorious on Thursday, which is neither schedule.

**Scope this honestly and trim what the research over-reached on.** Ship the day, the season, the recommendation, the daily quote, a featured set and an announcement. **Do not ship `Feasts`** in this stage: the research specified function headers with no bodies, its moduledoc promised movable feasts while the list contained only fixed dates, and `upcoming/2` needs a year rollover that was never specified. `MarianFeastDay` is already bundled on iOS and the consecration start-date arithmetic runs offline from it, so nothing is blocked.

**`lib/lumen_viae/today.ex`** — a read service above the domain, consuming `LumenViae.Rosary` exactly as a LiveView does. Two corrections:

- **`recommendation/1` returns `Categories.slugs()` strings, not atoms.** `recommended_mysteries/1` returns atoms and never returns `:luminous` or `:seven_sorrows`; the value flows into `MeditationSets.list(category: ...)` where it is compared against a `:string` column, and an atom leaking through returns no sets and no error.
- **`featured_set` must not go through `list_visible_meditation_sets_by_category/1`**, which preloads every meditation. The featured card needs a summary.

The featured pick is derived, not curated: `Enum.at(sets, rem(Date.to_gregorian_days(date), length(sets)))` — the same set all day for everyone, a different one tomorrow, no state and no curation.

Quotes and announcements are **value modules**, not tables. A Fly deploy is two minutes; an App Store review is days, and the value module already wins the thing that matters. Seed `LumenViae.Quotes` from `app/Data/RosaryQuotes.swift` so the two agree on day one, then grow only the Elixir copy — the bundle becomes the offline floor, not the source. Announcements carry `starts_on`/`ends_on` so they expire themselves. Validate the announcement `url` against the canonical host: it is **`www.lumenviae.org`** (`plugs/canonical_host.ex:11`), not lumenviae.com.

```json
{
  "data": {
    "date": "2026-10-07",
    "day_of_week": "wednesday",
    "season": "ordinary",
    "season_label": "Throughout the Year",
    "recommended_category": "glorious",
    "featured_set": { "id": 25, "name": "Blessed Fulton J. Sheen", "...": "set summary shape" },
    "quote": { "text": "The Rosary is the most beautiful and the most rich in graces of all prayers.",
               "author": "St. Pius X", "source": null },
    "announcement": null
  }
}
```

`?date=` is accepted and defaults to `Date.utc_today()`: the server runs in UTC and the client does not, and the app should send its own local date rather than have the server guess.

**Write `test/lumen_viae/liturgical_calendar_test.exs` first.** It does not exist. The Meeus/Jones/Butcher Easter computation, Ash Wednesday and the Advent start are entirely untested and are about to become an API contract consumed by a shipped app. Known Easters: 2024-04-01, 2025-04-20, 2026-04-05.

**Data migration** `20260820160000_align_days_prayed_with_calendar.exs` — literal strings and raw SQL (migrations must not name today's modules). Name all five categories explicitly, **including leaving `seven_sorrows` null deliberately** — all 7 rows are null in production today and the chaplet is not on a weekday rotation. Thursday's assignment is a live decision once Saturday is settled; see decision 2.

---

### Stage 13 — Completion analytics

**Delivers:** answers to "are the long sets finished as often as the short ones" and "is narration used", with nothing that identifies anyone.

**Migration** `20260820170000_add_context_to_rosary_completions.exs`:

```elixir
alter table(:rosary_completions) do
  add :category, :string           # denormalised, survives a set deletion
  add :source, :string             # "ios" | "web"
  add :duration_seconds, :integer
  add :audio_used, :boolean
  add :app_version, :string
end

create index(:rosary_completions, [:category])
```

**Do not re-create the `completed_at` index.** `20251124170745_create_rosary_completions.exs` already ends with `create index(:rosary_completions, [:completed_at])`; adding it again raises `relation already exists` and aborts the migration, taking the column additions with it. The research's claim that `count_in_range/2` "does a sequential scan today" is wrong on the same evidence.

**Guard `category_of_set/1`.** The controller passes `params["meditation_set_id"]` straight through as a string; `MeditationSets.list_by_ids(["abc"])` raises `Ecto.Query.CastError` *before* any changeset validation runs, turning a clean 422 into a 500 on an unauthenticated public endpoint. Resolve the category after a successful insert, from the validated integer.

Every new request field is optional, so a body carrying only `meditation_set_id` behaves exactly as it does today. `duration_seconds` is bounded (`> 0`, `<= 14_400`) so one bad client cannot poison an average.

**The privacy policy edit ships in this commit, not after.** `live/privacy_policy/index.ex` currently describes completion data as "which set was completed and when". Widen it to name duration and narration use, and add a sentence that completions carry no device, install or account identifier.

Explicitly rejected: any device or install identifier however rotated; IP on the API path (it stays `nil`); locale; timezone; and abandonment events. That last one is the only way to compute a true completion *rate*, so be clear about the consequence — `duration_seconds` and `audio_used` describe finished Rosaries and cannot tell you what fraction were finished.

---

## 3. The audio assets

All licence and duration facts below were read off the live source pages on 19 August 2026 during the research pass. They were **not** re-verified from this repository, and per-track pages are authoritative — Incompetech historically issued CC BY 3.0 as well as 4.0, and their own wording is "*nearly* all music". Record `verified_on` **and `verified_by`** in `priv/audio_sources/SOURCES.tsv`, and require that the licence recorded there was read off that individual item's own page, not off a catalog dump or a filtered search.

### Background music — ship these three

All Kevin MacLeod, incompetech.com, **CC BY 4.0**, one shared attribution block.

| Slug | Title | Length | Notes |
| --- | --- | --- | --- |
| `organ_meditation` | Music for Funeral Home - Part 11 | 7:33 | ISRC USUAN1200037. Solo organ, light flute stops, no reeds, no melody to follow. **Default track** — the one that sounds Catholic rather than spa. |
| `drone_in_d` | Drone in D | 21:23 | ISRC USUAN1200044. Piano over a sustained drone. Long enough that a five-decade Rosary never reaches a loop point. |
| `ambiment` | Ambiment | 22:53 | ISRC USUAN1100630. Piano and synth pads, the sparsest of the three. |

**The attribution string must say the track was edited.** CC BY 4.0 §3(a)(1)(B) requires indicating modification, and the pipeline cuts a 244-second block out of a 7:33 piece, crossfades it into a loop, applies `loudnorm` and folds it to mono. That is an adaptation. Every shipped credit reads: *"Music for Funeral Home - Part 11 by Kevin MacLeod (incompetech.com), edited, licensed under Creative Commons: By Attribution 4.0"* — and that rule goes in `docs/AUDIO_SOURCES.md`, not left to memory.

Alternates from the same catalogue, all CC BY 4.0: "Almost in F" (32:42), "Peace of Mind" (35:58), "Organic Meditations One" (16:28). "Agnus Dei X" (1:31, choir and pipe organ, real Latin text) is not a bed — it has words — but is a natural closing piece.

### Notification sounds — ship these, all CC0

Chosen CC0 deliberately so the reminder picker acquires **no** attribution obligation.

| Slug | Source | Licence | Length | Notes |
| --- | --- | --- | --- | --- |
| `altar_bell` | tec_studio, [freesound 99625](https://freesound.org/people/tec_studio/sounds/99625/) | CC0 | 0:04.000 | Already mono 44.1k. Trim to 2.5s. Replaces the current file's contents, keeps the filename. |
| `hand_bell` | 15HVojta_Michael, [freesound 462042](https://freesound.org/people/15HVojta_Michael/sounds/462042/) | CC0 | 0:02.359 | A Prague hand bell. Closest thing to a sacristy bell. |
| `angelus_bell` | Talitha5, [freesound 690594](https://freesound.org/people/Talitha5/sounds/690594/) | CC0 | 0:31.786 | Montserrat monastery. Trim to three strikes (~8s) — **note the source is already over Apple's 30s limit**. |
| `monastery_bell` | Robin Whittaker, [freesound 36628](https://freesound.org/people/Robin%20Whittaker/sounds/36628/) | CC0 | 2:29.350 | Benedictine abbey of Einsiedeln, mics in both towers. Extract one strike (~6s). |
| `singing_bowl` | Coleco, [freesound 59159](https://freesound.org/people/Coleco/sounds/59159/) | CC0 | 0:27.766 | Lossless WAV; trim to ~8s. Preferred over the MP3 alternative (inoshirodesign 271370). |
| `organ_chord` | Beetlemuse, [freesound 527206](https://freesound.org/people/Beetlemuse/sounds/527206/) | CC0 | 0:42.858 | Cathedral organ. Extract one sustained chord (~3s) with a long fade. |

Also available and CC0: `valamo_bell` (vollkornbrot, [149967](https://freesound.org/people/vollkornbrot/sounds/149967/), Finnish Orthodox monastery, 2:25) as a contrast option, and Audeption's [425172](https://freesound.org/people/Audeption/sounds/425172/) (0:31.640 — again over the limit as downloaded).

### Prayer cues — ship these, all CC0

Drawn from the sounds above so no attribution ever appears in the prayer flow.

- `cue_decade` — one soft strike, ~1.2s, from tec_studio 99625. Quieter and shorter than its reminder sibling so it reads as punctuation, not an alert.
- `cue_rosary_complete` — one sustained organ chord, ~4s, from Beetlemuse 527206. The only cue that should feel like an arrival.
- `cue_meditation_start` — struck bowl, ~2s. Off by default; three cues in a decade is one too many.

### Needs verification — do not ship until checked

- **"Little bell", NikoletB, [freesound 846674](https://freesound.org/people/NikoletB/sounds/846674/)** — surfaced by a CC0-filtered search; the individual sound page was never opened and the duration was never confirmed.
- **"campanes Montserrat.mp3", mariona sagarra, [freesound 419232](https://freesound.org/people/mariona%20sagarra/sounds/419232/)** — same: licence unconfirmed at the item level.
- **bassimat's "Tectonic Cathedral Sacred Drone", [freesound 854871](https://freesound.org/people/bassimat/sounds/854871/)** — licence reads CC0, but the description says the output was generated by a tool called MANTICE. The uploader's CC0 grant does not establish that a generator's output is free of third-party material.
- **"Gregorian choir & organ in Rome", tullio, [freesound 780488](https://freesound.org/people/tullio/sounds/780488/)** — CC0, 1:05, recorded in San Paolo fuori le mura. Genuinely beautiful, and too short to loop. The real question is that the uploader can waive rights in his recording but not the neighbouring rights of an identifiable choir. Bells have no performer in the legal sense; a singing choir does.
- **The 1925 public-domain boundary for US sound recordings** — stated from the Music Modernization Act's structure (pre-1923 released 1 Jan 2022, 1923-1946 given a flat 100-year term). The UCSB Public Domain Day page returns 403 to automated fetches, so one human check is warranted before anyone relies on the year.

### Rejected, with reasons — so nobody re-litigates them

- **archive.org "Gregorian Chant Mass"** — marked public domain by a 2008 uploader, performer listed as "Sacred Polyphony by ???". An uploader cannot place someone else's recording in the public domain. 115,000 views is not provenance.
- **The Schola Gregoriana of Ołtarzew files on Wikimedia Commons** (Ave Maria, Pater Noster, Kyrie, Magnificat, Deus in adjutorium) — excellent recordings, all **CC BY-SA 3.0**. Trimming, normalising and re-encoding creates an adaptation that must itself be released ShareAlike. Survivable but not worth it for music that has words in it anyway.
- **`File:Salve_Regina.ogg`** — despite the name it is a church-bell motif, and it is CC-BY-SA-2.0-DE. That would put both an attribution and a ShareAlike obligation on the reminder picker.
- **Musopen** — genuinely free (the archive.org mirrors carry CC0 and the PD mark, and the 2010 Kickstarter recordings were released for public domain use), but it is Beethoven, Brahms and Chopin: orchestral and pianistic, with melodies and dynamics. Wrong material for a bed under narration.
- **Pre-1926 chant 78s** — narrow-band and full of surface noise, which is exactly wrong under a clean TTS voice, and the Great 78 Project that hosts most of them is the subject of an active major-label suit.

**The rule worth writing down once:** a Gregorian melody from the 10th century is public domain as a *composition* everywhere. A 2015 recording of it is a separate copyrighted work owned by the performers and the label. The only routes to a free chant *recording* are that the performer licensed it themselves, that it is old enough to have fallen out of copyright, or that somebody synthesised it.

### Provenance record

`priv/audio_sources/SOURCES.tsv` is checked in — one row per source file, columns `slug, source_url, download_url, original_filename, host, author, license_spdx, license_url, attribution_required, attribution_text, verified_on, verified_by, notes`. `priv/audio_sources/originals/` and `build/` are gitignored beside the existing `priv/repo/imports/` entry. `docs/AUDIO_SOURCES.md` carries the composition-versus-recording rule, the acceptable hosts, and this rejection list.

**Credits must be reachable, not prominent.** CC BY 4.0 section 3(a)(2) allows the notice to sit wherever is reasonable for the medium, which for an app is an acknowledgements screen. One place, discreet: a `/credits` LiveView under `live/home/credits/` linked from the site footer, and an Acknowledgements row under Account > About on iOS. Not on the player, not on the admin dashboard.

What would break compliance: removing the screen in a later redesign, dropping the link that reaches it, or omitting "edited" from a credit line. A test asserting the credits route returns 200 and names all three tracks is cheap insurance against the first two. If the attribution ever becomes unwelcome, the answer is commissioning an organist and deleting the tracks - not quietly trimming the notice.

---

## 4. Left deliberately unbuilt: intentions

The iOS request marks §5 **"do not build yet"** and that is the right call, but for a different reason than it gives. The mechanism is two days of work. The content is a season.

### The vocabulary — decided, written down, not shipped as code

Fifteen ids, ordered trials → relationships → vocation and work → Church and world → gratitude → pure devotion. Each carries a slug (URL and JSON safe, permanent once shipped) and a separate prompt, so the module is shaped like `Categories`, not `Labels` — a label *is* its display text; an intention is not.

| id | prompt |
| --- | --- |
| `burden` | A cross I am carrying |
| `healing` | Healing, for body or soul |
| `grief` | Someone who has died |
| `fear` | Fear that will not leave me |
| `purity` | A sin I keep returning to |
| `marriage` | My marriage |
| `children` | My children |
| `family` | My family |
| `conversion` | Someone far from God |
| `discernment` | A decision before me |
| `provision` | Work and daily bread |
| `church` | The Church and her priests |
| `peace` | Our country, and peace |
| `thanksgiving` | In thanksgiving |
| `nearness` | Only to be near her |

`nearness` carries no petition at all, and it is the one the whole feature is worth having for.

Note these deliberately diverge from the ids the iOS request sketched (`["cross", "dead"]`). Nothing has shipped against those, so the divergence is free — but it is a decision, not an oversight.

### The seam being left

**Storage:** an `intentions text[]` column on `meditation_sets`, validated with `validate_subset` exactly as `labels` is. Not a join table. A join table forces a new Secondary Context, a new schema, an entry in `@secondary_contexts`, and — because Rule 3 forbids a Secondary Context from joining another table — turns *every set listing* into a cross-resource composition in the Primary Context. That is three moving parts on the hottest path in the app to store fifteen possible values against 27 rows. A join table only wins if the link ever needs its own data or if intentions become user-generated; neither is on the table.

One deliberate divergence from labels: intentions carry no meaningful order (a set for grief is not "primarily" one of them), so they normalize to canonical vocabulary order on write.

**Query:** the filter must be written as **containment**, not `= ANY`. Postgres cannot use a GIN `array_ops` index for `scalar = ANY(array_column)` — the planner does not rewrite it. Proved empirically: a 200k-row `text[]` table with a GIN index, analyzed, with `enable_seqscan = off`, still plans `WHERE 't3' = ANY(tags)` as a Seq Scan, while `WHERE tags @> ARRAY['t3']` uses the index. At 27 rows the index buys nothing either way, so the honest position is a `@>` fragment and no index at all.

**API:** `"intentions": []` on both endpoints (empty array, never null — null invents a third state every client then handles forever), `GET /api/intentions` returning only intentions at least one *visible* set actually carries, and `?intention=` on the list endpoint returning `200` with an empty array for an unknown slug rather than a `400`, so a stale cached slug never produces an error screen mid-prayer.

**What is left in place today:** nothing in stages 0-13 forecloses any of it. The `meditation_sets` table takes another array column cleanly, `MeditationSets.list/1` already threads options, and `set_summary/1` is now public and additive-safe with a contract test behind it.

### Why it is not being shipped empty now

The research argued for shipping the field empty — an empty array costs nothing and saves an App Store cycle. Two facts move it the other way.

**It is not free on the client.** Adding a stored property to `MeditationSet` and `MeditationSetSummary` changes their memberwise initializers, and they are constructed by hand in **25 places** (18 `MeditationSetSummary(...)` and 7 `MeditationSet(...)`, across `LuminousMeditationData.swift`, `SelectMeditationView.swift`, `MeditationSetDetailView.swift` and `MockDataService.swift`). Every one is a compile error until updated. The obvious dodge — `let intentions: [String]? = nil` — is worse: Swift excludes an immutable property with an initial value from the synthesized `init(from:)`, so the field would compile and silently never decode.

**The App Store cycle it saves does not exist yet**, because the row would stay hidden. The endpoint returns only populated intentions, and most are empty.

### What would actually have to happen to turn it on

The real catalogue is **27 sets**, not the 12 the research reported, and seven of them already carry the `Intentions` label (verified: ids 31, 32, 33, 34, 36, 37, 38). There is no set named "Marriage" — it is **"For those Married"** (id 33), and the research's backfill clause for "Marriage" would never have matched. Every set the research called "absent from dev, may exist in prod" is present right now.

Honest day-one coverage from a backfill:

| Intention | Set |
| --- | --- |
| `fear`, `purity` | For Scrupulous Minds (31) |
| `marriage` | For those Married (33) |
| `provision` | On Divine Providence (32) |
| `burden` | On Patience (38) |
| `burden`, `nearness` | On Dryness (34) |
| `discernment` | On Purpose (37) |

On Detachment (36) gets nothing — no honest fit. The other twenty sets are author and style sets (Sheen ×3, Liguori ×4, Emmerich ×4, Ignatius, Newman, Augustine, Chrysostom, Aquinas, Agreda, Faber, and two Seven Sorrows sets) and must stay untagged. Tagging them to pad the row would put the same twenty sets behind every chip and make the feature read as broken.

**So seven of fifteen intentions get content free, and eight need curation:** healing, grief, children, family, conversion, church, peace, thanksgiving. That is roughly 8-12 new sets, 40-60 new meditations, ElevenLabs narration and S3 uploads, following `docs/MEDITATION_CURATION_GUIDE.md`. By how often they are actually brought to the Rosary, curate in this order: **grief, healing, family, thanksgiving**.

Turning it on, once the content exists, is one migration, one value module, two JSON lines, one query clause, one admin card, one CSV column, and the 25 Swift call sites. Two days. The content is the feature.

One thing worth flagging now: the label `"Intentions"` will mean exactly the same thing as `intentions != []`. Two names for one fact is a smell, and the label should eventually be retired — but not in the same release, because old builds render it as a chip.

---

## 5. Not worth doing

Considered and rejected, so they do not come back.

**Artwork through the CSV importer, and a bulk artwork manifest task.** A CSV cannot carry image bytes, so any column could only name an object someone uploaded by other means, and it would be silently ignored on rows two through five of a set. The research's fallback — a separate `ArtworkManifest` service, a mix task, a manifest format, a doc section and a test file — is a lot of machinery to seed a few dozen images for a single owner who already has an admin form with a live crop preview, and its own design concedes every row still needs a visit to that form to set the focal point. Keep the *decision* (`@known_columns` unchanged, so a stray `image_filename` still fails header validation loudly) and drop the mechanism. If bulk seeding is ever genuinely wanted, it is a throwaway script from `iex -S mix`.

**`mix lumen_viae.artwork_sweep`.** Orphaned objects under a public bucket are a few megabytes. Delete them by hand.

**`image_zoom`.** A second framing control with no demonstrated case, costing a column on two tables, a constraint, a validation, two API keys, two Swift properties, a form input and a multiplication. Dropped before the migration lands, which is free; after, it is a migration and an API change.

**`meditations.language` and a `Languages` value module.** The research proposed a migration on the largest table, a third value module, a CSV column, a `?language=` filter and per-language coverage denominators — entirely to gate two voices it also said should ship dormant, against content that does not exist and is not on any roadmap. Delete the `latin` and `spanish` entries from the voice roster instead; that removes the failure mode at zero cost. If a Spanish set is ever curated, the column is a one-line additive migration then.

**ETags, `stale-while-revalidate`, and a text-only `/api/catalog` variant.** The entire justification was a size estimate that is roughly 10x too high — measured, all 27 set-detail payloads together are 196 KB uncompressed including 70 KB of presigned query strings, so ~35 KB gzipped as text. A 304 that saves 35 KB while still paying the Fly cold start is ceremony, and the text-only variant with `has_audio` and no `audio_url` would silently make `Meditation.hasAudio` false for every meditation and download nothing.

**A `voices` database table.** Nothing joins to it, the roster changes at the speed of deploys rather than user actions, and it would need admin CRUD, a Secondary Context and a schema to express five constant rows. `Categories` and `Labels` already establish how this codebase spells a controlled vocabulary.

**A jsonb `audio_urls` map, or convention-only S3 keys, for multi-voice.** The jsonb map puts per-voice metadata behind map surgery inside a schema Rule 1 restricts to schema and changeset, cannot be indexed, and loses concurrent per-voice writes to last-writer-wins. Convention-only keys can only establish existence with an S3 HEAD per meditation per voice — 35 network calls to render one seven-meditation set detail — and can never carry duration or byte size.

**`/api/v1` aliases.** Two URLs for one API, and the old one can never be removed anyway because builds in the wild use it. The only thing versioning buys is a place to put a breaking change, and there is none on the horizon. The contract test is the same guarantee with none of the surface.

**Pagination.** 27 sets and 27 mysteries. Revisit past roughly 200.

**Rate limiting.** Public GETs of public content on a single Fly machine that already sleeps. The realistic failure mode is a cold start, not a flood. `POST /api/completions` is the one route where it might eventually matter, and the mitigation is a five-minute deploy if it does.

**`Marian` and `Vocation` labels.** Labels answer "what kind of meditation is this" along two sub-axes — provenance (Saints, Scriptural) and style (Contemplative vs Considerations, mutually exclusive by the module's own doc). Marian and Vocation answer "what is it *about*", which is subject matter, which is the axis intentions exist to carry. Vocation is redundant with `discernment`/`children`/`family` on arrival; Marian applies to most of the catalogue, so it filters nothing. And `max_per_set` is 3 against a vocabulary of 5, so two subject labels would start pushing `Saints` off sets by actual saints. See decision 3 — this is your call, not mine, but the recommendation is no.

**Any device or install identifier in completions, however rotated.** It is a device identifier no matter what it is called, it would make the current privacy policy false, and it is the one thing the app's whole design — journal and history on device, never sent — is set up to avoid.

**Abandonment events.** The only privacy-clean route to a true completion *rate*, and it means the app phones home when someone stops praying. See decision 6.

**Quotes and announcements as database tables with admin CRUD.** At thirty quotations added over a year, a deploy is not friction, and a table drags in a Secondary Context, a schema, a migration and three LiveViews for a list of strings. Revisit only if you want to add a quote from your phone.

**A separate `LumenViae.Prayers` module.** Two dimensions independently proposed a home for the chant catalogue. One is enough: it goes in `LumenViae.Audio.Catalog` with `kind: :chant`, which also gives `PrayerController`'s inline `@prayers` map a home.

---

## 6. Decisions needed from you

*Resolved - see Decisions taken at the top. Kept for the reasoning.*

**1. Separate image bucket, or a public prefix on `lumenviae-audio`?**
A prefix policy needs `BlockPublicPolicy` and `RestrictPublicBuckets` turned off on the bucket that holds every paid ElevenLabs narration, and a `Resource` string of `arn:aws:s3:::lumenviae-audio/*` instead of `.../images/*` makes all of it world-readable. The bucket is also not as flat as the research assumed — `prayers/` already exists. **Recommendation: a separate `lumenviae-images` bucket.** Same credentials, one extra config line, and the blast radius of a policy mistake is zero. The database stores keys, not URLs, so putting CloudFront in front later is one environment variable either way.

**2. Saturday: Glorious or Joyful — and therefore Thursday?**
`LiturgicalCalendar` and lumenviae.org say Glorious on Saturday (traditional Wed/Sat/Sun). The shipped app says Joyful. The seeded `days_prayed` strings say Glorious on Thursday, which is neither. Whichever wins, the calendar module, the site copy, `ScheduleService` and all 27 mystery rows change together — and if Saturday resolves to Glorious then Thursday becomes a live choice between Joyful (traditional) and Luminous (which all 5 luminous rows already advertise as "Thursdays (modern schedule)"). **Recommendation: traditional throughout — Glorious on Saturday, Joyful on Thursday — and treat the app's Traditional/Modern setting as a later feature that `/api/today` can serve both halves of.** This will visibly flip Saturday's home screen, so decide it deliberately rather than discovering it.

**3. Add `Marian` and `Vocation` to the label vocabulary?**
The picker builds chips from whatever arrives, so nothing breaks either way. **Recommendation: no.** Both are subject matter, which belongs on the intentions axis, and adding them would crowd a 3-of-5 capacity. Instead, fix the four fixtures in `SelectMeditationView.swift` that currently advertise a vocabulary the API will never send (sets 3, 6, 7 and 8), and change the preview doc comment's suggested empty-state pair from "Scriptural + Vocation" to "Scriptural + Considerations".

**4. Background music: accept a permanent CC BY credits obligation, or commission an organist?**
Choosing CC0-only today means shipping nothing good — the verified CC0 pool is 43-second organ samples and 65-second field recordings. Choosing CC BY means three credit lines that must stay visible in three places forever, and a redesign that trims them puts the app out of compliance. **Recommendation: ship the three CC BY tracks now with "edited" in the attribution, and separately budget two hours of a parish organist with a work-for-hire assignment.** One session on a real instrument would beat every candidate above and end the licensing question permanently, for roughly a month of ElevenLabs.

**5. How much of the catalogue gets a second voice?**
A full pass is ~147,000 characters and roughly $32 per voice at current dev scale (149 meditations, 141,707 characters — verify prod via `fly ssh console` and `/app/bin/lumen_viae remote` before committing). The design supports partial coverage properly: the API reports per-voice coverage and falls back per meditation, so "Maternal on the Sheen sets only" is a legitimate shipping state. **Recommendation: audition a candidate voice on three meditations with `--limit 3` for pennies, then generate one complete set, then decide.** The `voice_settings` in `ElevenLabs.do_generate_audio/3` (stability 0.5, similarity_boost 0.75) are hardcoded and were tuned for the current voice; a different voice may need different values over 700-2500 characters of long-form reading, which is exactly what the audition tells you.

**6. Completion analytics: descriptive only, or a real completion rate?**
`duration_seconds` and `audio_used` describe finished Rosaries. Knowing what *fraction* were finished requires the app to report when someone stops praying. **Recommendation: no.** It turns a completion record into a partial behavioural trace, it is the one thing that would need the privacy policy rewritten rather than widened, and the curation question you actually asked — are the long sets finished as often as the short ones — is answerable from duration distributions among completions alone.
