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
  removed, and its two lines are joined by a line break instead of "/".
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
