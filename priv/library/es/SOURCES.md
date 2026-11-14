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

The Hail Mary is written "Ave María" as the prayer's name and counted "Ave Marías" ("Tres Ave Marías"), as most Catholic apps and the Vatican's and the Mexican bishops' texts write it (Abraham, 10 Nov 2026: "Follow how other apps do it"; reports/rig/spanish-wording/ave-maria-apps.md).

No good Spanish version was found, so the team translated these from the book's English (and its Latin, for the liturgical wording): natural, traditional Spanish, tú to God, Mary and the saints, line for line with the English. Each is marked `ai_translated: true`. Spanish needs a gender where the English has none; these use the masculine as the general form. Scripture quoted inside a prayer speaks to people in ustedes ("Pidan y recibirán"), as Latin American Missals and Bibles do; litany responses and the old jaculatories keep vosotros ("rogad por nosotros", "os doy mi corazón"), the fixed forms parishes still pray. Rubrics that name an intention are impersonal ("[Aquí se nombra...]"); the guides to confession and the examinations speak to the reader as tú. Why no existing version was used:

- `morning_offering`: The traditional Apostleship of Prayer text was not found in good Spanish: Catholic Company's Spanish version has different content (adds bishops, reunion of Christians, drops 'in reparation for my sins' wording), and the Pope's Prayer Network now gives a new, different offering.
- `newman_definite_service`: Spanish versions found online differ and carry calques or errors ('servicio definitivo', 'Talvez').
- `lead_kindly_light`: No Spanish version found.
- `examen`: No Spanish text exists with this wording (the Examen is a set of steps, not a fixed prayer).
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
- `suscipe`: Versions found had errors (archspm.org: "ya no desearán"; Wikipedia: "Vos me lo diste") or old spelling, and St Ignatius's own Spanish (Ejercicios 234) is shorter than our English.
- `before_confession`: No Spanish source found.
- `examination_of_conscience`: No Church Spanish text matches our guide.
- `the_confession`: No Church Spanish text matches our guide.
- `after_confession`: No Spanish text of this prayer-manual thanksgiving found.
- `st_alphonsus_visit`: The only lead is a scanned book PDF with the text not confirmed on the page and no extractable copy.
- `o_sacrum_convivium`: The Valladolid edition's translation is stilted ('en el que se toma a Cristo', 'y de una futura gloria se nos da señal').
- `ave_verum`: No Spanish text found.
- `litany_blessed_sacrament`: The only Spanish copy found (EWTN Español, 'Devoción al Santísimo Sacramento del Altar') is full of typos ('Preexcelxo', 'nosostros', 'deso', 'verdera', a doubled 'de corazón') and differs from our litany in places.
- `st_patrick_breastplate`: EWTN's short version has errors ('Cristo bajo mí').
- `breathe_in_me`: ACI Prensa's version is a different text (four plural petitions).
- `seven_gifts`: ACI Prensa dones.htm has different prayers.
- `secret_of_sanctity`: ACI Prensa's version (Oracion/oracionespi.htm) has an accent error ('dime que debo hacer') and turns the promise into a petition ('Concédeme someterme').
- `litany_holy_ghost`: No Spanish text of this litany found.
- `litany_holy_name`: The diocesan PDF named in the research (obispadoalcala.org) timed out again.
- `consecration_sacred_heart`: The santisimavirgen.com.ar PDF was checked: it drops 'and malice', paraphrases 'Let Thy pure love imprint Thee', runs the paragraphs differently and ends on a sentence fragment ('Ya que quiero...'), so it was not used.
- `efficacious_novena`: El País's text is an AI-written article with the petitions in a different order, paraphrased Gospel words and no closing prayer.
- `golden_arrow`: No Spanish text found in searches.
- `litany_precious_blood`: Three Spanish versions checked and rejected: EWTN (misspellings 'Sanfre', 'Verno', 'Jescucristo', and 'Nuevo y Antiguo Testamento'), ACI Prensa letaniasangre2 (a different litany), adoracionyliberacion.com PDF (gender error 'emanado', stray punctuation, different versicle).
- `precious_blood_offering`: The only source (a scanned Philippine parish bulletin) is OCR text with typos ("lglesia"), uses "mis culpas", lacks "Santa" and "Amén".
- `christ_the_king`: The FSSPX News Spanish text is the 1925 form, with two paragraphs our English does not have.
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
- `perpetual_help`: Search found only differently worded prayers.
- `our_lady_of_good_counsel`: Leo XIII's prayer was not found in Spanish.
- `our_lady_of_lourdes`: Only news and devotional sites with varying wording, none found with this full text.
- `immaculate_heart`: ACI Prensa's 'Oh Corazón de María, Madre de Dios y Madre nuestra' (aciprensa.com/Maria/oraciones/cor-mar.htm) is only the opening of this prayer, then a different short ending in vosotros.
- `mary_help_of_christians`: ACI Prensa's version (now offline, read from the Wayback Machine) is ungrammatical in its second half and adds words.
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

