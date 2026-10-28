# Woodcuts

The plates in `priv/static/images/woodcuts/` are black-and-white woodcuts
and engravings: Durer, Schongauer, Schnorr von Carolsfeld, Dore and their
like. Every one is listed in `priv/static/images/woodcuts/manifest.json`
with its source and licence.

## The rule

- Public domain only. The Commons file page must show a public-domain or
  CC0 licence (PD-old, PD-old-100, PD-Art, PD-scan, CC0, or a plain
  "Public domain" tag on the work of an artist dead over 100 years).
- Wikimedia Commons only (`commons.wikimedia.org`, `upload.wikimedia.org`).
  No other site, however free it says it is.
- Never overwrite an existing plate. A better scan of a covered mystery
  gets a new file name, and the manifest entry moves to it.
- One file may serve two keys when one print shows both scenes (the
  Seven Sorrows reuse several Joyful and Sorrowful plates).

## Where the plates are shown

Through `LumenViaeWeb.Components.WoodcutPlate`, on a vellum mat on the
night pages (never inverted, never blended into the dark), at most one per
screen:

- the category page's header and the home page's category card, until the
  category's own painting is published: `WoodcutPlate.category_key/1`
  picks the Annunciation, the Crucifixion, the Resurrection, the Baptism
  and the Lamentation;
- the head of each category on the mysteries in Scripture page, the same
  five;
- on the prayer page, the current mystery's plate above its announcement,
  unless the reader turned images off in the settings pane.

The Baptism (`luminous_1`) and the Transfiguration (`luminous_4`) plates
are the owner's choice; never swap or alter them.

## Adding a plate

1. Find it on Commons. Check the licence on its file page, or with the API:
   `https://commons.wikimedia.org/w/api.php?action=query&prop=imageinfo&iiprop=url|extmetadata|size&titles=File:NAME&format=json`
   (`LicenseShortName`, `Artist`, `DateTimeOriginal`). Send a User-Agent
   that starts with `Mozilla/5.0`.
2. Download it outside the repo and look at it: the right scene, the whole
   composition, no watermark, no colour tint (make a sepia scan grayscale),
   no figures cropped.
3. Resize: long side 1200px, JPEG quality 75, up to about 550KB. Lower
   the quality a little if needed, but open the result at full size: no
   blocking, no smeared hatching.

   ```
   sips -Z 1200 -s format jpeg -s formatOptions 75 in.jpg --out out.jpg
   ```

4. Save it as `priv/static/images/woodcuts/<scene>-<artist>.jpg`, lowercase
   with hyphens (`visitation-durer.jpg`).
5. Make the WebP variants beside it, 640px and 1200px wide at quality 85.
   Never upscale: skip a width the JPEG does not reach.

   ```
   cwebp -q 85 -resize 640 0 visitation-durer.jpg -o visitation-durer-640.webp
   cwebp -q 85 -resize 1200 0 visitation-durer.jpg -o visitation-durer-1200.webp
   ```

6. Add its entry to `manifest.json`, keeping the list sorted by key. One
   plate per key.

## A manifest entry

```json
{
  "file": "visitation-durer.jpg",
  "key": "joyful_2",
  "title": "The Visitation",
  "artist": "Albrecht Durer",
  "year": "c. 1504",
  "series": "Life of the Virgin",
  "alt": "Mary and her cousin Elizabeth embrace before a house",
  "width": 850,
  "height": 1200,
  "source": "https://commons.wikimedia.org/wiki/File:...",
  "licence": "CC0",
  "webp": {"640": "visitation-durer-640.webp"}
}
```

- `width` and `height` are the size of the file in the repo
  (`sips -g pixelWidth -g pixelHeight file.jpg`).
- `alt` describes the scene for someone who cannot see it. Never the file
  name, never "woodcut of".
- `source` is the Commons file page, `licence` its `LicenseShortName`.
- `webp` lists only the variants that exist, by width.

## Keys

A mystery's key is `<category>_<order>`, the same key the mysteries table
and the app use. A plate that belongs to no single mystery takes
`general_<short-name>`.

| Key | Mystery |
| --- | --- |
| joyful_1 | The Annunciation |
| joyful_2 | The Visitation |
| joyful_3 | The Nativity |
| joyful_4 | The Presentation in the Temple |
| joyful_5 | The Finding in the Temple |
| sorrowful_1 | The Agony in the Garden |
| sorrowful_2 | The Scourging at the Pillar |
| sorrowful_3 | The Crowning with Thorns |
| sorrowful_4 | The Carrying of the Cross |
| sorrowful_5 | The Crucifixion |
| glorious_1 | The Resurrection |
| glorious_2 | The Ascension |
| glorious_3 | The Descent of the Holy Ghost |
| glorious_4 | The Assumption |
| glorious_5 | The Coronation of Our Lady |
| luminous_1 | The Baptism in the Jordan |
| luminous_2 | The Wedding at Cana |
| luminous_3 | The Proclamation of the Kingdom |
| luminous_4 | The Transfiguration |
| luminous_5 | The Institution of the Eucharist |
| seven_sorrows_1 | The Prophecy of Simeon |
| seven_sorrows_2 | The Flight into Egypt |
| seven_sorrows_3 | The Loss of Jesus in the Temple |
| seven_sorrows_4 | Mary Meets Jesus Carrying the Cross |
| seven_sorrows_5 | The Crucifixion |
| seven_sorrows_6 | Jesus Taken Down from the Cross |
| seven_sorrows_7 | The Burial of Jesus |
