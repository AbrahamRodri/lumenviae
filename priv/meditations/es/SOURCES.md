# Sources of the meditations' Spanish

`es/meditations.json` holds the meditations in Spanish, keyed by
meditation id, served in a meditation set's `translations` section with
`lang=es` (`GET /api/v2/meditation-sets/:id`, GraphQL `meditationSet`).
Abraham's rule: "the rest if you can easily get it translated yes go
ahead add it". The lead's for spelling: "modernize spelling and accents
only (á to a, Magestad to Majestad, fué to fue, devocion to devoción...),
never the wording".

Each entry records the fingerprint of the English title and text it was
made from (the first 16 hex digits of SHA-256 of `title + "\n" +
content`, from the production API on 4 November 2026). An English edit in
the console changes the fingerprint, and that meditation falls back to
English until its Spanish is redone. The recordings stay English.

This file covers Groups A, B and C of
`reports/rig-es/meditation-sources.md`, and Faber: the eight sets with a
Spanish source, the four Blessed Anne Catherine Emmerich sets (42, 45,
46, 53), and the eight sets of Newman, Guéranger, St Augustine, St John
Chrysostom and Faber (52, 63, 64, 54, 55, 62, 59, 65). 106 meditations:
30 copied, 76 the team's translation, marked `ai_translated`. Only
Sheen's three sets stay English (see below). The Spanish titles are the
team's, translating the English titles. Every copied text was checked
sentence by sentence against a saved copy of its source.

## The editions

