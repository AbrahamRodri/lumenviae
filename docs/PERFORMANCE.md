# Page speed

What loading the public site costs a phone, measured on 7 October 2026, what
was changed in code that draws nothing, and what is left that only a template
or stylesheet change can fix.

## How it was measured

The production release, not the dev server: the dev server has no minified or
digested assets, no gzip, no cache headers and no `cache_static_manifest`.
`MIX_ENV=prod` cannot be run from this project's tooling, so the Dockerfile
was built (`docker build .`) and the release run against a copy of the dev
database with `PHX_HOST=www.lumenviae.org`.

The release forces HTTPS and only accepts websockets from
`https://www.lumenviae.org`, so a small local TLS proxy (a Node script, about
40 lines) stood in for Fly's edge: it ended TLS for that name, added
`X-Forwarded-Proto: https`, and forwarded to the container. Chrome reached it
with `--host-resolver-rules="MAP www.lumenviae.org 127.0.0.1:8443"` and
`--ignore-certificate-errors`.

- **Page load:** Lighthouse mobile, `--preset=perf`, simulated slow 4G and
  a 4x CPU slowdown. Three runs per page, the median taken. Pages: `/`,
  `/mysteries/joyful`, `/meditation-sets/26/pray`.
- **Websocket:** Playwright in Chrome recorded each frame; the proxy counted
  the bytes on the wire, so compression is included.
- **Repeat visits:** the same page loaded twice in one browser profile, with
  the proxy logging every request that reached the release.
- **Database:** a telemetry handler on `[:lumen_viae, :repo, :query]`
  attached inside the running release with `rpc`.
- **Memory:** 40 connected pages held open, `:erlang.memory/1` after a full
  garbage collection, with and without them.

## What a visit costs now

Lighthouse, median of three, mobile (unchanged by this work, since a cold load
was already fast):

| | Home | Category | Set prayer page |
| --- | --- | --- | --- |
| Performance score | 97 | 95 | 99 |
| First contentful paint | 1.8 s | 1.8 s | 1.7 s |
| Largest contentful paint | 2.3 s | 2.6 s | 1.7 s |
| Cumulative layout shift | 0.036 | 0.002 | 0.024 |
| Total blocking time | 0 ms | 0 ms | 0 ms |
| Transferred | 348 KB | 2.83 MB | 250 KB |
| Document (gzip) | 8.0 KB | 8.6 KB | 7.8 KB |
| JavaScript (gzip) | 50.6 KB | 50.6 KB | 50.6 KB |
| CSS (gzip) | 20.9 KB | 20.9 KB | 20.9 KB |
| Fonts | 133 KB | 133 KB | 70 KB |

The release already minified and digested its assets, served digested files
as `public, max-age=31536000, immutable`, and served precompressed `.gz`
files; Bandit compresses the HTML. The server answers in 15 to 25 ms.

## What changed

| Where | What | Effect |
| --- | --- | --- |
| `endpoint.ex`, socket | `compress: true`: the `/live` socket negotiates permessage-deflate | A visit's websocket traffic falls from 17.8, 18.4 and 16.7 KB to 4.75, 5.4 and 4.65 KB (home, category, prayer): about 73% less |
| `endpoint.ex`, `Plug.Static` | `images` and `fonts` (not digested, so they could only be revalidated) are cached for a week | A second visit sends 3 requests to the server instead of 6 or 7, and none of them a `304` (they are the document and `favicon.ico`, which Chrome fetches again every time) |
| `Rosary`, home, category page | `list_visible_meditation_set_summaries` and `..._by_category`: sets with `meditation_count` and `audio_count`, not every meditation's text | Home: 5 queries and 14 ms down to 4 and 9 ms; category: 4 and 11 ms down to 3 and 2.6 ms. Each connected home page holds about 220 KB instead of 735 KB, a category page about 100 KB instead of 185 KB |

Left alone because measuring showed no gain: esbuild flags (`--legal-comments`,
`--charset`: 160.2 KB to 160.1 KB), `phx.digest` (already runs), the
`cache_static_manifest` (already set in `config/prod.exs`), the hooks (all but
`FocalPoint`, 1.4 KB and admin-only, are used by the public site) and the
prayer page's diffs (see below).

