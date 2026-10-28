# Meditation content QA, October 2026

Date: 7 October 2026.

Data source: the local Postgres database `lumen_viae_uiux`, a migrated copy of `lumen_viae_dev`, queried read-only with SELECT. Its counts match `lumen_viae_dev` exactly (153 meditations, 257 narrations, 29 sets, 35 archived meditations), so the findings apply to the dev data. Production was not queried; where production is known to differ, it is noted below.

## Method

- A set is visible when it holds at least one meditation and none of them is archived (the `visible?` calculation in `lib/lumen_viae/rosary/meditation_set.ex`). 23 of the 29 sets are visible, holding 118 meditations. The six hidden sets (31, 32, 33, 34, 36, 37, all fully archived) were not reviewed.
- Voices are the `:narration_voices` in `config/config.exs`: `frederick` (default, offered as "Male"), `female` (offered), and `male` (hidden, replaced by `frederick`).
- A Python script read every visible meditation from psql as JSON and checked: word counts (under 60, over 600), long text with no blank line, footnote markers, OCR patterns, joined words, words missing from the system dictionary, doubled spaces, spaces before punctuation, unbalanced quotation marks, mojibake, HTML and markdown, missing author and source, and narration rows per voice.
- Openings and mystery mismatches were flagged by script and then checked by reading the opening and close of every meditation, and the full text where in doubt. Mismatches are flagged only where the text plainly belongs elsewhere.
- Not counted: trailing spaces before a line break (67 places), which readers cannot see; Scripture ellipses in set 39, which mark the set's own elisions; spelling that matches the source edition (honour, sepulchre, Nikodemus).

No meditation was under 60 or over 600 words (range 60 to 473). No footnote brackets, mojibake, HTML or markdown were found.

## Database-wide findings