- **[M1]** St Alphonsus Liguori, *Las glorias de María*, translated by P.
  Ramón García SJ, 2nd ed., Tolosa, Modesto Gorosabel, 1868 (public
  domain), from [the archive.org scan](https://archive.org/details/las-glorias-de-maria-san-alfonso-maria-de-ligorio.-an-o-1868),
  the seven sorrows, pp. 330-366, OCR corrected against the page images.
  García's translation is shorter than the English in places: 343 has no
  Seneca and gives Simeon's words indirectly; 344 has no "four hundred
  miles" and no St Bonaventure; 346 no Isaias quotations and no
  Bonaventure or Bernard by name; 347 gives St Vincent Ferrer
  indirectly; 348 says "dicen" for St Anselm and ends at "el pecho
  maternal"; 349 has no Turin, no St Bridget quotation and no Baronius.
- **[M2]** St Ignatius of Loyola, *Ejercicios espirituales*, the Spanish
  Autograph as transcribed in *Monumenta Ignatiana, Exercitia spiritualia*
  (Madrid, 1919), pp. 450-460, from [the archive.org scan](https://archive.org/details/monumentaignatia01igna).
  Ignatius wrote in Spanish: these are his own words. "Xpo." is written
  out. His parentheses around the Gospel words are kept.
- **[M3]** Ven. Mary of Agreda, *Mística Ciudad de Dios*, Barcelona,
  Librería Religiosa, 1860, Part II, from [the archive.org scan](https://archive.org/details/mcd186033).
  Agreda wrote in Spanish: these are her own words. Marison's English
  drops or adds phrases the Spanish keeps (328 "resuciten los muertos",
  336 "Porque le fue patente", 340 "como diré en el capítulo
  siguiente", 342 "le confesó por Hijo de Dios"); the Spanish is copied
  as she wrote it. Printer's errors corrected: "Perú" to "Pero" (337),
  "cástisimo" to "castísimo" (341).

- **[M4]** Bl. Anne Catherine Emmerich, *La dolorosa Pasión de N. S.
  Jesucristo, según las meditaciones de sor Ana Catalina Emmerich*,
  "traducida del francés" (the abbé de Cazalès's French), Madrid, Imp. de
  la Esperanza, a cargo de D. A. P. Dubrull, 1865, from [the archive.org
  scan](https://archive.org/details/la-dolorosa-pasion-de-nuestro-senor-jesucristo_202606)
  (the same edition in full view on [Google Books](https://books.google.com/books?id=cNu6oAluwJEC)),
  checked against the page images. The translator is not named: an
  anonymous work published 161 years ago is public domain. It follows
  the French, which condenses the English 1862 text, so the Spanish is
  shorter: 252 is shorter throughout; 253 has no gallery, open doors or
  potsherds; 255 has no "voice of God" passage and no trembling horse;
  254 says "puerta" where the English has a pillar. In 251 one printed
  sentence the English excerpt skips is left out. Printed paragraphs
  are split where the English breaks them. Printing errors corrected:
  "sotavoces" to "solas voces" (252; the English "they alone"), "dc" to
  "de" (255), and the missing "!" in «¡Salve, Rey de los judíos!» (253).
  The words of consecration (305), in italics in the print, are put in
  «». The print's own forms stay ("Quedaos", "Hacedlo morir", "le acompañaban", "a su rededor").

## What was changed from the source

- Spelling and accents modernized to the RAE's current rules, never the
  wording: "á" to "a", "fué" to "fue", "conçibirás" to "concebirás",
  "vn" to "un", "dixo" to "dijo", "Christo" to "Cristo", "Hierusalem" to
  "Jerusalén", "puncto" to "punto", "sancto" to "santo",
  "respetivamente" to "respectivamente" (338), "oprobrios" to "oprobios"
  (339) and the like. Older word forms stay ("agora", "veniendo",
  "della"), and so do the names as written ("Josef", "Elisabet",
  "Nicodemus"), and García's "no acostumbraba a semejantes viajes" (344).
- Punctuation: the ordinals are "2.º" and "3.º" (263 to 265), with the
  colon the others have after "3.º" in 265; a colon, not a semicolon,
  before the words "Hijo mío" (339).
- Footnote numbers left out; paragraph breaks put where the English has
  them, where a printed paragraph runs longer.

## Not from the books named in production

The fifteen meditations of the Joyful, Sorrowful and Glorious Liguori
sets (136-150) are credited in production to *The Glories of Mary*, but
they are not in it: they are the traditional English method of the
Rosary ("Let us contemplate in this mystery..."), as old English prayer
books print it. No Spanish source for them was looked for here; they are
the team's translation, marked. The English credit is not changed.

## St Thomas Aquinas

The only public-domain Spanish *Summa* (Hilario Abad de Aparicio, revised
by Manuel Mendía, Madrid, Moya y Plaza, 1880-1883; vol. 4 has the
Tertia Pars) is online only at the [Biblioteca Nacional de España](http://bdh-rd.bne.es/viewer.vm?id=0000015987&page=1),
which refuses automated reading. The five meditations are the team's
translation from the English Dominicans', marked. With the volume's two
PDFs downloaded, they can be copied instead. The modern Spanish editions
(BAC from 1947, the Dominicans' online text) are under copyright.

## Bl. Anne Catherine Emmerich

Only the *Dolorous Passion* has a public-domain Spanish edition online
([M4]); it covers 251-255 and 305. The other fourteen (227-231,
246-250, 301-304) come from *The Life of Jesus Christ and Biblical
Revelations*, and are the team's translation from the 1914 English,
marked. 246 has a shorter parallel account in [M4]'s Resurrection
chapter (p. 495), but it lacks most of the English excerpt, so it is
translated instead.

The one old Spanish *Life* is Guillermo Jünemann's (Freiburg, Herder,
1911; again 1921 and 1923), a one-volume condensation. Jünemann died at
Tomé in 1938 (Pablo Uribe Ulloa, *Cuestiones Teológicas* 47, 2020), so it
is public domain, but no scan of it was found (archive.org, Google
Books, Deutsche Digitale Bibliothek, Europeana, Memoria Chilena);
HathiTrust and the Biblioteca Digital Hispánica refused automated
reading and are still to be checked by hand. With a scan, the fourteen
can be copied where it has them. Older Spanish Lives of the Virgin
(Santiago de Chile 1877, 1894, Barcelona 1898) are known only from
catalogue records. Not used: the modern Spanish editions (*La amarga
Pasión*, Planeta 2004; J. Fuchs's *Visiones y revelaciones completas*,
Mexico, after 1966; the Espasa-Calpe *Vida de la Santa Virgen*, 1944;
the "Editorial Surgite!" PDFs).

## Newman, Guéranger, St Augustine, St John Chrysostom and Faber

These 42 meditations are the team's translation from the public-domain
English each set quotes (Newman's *Meditations and Devotions*, 1893;
Guéranger's *The Liturgical Year* in the 1871-1909 English (Laurence Shepherd and the Benedictines of Stanbrook); the Nicene and
Post-Nicene Fathers, 1888-1889; Faber's *Bethlehem*, 1860, and *The Foot
of the Cross*, 1858), marked. Their Spanish editions are modern and
under copyright and were not used: Cavaller's Newman (2006), the monks
of Silos's *El año litúrgico* (1954), the BAC's Augustine (from 1955)
and Ruiz Bueno's Chrysostom (1955-1956). No Spanish *Belén* by Faber
was found, and the only *Al pie de la Cruz* found is a 2017 PDF with no
translator or date.

## Bl. Fulton J. Sheen: left in English

Sets 25, 26 and 27 quote Sheen's *The Fifteen Mysteries of the Rosary*.
The iOS app's note that "his work having been checked and found out of
copyright (Oct 2026)" (`app/Data/RosaryQuotes.swift`) rests on one
commit, 5ee26d5 of 12 October 2026, "Sheen's work was checked and found
out of copyright", which records no evidence: no renewal search, no
edition, and it concerns his quotation from *The World's First Love*,
not this book. `Tools/ContentSourcing/MANIFEST.md` has no entry for
Sheen. A US work of 1928-1963 is public domain there only if its
copyright was not renewed, which was not checked here. In Spain Sheen's
works are protected until the end of 2059 (he died in 1979), and a
Spanish translation is a derivative work, so translating him needs his
estate's permission whatever the US status. The three sets stay English.

## The meditations and their sources

| Meditation | Set | English title or mystery | Source |
|---|---|---|---|
| 136 | 29 | The Annunciation | the team's translation (`ai_translated`): not in Liguori, see above |
| 137 | 29 | The Visitation | the team's translation (`ai_translated`): not in Liguori, see above |
| 138 | 29 | The Nativity | the team's translation (`ai_translated`): not in Liguori, see above |
| 139 | 29 | The Presentation | the team's translation (`ai_translated`): not in Liguori, see above |
| 140 | 29 | The Finding in the Temple | the team's translation (`ai_translated`): not in Liguori, see above |
| 141 | 30 | The Agony in the Garden | the team's translation (`ai_translated`): not in Liguori, see above |
| 142 | 30 | The Scourging at the Pillar | the team's translation (`ai_translated`): not in Liguori, see above |
| 143 | 30 | The Crowning with Thorns | the team's translation (`ai_translated`): not in Liguori, see above |
| 144 | 30 | The Carrying of the Cross | the team's translation (`ai_translated`): not in Liguori, see above |
| 145 | 30 | The Crucifixion | the team's translation (`ai_translated`): not in Liguori, see above |
| 146 | 28 | The Resurrection | the team's translation (`ai_translated`): not in Liguori, see above |
| 147 | 28 | The Ascension | the team's translation (`ai_translated`): not in Liguori, see above |
| 148 | 28 | The Descent of the Holy Spirit | the team's translation (`ai_translated`): not in Liguori, see above |
| 149 | 28 | The Assumption | the team's translation (`ai_translated`): not in Liguori, see above |
| 150 | 28 | The Coronation | the team's translation (`ai_translated`): not in Liguori, see above |
| 227 | 42 | The Fiat and the Flood of Light | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 228 | 42 | Light Passing Between Them | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 229 | 42 | The Light Born in the Cave | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 230 | 42 | Heaven Opened Over the Altar | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 231 | 42 | About My Father's Business | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 246 | 46 | Light in the Sealed Tomb | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 247 | 46 | Blessing the Whole World | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 248 | 46 | Tongues of Fire | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 249 | 46 | In Triumph to the Heavenly Jerusalem | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 250 | 46 | He Placed in Her Hand a Scepter | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 251 | 45 | Watch and Pray With Me | [M4] pp. 151-153 |
| 252 | 45 | The Lamb and the Lambs | [M4] pp. 311-312 |
| 253 | 45 | Hail, King of the Jews | [M4] pp. 334-335 |
| 254 | 45 | Mother and Son on the Way | [M4] pp. 360-361 |
| 255 | 45 | It Is Consummated | [M4] pp. 408-409 |
| 261 | 48 | Hail, Full of Grace | [M2] Ejercicios espirituales, n. 262 (De la anunciación de Nuestra Señora); MHSI 1919 p. 450 |
| 262 | 48 | The Infant Leaped in Her Womb | [M2] Ejercicios espirituales, n. 263 (De la visitación); MHSI 1919 pp. 450-452 |
| 263 | 48 | Laid in the Manger | [M2] Ejercicios espirituales, n. 264 (Del nacimiento); MHSI 1919 p. 452 |
| 264 | 48 | Received in Simeon's Arms | [M2] Ejercicios espirituales, n. 268 (De la purificación de Nuestra Señora y representación del Niño Jesú); MHSI 1919 p. 456 |
| 265 | 48 | In the Things of My Father | [M2] Ejercicios espirituales, n. 272 (De la venida de Christo al templo quando era de hedad de XII años); MHSI 1919 p. 460 |
| 296 | 52 | His Risen Body and Mine | the team's translation (`ai_translated`) from the English, see above |
| 297 | 52 | The Flesh of Bethlehem Enters Heaven | the team's translation (`ai_translated`) from the English, see above |
| 298 | 52 | The Fire That Makes Us Love | the team's translation (`ai_translated`) from the English, see above |
| 299 | 52 | Why She Has No Tomb | the team's translation (`ai_translated`) from the English, see above |
| 300 | 52 | Queen of the Angels | the team's translation (`ai_translated`) from the English, see above |
| 301 | 53 | The Heavens Opened | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 302 | 53 | A Word Spoken Low | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 303 | 53 | The Scroll Unrolled in Nazareth | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 304 | 53 | The Light on Thabor | the team's translation (`ai_translated`) from the 1914 English; no Spanish scan, see above |
| 305 | 53 | His Entire Self | [M4] pp. 129-130 |
| 306 | 54 | The Trinity at the Jordan | the team's translation (`ai_translated`) from the English, see above |
| 307 | 54 | The Wine He Makes Every Year | the team's translation (`ai_translated`) from the English, see above |
| 308 | 54 | The Season of Mercy | the team's translation (`ai_translated`) from the English, see above |
| 309 | 54 | One Tabernacle, Not Three | the team's translation (`ai_translated`) from the English, see above |
| 310 | 54 | O Bond of Charity | the team's translation (`ai_translated`) from the English, see above |
| 311 | 55 | The Lord Among the Servants | the team's translation (`ai_translated`) from the English, see above |
| 312 | 55 | Why He Granted What He Had Refused | the team's translation (`ai_translated`) from the English, see above |
| 314 | 55 | A Glimpse of the Brightness to Come | the team's translation (`ai_translated`) from the English, see above |
| 315 | 55 | He Mingled Himself With Us | the team's translation (`ai_translated`) from the English, see above |
| 316 | 56 | The Heavens Opened | the team's translation (`ai_translated`), from the English of III, q. 39, a. 5 |
| 317 | 56 | Sealed with the King's Ring | the team's translation (`ai_translated`), from the English of III, q. 43, a. 1 |
| 318 | 56 | Why He Came Into the World | the team's translation (`ai_translated`), from the English of III, q. 40, a. 1 |
| 319 | 56 | The Whole Trinity Appears | the team's translation (`ai_translated`), from the English of III, q. 45, a. 3 |
| 320 | 56 | The Sign of Supreme Charity | the team's translation (`ai_translated`), from the English of III, q. 75, a. 1 |
| 326 | 58 | The Archangel Descends Bearing the Cross | [M3] Segunda parte, lib. III, cap. X, n. 113 |
| 327 | 58 | The Two Mothers Greet Each Other | [M3] Segunda parte, lib. III, cap. XVI, n. 212 |
| 328 | 58 | The Mother Calls the Poor to the Crib | [M3] Segunda parte, lib. IV, cap. X, n. 483 |
| 329 | 58 | The Mother Presents Her Son in the Temple | [M3] Segunda parte, lib. IV, cap. XX, n. 598 |
| 330 | 58 | The Mother's Question and the Son's Answer | [M3] Segunda parte, lib. V, cap. V, nn. 766-767 |
| 331 | 59 | The Prayer That Drew Him Down | the team's translation (`ai_translated`) from the English, see above |
| 332 | 59 | The Sound of Her Voice | the team's translation (`ai_translated`) from the English, see above |
| 333 | 59 | The Desire That Could Not Be Recalled | the team's translation (`ai_translated`) from the English, see above |
| 334 | 59 | Old Age Receives Its God | the team's translation (`ai_translated`) from the English, see above |
| 335 | 59 | A Voice She Could Not Mistake | the team's translation (`ai_translated`) from the English, see above |
| 336 | 60 | Wounded in Advance by the Sword | [M3] Segunda parte, lib. IV, cap. XX, n. 601 |
| 337 | 60 | Waking the Child to Flee | [M3] Segunda parte, lib. IV, cap. XXI, nn. 611-613 |
| 338 | 60 | Turning Back to Jerusalem | [M3] Segunda parte, lib. V, cap. IV, n. 748 |
| 339 | 60 | Watching Him Carry the Cross | [M3] Segunda parte, lib. VI, cap. XXI, n. 1369 |
| 340 | 60 | She Felt the Pangs of His Death | [M3] Segunda parte, lib. VI, cap. XXII, n. 1398 |
| 341 | 60 | The Body Laid in Her Arms | [M3] Segunda parte, lib. VI, cap. XXIV, n. 1446 |
| 342 | 60 | Carrying Him to the Grave | [M3] Segunda parte, lib. VI, cap. XXIV, n. 1448 |
| 343 | 61 | A Sorrow Foreseen | [M1] pp. 330-331 (leaves n334-n335) |
| 344 | 61 | The Long Road to Egypt | [M1] pp. 337-338 (leaves n341-n342) |
| 345 | 61 | The Pain of Losing the Light | [M1] p. 341 (leaf n345) |
| 346 | 61 | The Look Between Mother and Son | [M1] pp. 348-349 (leaves n352-n353) |
| 347 | 61 | A Mother Who Could Give No Relief | [M1] p. 354 (leaf n358) |
| 348 | 61 | The World Returns Her Son | [M1] pp. 360-361 (leaves n364-n365) |
| 349 | 61 | Her Heart Left in the Tomb | [M1] pp. 365-366 (leaves n369-n370) |
| 350 | 55 | Not a City Did He Overlook | the team's translation (`ai_translated`) from the English, see above |
| 351 | 62 | The Fear Was Real | the team's translation (`ai_translated`) from the English, see above |
| 352 | 62 | Silent Beneath the Scourge | the team's translation (`ai_translated`) from the English, see above |
| 353 | 62 | Bear Them in Our Mind | the team's translation (`ai_translated`) from the English, see above |
| 354 | 62 | The Cross Borne as a Trophy | the team's translation (`ai_translated`) from the English, see above |
| 355 | 62 | He Died by His Own Power | the team's translation (`ai_translated`) from the English, see above |
| 356 | 63 | The Dazzling Light in the Sepulchre | the team's translation (`ai_translated`) from the English, see above |
| 357 | 63 | Their Eyes Upon the Cloud | the team's translation (`ai_translated`) from the English, see above |
| 358 | 63 | The Fire That Shall Not Be Checked | the team's translation (`ai_translated`) from the English, see above |
| 359 | 63 | The Eternal Gates Lifted Up | the team's translation (`ai_translated`) from the English, see above |
| 360 | 63 | Above All the Choirs | the team's translation (`ai_translated`) from the English, see above |
| 361 | 64 | Accepting the Chalice | the team's translation (`ai_translated`) from the English, see above |
| 362 | 64 | Bound to the Pillar | the team's translation (`ai_translated`) from the English, see above |
| 363 | 64 | A Crown of Thorns for a King | the team's translation (`ai_translated`) from the English, see above |
| 364 | 64 | Veronica and the Daughters of Jerusalem | the team's translation (`ai_translated`) from the English, see above |
| 365 | 64 | Mary Draws Near to the Cross | the team's translation (`ai_translated`) from the English, see above |
| 366 | 65 | The Words That Pierced Her | the team's translation (`ai_translated`) from the English, see above |
| 367 | 65 | Going Forth into the Cold Starlight | the team's translation (`ai_translated`) from the English, see above |
| 368 | 65 | The Light Went Out in Her Soul | the team's translation (`ai_translated`) from the English, see above |
| 369 | 65 | Her Eyes Fixed on His | the team's translation (`ai_translated`) from the English, see above |
| 370 | 65 | A Childless Mother | the team's translation (`ai_translated`) from the English, see above |
| 371 | 65 | Her Arms Receive Him Again | the team's translation (`ai_translated`) from the English, see above |
| 372 | 65 | The Stone Rolled to the Door | the team's translation (`ai_translated`) from the English, see above |

## The sets' own words

`priv/meditations/es/sets.json` holds each visible set's name, author,
description, source and image alt text in Spanish, served in `set_translation` with
`lang=es`. Added on 5 November 2026 for the 23 sets production shows,
Sheen's three included: a set's description and alt text are the team's
words, not the author's. Each field records a fingerprint of the English
a client is shown (`name`, the byline's `author` and `source`,
`description`, the artwork's alt) and is served only while that English is unchanged.

- **Names, authors, descriptions and alt texts** are the team's
  translation of the English, so every set carries `ai_translated`.
  Added to the set's name and author at the lead's word (5 November
  2026): "set name and author in Spanish with lang=es (e.g. 'San Alfonso
  María de Ligorio', 'Beata Ana Catalina Emmerich', 'Santo Tomás de
  Aquino'), the usual Spanish forms of the names". Sheen's set name is
  "Beato Fulton J. Sheen" and his byline "Arzobispo Fulton J. Sheen", as
  the English. Names follow Spanish usage: San Alfonso María de Ligorio, la Beata Ana Catalina Emmerich,
  la Venerable María de Jesús de Ágreda, Dom Próspero Guéranger,
  Federico Guillermo Faber (the set's name and byline "Padre Federico
  Guillermo Faber"), San John Henry Newman, San Ignacio de Loyola, San
  Agustín, San Juan Crisóstomo, Santo Tomás de Aquino. Sheen is "el
  arzobispo Fulton J. Sheen", as the English says. Books are named by
  their usual Spanish titles (*Las glorias de María*, *Mística Ciudad de
  Dios*, *Suma teológica*, *El año litúrgico*, St Augustine's *Tratados
  sobre el Evangelio de San Juan*); *Vida de Jesucristo y revelaciones
  bíblicas* translates the English title, as no Spanish edition of it was
  used. Set 48's last sentence follows St Ignatius's own Spanish
  (*Ejercicios*, n. 2, "no el mucho saber harta y satisface al ánima, mas
  el sentir y gustar de las cosas internamente") in modern wording. Set
  29's English alt misspells "Ligouri"; the Spanish has "Ligorio".
- **Sources** are the Spanish edition's title where the meditations were
  copied from one ([M1] to [M4] above), else the English citation
  translated. Where the English names no source and no edition was
  copied, there is none (set 53 has one meditation from [M4] among
  translated ones, so it has none either). Sheen's *The Fifteen Mysteries
  of the Rosary* is given as "Los quince misterios del Rosario", a
  translation of the title, not a Spanish edition.

| Set | Name | Source in Spanish | Why |
|---|---|---|---|
| 25 | Blessed Fulton J. Sheen | Los quince misterios del Rosario | the English citation translated |
| 26 | Blessed Fulton J. Sheen | Los quince misterios del Rosario | the English citation translated |
| 27 | Blessed Fulton J. Sheen | Los quince misterios del Rosario | the English citation translated |
| 28 | St. Alphonsus Liguori | Las glorias de María | the English citation translated |
| 29 | St. Alphonsus Liguori | Las glorias de María | the English citation translated |
| 30 | St. Alphonsus Liguori | Las glorias de María | the English citation translated |
| 42 | Blessed Anne Catherine Emmerich | Vida de Jesucristo y revelaciones bíblicas, vol. 1 (traducción inglesa de 1914) | the English citation translated |
| 45 | Blessed Anne Catherine Emmerich | La dolorosa Pasión de N. S. Jesucristo, según las meditaciones de sor Ana Catalina Emmerich (Madrid, 1865) | [M4], the edition copied |
| 46 | Blessed Anne Catherine Emmerich | Vida de Jesucristo y revelaciones bíblicas, vol. 4 (traducción inglesa de 1914) | the English citation translated |
| 48 | St. Ignatius of Loyola | Ejercicios espirituales, el autógrafo español (Monumenta Ignatiana, Madrid, 1919) | [M2], the edition copied |
| 52 | St. John Henry Newman | Meditaciones y devociones del difunto cardenal Newman (Longmans, Green and Co.; publicado por primera vez en 1893, reimpresión de 1916) | the English citation translated |
| 53 | Blessed Anne Catherine Emmerich | none | the English names none, and no Spanish edition was copied |
| 54 | St. Augustine | none | the English names none, and no Spanish edition was copied |
| 55 | St. John Chrysostom | none | the English names none, and no Spanish edition was copied |
| 56 | St. Thomas Aquinas | Suma teológica, tercera parte (Tertia Pars), traducción de los Padres de la Provincia Dominica de Inglaterra (edición de Benziger Brothers) | the English citation translated |
| 58 | Venerable Mary of Agreda | Mística Ciudad de Dios (Barcelona, 1860) | [M3], the edition copied; the English names none |
| 59 | Father Frederick William Faber | none | the English names none, and no Spanish edition was copied |
| 60 | Venerable Mary of Agreda | Mística Ciudad de Dios (Barcelona, 1860) | [M3], the edition copied; the English names none |
| 61 | St. Alphonsus Liguori | Las glorias de María, traducción del P. Ramón García, S. J., 2.ª ed. (Tolosa, 1868) | [M1], the edition copied |
| 62 | St. John Chrysostom | none | the English names none, and no Spanish edition was copied |
| 63 | Dom Prosper Guéranger | none | the English names none, and no Spanish edition was copied |
| 64 | Dom Prosper Guéranger | El año litúrgico: Tiempo de Pasión y Semana Santa (segunda edición, Dublín: James Duffy, 1886) | the English citation translated |
| 65 | Father Frederick William Faber | Al pie de la Cruz, o los dolores de María (1858) | the English citation translated |