## The Advent prayers

Added on 5 November 2026, for the three prayers the book added in English
that day. Each copied text was checked word for word against a saved copy
of its source (page scans for the 1860 book and the 1962 missal). The
layout changes are those of the first list.

### `o_antiphons`: "Antífonas de la O" (`ai_translated`)

The team's translation from the Latin of the seven Magnificat antiphons of
17 to 23 December (public domain), as the English book prints it beside
them, checked for natural es-MX by ios-review (10 Nov 2026). Abraham, 10
Nov 2026, Q1 "A": the team translates it, so no copyrighted Spanish is
used (the CEE *Liturgia de las Horas* was used before). The title is the
usual Spanish name.

- Layout: each antiphon headed by the English's rubric
  (`[Día 17 de diciembre.]`).
- Following the Latin: 17 "te extiendes de un confín a otro" (Wisdom 8:1)
  and "el camino de la prudencia"; 18 "Guía" for *Dux* and "con brazo
  extendido" (Exodus 6:6); 20 and 21 "habita" / "habitan" for *sedentem* /
  *sedentes* (Luke 1:79); 22 "Deseado de los pueblos" for *desideratus
  earum*; 23 "esperanza y Salvador de las naciones".

### `st_andrew_novena`: "Novena de Navidad de San Andrés" (`ai_translated`)

The team's translation of the 1897 English (public domain), checked by
ios-review (10 Nov 2026), as drafted. Abraham, 10 Nov 2026, Q1 "A"; the
archspm.org Spanish used before is not. The title is the devotion's usual
Spanish name.

- "Salve" for Hail; "bendita sea la hora y el momento", the form the
  prayer has in Spanish devotion; "frío penetrante" for piercing cold;
  "dígnate" for vouchsafe.

### `advent_wreath_collects`: "La corona de Adviento: las colectas de los domingos" (`ai_translated`)

The team's translation from the Latin of the four Advent Sunday collects
(*Missale Romanum*, Tours, Mame, 1882, public domain), checked for natural
es-MX by ios-review (10 Nov 2026). Abraham, 10 Nov 2026, Q2 "B" and the
SPEC's Spanish as Q1 "A". The rubric and headings follow the English's;
each collect ends "℟. Amén." as the English does.

- "Despierta, Señor, ... tu poder" for *Excita potentiam*, the same verb in
  the three *Excita* collects; 1 "protegidos por ti ... liberados por ti"
  for *te protegente ... te liberante*; 2 "con el alma purificada" for
  *purificatis mentibus*; 4 "el perdón de tu misericordia" for *indulgentia
  tuae propitiationis*.

### `immaculate_conception_novena`: "Novena a la Inmaculada Concepción" (`ai_translated`)

A mixed text, so it is marked `ai_translated`:

