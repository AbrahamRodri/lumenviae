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

This file covers Group A of `reports/rig-es/meditation-sources.md`: the
eight sets with a Spanish source. 44 meditations: 24 copied, 20 the
team's translation, marked `ai_translated`. The Spanish titles are the
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
| 261 | 48 | Hail, Full of Grace | [M2] Ejercicios espirituales, n. 262 (De la anunciación de Nuestra Señora); MHSI 1919 p. 450 |
| 262 | 48 | The Infant Leaped in Her Womb | [M2] Ejercicios espirituales, n. 263 (De la visitación); MHSI 1919 pp. 450-452 |
| 263 | 48 | Laid in the Manger | [M2] Ejercicios espirituales, n. 264 (Del nacimiento); MHSI 1919 p. 452 |
| 264 | 48 | Received in Simeon's Arms | [M2] Ejercicios espirituales, n. 268 (De la purificación de Nuestra Señora y representación del Niño Jesú); MHSI 1919 p. 456 |
| 265 | 48 | In the Things of My Father | [M2] Ejercicios espirituales, n. 272 (De la venida de Christo al templo quando era de hedad de XII años); MHSI 1919 p. 460 |
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
