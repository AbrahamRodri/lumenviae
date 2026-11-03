# Sources of the Prayer Book's Spanish

`es/prayer_book.json` holds the Prayer Book's prayers in Spanish, served in
the `translations` section of `GET /api/v2/prayer-book?lang=es`. Each text
is copied from an official Church source, not translated by us, and was
checked word for word against that source on 3 November 2026. A prayer
with no official Spanish text found is left out and stays in English.

The Rosary's prayers the book also prints (the Sign of the Cross, the
Creed, the Our Father and the rest) are not in this file: their Spanish is
`priv/rosary_content/es/prayers.json`'s, listed in
`priv/rosary_content/SOURCES.md`, so the two documents never disagree. A
Rosary prayer with no Spanish there has none here either. A prayer there
marked `ai_translated` (the Seven Sorrows closing prayer, once it is
served) keeps the mark here.

## The prayers and their sources

| Prayer (`id`) | Source |
|---|---|
| `nicene_creed` | [1] "Credo Niceno-Constantinopolitano" |
| `act_of_faith` | [1] "Acto de Fe", the first form, not the "tradición española" one |
| `act_of_hope` | [1] "Acto de Esperanza", the first form |
| `act_of_charity` | [1] "Acto de caridad", the first form |
| `benedictus` | [1] "Benedictus" |
| `angele_dei` | [1] "Ángel de Dios" |
| `angelus` | [1] "Ángelus" |
| `regina_caeli` | [1] "Regina Caeli" |
| `anima_christi` | [1] "Alma de Cristo" |
| `veni_creator` | [1] "Veni Creator" |
| `veni_sancte_spiritus` | [1] "Ven Santo Espíritu" (the sequence) |
| `magnificat` | [1] "Magnificat" |
| `sub_tuum` | [1] "Bajo tu protección" |
| `te_deum` | [1] "Te Deum" |
| `jesus_i_trust_in_thee` | [2] |
| `my_lord_and_my_god` | [3] John 20:28 |
| `pardon_prayer` | [4] |
| `angels_prayer_fatima` | [5] |
| `miraculous_medal` | [6], the opening invocation |
| `spiritual_communion` | [7], the first prayer (St. Alphonsus) |
| `reparation_sacred_heart` | [8], the act of reparation at its end |
| `ad_te_beate_ioseph` | [9], the prayer at its end |
| `nada_te_turbe` | [10] no. 227 |
| `jesus_prayer` | [10] no. 2667 |
| `peace_prayer` | [11] |
| `litany_sacred_heart` | [12] |