- The preparatory prayer and the nine prayers of the days: the same
  Raccolta novena (Pius VII, 1808) in Spanish, *Colección de oraciones y
  obras piadosas por las cuales han concedido los Sumos Pontífices santas
  indulgencias*, from the 13th Roman edition, translated by J. M. and
  Agustín Ferrer, Pbro. (Barcelona, 1860, with the Ordinary's licence),
  pp. 266 to 274, on
  [archive.org](https://archive.org/details/coleccion-de-oraciones-y-obras-piadosas-con-indulegncias).
  Public domain. No other Spanish of this novena was found (ACI Prensa's,
  Opus Dei's and other "Novena a la Inmaculada" are different texts).
- "Ven, Espíritu Santo": this file's `come_holy_ghost`, word for word,
  headed `[Oremos.]` as the English is, its "Amén" as "℟. Amén.".
- The three collects: the team's translation from their Latin (the 1860
  book prints them in Latin; the Roman Missal's *Deus, qui per
  immaculatam Virginis Conceptionem*, *Deus, omnium fidelium pastor et
  rector* and *Deus, refugium nostrum et virtus*), checked by ios-review
  (10 Nov 2026); Abraham, 10 Nov 2026, Q1 "A". The 1962 Lefebvre Spanish
  used before is not. The third keeps the English's layout, its "Amén"
  as "℟. Amén.".
- The team's translation: every rubric, the Tota pulchra versicles
  (following Lefebvre's Spanish of the 8 December Gradual and Tract where
  they say the same), the versicle "En tu concepción, oh Virgen..." and
  its response, and the endings of the first two collects, which follow
  the English (the Immaculate Conception's "Por Cristo nuestro Señor.
  Amén."; none for the Pope's).

Changed from the 1860 book, spelling and accents only: "á" and "ó" to "a"
and "o", the interjection "ó" to "oh", "Vírgen" to "Virgen", accents on
-ión words and on "día", "después", "Adán", "más"; "hácia", "piés",
"fuéseis", "triunfáseis", "fuísteis", "adorásteis", "dísteis" to "hacia",
"pies", "fueseis", "triunfaseis", "fuisteis", "adorasteis", "disteis";
"teneis", "hayais", "digneis", "alcanceis", "hagais" with their accents;
"y qué muera" to "y que muera". Spaces before punctuation removed, the
quotation set as «Mostrad que sois nuestra Madre». and its Latin tag
("Monstra te esse Matrem") left out, as the English has none. The book's
headings and rubrics give way to the English's in Spanish, and its rubric
repeated after each day ("Se rezará la Letanía o el Himno...") is left
out, as the English gives it once. "nono" is "noveno". Lowercase after "!"
is kept as printed.

Where it differs from the English:

- The 1860 prayers speak to Mary in vos ("os venero", "alcanzadme"), the
  book's own form, kept as in `memorare_st_joseph`; the versicles, the
  team's, use tú. They keep the book's leísmo ("volver a cometerle" for
  sin, "inflamadle" for the heart, "le ame" for God): the rule is spelling
  only, never the wording.
- The preparatory prayer: "y desde aquel primer instante toda hermosa y
  sin mancilla" for all fair and stainless in thy Conception; "Madre de
  misericordia"; "lo que en esta Novena os consagro"; «Mostrad que sois
  nuestra Madre» for Show thyself a mother.
- The days: 1 "Aquí me tenéis a vuestros santísimos pies" and "Ea, pues,
  haced que los venza"; 2 "me lleno de confusión en vuestra presencia"
  for overwhelmed with shame; 3 and 7 no "mortal" before sin; 5 "la
  pasión y muerte" and no "Precious"; 6 ends "eternamente." with no "world
  without end. Amen."; 7 "un total y continuo aborrecimiento al pecado
  sobre todo otro mal"; 8 "que jamás abuse de ella" for never more to
  receive it in vain, "una total renovación de mi vida"; 9 "ejemplar de
  pureza", "descendía la plena bendición", "gozar de Vos coronada de tanta
  gloria".
- The collects (the team's, from the Latin): "limpios de toda mancha" for
  *mundos* where the English says purified, "por su intercesión"; "Pastor y
  Guía" for *pastor et rector*, "edifique a quienes preside" for
  *proficere*; "autor de toda piedad" and "piadosas súplicas" for the
  author of all holiness and pious prayers, "alcanzar plenamente" for
  effectually obtain.

# Sources of the Consecration's Spanish

`es/consecration.json` holds the 33-day Consecration in Spanish, served in
the `translations` section of `GET /api/v2/consecration?lang=es`. Every
phase, day, reading, prayer and feast has Spanish. Every copied reading
was checked sentence by sentence against a saved copy of its source on 3
November 2026; where a source had only a scan, the passage was
transcribed from the page images and the transcription checked against
them.

The eight prayers the Prayer Book also prints (`veni_creator`,
`ave_maris_stella`, `magnificat`, `glory_be`, `litany_holy_ghost`,
`litany_loreto`, `litany_holy_name`, `o_jesus_living_in_mary`) are not in
this file: their Spanish is `es/prayer_book.json`'s, listed above, so the
two documents never disagree.

## The editions

- **[S1]** Félix Torres Amat, *La Sagrada Biblia, traducida al español de
  la Vulgata latina* (first edition Madrid 1823-1825; public domain),
  Vulgate-based like the Douay-Rheims, with the Vulgate's psalm numbers.
  24 readings from es.wikisource's proofread transcription of the 1836
  printing (tomos XIII to XV, for example [Mateo](https://es.wikisource.org/wiki/La_Sagrada_Biblia_(XIII)/Mateo)),
  4 transcribed from the scans of the first edition on archive.org
  ([sagrada-biblia-torres-amat-completa](https://archive.org/details/sagrada-biblia-torres-amat-completa)).
  Source label: "Biblia de Torres Amat".
- **[S2]** Thomas à Kempis, *Imitación de Cristo*, translated by Juan
  Eusebio Nieremberg SJ (died 1658; public domain), Madrid, Saturnino
  Calleja, 1876, from the scan on archive.org
  ([imitacion-de-cristo...nieremberg](https://archive.org/details/imitacion-de-cristo-tomas-de-kempis-traduzido-por-pe.-juan-eusebio-nieremberg)),
  each passage checked against the page images. Source label:
  "Imitación de Cristo, trad. Nieremberg".
- **[S3]** St Louis Marie Grignion de Montfort, *Tratado de la verdadera
  devoción a la Santísima Virgen*, translated from the eighth French
  edition by Ramón María de Araiztegui, Habana, Imprenta de Casa-Nova e
  Hijos, 1885 (public domain: printed 141 years ago, the translator a
  judge by 1885), from the scan on archive.org
  ([tratado-de-la-verdadera-devocion-a-la-virgen-maria](https://archive.org/details/tratado-de-la-verdadera-devocion-a-la-virgen-maria)).
  Its OCR is poor: every passage was corrected against the page images,
  and paragraphs 247 and the opening of 257-258 transcribed from them.
  Source label: "Tratado de la verdadera devoción a la Santísima Virgen,
  trad. Araiztegui (1885)"; citations as the English gives them
  ("Verdadera devoción, números 152–164"). Not used: the Lérida 1872 (Orgaz) and Quito 1890 (Peña)
  translations, also public domain, and the modern ones (the 1954 BAC
  *Obras*, montfort.org, EWTN), under copyright.

The spelling and accents are modernized to the RAE's current rules, never
the wording: "á" to "a", "fué" to "fue", "devocion" to "devoción",
"Magestad" to "Majestad", "muger" to "mujer", "zelo" to "celo",
"esquisito" to "exquisito" and the like. The words stay the 19th-century
translators', and so do their old names and forms ("Jesu-Cristo",
"priesa", "trasformaos").

## The readings and their sources

| Day | Reading | English | Spanish | Edition | Note |
|---|---|---|---|---|---|
| 1 | 1 | Matthew 5:1-19 | Mateo 5, 1-19 | [S1] |  |
| 1 | 2 | True Devotion, paragraph 227 | Verdadera devoción, número 227 | [S3] |  |
| 2 | 1 | Matthew 5:48, 6:1-15 | Mateo 5, 48; 6, 1-15 | [S1] |  |
| 2 | 2 | Imitation of Christ, Book 2, Chapter 6 | Imitación de Cristo, libro 2, capítulo 6 | [S2] |  |
| 3 | 1 | Matthew 7:1-14 | Mateo 7, 1-14 | [S1] |  |
| 3 | 2 | Imitation of Christ, Book 3, Chapter 56 | Imitación de Cristo, libro 3, capítulo 56 | [S2] |  |
| 4 | 1 | Imitation of Christ, Book 3, Chapters 7 & 40 | Imitación de Cristo, libro 3, capítulos 40 y 7 | [S2] |  |
| 4 | 2 | Psalm 102:13-18 | Salmo 102, 13-18 | [S1] | transcribed from the scan of the first edition |
| 5 | 1 | Imitation of Christ, Book 3, Chapter 40 | Imitación de Cristo, libro 3, capítulo 40 | [S2] |  |
| 5 | 2 | Luke 18:9-14 | Lucas 18, 9-14 | [S1] |  |
| 6 | 1 | Imitation of Christ, Book 1, Chapter 18 | Imitación de Cristo, libro 1, capítulo 18 | [S2] |  |
| 6 | 2 | Hebrews 12:1-3 | Hebreos 12, 1-3 | [S1] | transcribed from the scan of the first edition |
| 7 | 1 | Imitation of Christ, Book 1, Chapter 18 (cont.) | Imitación de Cristo, libro 1, capítulo 18 | [S2] |  |
| 7 | 2 | Apocalypse 3:14-20 | Apocalipsis 3, 14-20 | [S1] |  |
| 8 | 1 | Imitation of Christ, Book 1, Chapter 13 | Imitación de Cristo, libro 1, capítulo 13 | [S2] |  |
| 8 | 2 | Matthew 4:1-11 | Mateo 4, 1-11 | [S1] |  |
| 9 | 1 | Imitation of Christ, Book 1, Chapter 13 (cont.) | Imitación de Cristo, libro 1, capítulo 13 | [S2] |  |
| 9 | 2 | James 1:12-15; 1 Corinthians 10:13 | Santiago 1, 12-15; 1 Corintios 10, 13 | [S1] |  |
| 10 | 1 | Imitation of Christ, Book 3, Chapter 10 | Imitación de Cristo, libro 3, capítulo 10 | [S2] |  |
| 10 | 2 | 1 John 2:15-17 | 1 Juan 2, 15-17 | [S1] |  |
| 11 | 1 | Imitation of Christ, Book 1, Chapter 25 | Imitación de Cristo, libro 1, capítulo 25 | [S2] |  |
| 11 | 2 | Luke 15:11-24 | Lucas 15, 11-24 | [S1] |  |
| 12 | 1 | Imitation of Christ, Book 1, Chapter 25 (cont.) | Imitación de Cristo, libro 1, capítulo 25 | [S2] |  |
| 12 | 2 | Galatians 2:19-20; 6:14 | Gálatas 2, 19-20; 6, 14 | [S1] | transcribed from the scan of the first edition |
| 13 | 1 | True Devotion, paragraph 228 | Verdadera devoción, número 228 | [S3] |  |
| 13 | 2 | Luke 11:1-10 | Lucas 11, 1-10 | [S1] |  |
| 14 | 1 | Imitation of Christ, Book 3, Chapter 13 | Imitación de Cristo, libro 3, capítulo 13 | [S2] |  |
| 14 | 2 | Philippians 2:5-11 | Filipenses 2, 5-11 | [S1] | transcribed from the scan of the first edition |
| 15 | 1 | Luke 13:1-5 | Lucas 13, 1-5 | [S1] |  |
| 15 | 2 | True Devotion, paragraphs 81–82 | Verdadera devoción, números 81–82 | [S3] |  |
| 16 | 1 | True Devotion, paragraphs 79–80 | Verdadera devoción, números 79–80 | [S3] |  |
| 16 | 2 | Imitation of Christ, Book 2, Chapter 5 | Imitación de Cristo, libro 2, capítulo 5 | [S2] |  |
| 17 | 1 | Imitation of Christ, Book 1, Chapter 24 | Imitación de Cristo, libro 1, capítulo 24 | [S2] |  |
| 17 | 2 | Luke 16:1-8 | Lucas 16, 1-8 | [S1] |  |
| 18 | 1 | Luke 17:1-10 | Lucas 17, 1-10 | [S1] |  |
| 18 | 2 | Imitation of Christ, Book 3, Chapter 47 | Imitación de Cristo, libro 3, capítulo 47 | [S2] |  |
| 19 | 1 | Luke 18:15-30 | Lucas 18, 15-30 | [S1] |  |
| 19 | 2 | Imitation of Christ, Book 3, Chapter 4 | Imitación de Cristo, libro 3, capítulo 4 | [S2] |  |
| 20 | 1 | True Devotion, paragraph 229 | Verdadera devoción, número 229 | [S3] |  |
| 20 | 2 | Luke 2:16-21, 45-52 | Lucas 2, 16-21. 45-52 | [S1] |  |
| 21 | 1 | True Devotion, paragraphs 115–118 | Verdadera devoción, números 115–118 | [S3] |  |
| 21 | 2 | John 19:25-27 | Juan 19, 25-27 | [S1] |  |
| 22 | 1 | True Devotion, paragraphs 106–110 | Verdadera devoción, números 106–110 | [S3] |  |
| 22 | 2 | Luke 8:19-21; 11:27-28 | Lucas 8, 19-21; 11, 27-28 | [S1] |  |
| 23 | 1 | True Devotion, paragraphs 120–121 | Verdadera devoción, números 120–121 | [S3] |  |
| 23 | 2 | Romans 12:1-2; 6:3-4 | Romanos 12, 1-2; 6, 3-4 | [S1] |  |
| 24 | 1 | True Devotion, paragraphs 152–164 | Verdadera devoción, números 152–164 | [S3] |  |
| 24 | 2 | John 14:1-6 | Juan 14, 1-6 | [S1] |  |
| 25 | 1 | True Devotion, paragraphs 213–225 | Verdadera devoción, números 213–225 | [S3] |  |
| 25 | 2 | John 15:1-8 | Juan 15, 1-8 | [S1] |  |
| 26 | 1 | True Devotion, paragraphs 14–38 | Verdadera devoción, números 14–38 | [S3] |  |
| 26 | 2 | Apocalypse 12:1-6 | Apocalipsis 12, 1-6 | [S1] |  |
| 27 | 1 | True Devotion, paragraph 230 | Verdadera devoción, número 230 | [S3] |  |
| 27 | 2 | True Devotion, paragraphs 61–62 | Verdadera devoción, números 61–62 | [S3] |  |
| 28 | 1 | Matthew 26:1-2, 26-29, 36-46 | Mateo 26, 1-2. 26-29. 36-46 | [S1] |  |
| 28 | 2 | Imitation of Christ, Book 2, Chapter 11 | Imitación de Cristo, libro 2, capítulo 11 | [S2] |  |
| 29 | 1 | Imitation of Christ, Book 1, Chapter 1 | Imitación de Cristo, libro 1, capítulo 1 | [S2] |  |
| 29 | 2 | 1 Peter 2:21-25 | 1 Pedro 2, 21-25 | [S1] |  |
| 30 | 1 | Matthew 27:36-44 | Mateo 27, 36-44 | [S1] |  |
| 30 | 2 | Imitation of Christ, Book 2, Chapter 12 | Imitación de Cristo, libro 2, capítulo 12 | [S2] |  |
| 31 | 1 | Imitation of Christ, Book 4, Chapter 2 | Imitación de Cristo, libro 4, capítulo 2 | [S2] |  |
| 31 | 2 | True Devotion, paragraphs 243, 247, 249, 253 | Verdadera devoción, números 243, 247, 249, 253 | [S3] |  |
| 32 | 1 | Imitation of Christ, Book 2, Chapter 7 | Imitación de Cristo, libro 2, capítulo 7 | [S2] |  |
| 32 | 2 | True Devotion, paragraphs 257–260 | Verdadera devoción, números 257–260 | [S3] |  |
| 33 | 1 | Imitation of Christ, Book 4, Chapter 11 | Imitación de Cristo, libro 4, capítulo 11 | [S2] |  |
| 33 | 2 | True Devotion, paragraphs 261–265 | Verdadera devoción, números 261–265 | [S3] | `ai_translated`: the passage the edition leaves out (264, point 4, to the middle of 265) is the team's translation |
| 34 | 1 | True Devotion, paragraphs 230–231 | Verdadera devoción, números 230–231 | [S3] |  |
| 34 | 2 | True Devotion, paragraphs 234–256 | Verdadera devoción, números 234–256 | [S3] |  |

## What was changed from the source

- Verse numbers, paragraph numbers, footnote markers, running heads,
  page numbers and the section dashes at the ends of verses are left
  out. Torres Amat's italic glosses in the running text are kept, as he
  prints them.
- Each reading has the English's excerpt and the English's paragraph
  breaks, where they fall inside a printed paragraph.
- The speaker labels the 1876 Imitation adds ("JESUCRISTO:", "EL
  ALMA:") are left out, as the English has none. A heading is the
  chapter's title as Nieremberg prints it.
- Two Scripture readings open with a heading in the English ("Examples
  inviting Repentance", "The Crafty Steward"), which is not Scripture:
  the team's "Ejemplos que mueven a penitencia" and "El mayordomo
  astuto".
- Transcription and print errors corrected:
  - [S1] Wikisource: "En vendad" to "En verdad", "hipócrilas" to
    "hipócritas", "pordonará" to "perdonará", "asl" to "asi" (day 2);
    "aciertos hombres" to "á ciertos hombres" (day 5); "cuando no se,
    levantare" to "cuando no se levantare" (day 13); "la palabra el
    Dios" to "la palabra de Dios" (day 22); "yo permanecerá" to "yo
    permaneceré" (day 25).
  - [S2] the 1876 printing: "necesidadd el" to "necesidad del" (day 6),
    "do toda tentación" to "de toda tentación" and "insconstancia" to
    "inconstancia" (day 8), "Todas las cosas pasadas" to "Todas las
    cosas pesadas" (the title of book 3, chapter 47, day 18), "Muhos" to
    "Muchos" (day 28), "la irá de Dios" to "la ira de Dios" (day 2).
  - [S3] the OCR's misreadings, from the page images, and the printer's
    turned letters ("de reducen" to "se reducen"). Kept as printed:
    "Santos muy esclavos" and "no da fruta".
- Day 33, reading 2: the 1885 edition runs from the end of paragraph
  264, point 3 ("los que obran en Ella no pecan,") straight into the
  second half of 265 ("es menester atraer á todo el mundo"), with no page
  missing from the scan. The lost passage (the Latin "Qui operantur in
  me, non peccabunt", point 4, and the start of IV) is the team's
  translation from Faber, so the reading is marked `ai_translated`. Its
  third section is numbered "III." for the printed "3.º", to match "IV."
  and the English.

## Where the Spanish differs from the English

Each translation is its own, made from the Vulgate, the Latin or the
French, not from these English versions:

- [S1] 1 John 2:15 opens "Ved pues lo que os escribo á todos:";
  Matthew 5:48 ends with Torres Amat's gloss "imitándole en cuanto
  podais"; in Galatians 2:19 "Estoy clavado en la cruz" closes the verse.
- [S2] Day 3 "vence todas las cosas" where the English has "sell all
  that thou hast"; day 10 "me mandaste que te amase" for "commanded me
  to serve Thee"; day 6 has a sentence the English lacks ("¡Cuán gran
  celo y fervor tuvieron en su aprovechamiento espiritual!"), day 7 a
  phrase ("del cual eran familiares amigos"); day 9 gives the couplet
  "Atajar al principio el mal procura" without the English's "Whence a
  certain one has said".
- [S3] The fifth motive is "camino fácil, perfecto y seguro", without
  "corto"; the Act says "este pequeño gusano y miserable pecador" for
  "this poor sinner".

## The prayers

| Prayer (`id`) | Source |
|---|---|
| `act_of_consecration` | [S3], the end of the Treatise, `ai_translated`: two lines the 1885 edition does not print are the team's translation ("no he guardado las promesas que tan solemnemente os hice en mi Bautismo;" and "Os saludo, oh Reina del cielo y de la tierra, a cuyo imperio está sometido todo lo que está debajo de Dios."). "N." is put for the printed "N......." as in the Prayer Book. Kept in vos, the edition's own form. Phrases broken in the print, mended: the opening exclamation closed ("siempre Virgen! Os adoro"); "no os he cumplido mis deberes" to "no he cumplido mis deberes"; "la Sabiduría eterna escondida quiere ser adorada" to "la Sabiduría eterna quiso estar escondida y ser adorada"; "para en adelante" to "en adelante"; "sobre tierra" to "sobre la tierra"; "por que os habéis sometido" to "porque os habéis sometido" |
| `st_louis_prayer_mary` | the team's translation, `ai_translated`. It is from *The Secret of Mary*; the only old Spanish found (P. Nazario Pérez SJ, died 1952) is under copyright |
| `st_louis_prayer_jesus` | the team's translation, `ai_translated`, for the same reason |
| `rosary` | the team's translation of the app's rubric, `ai_translated`, with the app's Spanish names "Inicio" and "Rezar" |

The team's translations address Jesus and Mary as tú, as the Prayer
Book's do; the Act keeps the 1885 edition's vos.

## The team's translation of the rest (`ai_translated`)

The day titles and journal questions (tú to the reader), the phases'
names and subtitles, and the feasts' names and descriptions, in the
names Spanish-speaking Catholics use ("Nuestra Señora del Carmen"). A
journal question that quotes a reading quotes that day's Spanish
reading.
