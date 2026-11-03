# Sources of the Prayer Book's Spanish

`es/prayer_book.json` holds the Prayer Book's prayers in Spanish, served in
the `translations` section of `GET /api/v2/prayer-book?lang=es`. Each text
is copied from a Church source, not translated by us, and was checked
word for word against that source on 3 November 2026: first the Holy
See, bishops' conferences and the Church's own pages (the first list
below), then the Spanish Missal and Liturgy of the Hours, diocese and
religious-order reprints, and the Church's own Spanish form where it
differs from the book's English (the second list). A prayer with no
Spanish text here stays in English.

The Rosary's prayers the book also prints (the Sign of the Cross, the
Creed, the Our Father and the rest) are not in this file: their Spanish is
`priv/rosary_content/es/prayers.json`'s, listed in
`priv/rosary_content/SOURCES.md`, so the two documents never disagree. A
Rosary prayer with no Spanish there has none here either. A prayer there
marked `ai_translated` (the Seven Sorrows closing prayer) keeps the mark
here.

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

## The second list: the Missal, the Hours, reprints and other forms

Added on 3 November 2026. Each text was copied as its source prints it
and checked word for word against a saved copy of the source; only the
layout was changed (below). Where the Church's Spanish is a different
form of the prayer from the one the book's English prints, the Spanish
form is used and the difference is listed.

| Prayer (`id`) | Source |
|---|---|
| `actiones_nostras` | [13] the collect of the Thursday after Ash Wednesday |
| `visita_quaesumus` | [14] the Night Prayer collect after Vespers of a solemnity |
| `fidelium_deus` | [15] Masses for the dead III, B, 4, the collect |
| `domine_non_sum_dignus` | [16] the Communion rite |
| `de_profundis` | [17] Wednesday Night Prayer, Psalm 129 |
| `nunc_dimittis` | [17] Night Prayer, the Canticle of Simeon with its antiphon |
| `confiteor` | [18] the penitential act |
| `o_salutaris` | [19] |
| `tantum_ergo` | [19] the hymn; [20] the versicle, response and collect |
| `divine_praises` | [20] |
| `st_francis_before_crucifix` | [21] |
| `st_dominic_o_lumen` | [22] the antiphon, quoted in the homily of 8 August 2014 |
| `requiem_aeternam` | [23] the rite of conclusion |
| `come_holy_ghost` | [24] |
| `miserere` | [3] Psalm 51 |
| `beati_quorum` | [3] Psalm 32 |
| `infant_of_prague` | [25] the prayer of Ven. Fr. Cyril |
| `litany_loreto` | [26] |
| `divine_mercy_chaplet` | [27] |
| `alma_redemptoris` | [28] |
| `litany_st_joseph` | [29] |
| `prayer_for_the_pope` | [30] |
| `prayer_for_priests` | [31] the Good Friday prayer for the ministers of the Church |

