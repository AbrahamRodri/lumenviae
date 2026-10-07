# Mystery paintings

The paintings the iOS app shows for the mysteries and on the categories'
cards, and what it takes to serve each from the server. Written on 4
October 2026 for the owner's steps of the Android plan's W8 (decision D7):
confirm each painting's source and licence, supply originals where the
bundled file will not pass the upload rules, and upload through the
console in production. Nothing here has been uploaded; until a painting is
uploaded and published, the API serves its `artwork` as null and the apps
keep their bundled copy.

## The headline

- **26 paintings**: the 25 the app maps to mysteries
  (`Constants.swift`, `*MysteryImages`), and `seven_sorrows_pieta`, the
  Seven Sorrows' card (`MysteryCategory.swift`, `cardImageName`). They fill
  **28 slots**: the 27 mysteries and the Sorrows' card. The third and fifth
  sorrows reuse `joyful_finding` and `sorrowful_crucifixion`, so each of
  those two is uploaded twice, once on each mystery's page. The four
  Rosaries' cards are their first mystery's painting
  (`card_mystery_key`), so they need no upload of their own.
- **14 of 26 pass the upload rules as bundled.** 11 are under 1200px on
  their short side and need a larger original; one, `joyful_annunciation`,
  is over 4000px on its long side and needs scaling down.
- **22 of 26 have recorded provenance**: the work, its collection and a
  Wikimedia Commons file with a Public domain licence, from
  `Tools/ContentSourcing/sources.py` in the iOS repository (`EXISTING` and
  `PROVENANCE`, Sept 2026). For 17 the bundled image is that Commons file
  or a resize of it ("exact"); for 5 it is the same work but not proven to
  be that file ("same work": a crop or another scan). Every one of the 14
  that pass the rules has provenance.
- **4 have none**: `joyful_nativity`, `glorious_ascension`,
  `glorious_pentecost` and `glorious_assumption`. The sourcing notes
  describe each picture but could not identify it, and mark it "ask
  Abraham". They are owner decisions: identify the work, its source and its
  licence, or replace the painting, before any upload. No source or licence
  is guessed here.
- The app bundles no credits, so every attribution field below comes from
  the sourcing notes, not from the app.

The upload rules are `LumenViae.Curation.ArtworkUpload`'s: a JPEG, at most
12 MB, at least 1200px on its shortest side and at most 4000px on its
longest, in RGB (not CMYK). The original is never resized on the
server; the website's smaller copies are made beside it (see "Display
variants" below). All 26
bundled files are RGB JPEGs under 12 MB, so size is the only rule any of
them fails.

## Every slot

Pixel sizes were read from the app's `Assets.xcassets` with `sips`. A row
names what is recorded about the painting and what the owner must do.

