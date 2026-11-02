# Sources of the Spanish prayers

`es/prayers.json` holds the Rosary's prayers in Spanish. Each text is
copied from an official Church source, not translated by us. When no
official Spanish text could be found, the prayer is left out of the file
and served in English.

| Prayer (`id`) | Source |
|---|---|
| `sign_of_cross` | [1] "Señal de la Cruz" |
| `apostles_creed` | [1] "Símbolo de los Apóstoles" (the Creed section) |
| `our_father` | [1] "Padre nuestro" |
| `hail_mary` | [1] "Ave María" |
| `glory_be` | [1] "Gloria al Padre" |
| `fatima_prayer` | [3] "¿Cómo se reza el rosario?", the second ejaculation after each decade |
| `hail_holy_queen` | [1] "Salve Regina", with the versicle and response from [1] "Rosario" ("Ruega por nosotros, Santa Madre de Dios...") |
| `rosary_closing_prayer` | [1] "Rosario", the first "Oremos" ("Oh Dios, cuyo Hijo...") |
| `act_of_contrition` | [1] "Acto de Contrición", the first form (the one that pairs with the Latin "Deus meus, ex toto corde"), not the "tradición española" form |
| `memorare` | [1] "Acordaos" |
| `st_michael_prayer` | [2] |
| `sorrows_closing_prayer` | None found. Served in English. |

1. *Compendio del Catecismo de la Iglesia Católica*, Apéndice A, "Oraciones
   comunes" (Libreria Editrice Vaticana, 2005), on
   [vatican.va](https://www.vatican.va/archive/compendium_ccc/documents/archive_2005_compendium-ccc_sp.html).
2. Vatican News (Dicastery for Communication), "Oraciones: San Miguel
   Arcángel", on
   [vaticannews.va](https://www.vaticannews.va/es/oraciones/san-miguel-arcangel.html).
3. Santuario de Fátima, "Rosario", on
   [fatima.pt](https://www.fatima.pt/es/pages/rosario).

All three were read on 2 November 2026.

## What was changed from the source

- Line breaks are ours, so that each prayer shows on screen like the
  English.
- A final period is added where the source ends a prayer with "Amén" and
  no period.
- `apostles_creed`: "que fue concebido" is lowercase. The source has "Que"
  at the start of a printed line in the middle of the sentence.
- `rosary_closing_prayer`: the source's "Oremos" is written `[Oremos.]`,
  the way the English and Latin mark a rubric.
- `fatima_prayer`: the stray comma in the source's "Oh Jesús, mío" is
  removed, and its two lines are joined by a line break instead of "/",
  so the second line's "Lleva" is lowercase ("lleva").
  The source has no "Amén", so neither does the text.

## Not found

- `sorrows_closing_prayer` (the Seven Sorrows chaplet's closing prayer,
  "Pray for us, O most sorrowful Virgin..." with "Lord Jesus, we now
  implore..."): no Spanish text from the Servite Order, the Holy See or a
  bishops' conference was found. Devotional sites print several different
  Spanish versions, none with a Church source.
- The longer Spanish custom of the Sign of the Cross ("Por la señal de la
  Santa Cruz, de nuestros enemigos líbranos, Señor, Dios nuestro") is not
  in the Compendium, so only "En el nombre del Padre..." is used.

# Sources of the mysteries' names and fruits

`es/mysteries.json` holds the Spanish names of the mysteries, their
fruits, and the names of the five sets. `lang=es` serves them in the
`mysteries` and `categories` sections. Anything the file does not hold
stays English: each mystery's description, key verse and spoken
announcement, and every set's other labels.

## Names: copied from official sources

- The 20 mysteries of the Joyful, Luminous, Sorrowful and Glorious sets,
  and the sets' titles ("Misterios gozosos" and the rest): [1] "Rosario",
  word for word. The list's numbers and final periods are left out.
- The sets' short names ("Gozosos", "Luminosos", "Dolorosos",
  "Gloriosos") are the second word of those titles, capitalized because
  they stand alone.
- The Seven Sorrows: [4], where Pope Francis names the seven sorrows one
  by one. Each name is his phrase, with an article added where it starts
  the name. The third is "Los tres días de angustia cuando el niño se
  quedó en el templo", from his "esos tres días de angustia cuando el
  niño se quedó en el templo".
- The Seven Sorrows set: [4] gives no title for the devotion. Its names
  are built from the homily's own words, "los “siete dolores”" and
  "los dolores de María": "Siete Dolores" (`name`) and "Los siete
  dolores de María" (`devotion_title`, for the English "Seven Sorrows of
  Mary").

4. Pope Francis, morning meditation in the chapel of the Domus Sanctae
   Marthae, 3 April 2020, "La Dolorosa, discípula y madre", on
   [vatican.va](https://www.vatican.va/content/francesco/es/cotidie/2020/documents/papa-francesco-cotidie_20200403_l-addolorata-discepola-emadre.html),
   read on 2 November 2026.

## Fruits: the team's translation

No official Church list of the mysteries' fruits was found; the fruits
are a devotional custom, not a liturgical text. All 27 Spanish fruits
are the team's own translation of the English fruits, in the usual
words of Spanish prayer books ("Humildad", "Amor al prójimo", "Dolor de
los pecados"). They are covered by the app's notice that some words are
translated with AI.

## Not in this file

- Descriptions: the team would have to write them, so they wait for
  Abraham's decision.
- Key verses: a Spanish Bible translation is needed. Torres Amat (1825)
  and Scío are in the public domain; any modern translation needs its
  publisher's licence.