13. Revista Ecclesia (Conferencia Episcopal Española), *Subsidios
    litúrgicos*, March 2025, reproducing the Misal Romano (CEE), on
    [revistaecclesia.es](https://revistaecclesia.es/wp-content/uploads/2025/02/SUBSIDIOS-LITURGICOS-MARZO-2025.pdf).
14. *Liturgia de las Horas* (CEE), Completas del domingo, in "Oración para
    antes del descanso nocturno", prepared by José Cascant Ribelles
    (2013), on
    [almudi.org](https://www.almudi.org/Portals/0/docs/LH/V_COMPLETAS.epub).
    No bishops' conference or diocesan copy was found online.
15. Revista Ecclesia (CEE), *Subsidio litúrgico*, November 2026,
    reproducing the Misal Romano (CEE), on
    [revistaecclesia.es](https://revistaecclesia.es/wp-content/uploads/2026/10/SUBSIDIO-LITURGICO-NOVIEMBRE-2026.pdf).
16. Office of the Liturgical Celebrations of the Supreme Pontiff, booklet
    of the papal Masses in Spain, June 2026, on
    [vatican.va](https://www.vatican.va/content/dam/liturgy/pdf/2026/20260606-12-messale-spagna.pdf).
17. *Liturgia de las Horas* (CEE), Completas, as iBreviary prints it in
    Spanish, on [ibreviary.com](https://www.ibreviary.com/m2/breviario.php?s=compieta)
    (the page shows the day set in its options).
18. *Misal Romano*, tercera edición (USCCB and Conferencia Episcopal
    Mexicana, 2014), Ordinario de la Misa, reprinted by the Diocese of Fort
    Wayne-South Bend, on
    [diocesefwsb.org](https://diocesefwsb.org/wp-content/uploads/2021/11/Ordinario-de-la-Misa-8.5x11.pdf).
19. Archdiocese of Milwaukee, *Adoración Eucarística: Guía para la
    Arquidiócesis de Milwaukee* (2024), on
    [archmil.org](https://archmil.org/ArchMil/Resources/2024AdorationGuide_SPANISH.pdf).
20. Diocese of Osma-Soria, vigil booklet for the Día de la Iglesia
    Diocesana 2023, the Benediction, on
    [osma-soria.org](https://osma-soria.org/pdf/especiales/dia_iglesia_2023/vigilia_oracion.pdf).
21. Secular Franciscan Order, National Fraternity of the USA, prayer card,
    on [secularfranciscansusa.org](https://www.secularfranciscansusa.org/wp-content/uploads/Vocations_Tool_Kit-Prayer_Before_Crucifix_esp.pdf).
22. Dominicos de España (Order of Preachers), homily of 8 August 2014, on
    [dominicos.org](https://www.dominicos.org/predicacion/pdf-homilia/8-8-2014/completa.pdf).
23. Diocese of Salamanca, "Oración en el cementerio" for 2 November, on
    [diocesisdesalamanca.com](https://diocesisdesalamanca.com/wp-content/uploads/2024/10/2023-2024.-Oracion-en-el-cementerio.-Laico.pdf).
24. John Paul II, homily at the Vigil of Pentecost, 29 May 2004, Spanish,
    on [vatican.va](https://www.vatican.va/content/john-paul-ii/es/homilies/2004/documents/hf_jp-ii_hom_20040529_vigil-pentecost.html).
25. The Shrine of the Infant Jesus of Prague (Discalced Carmelites), on
    [pragjesu.cz](https://pragjesu.cz/es/nino-jesus-de-praga/oraciones/).
26. The Holy See, "Letanías de la Virgen", on
    [vatican.va](https://www.vatican.va/special/rosary/documents/litanie-lauretane_sp.html).
27. Vatican News, "Coronilla de la Divina Misericordia", on
    [vaticannews.va](https://www.vaticannews.va/es/oraciones/coronilla-de-la-divina-misericordia.html).
28. John Paul II, homily of 8 December 1995, Spanish, on
    [vatican.va](https://www.vatican.va/content/john-paul-ii/es/homilies/1995/documents/hf_jp-ii_hom_19951208_immacolata.html).
29. Conferencia Episcopal Española, Comisión Permanente (June 2021), the
    litany as published by the Diocese of Huelva, on
    [diocesisdehuelva.es](https://diocesisdehuelva.es/wp-content/uploads/2021/07/LETANIAS-EN-HONOR-DE-SAN-JOSE.pdf).
30. Vatican News, "La oración por el Papa", on
    [vaticannews.va](https://www.vaticannews.va/es/oraciones/la-oracion-por-el-papa.html).
31. *Misal Romano* (CEE), Good Friday, the universal prayer, as the
    Diocese of Astorga reproduces it, on
    [diocesisastorga.es](https://www.diocesisastorga.es/recursos/publicaciones/9fb14d02a3f3d27c485aad6c02915305.docx).

### What was changed

The same layout changes as the first list (line and paragraph breaks
following the English, ℣./℟. for the source's V/ and R/, `[Oremos.]`,
labels such as "Colecta:", "Ant." and speaker names removed, quotation
marks, verse numbers and headings removed, a final period after "Amén").
Also:

- `tantum_ergo`: the source's misprint "la fe suplala incapacidad" is
  corrected to "la fe supla la incapacidad". The hymn and the versicle
  and collect come from two dioceses, since Milwaukee's versicle and
  collect are not the ones the book prints.
- `infant_of_prague`: the source's rubrics in parentheses are written in
  square brackets, and its four paragraphs are joined into the English's
  two.
- `de_profundis`: the flex mark "†" is removed.
- `divine_mercy_chaplet`: the source's instructions are bracketed rubrics,
  without their list numbers.
- Titles: where the source's heading is only a label ("Colecta",
  "Oración", "Salmo"), the title is the prayer's first words or the
  psalm's number.

### How these differ from the English

- `actiones_nostras`, `fidelium_deus`: the current Missal's collects,
  recast from the old Latin, with the short ending "Por nuestro Señor
  Jesucristo." and no "Amén" (the source prints none). `fidelium_deus`
  asks "la misericordia" where the English asks pardon.
- `visita_quaesumus`: no "Oremos" or "Amén", and the short ending.
- `domine_non_sum_dignus`: the Mass form, "entres en mi casa" (my house,
  for "under my roof") and "una palabra tuya bastará para sanarme".
- `de_profundis`: the Liturgy of the Hours translation, not the Vulgate's;
  the Requiem versicle after it has no Spanish in the source and is left
  out.
- `nunc_dimittis`: the Liturgy of the Hours translation in six lines,
  with its antiphon and Glory Be.
- `confiteor`: the current Missal's form: "ante ustedes, hermanos", "y
  omisión", and no St Michael, St John the Baptist or Sts Peter and Paul;
  no "Amén".
- `o_salutaris`: the first line stays in Latin, as the source prints it.
- `divine_praises`: one more line than the English, "Bendito sea el
  Espíritu Santo Paráclito" (added in 1964).
- `st_dominic_o_lumen`: "Ejemplo de paciencia, Ideal de castidad" for
  "rose of patience, ivory of chastity", "júntanos a los santos" for
  "join us to the blessed", and no opening "O".
- `requiem_aeternam`: "Señor" first, and "luz eterna" for perpetual light.
- `come_holy_ghost`: the Magnificat antiphon of Pentecost: it adds "tú
  que congregas a los pueblos de todas las lenguas en la confesión de una
  sola fe. Aleluya", and has no versicle or collect.
- `miserere`, `beati_quorum`: a modern Bible translation, numbered as in
  the Hebrew (51 and 32), with no Glory Be.
- `infant_of_prague`: a freer version of the same prayer.
- `litany_loreto`: the current form, with the invocations added since
  (Madre de la Iglesia, de la misericordia, de la esperanza, Consuelo de
  los migrantes, Reina de la familia).
- `divine_mercy_chaplet`: adds the optional closing prayer.
- `alma_redemptoris`: the antiphon alone, without the seasons' versicles
  and collects.
- `litany_st_joseph`: the 2021 form, with the invocations added that
  year.
- `prayer_for_the_pope`: names Pope Leo XIV where the English says "N.",
  adds an Our Father and Hail Mary, and has a different collect. Change
  the name with the Pope.
- `prayer_for_priests`: the Good Friday prayer, for all the ministers of
  the Church, with the short ending.

## Left in English

Every other prayer in the book has no Spanish text here yet. A later
change adds them: an unofficial Spanish version where a good one exists,
otherwise the team's translation, marked `ai_translated`. Two had Church
sources that could not serve: `litany_of_the_saints` (the only Spanish
found is the short Easter Vigil litany, with its baptism petitions) and
`da_pacem`, `in_manus_tuas` and `deceased_parents` (no full Church text
found online), and `examination_of_conscience` and `the_confession`
(the book's own guides; no Church text matches them).
