# Page metadata

What each public page says about itself to search engines and link previews:
its title, description, canonical address, preview image and structured data.
Written on 7 October 2026.

## How a page says it

A public LiveView calls `LumenViaeWeb.PageMeta.put/3` from `mount/3`:

```elixir
PageMeta.put(socket, "/mysteries/joyful",
  title: "The Joyful Mysteries",
  description: "...",
  image: PageMeta.category_image("joyful"),
  trail: [{"The Joyful Mysteries", "/mysteries/joyful"}]
)
```

That assigns `:page_title`, `:meta_description` and `:meta`. The root layout
passes them to `LumenViaeWeb.Components.MetaTags`, which writes the tags in
`<head>` of the first, server-rendered response: the one a crawler or a link
preview reads. A page that sets nothing gets the site's default description,
the Our Lady of Sorrows banner and the address it was asked for.

`PageMeta` is a value module, like `LumenViae.Rosary.Categories`: no state, no
queries. The text for a set's or a category's prayer page is built there
(`pray_set/3`, `pray_category/2`) so it can be tested without a page.

## What every public page has

- A `<title>` of the page's own, ending ` | Lumen Viae` (the root layout's
  suffix).
- A description of at most 160 characters. A longer one is cut at a word and
  ends in `...`; the prayer pages choose the longest of a few sentences that
  fits rather than cutting.
- `<link rel="canonical">` and `og:url`: the page's path with no query string.
  The category page's filters and the prayer page's `mystery`, `count`,
  `voice` and `form` are views of the page, not other pages.
- `og:title`, `og:description`, `og:type` (`website`), `og:site_name`, and
  `og:image` with `og:image:width`, `og:image:height` and `og:image:alt`, with
  the same in `twitter:*`.

## Preview images

Every image is an absolute address to a JPEG, since not every preview crawler
reads WebP.

| Page | Image |
| --- | --- |
| Home, Scripture, privacy | the Our Lady of Sorrows banner, 1200x410 |
| The app page | three app screenshots, `images/app/og-app.jpg`, 1200x630 |
| A category | the woodcut its header shows (`PageMeta.category_image/1`) |
| A set's prayer page | the woodcut of the set's first mystery, else the category's |
| A category's prayer page | the woodcut of the category's first mystery |

The woodcuts are taller than wide, so those pages use the `summary` Twitter
card, which shows a small square, and the banner pages use
`summary_large_image`. The large card would crop a portrait print to a strip.

## Structured data

Light, and nothing that is not true of the page.

- Home: `WebSite`, with its name, address and description. No `SearchAction`:
  the site has no search.
- A category's page, a set's prayer page and a category's prayer page:
  `BreadcrumbList` (Home, the category, and the page itself).
- No ratings, no reviews, no `Organization` claims.

The JSON is written with `"<"` escaped, so a set's name can never close the
script tag.

## The sitemap

`priv/static/sitemap.xml` stays static. A dynamic one listing visible sets
would list `/meditation-sets/:id/pray`, which `priv/static/robots.txt`
disallows (a crawler walking the prayer flow used to trip the Complete
button), and a sitemap that names addresses `robots.txt` forbids is a
contradiction a crawler resolves by indexing the bare address. If the prayer
pages are ever opened to crawlers, change `robots.txt` first, then generate the
sitemap from `Rosary.list_visible_meditation_sets!/0`.

Link previews do not depend on the sitemap, but they may depend on
`robots.txt`: preview crawlers differ in whether they obey it, and some, such
as Twitterbot, are documented to. While `/meditation-sets/` is disallowed, a
set's prayer link may show a preview on some services and not on others. That
is a trade the owner makes between the Complete button and shareable sets; the
tags are in place for the day it changes.

## Tests

`test/lumen_viae_web/page_meta_test.exs` reads the real response of every
public page and checks each of the above.