- **No Female narrations exist.** `meditation_narrations` holds 153 `male` rows and 104 `frederick` rows and none for `female`, which the site offers in its voice picker. Every visible meditation lacks a Female recording in this database. Production may differ (Arabella's recordings are described in `config/config.exs`); confirm there before acting. These 118 gaps are not repeated in the per-set tables.
- **No set carries its own author, source or author link**, and the `authors` table is empty here (production has 11 authors linked to its sets). Bylines here come only from the meditations' agreed `author` and `source`.

## Summary

Counts are table rows below. A set-level row (attribution, audio) counts once for the set.

| Issue type | Count |
|---|---|
| Opening | 8 |
| Formatting | 5 |
| Mismatch | 2 |
| Length | 0 |
| Attribution | 8 |
| Audio | 2 |
| Artefact | 27 |
| **Total** | **52** |

| Set | Category | Opening | Formatting | Mismatch | Length | Attribution | Audio | Artefact | Total |
|---|---|---|---|---|---|---|---|---|---|
| 25 Venerable Fulton J. Sheen | glorious | 0 | 0 | 0 | 0 | 1 | 0 | 5 | 6 |
| 28 St. Alphonsus Liguori | glorious | 0 | 0 | 0 | 0 | 1 | 0 | 1 | 2 |
| 46 Blessed Anne Catherine Emmerich | glorious | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| 52 St. John Henry Newman | glorious | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 26 Venerable Fulton J. Sheen | joyful | 0 | 0 | 0 | 0 | 1 | 0 | 3 | 4 |
| 29 St. Alphonsus Liguori | joyful | 0 | 5 | 1 | 0 | 1 | 0 | 3 | 10 |
| 42 Blessed Anne Catherine Emmerich | joyful | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 48 St. Ignatius of Loyola | joyful | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 58 Venerable Mary of Agreda | joyful | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 59 Father Frederick William Faber | joyful | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 2 |
| 53 Blessed Anne Catherine Emmerich | luminous | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 |
| 54 St. Augustine | luminous | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 55 St. John Chrysostom | luminous | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| 56 St. Thomas Aquinas | luminous | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 1 |
| 39 Scripture + Short Meditation | seven_sorrows | 0 | 0 | 0 | 0 | 1 | 1 | 6 | 8 |
| 40 Meditation + Prayer | seven_sorrows | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 3 |
| 60 Venerable Mary of Agreda | seven_sorrows | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 61 St. Alphonsus Liguori | seven_sorrows | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| 27 Venerable Fulton J. Sheen | sorrowful | 0 | 0 | 0 | 0 | 1 | 0 | 5 | 6 |
| 30 St. Alphonsus Liguori | sorrowful | 0 | 0 | 0 | 0 | 1 | 0 | 2 | 3 |
| 45 Blessed Anne Catherine Emmerich | sorrowful | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 62 St. John Chrysostom | sorrowful | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 3 |

## Findings by set

### Set 26: Venerable Fulton J. Sheen

Category: joyful. Author (from meditations): Archbishop Fulton J. Sheen. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 122 | joyful_2 | Artefact: 5 spaces before commas, a doubled space, unbalanced quotation marks | "the cousin , of His Mother. Thus , long before Cana" |
| 123 | joyful_3 | Artefact: 2 space(s) before punctuation (OCR spacing) | "of His Father , new hands" |
| 125 | joyful_5 | Artefact: 2 space(s) before punctuation (OCR spacing) | "two kinds of souls in the world ; those who hide" |
| all | - | Attribution: Meditations say "Archbishop Fulton J. Sheen", set name says "Venerable"; source has no edition | "Archbishop Fulton J. Sheen" vs "Venerable Fulton J. Sheen" |

### Set 29: St. Alphonsus Liguori

Category: joyful. Author (from meditations): St. Alphonsus Liguori. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 140 | joyful_5 | Mismatch: Finding in the Temple carries the Presentation text, identical to meditation 139 | "on the day of her purification, presented the Child Jesus" |
| 136 | joyful_1 | Formatting: Over-fragmented: blank line every few words, mid-sentence (11-13 paragraphs in ~100 words) | "Let us contemplate in this mystery" / "how the..." |
| 137 | joyful_2 | Formatting: Over-fragmented: blank line every few words, mid-sentence (11-13 paragraphs in ~100 words) | "Let us contemplate in this mystery" / "how the..." |
| 138 | joyful_3 | Formatting: Over-fragmented: blank line every few words, mid-sentence (11-13 paragraphs in ~100 words) | "Let us contemplate in this mystery" / "how the..." |
| 139 | joyful_4 | Formatting: Over-fragmented: blank line every few words, mid-sentence (11-13 paragraphs in ~100 words) | "Let us contemplate in this mystery" / "how the..." |
| 140 | joyful_5 | Formatting: Over-fragmented: blank line every few words, mid-sentence (11-13 paragraphs in ~100 words) | "Let us contemplate in this mystery" / "how the..." |
| 138 | joyful_3 | Artefact: Misplaced comma and space | "when the time of her delivery was come ,brought forth" |
| 137 | joyful_2 | Artefact: Doubled space | "by that  exceeding charity" |
| 136 | joyful_1 | Artefact: No period before closing Amen (also 139 and 140: "forever Amen") | "to be our Mother also / Amen." |
| all | - | Attribution: Source is "Glories of Mary" with no edition or translation (set 61 names its edition) | "Glories of Mary" |

### Set 42: Blessed Anne Catherine Emmerich

Category: joyful. Author (from meditations): Blessed Anne Catherine Emmerich. Meditations: 5.

No issues found.

### Set 48: St. Ignatius of Loyola

Category: joyful. Author (from meditations): St. Ignatius of Loyola. Meditations: 5.

No issues found.

### Set 58: Venerable Mary of Agreda

Category: joyful. Author (from meditations): Venerable Mary of Agreda. Meditations: 5.

No issues found.

### Set 59: Father Frederick William Faber

Category: joyful. Author (from meditations): Father Frederick William Faber. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 331 | joyful_1 | Opening: Opens on bare "her"; Mary not named in first sentence | "The night was still and calm around her." |
| 333 | joyful_3 | Opening: First sentence speaks of "her ecstasy" with no named subject | "seem to flit before her in her ecstasy" |

### Set 53: Blessed Anne Catherine Emmerich

Category: luminous. Author (from meditations): Blessed Anne Catherine Emmerich. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 301 | luminous_1 | Artefact: Stray footnote numeral left in the text | "a long, white baptismal robe. 1 After this Jesus stepped" |

### Set 54: St. Augustine

Category: luminous. Author (from meditations): St. Augustine. Meditations: 5.

No issues found.

### Set 55: St. John Chrysostom

Category: luminous. Author (from meditations): St. John Chrysostom. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 312 | luminous_2 | Opening: Opens on bare "He"; Cana and Mary not named | "Why then after He had said, 'Mine hour is not yet come,'" |

### Set 56: St. Thomas Aquinas

Category: luminous. Author (from meditations): St. Thomas Aquinas. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 317 | luminous_2 | Mismatch: Weak anchor only: general treatise on miracles, never mentions Cana or wine | "God enables man to work miracles for two reasons." |

### Set 27: Venerable Fulton J. Sheen

Category: sorrowful. Author (from meditations): Archbishop Fulton J. Sheen. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 128 | sorrowful_3 | Artefact: Split word "be cloud" for "becloud"; 3 spaces before commas | "whose evil lives be cloud their thinking" |
| 130 | sorrowful_5 | Artefact: Stray period mid-phrase; 4 spaces before punctuation | "A broken heart, O Saviour. of the world" |
| 126 | sorrowful_1 | Artefact: 4 spaces before punctuation; unbalanced quotation marks | "our Lord said to His enemies . Evil has its hour" |
| 127 | sorrowful_2 | Artefact: 2 space(s) before punctuation (OCR spacing) | "thought Him , as it were, a leper" |
| 129 | sorrowful_4 | Artefact: 1 space(s) before punctuation (OCR spacing) | "or impure crosses , which come" |
| all | - | Attribution: Meditations say "Archbishop Fulton J. Sheen", set name says "Venerable"; source has no edition | "Archbishop Fulton J. Sheen" vs "Venerable Fulton J. Sheen" |

### Set 30: St. Alphonsus Liguori

Category: sorrowful. Author (from meditations): St. Alphonsus Liguori. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 145 | sorrowful_5 | Artefact: Space before comma | "Let us contemplate in this mystery , how" |
| 144 | sorrowful_4 | Artefact: "heavyweight" for "heavy weight" | "bore the heavyweight of our sins" |
| all | - | Attribution: Source is "Glories of Mary" with no edition or translation (set 61 names its edition) | "Glories of Mary" |

### Set 45: Blessed Anne Catherine Emmerich

Category: sorrowful. Author (from meditations): Blessed Anne Catherine Emmerich. Meditations: 5.

No issues found.

### Set 62: St. John Chrysostom

Category: sorrowful. Author (from meditations): St. John Chrysostom. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 351 | sorrowful_1 | Opening: Opens on bare "He"; no name or Gethsemane scene | "And He prays with earnestness" |
| 354 | sorrowful_4 | Opening: Opens on bare "they" and "Him" | "And now they laid the cross upon Him as a malefactor." |
| 353 | sorrowful_3 | Opening: Weak: opens mid-argument, no subject or scene named | "And the insults were different, and varied." |

### Set 25: Venerable Fulton J. Sheen

Category: glorious. Author (from meditations): Archbishop Fulton J. Sheen. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 132 | glorious_2 | Artefact: Joined words (OCR) | "speaking to theApostles about the Kingdom"; "the details ofHis Church" |
| 132 | glorious_2 | Artefact: Final sentence has no closing punctuation | "we may later ascend with Thee in the flesh" |
| 133 | glorious_3 | Artefact: Split word "be friend" for "befriend"; 7 spaces before commas | "He who is to be friend you will not come" |
| 131 | glorious_1 | Artefact: 2 space(s) before punctuation (OCR spacing) | "on Easter Sunday , our Lord said" |
| 134 | glorious_4 | Artefact: 2 space(s) before punctuation (OCR spacing) | "Certainly she , the new Garden of Paradise" |
| all | - | Attribution: Meditations say "Archbishop Fulton J. Sheen", set name says "Venerable"; source has no edition | "Archbishop Fulton J. Sheen" vs "Venerable Fulton J. Sheen" |

### Set 28: St. Alphonsus Liguori

Category: glorious. Author (from meditations): St. Alphonsus Liguori. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 148 | glorious_3 | Artefact: 2 spaces before commas | "who after he was ascended , returning to Jerusalem" |
| all | - | Attribution: Source is "Glories of Mary" with no edition or translation (set 61 names its edition) | "Glories of Mary" |

### Set 46: Blessed Anne Catherine Emmerich

Category: glorious. Author (from meditations): Blessed Anne Catherine Emmerich. Meditations: 5.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 248 | glorious_3 | Opening: Weak: scene (Supper Room, Pentecost) not established in first sentence | "After midnight there arose a wonderful movement in all nature." |

### Set 52: St. John Henry Newman

Category: glorious. Author (from meditations): St. John Henry Newman. Meditations: 5.

No issues found.

### Set 39: Scripture + Short Meditation

Category: seven_sorrows. Author (from meditations): Servants of Mary. Meditations: 7.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 217 | seven_sorrows_2 | Artefact: Typo "Joesph" | "appeared in sleep to Joesph saying" |
| 213 | seven_sorrows_4 | Artefact: Typos "hearth" (heart) and "addd" (add) | "her hearth almost breaks"; "addd weight to His Cross" |
| 214 | seven_sorrows_5 | Artefact: Typos "they" for "thy" (twice), missing comma | "Woman Behold they son." ... "Behold they Mother" |
| 215 | seven_sorrows_6 | Artefact: Typos "has thou", "be we"; citation should be Mark 15:43-46 | "why has thou forsaken Me"; "— Mark 14: 43-46" |
| 216 | seven_sorrows_7 | Artefact: Typo "therefor" (Douay: "therefore") | "There, therefor, because of the Parasceve" |
| 211 | seven_sorrows_1 | Artefact: Spaces before commas inside the Scripture quotation | "And thy own soul , a sword shall pierce ," |
| all | - | Attribution: No source on any of the 7 meditations; author is "Servants of Mary"; set has no author, source or author link | - |
| all | - | Audio: None of the 7 meditations has a Frederick (default voice) narration; only the retired "male" voice | voices: male only |

### Set 40: Meditation + Prayer

Category: seven_sorrows. Author (from meditations): Servants of Mary. Meditations: 7.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 224 | seven_sorrows_2 | Artefact: Garbled word order in closing prayer (likely "I promise thee that") | "I promise that thee, for the future" |
| all | - | Attribution: No source on any of the 7 meditations; author is "Servants of Mary"; set has no author, source or author link | - |
| all | - | Audio: None of the 7 meditations has a Frederick (default voice) narration; only the retired "male" voice | voices: male only |

### Set 60: Venerable Mary of Agreda

Category: seven_sorrows. Author (from meditations): Venerable Mary of Agreda. Meditations: 7.

No issues found.

### Set 61: St. Alphonsus Liguori

Category: seven_sorrows. Author (from meditations): St. Alphonsus Liguori. Meditations: 7.

| meditation id | mystery key | issue | quote |
|---|---|---|---|
| 346 | seven_sorrows_4 | Opening: First sentence turns on bare "she"; Mary not named | "the ministers of justice had passed, she raises her eyes" |

## Fix first

Ranked by what a reader or listener meets.

1. **Meditation 140 (St. Alphonsus Liguori, Joyful, Finding in the Temple) is a copy of the Presentation meditation (139).** Anyone praying the fifth Joyful Mystery with this set reads and hears the Presentation again. Replace it with Liguori's Finding prayer and re-record it.
2. **The two "Servants of Mary" Seven Sorrows sets (39, 40) have no Frederick narration and no source.** The default voice has nothing to play for 14 meditations, and readers cannot tell where the text comes from. Record Frederick, fill in the source, and consider giving the sets proper names in place of "Scripture + Short Meditation" and "Meditation + Prayer".
3. **Set 39 has typos inside Scripture quotations**: "Behold they son", "why has thou forsaken Me", "Joesph", "therefor", a wrong citation (Mark 14 for Mark 15), plus "hearth" and "addd" in the reflections. These sit in quoted Gospel text and are read aloud by the narrator.
4. **Six openings start on a bare pronoun** (331, 333, 346, 351, 354, 312), against rule 4 of the curation guide; two more (353, 248) are weak. Move each excerpt's start back a sentence so Jesus, Mary and the scene are named.
5. **The three Sheen sets (25, 26, 27) carry OCR damage**: joined and split words ("theApostles", "ofHis", "be friend", "be cloud"), a stray period ("O Saviour. of the world"), a missing final period, and about 35 spaces before commas. Clean the text; the author field also says "Archbishop" where the set says "Venerable" (production now uses "Blessed"), so align them in the same pass.

Also worth doing: the Liguori Joyful set (29) splits every sentence into blank-line fragments, which reads poorly and paces oddly in narration, and meditation 301 carries a stray footnote numeral ("robe. 1 After this").
