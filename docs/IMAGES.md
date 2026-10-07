# Static images

Which images under `priv/static/images` the public site loads, the lighter
WebP versions that sit next to them, and the markup each call site should
use to ask for them. Written on 7 October 2026 on `website/images`.

Nothing in `lib/` was edited for this change. The variants are files only;
no page uses them until the call sites below are changed.

## The headline

- A phone loading the home page downloads about **2.17 MB** of static
  images today (the ornate background, the Madonna cutout, the Queen of
  Heaven and the Our Lady of Sorrows banner). With the variants below it
  downloads about **0.24 MB**, a saving of about **1.94 MB** per first
  visit. The Madonna cutout is 1.76 MB of that on its own: an 864x1512 PNG
  drawn 208 to 256 CSS pixels wide.
- `/pray` and the category list each save about 82 KB (the ornate
  background), and every page saves about 14 KB (the footer crucifix).
- The variants are lossy WebP made with `cwebp`; the originals are
  untouched and stay as the fallback inside `<picture>`. The variants add
  about 0.5 MB to the repository.
- The mystery and set paintings on the category list come from S3, not
  from this folder, and are **not** covered here: see "Paintings served
  from S3" below.

## How the variants are named and made

`<name>-<width>.webp`, next to the original, where `<width>` is the pixel
width of the file. They were made with:

```
cwebp -q <quality> -alpha_q 90 -m 6 -resize <width> 0 <original> -o <name>-<width>.webp
```

AVIF was not made: `avifenc` is not installed, and WebP is understood by
every browser the site supports. Each call site keeps the original as the
`<img>` inside `<picture>`, so a browser that cannot read WebP still gets
the file it gets today.

Plug.Static serves anything under `images/` (`LumenViaeWeb.static_paths/0`),
so the `.webp` files need no router or endpoint change.

## Inventory

Sizes are the file's bytes. "Live" means a template or component under
`lib/` names it; "archive" means only `archive/` does; "none" means nothing
in the repository names it.

| File | Pixels | Bytes | Status |
| --- | --- | --- | --- |
| `pngs/blessed-mary-with-child-jesus-rustic-cutout.png` | 864x1512 | 1,762,243 | live (home) and archive |
| `pngs/cruxified-jesus.jpg` | | 597,258 | none |
| `pngs/black-white-chalise.png` | | 521,567 | none |
| `woodcuts/crucifixion-durer.jpg` | 800x1060 | 455,655 | live (Sorrowful), left to `website/woodcuts` |
| `woodcuts/coronation-durer.jpg` | | 454,911 | archive only |
| `woodcuts/resurrection-durer.jpg` | 800x1134 | 450,980 | live (Glorious), left to `website/woodcuts` |
| `woodcuts/lamentation-durer.jpg` | 800x1030 | 442,166 | live (Seven Sorrows), left to `website/woodcuts` |
| `woodcuts/annunciation-durer.jpg` | 800x1121 | 410,703 | live (Joyful), left to `website/woodcuts` |
| `pngs/angels-around-tabernacle.jpg` | | 353,588 | none |
| `pngs/cruxific-circle-extended.jpg` | | 308,043 | none |
| `woodcuts/madonna-crescent-durer.jpg` | | 208,130 | none |
| `pngs/our-lady-of-sorrows-horizontal.jpg` | 1200x410 | 198,651 | live (home, and the `og:image` / `twitter:image`) |
| `woodcuts/baptism-dore.jpg` | 800x1014 | 197,824 | live (Luminous), left to `website/woodcuts` |
| `pngs/deo-gratias.png` | 474x266 | 181,459 | component only: `<.medallion type="deo_gratias">`, no caller |
| `pngs/holy-family.png` | 474x287 | 163,715 | component only: `type="holy_family"`, no caller |
| `pngs/olive-branch-pax.png` | 591x422 | 144,336 | component only: `type="pax"`, no caller |
| `ornate-blue-gold-bg-symbols.jpg` | 735x489 | 143,570 | live (home, pray, category list) and archive |
| `woodcuts/madonna-crescent-crop.jpg` | | 133,206 | archive only |
| `pngs/ornate-corner.jpg` | | 121,205 | none (the `.ornate-corners` CSS class is unrelated) |
| `pngs/queen-of-heaven-white-bg.jpg` | 474x568 | 60,808 | live (home) |
| `carlo-acutis.jpg` | | 46,098 | archive, and `test/lumen_viae/images/inspector_test.exs` reads it as a fixture |
| `pngs/crucifix.png` | 322x321 | 42,535 | live (footer on every page) and archive. It is a GIF with a `.png` name |
| `white-background/olive-branch-white-bg.jpeg` | | 40,668 | none |
| `white-background/holy-family-white-bg.jpg` | | 38,743 | none |
| `white-background/deo-gratias-white-bg.jpg` | | 37,843 | none |
| `pngs/ave-gratia-plena-white-bg.jpg` | | 36,033 | none |
| `pngs/white-ornate.png` | 1280x192 | 34,964 | component only: `<.ornate_divider variant="white">`, no caller |
| `pngs/most-sacred-heart-white-bg.jpg` | | 26,588 | archive only |
| `pngs/black-ornate.png` | 2048x231 | 18,241 | component only: `<.ornate_divider>`, no caller |
| `pngs/long-straight-black-ornatae.png` | | 16,732 | none |
| `pngs/middle-bell-curve-white-ornate.png` | | 14,008 | none |
| `pngs/saint-benedict-symbol.png` | 150x150 | 9,046 | live (nav, shown at 40 to 48 CSS pixels) |
| `logo.svg` | | 2,881 | none |

