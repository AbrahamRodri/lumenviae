# Meditation Curation Guide

Rules for selecting and formatting meditation content pulled from source
texts (saints, mystics, Church Fathers). These apply to every meditation
imported into LumenViae, whether curated by hand or with Claude's help.

## Source fidelity

1. Meditations quote the source verbatim. Never summarize, paraphrase, or
   add words to the author's text. Only public domain editions may be used,
   and the edition/translation is recorded in the `source` field.
2. Excerpts may begin and end only at sentence boundaries. Paragraph breaks
   may be added for readability (see Formatting), but the words themselves
   are untouched.

## Excerpt selection

3. Each meditation focuses on ONE aspect of the mystery - a single scene,
   image, or movement of the soul. Do not stitch together disconnected
   moments.
4. The excerpt must stand alone. A listener who knows only the name of the
   mystery must be able to follow it from the first sentence:
   - Named subjects: if the excerpt opens with "He" or "She", the listener
     is lost. Start early enough that Jesus, Mary, or the speaker is
     established.
   - Established scene: the setting (the cave at Bethlehem, the Temple,
     Nazareth) must be clear from the text itself, not assumed.
5. Short is the goal, context is the constraint. Prefer concise excerpts
   when the passage carries its own context (good example: Emmerich's
   Annunciation passage, which opens with Mary's fiat and needs nothing
   before it). But when the natural starting point sits earlier in the
   scene, make the meditation longer rather than confusing (e.g. the
   Nativity excerpt must begin with Mary and Joseph in the cave, not at
   "Mary continued in prayer").
6. Never narrow an excerpt so far that the theme loses its anchor in the
   mystery. If the focused aspect cannot be understood without material
   that was cut, restore the material or choose a different passage.

## Formatting

7. Content must be formatted with paragraph breaks (blank line between
   paragraphs) so it reads well on screen and paces well when converted to
   audio. Break at natural movements in the text - scene shifts, speech,
   the turn from action to vision.
8. Do not use markdown, headers, or list syntax inside content; plain
   paragraphs only. The app renders content with `whitespace-pre-wrap`, so
   line breaks in the database appear exactly as stored.
9. Dialogue keeps the source's own quotation style.

## Metadata

10. `title` is a short editorial theme (these may be our words), e.g.
    "The Fiat and the Flood of Light".
11. `author` uses the honorific matching the Church's current recognition
    (St., Blessed, Venerable). Only canonized authors' sets carry the
    "Saints" label.
12. Every set carries exactly one style label. "Contemplative" is for
    imaginative, scene-based writing that shows what was happening in the
    mystery (Emmerich's visions, Ignatian composition of place).
    "Considerations" is for discursive writing that explains the mystery's
    meaning and doctrine (Sheen's essays, Liguori's "Consider how..."
    points). Judge by how the text prays, not by the author's reputation.
13. Audio filenames follow `<category>_<author>_<n>.mp3`, e.g.
    `joyful_emmerich_1.mp3`.
14. Generated import CSVs live in `priv/repo/imports/` and are gitignored -
    meditation content stays out of version control.