### Things to know about those changes

- **Compression costs memory.** Each open socket holds a zlib context:
  about 300 KB on top of the page's own process. At the machine's
  `hard_limit` of 100 connections that is 30 MB of 1 GB, and the saving above
  is in bandwidth on every visit. If memory ever matters more than bytes,
  remove `compress: true`.
- **Images and fonts can be a week stale.** A file replaced in place under
  the same name reaches a returning visitor up to a week late. Give a changed
  image a new name, as the WebP variants and woodcuts already do. `robots.txt`,
  `sitemap.xml` and the favicon still revalidate.
- **"Narrated" now means a non-empty `audio_url`.** The page used to ask
  whether `audio_url` was truthy, so an empty string counted as narration; the
  aggregate (`has_audio?`) already treats an empty string as none. No set has
  one today.

### What the prayer page sends

One bead-by-bead press is three frames: the event (107 bytes), a `live_patch`
(136 bytes) and the diff. A whole press, in and out, is 1.4 to 2.4 KB on
the bead screen (up to 5.8 KB where a new decade's text arrives) and 3.1 to
4.8 KB on the beads page, with 9.5 KB for the first move from the opening
prayers to a decade, which carries the meditation. Most of a diff is the
progress strand's class strings, which are dynamic attributes. Nothing large
is re-sent, and no stream or `temporary_assigns` would make a smaller diff:
the audio URLs are signed once per voice, not per render.

### Queries

No N+1 on any public page. Per page: home 4, category 3, a set's prayer page 6
(set, author, memberships, meditations, narrations, mysteries), a category's
prayer page 1, Scripture 1, privacy 0. A connected page runs them again on its
second mount, which LiveView does by design.

## What is left, and needs a template or stylesheet change

In order of what it would save a phone:

1. **The category page loads 2.1 MB of set artwork from S3** (four JPEGs of
   207 to 866 KB, whatever size was uploaded) and a 411 KB JPEG of the header
   woodcut, `annunciation-durer.jpg`, where a 640 pixel WebP of it exists. The
   artwork is resized at upload, not by this change: see "Paintings served from
   S3" in `docs/IMAGES.md`. The woodcut is a template change:
   `<.woodcut_plate>` serves the WebP. **Done in the redesign**: the header
   draws its woodcut through `<.woodcut_plate>`.
2. **Layout shift on the home page (0.036).** It comes from the web fonts
   arriving after the text: blocking Google Fonts in a test run takes it to
   0.000, with no change in the paint times. Self-hosting the three families,
   with `size-adjust` on the fallback faces, removes the shift and the
   cross-origin hop. That is a stylesheet change. **Done in the redesign**:
   the fonts are served from `priv/static/fonts` with fallback faces
   measured against Times New Roman (the fonts block in `app.css`); home
   measures 0.000 locally.
3. **The fonts are 133 KB on the home page**: EB Garamond, Cinzel and Cinzel
   Decorative, ten styles between them asked for in the `<link>` in
   `root.html.heex`. Any the redesign does not use need not be asked for.
   **Done in the redesign**: three files, about 109 KB, all Latin-subset
   woff2 (Cormorant Garamond and EB Garamond upright, each a variable font
   over 500 to 600, and EB Garamond italic 500). The two uprights are
   preloaded; the italic loads at first use.
4. **`woodcuts/*-640.webp`** are 84 to 256 KB each, most about 200 KB, large
   for a 640 pixel print, because a woodcut's fine lines do not compress. A
   lower quality or a 480 pixel width would shrink them; it changes how the
   print looks, so it is a decision for whoever chose them.

First paint is bound by the HTML and the stylesheet, two round trips on a slow
connection: nothing on the server shortens that further.

## Running it again

The container needs `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`,
`PHX_SERVER=true` and, to open a remote shell for the query counter,
`RELEASE_NODE=lumen_viae@127.0.0.1`, since the release's `rel/env.sh.eex`
names the node from the container's hostname and a long name needs a dot. Fake
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` make the prayer page sign its
audio URLs without any request to S3. Lighthouse and Playwright come from
`npx`, as in `scripts/e2e/run.sh`.