### Used only by archived pages

Left in place, as asked: `woodcuts/coronation-durer.jpg`,
`woodcuts/madonna-crescent-crop.jpg`, `pngs/most-sacred-heart-white-bg.jpg`
and `carlo-acutis.jpg` (which a test also reads).

### Named by nothing

These are not in `lib/`, `assets/`, `config/`, `docs/`, `test/` or
`archive/` (checked with `git grep`). They are not downloaded by anyone, so
they cost nothing to a phone, only repository and release size: 2.30 MB in
all. They are candidates for deletion, which this branch does not do:
`cruxified-jesus.jpg`, `black-white-chalise.png`,
`angels-around-tabernacle.jpg`, `cruxific-circle-extended.jpg`,
`woodcuts/madonna-crescent-durer.jpg`, `ornate-corner.jpg`, the three
`white-background/` files, `ave-gratia-plena-white-bg.jpg`,
`long-straight-black-ornatae.png`, `middle-bell-curve-white-ornate.png` and
`logo.svg`.

### Left out on purpose

- `woodcuts/`: another branch, `website/woodcuts`, is adding to that folder.
  No variants were made for the five live woodcuts (800 pixels wide, about
  200 to 455 KB, drawn 160 to 208 CSS pixels wide), so they remain the
  largest unfixed images on the Mysteries pages. When that branch lands,
  320 and 480 pixel widths with `sizes="(min-width: 768px) 208px, 160px"`
  would fit the `w-44 md:w-56` figure with its `p-2` frame.
- `pngs/saint-benedict-symbol.png`: 9 KB at 150 pixels; the WebP at 96
  pixels was larger than the original.
- The `og:image` and `twitter:image` in `root.html.heex` stay a JPEG:
  link-preview crawlers do not all read WebP.
- `black-ornate.png`, `white-ornate.png`, `holy-family.png`,
  `deo-gratias.png`, `olive-branch-pax.png`: no caller today, so no variants.
  Make them when a page starts using one.

## The variants

| Original | Variant | Bytes (original) |
| --- | --- | --- |
| `ornate-blue-gold-bg-symbols.jpg` | `ornate-blue-gold-bg-symbols-480.webp` 31,022 | 143,570 |
| | `ornate-blue-gold-bg-symbols-735.webp` 61,924 | |
| `pngs/blessed-mary-with-child-jesus-rustic-cutout.png` | `...-320.webp` 33,704 (320x560) | 1,762,243 |
| | `...-512.webp` 66,982 (512x896) | |
| `pngs/our-lady-of-sorrows-horizontal.jpg` | `...-768.webp` 67,926 | 198,651 |
| | `...-1200.webp` 138,230 | |
| `pngs/queen-of-heaven-white-bg.jpg` | `...-320.webp` 20,446 | 60,808 |
| | `...-474.webp` 42,946 | |
| `pngs/crucifix.png` | `...-160.webp` 13,864 | 42,535 |
| | `...-256.webp` 28,648 | |

