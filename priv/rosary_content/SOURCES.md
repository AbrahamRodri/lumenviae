# Sources of the Spanish prayers

`es/prayers.json` holds the Rosary's prayers in Spanish. Each text is
copied from an official Church source, not translated by us, except the
one Abraham supplied (below). When no Spanish text could be found, the
prayer is left out of the file and served in English.

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
| `sorrows_closing_prayer` | Supplied by Abraham, 3 Nov 2026, with the opening versicle and one phrase translated by the team (below). |

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

## Supplied by Abraham, completed by the team

- `sorrows_closing_prayer`: Abraham supplied the prayer's text on 3 Nov
  2026 ("this is what i found"; the same text is on rezarconfe.com,
  credited there to devocionario.com). No Spanish text from the Servite
  Order, the Holy See or a bishops' conference had been found.
  - Lines 4 to 9 are his text word for word, except the phrase "ahora y
    en la hora de nuestra muerte," at the end of line 4. Line breaks are
    ours, and a final period is added after "Amén".
  - Translated by the team (AI), because Abraham asked that the Spanish
    "Match the English": the opening versicle (lines 1 to 3, "Ruega por
    nosotros, Virgen dolorosísima, / para que seamos dignos de alcanzar
    las promesas de Cristo. / [Oremos.]") and "ahora y en la hora de
    nuestra muerte,". They follow the official wording in [1]: the Salve
    Regina's versicle ("Ruega por nosotros, Santa Madre de Dios, para que
    seamos dignos de alcanzar las promesas...") and the Ave María
    ("ahora y en la hora de nuestra muerte"). The versicle was checked
    against the Latin ("Ora pro nobis, Virgo dolorosissima, ut digni
    efficiamur promissionibus Christi").
  - Title: no official source names the prayer in Spanish, so "Oración
    final de los Siete Dolores" is the team's wording, after the English
    "Closing Prayer of the Seven Sorrows".

## Not found

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
4. Pope Francis, morning meditation in the chapel of the Domus Sanctae
   Marthae, 3 April 2020, "La Dolorosa, discípula y madre", on
   [vatican.va](https://www.vatican.va/content/francesco/es/cotidie/2020/documents/papa-francesco-cotidie_20200403_l-addolorata-discepola-emadre.html),
   read on 2 November 2026.

## The team's translations

### The Seven Sorrows set's names

"Siete Dolores" (`name`) and "Los siete dolores de María"
(`devotion_title`, for the English "Seven Sorrows of Mary") are the
team's translation. [4] names the devotion ("los “siete dolores”", "los
dolores de María") but gives it no title.

### Fruits

No official Church list of the mysteries' fruits was found; the fruits
are a devotional custom, not a liturgical text. All 27 Spanish fruits
are the team's own translation of the English fruits, in the usual
words of Spanish prayer books ("Humildad", "Amor al prójimo", "Dolor de
los pecados"; "Fortaleza", the traditional word, for "Moral Courage").
They are covered by the app's notice that some words are
translated with AI.

## Not in this file

- Descriptions: the team would have to write them, so they wait for
  Abraham's decision.
- Key verses: a Spanish Bible translation is needed. Torres Amat (1825)
  and Scío are in the public domain; any modern translation needs its
  publisher's licence.