| Slot | The app's asset | Pixels | Passes the rules | Provenance | What the owner must do |
| --- | --- | --- | --- | --- | --- |
| `joyful_1` | `joyful_annunciation` | 4351x5077 | no (long side 5077px, over 4000) | The Annunciation, Paolo de Matteis, 1712 (Saint Louis Art Museum). Commons: `Paolo de Matteis - The Annunciation - 69-1973 - Saint Louis Art Museum.jpg`, Public domain, match: same work | Confirm the source: the bundled file is the same work, but not proven to be the Commons file named; scale it down to at most 4000px on its long side, then upload. |
| `joyful_2` | `joyful_visitation` | 1157x1600 | no (short side 1157px, under 1200) | The Visitation, Raphael and workshop (Giulio Romano), c. 1517 (Museo del Prado). Commons: `Visitación de Rafael.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; supply an original at least 1200px on its short side (short side 1157px, under 1200), then upload. |
| `joyful_3` | `joyful_nativity` | 711x1080 | no (short side 711px, under 1200) | Not identified: The Adoration of the Shepherds, night scene with putti (Italian Baroque, in the manner of Guido Reni). Recorded as "ask Abraham"; no source or licence | Owner decision: identify the work and its source and licence, or replace the painting. Do not upload until then. |
| `joyful_4` | `joyful_presentation` | 800x1302 | no (short side 800px, under 1200) | The Presentation in the Temple, Simon Vouet, 1641 (Musée du Louvre). Commons: `Simon Vouet - Presentation in the Temple - WGA25366.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; supply an original at least 1200px on its short side (short side 800px, under 1200), then upload. |
| `joyful_5` | `joyful_finding` | 3051x1667 | yes | Christ among the Doctors, Paolo Veronese, c. 1558 (Museo del Prado). Commons: `Disputa con los doctores (El Veronés) grande.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `sorrowful_1` | `sorrowful_agony` | 960x1346 | no (short side 960px, under 1200) | Christ in Gethsemane, Heinrich Hofmann (d. 1911), 1886 (Riverside Church, New York). Commons: `Christ in Gethsemane.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; supply an original at least 1200px on its short side (short side 960px, under 1200), then upload. |
| `sorrowful_2` | `sorrowful_scourging` | 1118x1600 | no (short side 1118px, under 1200) | The Flagellation of Our Lord Jesus Christ, William-Adolphe Bouguereau (d. 1905), 1880 (Cathédrale Saint-Louis, La Rochelle). Commons: `William-Adolphe Bouguereau (1825-1905) - The Flagellation of Our Lord Jesus Christ (1880).jpg`, Public domain, match: exact | Confirm the licence on the Commons page; supply an original at least 1200px on its short side (short side 1118px, under 1200), then upload. |
| `sorrowful_3` | `sorrowful_crowning` | 2362x2705 | yes | The Crowning with Thorns, Anthony van Dyck, 1618–20 (Museo del Prado). Commons: `Anthonis van Dyck 004.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `sorrowful_4` | `sorrowful_carrying` | 1218x1600 | yes | Christ Carrying the Cross, Anthony van Dyck, 1617–18 (Sint-Pauluskerk, Antwerp). Commons: `Anthony van Dyck - Jesus Christ bearing the Cross.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `sorrowful_5` | `sorrowful_crucifixion` | 2046x3051 | yes | Christ Crucified, Diego Velázquez, c. 1632 (Museo del Prado). Commons: `Cristo crucificado.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `glorious_1` | `glorious_resurrection` | 566x732 | no (short side 566px, under 1200) | The Resurrection of Christ, Noël Coypel, 1700 (unconfirmed (French royal commission)). Commons: `Noël Coypel - Resurrection of Christ (large version).jpg`, Public domain, match: same work | Confirm the source: the bundled file is the same work, but not proven to be the Commons file named; supply an original at least 1200px on its short side (short side 566px, under 1200), then upload. |
| `glorious_2` | `glorious_ascension` | 672x1024 | no (short side 672px, under 1200) | Not identified: The Ascension (Spanish or Flemish Baroque, 17th c.). Recorded as "ask Abraham"; no source or licence | Owner decision: identify the work and its source and licence, or replace the painting. Do not upload until then. |
| `glorious_3` | `glorious_pentecost` | 1024x772 | no (short side 772px, under 1200) | Not identified: Pentecost (not Maíno's: the Prado's Maíno is a different composition). Recorded as "ask Abraham"; no source or licence | Owner decision: identify the work and its source and licence, or replace the painting. Do not upload until then. |
| `glorious_4` | `glorious_assumption` | 800x1245 | no (short side 800px, under 1200) | Not identified: The Assumption of the Virgin (Neapolitan/Roman, 18th c., in the manner of Giaquinto or Solimena). Recorded as "ask Abraham"; no source or licence | Owner decision: identify the work and its source and licence, or replace the painting. Do not upload until then. |
| `glorious_5` | `glorious_coronation` | 1202x1600 | yes | The Coronation of the Virgin, Diego Velázquez, 1635–36 (Museo del Prado). Commons: `Diego Velázquez - Coronation of the Virgin - Prado.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `luminous_1` | `luminous_baptism` | 1920x2727 | yes | The Baptism of Christ, Guido Reni, c. 1623 (Kunsthistorisches Museum, Vienna). Commons: `Guido Reni - The Baptism of Christ - Google Art Project.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `luminous_2` | `luminous_cana` | 1920x1407 | yes | The Marriage Feast at Cana, Bartolomé Esteban Murillo, c. 1672 (Barber Institute of Fine Arts, Birmingham). Commons: `The Barber Institute of Fine Arts - Bartolomé Esteban Murillo - The Marriage Feast at CanaFXD.jpg`, Public domain, match: same work | Confirm the source: the bundled file is the same work, but not proven to be the Commons file named; upload the bundled file. |
| `luminous_3` | `luminous_proclamation` | 1377x1545 | yes | The Sermon on the Mount, Carl Heinrich Bloch (d. 1890), 1877 (Museum of National History, Frederiksborg Castle). Commons: `Bloch-SermonOnTheMount.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `luminous_4` | `luminous_transfiguration` | 1067x1608 | no (short side 1067px, under 1200) | The Transfiguration, Raphael, 1516–20 (Pinacoteca Vaticana). Commons: `Transfiguration Raphael.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; supply an original at least 1200px on its short side (short side 1067px, under 1200), then upload. |
| `luminous_5` | `luminous_eucharist` | 1517x998 | no (short side 998px, under 1200) | The Last Supper, Juan de Juanes, c. 1562 (Museo del Prado). Commons: `The Last Supper by Vicente Juan Macip.jpg`, Public domain, match: same work | Confirm the source: the bundled file is the same work, but not proven to be the Commons file named; supply an original at least 1200px on its short side (short side 998px, under 1200), then upload. |
| `seven_sorrows_1` | `seven_sorrows_simeon` | 1920x2473 | yes | Simeon's Song of Praise, Rembrandt, 1631 (Mauritshuis, The Hague). Commons: `Simeon in the temple, by Rembrandt van Rijn.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `seven_sorrows_2` | `seven_sorrows_flight` | 1920x2465 | yes | The Flight into Egypt, Bartolomé Esteban Murillo, 1647–50 (Musei di Strada Nuova (Palazzo Bianco), Genoa). Commons: `Bartolomé Esteban Murillo - The Flight into Egypt - Google Art Project.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `seven_sorrows_3` | `joyful_finding` | 3051x1667 | yes | Christ among the Doctors, Paolo Veronese, c. 1558 (Museo del Prado). Commons: `Disputa con los doctores (El Veronés) grande.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `seven_sorrows_4` | `seven_sorrows_meeting` | 1920x2663 | yes | Christ Falls on the Way to Calvary (Lo Spasimo di Sicilia), Raphael, c. 1516 (Museo del Prado). Commons: `Christ Falling on the Way to Calvary - Raphael.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `seven_sorrows_5` | `sorrowful_crucifixion` | 2046x3051 | yes | Christ Crucified, Diego Velázquez, c. 1632 (Museo del Prado). Commons: `Cristo crucificado.jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `seven_sorrows_6` | `seven_sorrows_descent` | 1689x2248 | yes | The Descent from the Cross, Peter Paul Rubens, 1612–14 (Cathedral of Our Lady, Antwerp). Commons: `Peter Paul Rubens - Descent from the Cross - WGA20212 (cropped).jpg`, Public domain, match: same work | Confirm the source: the bundled file is the same work, but not proven to be the Commons file named; upload the bundled file. |
| `seven_sorrows_7` | `seven_sorrows_burial` | 1920x2852 | yes | The Entombment of Christ, Caravaggio, 1603–04 (Pinacoteca Vaticana). Commons: `The Entombment of Christ-Caravaggio (c.1602-3).jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |
| `card: seven_sorrows` | `seven_sorrows_pieta` | 1920x3015 | yes | Pietà, William-Adolphe Bouguereau (d. 1905), 1876 (Private collection). Commons: `William-Adolphe Bouguereau (1825-1905) - Pieta (1876).jpg`, Public domain, match: exact | Confirm the licence on the Commons page; upload the bundled file. |

## How to upload

In the production console, signed in as an admin:

1. **A mystery's painting**: Mysteries (`/admin/mysteries`), the mystery's
   Edit page, the **Artwork** panel at the foot. Choose the JPEG and
   upload it, then click the painting to set its focal point (the crops
   beside it are the frames the app draws).
2. **The Seven Sorrows' card**: Mysteries, **Seven Sorrows card**
   (`/admin/mysteries/cards/seven_sorrows`), the same panel. The card's
   record is created the first time anything on that page is saved.
3. **Describe it** in the panel's "About the painting" form. Two fields
   are the publish gate, and a painting is not served until both are set:
   - **Description** (alt text): what is shown, for screen readers.
   - **Licence**: for these, Public domain, as the Commons page says. Do
     not choose "Unknown"; it would publish the painting with no licence
     established.

   Fill in Title, Artist, Year and Source URL (the Commons file page) too:
   they are the attribution the apps show.

Each upload gets a new address, so a replaced painting refreshes on every
device by itself. Publishing a painting moves the content document's
`version`, so a device polling it fetches the new painting's address.

Check afterwards with `GET /api/v2/mysteries`, or
`GET /api/v2/rosary-content?fields[rosary_content]=mysteries,categories`:
a published painting's `artwork` (a card's `card_artwork`) is an object,
and every other is null.

## Display variants

Every upload is stored twice over. The original goes to the public assets
bucket exactly as uploaded, at `<scope>/<id>/<hash>.jpg`, and is what the
iOS and Android apps, the APIs and the console show. Beside it go WebP
copies for the website at `<scope>/<id>/<hash>-480.webp`, `-960.webp` and
`-1600.webp` (`LumenViae.Images.Variants`): quality 85, resized with
lanczos3, turned upright by the EXIF orientation, converted to sRGB, and
stripped of every piece of metadata except the colour profile. A width at
or above the original's is never made, so nothing is upscaled.

The widths actually stored are recorded on the row
(`image_variant_widths`), and the public pages offer only those, with the
original as the `<img>` fallback. A painting with no variants yet is drawn
from its original, exactly as before, so a missing variant can never show
as a broken image.

Paintings uploaded before this existed have no variants until the backfill
runs. It finds every set, author, mystery and category card whose painting
is missing a variant, downloads the original, makes the missing ones and
records them. It never changes the original, and it skips anything already
done, so it can be re-run after a partial failure. **Always dry-run
first.** The dry run reads the database and lists what it would make,
without touching S3 or writing anything.

Locally:

    mix lumen_viae.artwork_variants --dry-run
    mix lumen_viae.artwork_variants

In production, after the deploy that adds the `image_variant_widths`
column:

    fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.artwork_variants(dry_run: true)'"
    fly ssh console -C "/app/bin/lumen_viae eval 'LumenViae.Release.artwork_variants()'"

Each painting is a GET of the original and three PUTs. Read the output:
`WARN` means a painting's original is not in the bucket, and `ERROR` means
only some of its variants were stored, or a download or the database write
failed (run it again). The mix task exits non-zero after its summary line
when any painting failed; the release task returns the counts
(`%{succeeded:, warnings:, failed:, failures:}`) and logs each failure.
A photograph recorded sideways by an earlier upload (an Exif quarter
turn) has its size corrected by the same run. Backfill writes do not appear in a record's History panel.