The ornate background is drawn at 4 to 5 percent opacity, so it was
compressed hard (quality 25). The cutout keeps its transparency.

## Call sites

Line numbers are on `website/rosary-focus` at `72bda90`. The templates are
being edited, so find each by its `src`, not its line.

### 1. Ornate background: three templates

- `lib/lumen_viae_web/live/home/index.html.heex:10`
- `lib/lumen_viae_web/live/pray/index.html.heex:9`
- `lib/lumen_viae_web/live/mysteries/category_list/category_list.html.heex:8`

It fills its parent (`w-full h-full object-cover`), so `sizes` is the
viewport. Replace the `<img>` with:

```heex
<picture>
  <source
    type="image/webp"
    srcset="/images/ornate-blue-gold-bg-symbols-480.webp 480w, /images/ornate-blue-gold-bg-symbols-735.webp 735w"
    sizes="100vw"
  />
  <img
    src="/images/ornate-blue-gold-bg-symbols.jpg"
    alt=""
    class="w-full h-full object-cover"
  />
</picture>
```

The `class` stays on the `<img>`. A `<picture>` is inline and has no size
of its own, so check that `<img>`'s percentage height still resolves: give
the `<picture>` `class="contents"` (Tailwind's `display: contents`) so the
`<img>` sizes against the wrapping `div` exactly as before.

### 2. Madonna cutout: home hero

`lib/lumen_viae_web/live/home/index.html.heex:31`. Drawn `w-52 md:w-64`
(208 and 256 CSS pixels). Adding `width` and `height` reserves the space
before the image arrives; `h-auto` is already Tailwind's default for `img`,
so the class list does not change.

```heex
<picture>
  <source
    type="image/webp"
    srcset="/images/pngs/blessed-mary-with-child-jesus-rustic-cutout-320.webp 320w, /images/pngs/blessed-mary-with-child-jesus-rustic-cutout-512.webp 512w"
    sizes="(min-width: 768px) 256px, 208px"
  />
  <img
    src="/images/pngs/blessed-mary-with-child-jesus-rustic-cutout.png"
    width="864"
    height="1512"
    alt="Blessed Virgin Mary with Child Jesus"
    class="relative w-52 md:w-64 mx-auto drop-shadow-2xl"
  />
</picture>
```

This is the hero image, so it is also the page's largest paint. Consider
`fetchpriority="high"` on the `<img>` and no `loading="lazy"`.

### 3. Queen of Heaven: the arch frame component

The one call is `lib/lumen_viae_web/live/home/index.html.heex:142`
(`<.arch_frame src="/images/pngs/queen-of-heaven-white-bg.jpg" ...
class="w-64 md:w-80" />`), but the `<img>` is in
`lib/lumen_viae_web/components/core_components.ex:251`, shared by anything
that uses `<.arch_frame>`. Add an optional `srcset` attribute and `sizes`
attribute to the component and pass them through, rather than a `<picture>`,
so the `clip-path` style and `object-cover` stay on the one `<img>`:

```heex
<.arch_frame
  src="/images/pngs/queen-of-heaven-white-bg.jpg"
  srcset="/images/pngs/queen-of-heaven-white-bg-320.webp 320w, /images/pngs/queen-of-heaven-white-bg-474.webp 474w"
  sizes="(min-width: 768px) 320px, 256px"
  alt="Queen of Heaven"
  class="w-64 md:w-80"
/>
```

and in the component, on the `<img>`:

```heex
<img
  src={@src}
  srcset={@srcset}
  sizes={@sizes}
  alt={@alt}
  ...
/>
```

with `attr :srcset, :string, default: nil` and `attr :sizes, :string,
default: nil`. A `srcset` that lists only WebP files has no JPEG fallback
for a browser that cannot read WebP, which is acceptable only if the project
is happy to drop browsers older than Safari 14; if not, give the component a
`<picture>` with the `<source>` and keep the `<img src={@src}>` inside it.

### 4. Our Lady of Sorrows banner: home

`lib/lumen_viae_web/live/home/index.html.heex:301`. Drawn `w-full
max-w-2xl` (672 CSS pixels at most).

```heex
<picture>
  <source
    type="image/webp"
    srcset="/images/pngs/our-lady-of-sorrows-horizontal-768.webp 768w, /images/pngs/our-lady-of-sorrows-horizontal-1200.webp 1200w"
    sizes="(min-width: 42rem) 42rem, calc(100vw - 2rem)"
  />
  <img
    src="/images/pngs/our-lady-of-sorrows-horizontal.jpg"
    width="1200"
    height="410"
    alt="Our Lady of Sorrows"
    class="w-full max-w-2xl mx-auto rounded-2xl border border-gold/30 shadow-soft mb-8"
  />
</picture>
```

`calc(100vw - 2rem)` assumes 1rem of page padding each side; adjust to the
section's real gutter. Leave `root.html.heex:25` and `:35` (`og:image`,
`twitter:image`) as the JPEG.

