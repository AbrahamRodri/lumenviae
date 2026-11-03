# Sources of the Prayer Book's Spanish

`es/prayer_book.json` holds the Prayer Book's prayers in Spanish, served in
the `translations` section of `GET /api/v2/prayer-book?lang=es`. Every
prayer the book prints has Spanish, from three lists below, in this
order of preference: first a Church source (the Holy See, bishops'
conferences and the Church's own pages), then the Spanish Missal and
Liturgy of the Hours, diocese and religious-order reprints and the
Church's own Spanish form where it differs from the book's English (the
second list), and last a good unofficial version or the team's own
translation, marked `ai_translated` (the third list). Every copied text
was checked word for word against a saved copy of its source on 3
November 2026.

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

Added on 3 November 2026. Where the book's English is the traditional
(pre-1970) form, the Spanish is the traditional form too, from a 1962
Spanish missal or an older devocionario (Abraham's rule: "Match the
English"). Each text was copied as its source prints it
and checked word for word against a saved copy of the source; only the
layout was changed (below). Where the Church's Spanish is a different
form of the prayer from the one the book's English prints, the Spanish
form is used and the difference is listed.

| Prayer (`id`) | Source |
|---|---|
| `actiones_nostras` | [13] the thanksgiving after Mass, p. 1007 |
| `visita_quaesumus` | [13] Compline, p. 1051 |
| `fidelium_deus` | [13] the first Mass of 2 November, the collect, p. 1951 |
| `domine_non_sum_dignus` | [15] the Communion rite |
| `de_profundis` | [16] Wednesday Night Prayer, Psalm 129 |
| `nunc_dimittis` | [16] Night Prayer, the Canticle of Simeon with its antiphon |
| `confiteor` | [13] the Ordinary of the Mass, pp. 957 and 959 |
| `o_salutaris` | [17] |
| `tantum_ergo` | [17] the hymn; [18] the versicle, response and collect |
| `divine_praises` | [18] |
| `st_francis_before_crucifix` | [19] |
| `st_dominic_o_lumen` | [20] the antiphon, quoted in the homily of 8 August 2014 |
| `requiem_aeternam` | [21] the rite of conclusion |
| `come_holy_ghost` | [14] |
| `miserere` | [3] Psalm 51 |
| `beati_quorum` | [3] Psalm 32 |
| `infant_of_prague` | [22] the prayer of Ven. Fr. Cyril |
| `litany_loreto` | [23] |
| `divine_mercy_chaplet` | [24] |
| `alma_redemptoris` | [25] |
| `litany_st_joseph` | [26] |
| `prayer_for_the_pope` | [27] |
| `prayer_for_priests` | [28] the Good Friday prayer for the ministers of the Church |

13. Dom Gaspar Lefebvre, *Misal diario y vesperal*, translated by P. Germán
    Prado and the monks of Silos (Desclée de Brouwer, 1962), on
    [archive.org](https://archive.org/details/misal-diario-y-vesperal-1962-gaspar-lefebvre).
14. P. Remigio Vilariño, S.J., *Devocionario completo (El Caballero
    Cristiano)* (El Mensajero del Corazón de Jesús, Bilbao, 1923, with
    imprimatur), p. 336, on
    [archive.org](https://archive.org/details/el-caballero-cristiano-devocionario_compress).
15. Office of the Liturgical Celebrations of the Supreme Pontiff, booklet
    of the papal Masses in Spain, June 2026, on
    [vatican.va](https://www.vatican.va/content/dam/liturgy/pdf/2026/20260606-12-messale-spagna.pdf).
16. *Liturgia de las Horas* (CEE), Completas, as iBreviary prints it in
    Spanish, on [ibreviary.com](https://www.ibreviary.com/m2/breviario.php?s=compieta)
    (the page shows the day set in its options).
17. Archdiocese of Milwaukee, *Adoración Eucarística: Guía para la
    Arquidiócesis de Milwaukee* (2024), on
    [archmil.org](https://archmil.org/ArchMil/Resources/2024AdorationGuide_SPANISH.pdf).
18. Diocese of Osma-Soria, vigil booklet for the Día de la Iglesia
    Diocesana 2023, the Benediction, on
    [osma-soria.org](https://osma-soria.org/pdf/especiales/dia_iglesia_2023/vigilia_oracion.pdf).
19. Secular Franciscan Order, National Fraternity of the USA, prayer card,
    on [secularfranciscansusa.org](https://www.secularfranciscansusa.org/wp-content/uploads/Vocations_Tool_Kit-Prayer_Before_Crucifix_esp.pdf).
20. Dominicos de España (Order of Preachers), homily of 8 August 2014, on
    [dominicos.org](https://www.dominicos.org/predicacion/pdf-homilia/8-8-2014/completa.pdf).
21. Diocese of Salamanca, "Oración en el cementerio" for 2 November, on
    [diocesisdesalamanca.com](https://diocesisdesalamanca.com/wp-content/uploads/2024/10/2023-2024.-Oracion-en-el-cementerio.-Laico.pdf).
22. The Shrine of the Infant Jesus of Prague (Discalced Carmelites), on
    [pragjesu.cz](https://pragjesu.cz/es/nino-jesus-de-praga/oraciones/).
23. The Holy See, "Letanías de la Virgen", on
    [vatican.va](https://www.vatican.va/special/rosary/documents/litanie-lauretane_sp.html).
24. Vatican News, "Coronilla de la Divina Misericordia", on
    [vaticannews.va](https://www.vaticannews.va/es/oraciones/coronilla-de-la-divina-misericordia.html).
25. John Paul II, homily of 8 December 1995, Spanish, on
    [vatican.va](https://www.vatican.va/content/john-paul-ii/es/homilies/1995/documents/hf_jp-ii_hom_19951208_immacolata.html).
26. Conferencia Episcopal Española, Comisión Permanente (June 2021), the
    litany as published by the Diocese of Huelva, on
    [diocesisdehuelva.es](https://diocesisdehuelva.es/wp-content/uploads/2021/07/LETANIAS-EN-HONOR-DE-SAN-JOSE.pdf).
27. Vatican News, "La oración por el Papa", on
    [vaticannews.va](https://www.vaticannews.va/es/oraciones/la-oracion-por-el-papa.html).
28. *Misal Romano* (CEE), Good Friday, the universal prayer, as the
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
- `prayer_for_the_pope`: the source names Pope Leo XIV; the name is
  written "N.", as in the English, so the prayer serves any Pope.
- `divine_mercy_chaplet`: the source's instructions are bracketed rubrics,
  without their list numbers.
- `come_holy_ghost`: the source's "del espíritu Santo" is written "del
  Espíritu Santo".
- `confiteor`: "y a ti, Padre" is left out, twice (below).
- Titles: where the source's heading is only a label ("Colecta",
  "Oración", "Salmo"), the title is the prayer's first words or the
  psalm's number.

### How these differ from the English

- `actiones_nostras`: the source prints one ending, "Por Cristo nuestro
  Señor. Amén.", after a group of three collects; it is given to this
  one.
- `fidelium_deus`: "siervos y siervas", and the ending "Tú que vives y
  reinas con Dios Padre en unidad del Espíritu Santo." with no "Amén"; no
  "Oremos" before it.
- `visita_quaesumus`: the short ending "Por nuestro Señor Jesucristo.".
- `domine_non_sum_dignus`: the Mass form, "entres en mi casa" (my house,
  for "under my roof") and "una palabra tuya bastará para sanarme".
- `de_profundis`: the Liturgy of the Hours translation, not the Vulgate's;
  the Requiem versicle after it has no Spanish in the source and is left
  out.
- `nunc_dimittis`: the Liturgy of the Hours translation in six lines,
  with its antiphon and Glory Be.
- `confiteor`: the traditional form, as the English. The missal prints
  it as the server says it at Mass, with "y a ti, Padre" in both halves;
  those words are left out, as the English leaves out "and to you,
  Father". No rubric to strike the breast and no "Amén" (the source has
  neither).
- `o_salutaris`: the first line stays in Latin, as the source prints it.
- `divine_praises`: one more line than the English, "Bendito sea el
  Espíritu Santo Paráclito" (added in 1964).
- `st_dominic_o_lumen`: "Ejemplo de paciencia, Ideal de castidad" for
  "rose of patience, ivory of chastity", "júntanos a los santos" for
  "join us to the blessed", and no opening "O".
- `requiem_aeternam`: "Señor" first, and "luz eterna" for perpetual light.
- `come_holy_ghost`: "Envía, Señor, tu Espíritu, y vivirán todas las
  cosas" for "Send forth Thy Spirit, and they shall be created"; the
  collect is headed "[Oración.]", as the source heads it.
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
- `prayer_for_the_pope`: adds an Our Father and Hail Mary, and has a
  different collect.
- `prayer_for_priests`: the Good Friday prayer, for all the ministers of
  the Church, with the short ending.

## The third list: unofficial versions and the team's translations

Added on 3 November 2026, at Abraham's word: "use even unofficial versions if the translations are good then the rest translate with ai". Every prayer the book prints now has Spanish.

### Unofficial versions

Copied word for word from a devotional or parish site, and checked against a saved copy of the page, because the Spanish is natural, correct and faithful to the English. They carry no mark; whether they should is Abraham's call, and a mark would be one more field. The layout changes are those of the first list.

- `grace_before`: [Legionarios de Cristo](https://legionariosdecristo.org/?p=5792). The usual Spanish table blessing in correct, natural Spanish, with the closing 'Por Cristo nuestro Señor' that matches our English and the Latin (catholic.net's Bendicional form lacks it).
- `grace_after`: [Legionarios de Cristo](https://legionariosdecristo.org/?p=5792). Correct, natural Spanish from a religious order, with the same two parts as ours (the thanks and the versicle for the departed). It says "Señor" for "almighty God", "difuntos" for the faithful departed, and "Así sea" for the last Amen.
- `aquinas_before_study`: [ACI Prensa](https://www.aciprensa.com/recurso/3959/oracion-para-antes-de-estudiar). Widely used Spanish version, correct and natural, following the Latin clause by clause (three hierarchies, cielo empíreo, twofold darkness, the five gifts, ingressum/progressum/egressum).
- `jesus_meek`: [EWTN Español](https://www.ewtn.com/es/catolicismo/devociones/letanias-al-sagrado-corazon-de-jesus-15291). The standard Spanish form of this jaculatory, correct and exactly our content ("our hearts" as "nuestro corazón").
- `sacred_heart_trust`: [Catholic.net](https://es.catholic.net/imprimir.php?id=15534). The standard Spanish form of this aspiration, correct and faithful. The traditional "en Vos confío".
- `jmj`: [ACI Prensa](https://www.aciprensa.com/recursos/segundo-dia-de-la-novena-a-san-jose-1983/). The traditional rhymed Spanish form of the Raccolta ejaculations, correct and complete: heart and soul, help in the last agony, the soul at rest in peace with them. The traditional rhymed order "Jesús, José y María".
- `jmj_heart_and_soul`: [ACI Prensa](https://www.aciprensa.com/recursos/segundo-dia-de-la-novena-a-san-jose-1983/). The traditional rhymed Spanish form of the Raccolta aspiration, correct and prayed throughout the Spanish-speaking world, same three petitions as our English. The traditional rhymed form, in Vos, its six short lines joined into the English's three, as in `jmj`.
- `adoro_te`: [EWTN Español](https://www.ewtn.com/es/oracion/himno-a-jesus-sacramentado). The widely used Spanish prose version of the Adoro te devote, line for line with the Latin and our English, natural and correct.
- `o_domina_mea`: [Association of the Miraculous Medal](https://amm.org/pray-with-us/special-prayers/ofrecimiento-a-la-santisima-virgen). The classic Spanish form of the O Domina mea, correct and natural, addressing Mary with tú. "Mi lengua" where the English says my mouth.
- `memorare_st_joseph`: [Devocionario Católico](https://mail.devocionario.com/pdf/jose3.pdf). The traditional Spanish Acordaos to St Joseph, correct and natural, with the same request in the same order. The traditional text adds "y amable protector mío" and "en vuestro poder", says "ya que ejercisteis con Jesús el cargo de Padre" for "father of the Redeemer", and uses the old Vos forms.

### The team's translations (`ai_translated`)

No good Spanish version was found, so the team translated these from the book's English (and its Latin, for the liturgical wording): natural, traditional Spanish, tú to God, Mary and the saints, line for line with the English. Each is marked `ai_translated: true`. Spanish needs a gender where the English has none; these use the masculine as the general form. Scripture quoted inside a prayer speaks to people in ustedes ("Pidan y recibirán"), as Latin American Missals and Bibles do; litany responses and the old jaculatories keep vosotros ("rogad por nosotros", "os doy mi corazón"), the fixed forms parishes still pray. Rubrics that name an intention are impersonal ("[Aquí se nombra...]"); the guides to confession and the examinations speak to the reader as tú. Why no existing version was used:

- `morning_offering`: The traditional Apostleship of Prayer text was not found in good Spanish: Catholic Company's Spanish version has different content (adds bishops, reunion of Christians, drops 'in reparation for my sins' wording), and the Pope's Prayer Network now gives a new, different offering.
- `newman_definite_service`: Spanish versions found online differ and carry calques or errors ('servicio definitivo', 'Talvez').
- `lead_kindly_light`: No Spanish version found.
- `examen`: No Spanish text exists with this wording (the research found none.
- `in_manus_tuas`: Translated from our English and the Latin.
- `my_jesus_mercy`: One-line jaculatory.
- `sweet_heart`: No Spanish source found for this couplet (search for the exact wording returned nothing).
- `my_jesus_i_love_thee`: No Spanish source found.
- `my_god_and_my_all`: EWTN's page only quotes the phrase inside a biography ('"mi Dios y mi todo"', lowercase, no period), so it cannot be copied as a prayer text with the allowed edits.
- `o_sacrament_most_holy`: No Spanish version found.
- `blessed_be_conception`: No Spanish source with this exact wording found.
- `totus_tuus`: The catholic.net page quotes only the first half ("Soy todo Tuyo y todo lo mío es Tuyo") in John Paul II's Marian sense, without "oh amantísimo Jesús, por María".
- `st_joseph_pray`: No dedicated source needed or found.
- `holy_spirit_enlighten`: No Spanish source found.
- `aquinas_before_mass`: ACI Prensa's version (Oracion/tomas2.htm) has punctuation errors ('!Oh' for '¡Oh', a missing period) and uses vos.
- `st_ambrose_before_mass`: Not found online in Spanish.
- `en_ego`: ACI Prensa's version ('¡Oh mi amado y buen Jesús!') drops punctuation ('caridad verdadero dolor' with no comma) and changes the sense of the close ('lo que dijo de Ti' rather than what David put in His mouth).
- `aquinas_after_mass`: Spanish versions found all had errors or rewrites: ACI Prensa santisimo.htm is a loose paraphrase with typos ("pasionres", "inexpungable").
- `transfige`: EWTN's version ('Traspasa, dulcísimo Jesús y Señor mío') is close but has a punctuation error (an opening '¡Oh Jesús' never closed) and adds wording ('tal como la que llenaba el corazón de los Santos Apóstoles').
- `mary_after_communion`: EWTN's and catholic.org's version says 'servirte' (serve Mary) where the Latin and our English say serve Him.
- `suscipe`: Versions found had errors (archspm.org: "ya no desearán".
- `before_confession`: No Spanish source found.
- `examination_of_conscience`: No Church Spanish text matches our guide.
- `the_confession`: No Church Spanish text matches our guide.
- `after_confession`: No Spanish text of this prayer-manual thanksgiving found.
- `st_alphonsus_visit`: The only lead is a scanned book PDF with the text not confirmed on the page and no extractable copy.
- `o_sacrum_convivium`: The Valladolid edition's translation is stilted ('en el que se toma a Cristo', 'y de una futura gloria se nos da señal').
- `ave_verum`: No Spanish text found.
- `litany_blessed_sacrament`: The only Spanish copy found (EWTN Español, 'Devoción al Santísimo Sacramento del Altar') is full of typos ('Preexcelxo', 'nosostros', 'deso', 'verdera', a doubled 'de corazón') and differs from our litany in places.
- `st_patrick_breastplate`: EWTN's short version has errors ('Cristo bajo mí'.
- `breathe_in_me`: ACI Prensa's version is a different text (four plural petitions, 'inspíranos ...
- `seven_gifts`: ACI Prensa dones.htm has different prayers.
- `secret_of_sanctity`: ACI Prensa's version (Oracion/oracionespi.htm) has an accent error ('dime que debo hacer') and turns the promise into a petition ('Concédeme someterme').
- `litany_holy_ghost`: No Spanish text of this litany found.
- `litany_holy_name`: The diocesan PDF named in the research (obispadoalcala.org) timed out again.
- `consecration_sacred_heart`: The santisimavirgen.com.ar PDF was checked: it drops 'and malice', paraphrases 'Let Thy pure love imprint Thee', runs the paragraphs differently and ends on a sentence fragment ('Ya que quiero...'), so it was not used.
- `efficacious_novena`: El País's text is an AI-written article with the petitions in a different order, paraphrased Gospel words and no closing prayer.
- `golden_arrow`: No Spanish text found in searches.
- `litany_precious_blood`: Three Spanish versions checked and rejected: EWTN (misspellings 'Sanfre', 'Verno', 'Jescucristo', and 'Nuevo y Antiguo Testamento'), ACI Prensa letaniasangre2 (a different litany), adoracionyliberacion.com PDF (gender error 'emanado', stray punctuation, different versicle).
- `precious_blood_offering`: The only source (a scanned Philippine parish bulletin) is OCR text with typos ("lglesia"), uses "mis culpas", lacks "Santa" and "Amén".
- `christ_the_king`: The FSSPX News Spanish text is the 1925 form with two paragraphs our English does not have (idolatry and Islam.
- `st_richard`: Only loose paraphrases exist in Spanish.
- `o_jesus_living_in_mary`: No Spanish version found.
- `generosity_ignatius`: Common Spanish versions are in the singular ('enséñame a ser generoso') and vary in wording.
- `abandonment_foucauld`: The ACI Prensa link now leads to EWTN's version, which has a spelling error ('porque Tu eres', no accent), inconsistent 'Tu/tus' capitals, and 'Pongo mi vida' for 'Into Thy hands I commend my soul'.
- `radiating_christ`: ACI Prensa's version has a spelling error ('a Tí') and loose wording ('Sugiéreme la alabanza que más te agrada').
- `ave_regina_caelorum`: Spanish versions seen (CPDL, Flor y Canto) are hymn adaptations, not faithful to our text.
- `ave_maris_stella`: catholic.net's 'Salve Estrella del Mar' has a spelling error ('has segura' for 'haz segura'), drops the first line, and follows the Latin rather than our English stanzas.
- `inviolata`: No Spanish text found.
- `salve_mater`: No Spanish text found.
- `tota_pulchra`: Only devotional and music-site versions exist, with varying wording.
- `flos_carmeli`: No Spanish text on a Carmelite site.
- `three_hail_marys`: Devotional sites only, with varying wording.
- `perpetual_help`: Search found only differently worded prayers (ACI Prensa's 'bellísimo nombre...
- `our_lady_of_good_counsel`: Leo XIII's prayer was not found in Spanish.
- `our_lady_of_lourdes`: Only news and devotional sites with varying wording, none found with this full text.
- `immaculate_heart`: ACI Prensa's 'Oh Corazón de María, Madre de Dios y Madre nuestra' (aciprensa.com/Maria/oraciones/cor-mar.htm) is only the opening of this prayer, then a different short ending in vosotros.
- `mary_help_of_christians`: ACI Prensa's version (now offline, read from the Wayback Machine) is ungrammatical in its second half ('Tú, en las angustias...
- `our_lady_of_mount_carmel`: The Leo XIII prayer was not found in Spanish.
- `stabat_mater`: No official Spanish text confirmed online.
- `our_lady_of_sorrows`: No Spanish text of this Raccolta form found (devotional sites only, none matching).
- `litany_seven_sorrows`: Only devotional Spanish litanies of the Sorrows were noted, none matching this Pius VII / Servite text invocation for invocation.
- `st_joseph_workers`: The one good Spanish copy found is on FSSPX News, which the team does not cite; no other Church or devotional copy of the same text was found.
- `st_joseph_happy_death`: Devotional sites only.
- `litany_of_the_saints`: The official Spanish text (Misal Romano, Easter Vigil) is the post-1969 shortened litany, not the pre-1969 Roman Ritual form in our book.
- `st_anne`: Our text is an adaptation after the Raccolta.
- `st_anthony`: Spanish St Anthony prayers found online are different texts (devotional sites only).
- `st_jude`: Spanish St Jude prayers found online are longer, different texts.
- `st_peregrine`: The EWTN Español San Peregrino page has a different prayer ('San Peregrino, humilde servidor del Señor...'), not this one.
- `st_benedict_medal`: Spanish versions are on devotional and news sites only, and the second line varies between them.
- `st_gertrude`: The ACI Prensa versions checked have missing accents (aciprensa.com/Oracion/gertrudis.htm) or broken punctuation and a missing article ('en propia casa', novena page).
- `litany_of_humility`: EWTN's 'Letanías de Humildad' has different petitions and adds a closing prayer.
- `conversion_of_sinners`: Raccolta prayer not found in Spanish.
- `prayer_for_family`: Leo XIII's prayer not found in Spanish.
- `parents_for_children`: This 19th-century text was not found in Spanish.
- `prayer_for_our_country`: The Diocese of Orange's Spanish (rcbo.org) is a literal calque with errors: 'estaciones' for stations (offices), 'eminentemente útil', and 'ser admitidos entre aquellos que son eternos', which turns the eternal blessings into people.
- `da_pacem`: Translated from our English and the Latin.
- `prayer_for_the_sick`: The pre-1969 Roman Ritual prayer is not online in Spanish.
- `happy_death`: Newman's prayer not found in Spanish from a reliable page.
- `deceased_parents`: Translated from our English and the Latin.
- `prayer_for_travel`: The Itinerarium is not in the Spanish Liturgia de las Horas and no Spanish text was found.
