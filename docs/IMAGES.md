# Static images

Which images under `priv/static/images` the public site loads, the lighter
WebP versions that sit next to them, and where each is wired in. Written on
7 October 2026; updated the same day when the variants were wired in.

## What a phone saves

A phone loading the home page downloaded about 2.17 MB of static images
before this work (the ornate background, the Madonna cutout, the Queen of
Heaven and the Our Lady of Sorrows banner). The home page now draws the
background and the cutout only, and with their WebP variants a phone fetches
about 0.13 MB of them instead of 1.91 MB. The cutout was an 864x1512 PNG of
1.76 MB drawn 128 to 176 CSS pixels wide; its 512 pixel WebP is 67 KB.

The footer crucifix, on every page, goes from 42.5 KB to 28.6 KB (14 KB on a
1x screen). The category page saves about 82 KB (the background).

## The variants

`<name>-<width>.webp`, next to the original, `<width>` being the pixel width
of the file. Made with:

```
cwebp -q <quality> -alpha_q 90 -m 6 -resize <width> 0 <original> -o <name>-<width>.webp
```

| Original | Variants | Used by |
| --- | --- | --- |
| `ornate-blue-gold-bg-symbols.jpg` (143,570) | `-480.webp` 31,022; `-735.webp` 61,924 | home hero, category header; `/pray` not yet |
| `pngs/blessed-mary-with-child-jesus-rustic-cutout.png` (1,762,243) | `-320.webp` 33,704; `-512.webp` 66,982 | home hero |
| `pngs/crucifix.png` (42,535) | `-160.webp` 13,864; `-256.webp` 28,648 | `<.medallion type="crucifix">`, the footer |

The ornate background is drawn at 4 to 5 percent opacity, so it is
compressed hard (quality 25). The cutout keeps its transparency.
`crucifix.png` is really a GIF with a `.png` name; browsers read it by
content. AVIF was not made: `avifenc` is not installed.

Variants were made, then removed, for the Queen of Heaven and the Our Lady of
Sorrows banner: no template shows either now. If a page brings one back,
make 320 and 474 pixel copies of the first, 768 and 1200 of the second, and
use the same `<picture>` shape as the cutout.

## How each call site is written

A `<picture>` with a WebP `<source>` and the original as the `<img>`, so a
browser that cannot read WebP still gets the original, with `width` and
`height` on the `<img>` so nothing shifts as it loads:

- The ornate background, in `live/home/index.html.heex` and
  `live/mysteries/category_list/header/header.ex`: `<picture class="contents">`
  so the `<img>`'s `h-full` still resolves against the wrapping `div`;
  `sizes="100vw"`; 735x489.
- The cutout, in `live/home/index.html.heex`:
  `sizes="(min-width: 768px) 176px, 128px"` (the `w-32 md:w-44` it is drawn
  at); 864x1512.
- `<.medallion>` and `<.medallion_bg>` in `core_components.ex`: one private
  `medallion_img/1` renders every medallion, with the pixel size of each
  file; only the crucifix has a `srcset` (`medallion_image/1`), and
  `medallion_sizes/2` gives its `sizes` from the size class.
- `<.arch_frame>` takes optional `srcset` and `sizes` attributes, passed to
  its `<img>` (a `srcset` rather than a `<picture>`, so the `clip-path` and
  `object-cover` stay on one element). Both default to `nil`, so existing
  callers are unchanged. No caller passes them today: the category header
  frames a woodcut, which has no variants.

### Still to do: `/pray`

`live/pray/index.html.heex` (line 9 when this was written) draws the same
ornate background and was left alone, as another worker is rewriting it.
Replace its `<img src="/images/ornate-blue-gold-bg-symbols.jpg" ...>` with:

```heex
<picture class="contents">
  <source
    type="image/webp"
    srcset="/images/ornate-blue-gold-bg-symbols-480.webp 480w, /images/ornate-blue-gold-bg-symbols-735.webp 735w"
    sizes="100vw"
  />
  <img
    src="/images/ornate-blue-gold-bg-symbols.jpg"
    width="735"
    height="489"
    alt=""
    class="w-full h-full object-cover"
  />
</picture>
```

## Files kept for other reasons

- `pngs/our-lady-of-sorrows-horizontal.jpg`: the `og:image` and
  `twitter:image` in `root.html.heex`. They stay a JPEG, as link-preview
  crawlers do not all read WebP.
- `pngs/queen-of-heaven-white-bg.jpg`: named only in the `<.arch_frame>`
  example in `core_components.ex`. No page shows it; a candidate for deletion
  with that example.
- `pngs/deo-gratias.png` and `carlo-acutis.jpg`: read as fixtures by
  `test/lumen_viae/images/inspector_test.exs`.
- `pngs/holy-family.png`, `pngs/olive-branch-pax.png`,
  `pngs/saint-benedict-symbol.png`: reached through `<.medallion>`. Only the
  Saint Benedict symbol is shown (the nav, 9 KB, where a WebP was larger);
  the other two have no caller and no variants.
- Used only by `archive/`: `woodcuts/coronation-durer.jpg`,
  `woodcuts/madonna-crescent-crop.jpg`, `pngs/most-sacred-heart-white-bg.jpg`.
- `woodcuts/`: the five live woodcuts (800 pixels wide, 198 to 456 KB each,
  drawn about 160 to 208 CSS pixels wide) have no variants and are now the
  largest images on the Mysteries pages. When that folder settles, 320 and
  480 pixel copies with `sizes="(min-width: 768px) 208px, 160px"` would fit
  the `w-44 md:w-56` figure with its `p-2` frame.

## Deleted

About 2.35 MB of images that nothing in `lib/`, `assets/`, `test/`, `priv/`
or `config/` named: `pngs/cruxified-jesus.jpg`, `pngs/black-white-chalise.png`,
`pngs/angels-around-tabernacle.jpg`, `pngs/cruxific-circle-extended.jpg`,
`pngs/ornate-corner.jpg`, `pngs/ave-gratia-plena-white-bg.jpg`,
`pngs/long-straight-black-ornatae.png`,
`pngs/middle-bell-curve-white-ornate.png`, `pngs/black-ornate.png`,
`pngs/white-ornate.png` (the ornate divider component is gone),
`woodcuts/madonna-crescent-durer.jpg`, the three `white-background/` files
and `logo.svg`. They are in the git history if one is wanted back.

## Paintings served from S3

The mystery and category paintings (`docs/MYSTERY_PAINTINGS.md`) are not
static files: they are uploaded through the console to the public assets
bucket (`LumenViae.Curation.ArtworkUpload`, URL from `Rosary.artwork_url/1`).
The originals are whatever was uploaded: JPEGs of 1200 to 4000 pixels, up
to 12 MB, stored without resizing, and still what the APIs serve. Beside
each, the upload stores WebP display variants at 480, 960 and 1600 pixels
wide, and the public pages (the category list's set cards and the home
page's category cards) draw from those with `srcset`. Paintings uploaded
before the variants existed are backfilled with
`mix lumen_viae.artwork_variants`. See docs/MYSTERY_PAINTINGS.md,
"Display variants".

## Also worth doing

`Plug.Static` in `lib/lumen_viae_web/endpoint.ex` sets no
`cache_control_for_etags`, so every image is revalidated on each visit (a
304, but a round trip each). The files are not content-hashed, so a long
`max-age` would pin an edited image; a day
(`cache_control_for_etags: "public, max-age=86400"`) is the safe middle.