### 5. Crucifix medallion: footer, every page

`lib/lumen_viae_web/components/footer.ex:17` calls `<.medallion
type="crucifix" size="medium" />`; the `<img>` is at
`lib/lumen_viae_web/components/core_components.ex:309` (`medallion`) and
`:352` (`medallion_bg`), both fed by `medallion_image_path/1` at `:314` to
`:318`. Medium is `w-28 md:w-32` (112 and 128 CSS pixels).

Only the crucifix has variants. The simplest change that does not touch the
other four types is a `srcset` the component looks up by type, `nil` when
there is none:

```heex
<img
  src={@image_path}
  srcset={medallion_srcset(@type)}
  sizes={medallion_sizes(@size)}
  alt=""
  class={["h-auto", @size_class]}
/>
```

```elixir
defp medallion_srcset("crucifix"),
  do: "/images/pngs/crucifix-160.webp 160w, /images/pngs/crucifix-256.webp 256w"

defp medallion_srcset(_type), do: nil

defp medallion_sizes("small"), do: "(min-width: 768px) 48px, 40px"
defp medallion_sizes("medium"), do: "(min-width: 768px) 128px, 112px"
defp medallion_sizes("large"), do: "(min-width: 768px) 256px, 192px"
```

With `srcset` set to `nil` Phoenix omits the attribute, and `src` stays the
fallback. `crucifix.png` is really a GIF; it is served as `image/png` and
browsers read it by content, so it works today, but replacing it with a
true PNG or the WebP is cleaner.

## Paintings served from S3

The mystery and category paintings (`docs/MYSTERY_PAINTINGS.md`) are not
static files: they are uploaded through the console to the public assets
bucket (`LumenViae.Curation.ArtworkUpload`, key from `Rosary.artwork_url/1`).
The one place the public site shows them is the set cards on the category
list, `category_list.html.heex:103`, a `w-full h-full object-cover` card at
least 24rem tall.

Those objects are whatever was uploaded: JPEGs of 1200 to 4000 pixels, up
to 12 MB, stored without resizing. A phone gets the original for every card.
This was not measured here (no production bucket listing was run) but it is
likely the biggest remaining cost, and nothing in `priv/static` can fix it.
The fix is in the upload path: write one or two narrower copies beside the
original in `ArtworkUpload` (for example 800 pixels wide as WebP), give
`Rosary.artwork_url/1` a way to name them, then use `srcset` at that
`<img>`. That is a change to `.ex` files and to what the apps may rely on
(`image_key` is the cache-invalidation contract), so it is a decision for the
coordinator, not part of this change.

## Also worth doing

`Plug.Static` in `lib/lumen_viae_web/endpoint.ex:37` sets no
`cache_control_for_etags`, so every image is revalidated on each visit (a
304, but a round trip each). The files are not content-hashed, so a long
`max-age` would also pin an edited image; a day
(`cache_control_for_etags: "public, max-age=86400"`) is the safe middle.