1. *Compendio del Catecismo de la Iglesia Católica*, Apéndice A,
   "Oraciones comunes" (Libreria Editrice Vaticana, 2005), on
   [vatican.va](https://www.vatican.va/archive/compendium_ccc/documents/archive_2005_compendium-ccc_sp.html).
2. Congregación de las Hermanas de la Madre de Dios de la Misericordia
   (St. Faustina's order), "La imagen", on
   [santafaustina.es](https://www.santafaustina.es/imagen/).
3. *El Libro del Pueblo de Dios*, John 20, on
   [vatican.va](https://www.vatican.va/archive/ESL0506/__PWQ.HTM).
4. Santuario de Fátima, "Oraciones de Fátima", on
   [fatima.pt](https://www.fatima.pt/es/pages/oraciones-de-fatima).
5. Santuario de Fátima, "Palabra clave: adoración", on
   [fatima.pt](https://www.fatima.pt/es/pages/palabra-clave-adoracion).
6. Association of the Miraculous Medal (the Vincentians), "Oración a la
   Virgen de la Medalla Milagrosa", on
   [amm.org](https://amm.org/pray-with-us/special-prayers/oracion-a-la-virgen-de-la-medalla-milagrosa).
7. Vatican News, "Oraciones: Comunión espiritual", on
   [vaticannews.va](https://www.vaticannews.va/es/oraciones/comunion-espiritual.html).
8. Pius XI, *Miserentissimus Redemptor* (1928), Spanish text, on
   [vatican.va](https://www.vatican.va/content/pius-xi/es/encyclicals/documents/hf_p-xi_enc_19280508_miserentissimus-redemptor.html).
9. Leo XIII, *Quamquam pluries* (1889), Spanish text, on
   [vatican.va](https://www.vatican.va/content/leo-xiii/es/encyclicals/documents/hf_l-xiii_enc_15081889_quamquam-pluries.html).
10. *Catecismo de la Iglesia Católica*, on
    [vatican.va](https://www.vatican.va/archive/catechism_sp/p1s2c1p1_sp.html)
    (no. 227) and
    [vatican.va](https://www.vatican.va/archive/catechism_sp/p4s1c2a2_sp.html)
    (no. 2667).
11. United States Conference of Catholic Bishops, "Oración por la paz", on
    [usccb.org](https://www.usccb.org/node/40055).
12. United States Conference of Catholic Bishops, "Letanías al Sagrado
    Corazón de Jesús" (#PrayTogether card), hosted by the Archdiocese of
    Los Angeles on
    [lacatholics.org](https://lacatholics.org/wp-content/uploads/2020/04/Litany-of-the-Sacred-Heart-Spanish.pdf).

All were read on 2 and 3 November 2026.

## What was changed from the source

Everywhere:

- Line breaks and paragraph breaks are ours, so each prayer shows like the
  English: a line break inside a stanza, a blank line between stanzas.
  Where a source runs a prayer as one paragraph, or in more stanzas than
  the English, it was split or regrouped at the English's places.
- Versicles and responses are marked ℣. and ℟., and "Oremos" is written
  `[Oremos.]`, the way the English marks a rubric.
- A final period is added where a source ends with "Amén" or the last word
  and no period.
- Quotation marks, verse numbers, citations and attribution lines around a
  prayer are removed.
- Where a source gives the prayer no title, the title is its first words
  (`jesus_i_trust_in_thee`, `my_lord_and_my_god`, `pardon_prayer`,
  `angels_prayer_fatima`, `nada_te_turbe`, `jesus_prayer`,
  `peace_prayer`). The titles of `reparation_sacred_heart` and
  `ad_te_beate_ioseph` describe the prayer, since the encyclicals print it
  untitled.

Prayer by prayer:

- `angelus`: each "Dios te salve, María..." and the closing "Gloria al
  Padre..." the source abbreviates is written out in full from the same
  appendix.
- `regina_caeli`: each "aleluya" is joined onto its line. The source's
  misprint "los gozos eterno" is corrected to "los gozos eternos".
- `magnificat`: a character-encoding error on the page
  ("Â–como lo había prometido...Â–") is written with the en dashes the
  source intends.
- `my_lord_and_my_god`: "Tomás respondió:" and the opening « are removed;
  the source's "!." is kept.
- `miraculous_medal`: only the opening invocation, which is the whole of
  the English. The couplets and collect that follow on the page are left
  out.
- `spiritual_communion`: the source's ten short lines are one paragraph,
  as the English is.
- `reparation_sacred_heart`: two misprints corrected: "A1 mismo tiempo"
  (a digit 1 for l) to "Al mismo tiempo", and "ofrecisté" to
  "ofreciste".
- `nada_te_turbe`: each " / " is a line break, and the stray space
  before the comma in "Todo se pasa ," is removed.
- `peace_prayer`: a stray space before the final period is removed, and
  the misprint "házme" is corrected to "hazme", in the title too.
- `litany_sacred_heart`: read from the card's rendered page (its text
  layer is garbled). Each people's response follows its call after "℟.",
  and "Amén" is the closing response. The card's footnote ("Ten
  misericordia de nosotros se repite después de cada invocación") is left
  out: it names a response the card itself does not print. Instead, as in
  the English, "℟. ten piedad de nosotros." (the response the card prints
  after the first invocation) is written at the head of each stanza of
  invocations.

## Where the Spanish differs from the English

These texts are the Church's own Spanish, not a translation of the
English, so some say a little more or less:

- `nicene_creed` and `te_deum`: no "[Here all genuflect.]" or "[Here all
  kneel.]": the source has no rubric.
- `benedictus` and `magnificat`: the modern liturgical translation, with
  no * marks at the middle of a verse.
- `angele_dei`: a prose translation of the Latin, not the English rhymed
  verse.
- `angelus`: ends with a Gloria al Padre, which the English does not.
- `veni_creator`: a translation of the Latin that does not rhyme, in the
  same seven stanzas.
- `veni_sancte_spiritus`: the Spanish liturgical verse form, five stanzas
  of six lines, ending "Amén." with no "Alleluia".
- `jesus_prayer`: "ten piedad de nosotros, pecadores" (on us, sinners),
  where the English says "on me, a sinner".
- `peace_prayer`: ends "muriendo se resucita a la vida", with no word for
  "eternal".
- `litany_sacred_heart`: the people repeat each opening Kyrie line, and
  both "Cristo, óyenos" and "Cristo, escúchanos"; the third Agnus Dei is
  "ten piedad y misericordia de nosotros".

## Left in English

Served in English, with no translation, because no official Spanish text
was found that matches the English:

- A different form of the prayer from the one the book prints:
  `nunc_dimittis`, `come_holy_ghost`, `domine_non_sum_dignus`,
  `miserere`, `beati_quorum`, `infant_of_prague`, `litany_loreto`,
  `divine_mercy_chaplet`, `alma_redemptoris`, `litany_st_joseph`,
  `litany_of_the_saints`, `prayer_for_the_pope`, `prayer_for_priests`.
- A different meaning: `requiem_aeternam` (the official Spanish found is
  for one soul; the English prays for all the faithful departed).
- Not matched word for word against its source: `st_dominic_o_lumen`.
- Source page could not be read: `examination_of_conscience`,
  `the_confession`, `de_profundis`.
- Every other prayer in the book: no official Spanish found, only in
  print, or only in a parish or order's reprint. The list is in the
  research report the team keeps outside the repo
  (`reports/rig-es/prayer-book-spanish.md`).
