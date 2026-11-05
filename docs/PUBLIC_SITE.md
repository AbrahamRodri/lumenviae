# The public site

Read this before you touch a public page. It says what the pages are, what
is in a prayer link, where each setting is kept, how to check your work in
a browser, and which pages nobody maintains.

The public site is the Rosary, the Consecration, the Prayer Book, the
Chant Library, Hours of Prayer, the Daily Missal, True Devotion, Explore and Spiritual Reading: the iOS app's tabs and books coming to the
website, one at a
time, as its desktop version. The console
(`/admin`), the APIs (`/api`) and `/healthz` are not part of it.

## The pages

| Path | Module | What it is |
| --- | --- | --- |
| `/` | `LumenViaeWeb.Live.Home.Index` | The daily hub. Today's mysteries, on the traditional weekly schedule or the modern one, in the visitor's own time zone. The five mysteries and their fruits, the meditation sets for today, the Rosary without a set, a card for every category, and Today's Prayer (the Consecration's day, the hour's order of prayer, Today's Mass and the Hours of Prayer; see below). |
| `/mysteries` | `LumenViaeWeb.Live.Mysteries.Scripture` | "Finding the Mysteries in Scripture". Every mystery, with its Douay-Rheims passages, and a note on the Traditional and Modern schedules. |
| `/mysteries/:category` | `LumenViaeWeb.Live.Mysteries.CategoryList` | One category: `joyful`, `sorrowful`, `glorious`, `luminous` or `seven_sorrows`. Its mysteries, "Your Rosary Today" choices, the two ways to pray without a set, and the shelf of meditation sets. |
| `/meditation-sets/:set_id/pray` | `LumenViaeWeb.Live.Pray.Index` | The prayer page, praying one set. |
| `/mysteries/:category/pray` | `LumenViaeWeb.Live.Pray.Index` | The same page, praying a category without a set. |
| `/app` | `LumenViaeWeb.Live.Home.App.Index` | The iPhone app's page: real screenshots of the app in CSS-drawn phones, what it holds in the app's own names, and the App Store link. |
| `/privacy-policy` | `LumenViaeWeb.Live.PrivacyPolicy.Index` | The privacy policy the App Store listing links to. |
| `/consecration` | `LumenViaeWeb.Live.Consecration.Index` | The 33-day Consecration to Jesus through Mary, as the app's Consecration tab: with no plan in this browser, the introduction (`?step=devotion`, `day`, `journey`, the welcome never written) and the feast chooser (`?step=choose`; where a visitor who has reached it before opens); a plan before its Day 1, the waiting page; a plan under way goes on to today's day; a finished one offers the feasts again under a note that it was made. |
| `/consecration/days/:n` | `LumenViaeWeb.Live.Consecration.Day` | Day `n`, 1 to 34 (Consecration Day): the phase's painting in the arch with the badge, the title and Pray; the feast the plan ends on; the day's prayers (`?lang=`), readings and question; the journey; the book; Restart. `?step=` walks it a page a step, the prayers then the readings, with Amen on the last. Open to anyone, plan or none. |
| `/consecration/act` | `LumenViaeWeb.Live.Consecration.Act` | The Act made, as the app's completion: the seal, "I am all yours", the way back, then the Act's own words to renew it, and Restart under a plan. |
| `/prayers` | `LumenViaeWeb.Live.Prayers.Index` | The Prayer Book, as the app's Prayers tab: the number of prayers, the search (`?q=`; topics, then up to three orders of prayer, then the prayers), the shortcuts to Morning Prayers, the Angelus, Night Prayers, Before Mass and Before Confession, Now (the order for the visitor's hour, with Pray), Everyday Prayers, Prayers to Mary (the season's song first) and All Topics under the book's five parts, as shelves of square painted cards (sideways on a phone, wrapping from 640px). |
| `/prayers/topics/:chapter_id` | `LumenViaeWeb.Live.Prayers.Chapter` | One topic, as the app's topic page: its painting with the title and line over it, Pray together (the topic's orders of prayer, a row each) where it has any, its prayers (a small arched painting and the title each) under its sections where it has more than one, the next topic as a painted card and a line back to the one before. |
| `/prayers/orders/:order_id` | `LumenViaeWeb.Live.Prayers.Order` | An order of prayer, as the app's `PrayerOrderView`: its painting, when it is said and its name for the day, its prayers numbered (each begins praying there), the Eastertide line on the Angelus, and Pray. |
| `/prayers/orders/:order_id/pray` | `LumenViaeWeb.Live.Prayers.Order.Pray` | Praying an order in silence, a prayer a page, as the app's `PrayAlongView`: the way back, the order's name, its beads and "2 of 9", the prayer in English, Latin or Both, the way back a prayer and Next, Amen on the last and the close (Done, Pray again). From 1024px a rail of its prayers. Nothing is recorded. |
| `/prayers/:prayer_id` | `LumenViaeWeb.Live.Prayers.Prayer` | One prayer, as the app opens a prayer alone: its second name as a gold label over the title where the app shows one, English, Latin or Both (`?lang=`), the words, and a link back to its topic. |
| `/chant` | `LumenViaeWeb.Live.Chants.Index` | The Chant Library, as the app's Chant tab: the number of recordings, the search (`?q=`; by title, by the prayer sung, by a line of the words), the tiles (A Sung Rosary, Adoration and Blessing, the Mass of the Angels, Before Bed), Songs to Mary as square cards with their length and a play disc, Sets of Chants (the six sung sets as cards whose disc sings the whole set, the shelf's All sets opening `/chant/sets`), and All Chants, the book's twelve sections as painted cards. |
| `/chant/sections/:section_id` | `LumenViaeWeb.Live.Chants.Section` | A section's shelf (`hymns`, `ourLady`), or the Mass of the Angels' (`mass_of_the_angels`): its painting with the name, when it is sung, how many chants and how long, Play all, the strip of its parts where it has them, and its chants, numbered where they share the shelf's painting, each with its own painting otherwise. |
| `/chant/sets` | `LumenViaeWeb.Live.Chants.Sets` | Sets of Chants, as the app's `ChantSetsPage`: the six sung sets as wide painted cards, each with what it is for and how many chants and how long. |
| `/chant/sets/:occasion_id` | `LumenViaeWeb.Live.Chants.Set` | A sung set (`benediction`, `sung_rosary`, `before_bed`), as the app's `ChantSetPage`: its painting with the name, its line, how many chants and how long, Play all (then Pause, Resume, Play next), Pause Between Chants, and its order: the notes in red over the chants they lead to, each chant numbered with how often it is sung and a Play from Here. |
| `/chant/:chant_id` | `LumenViaeWeb.Live.Chants.Chant` | One chant, as the app's `ChantView`: its painting and its Latin and English names; the recording with the scrubber, back and on a line (greyed until it has played), the gold play, Repeat this line (which starts it) and three-quarter speed; the line being sung, or when it is sung for a chant with no timed lines; the Words (`?words=`), every line lit as it is sung and a click playing from it; The Sheet Music, opening the full score over the page (`?score=full`); the prayer it sings, its other settings and the singers' credit. |
| `/hours` | `LumenViaeWeb.Live.Hours.Index` | Hours of Prayer, the Divine Office as the app's landing opens it, for the visitor's today: the hour now under its painting (NOW and when it lapses) with a gold Pray, the day's feast and class in plain words, the eight hours on a strand in a breviary's three groups, and a link to the month. The hour and the date wait, as an empty frame, for the browser's clock, so the server's UTC never names them. |
| `/hours/:date` | `LumenViaeWeb.Live.Hours.Index` | The same for another day (`YYYY-MM-DD`): its date where NOW stands, and a link back to today. |
| `/hours/:date/:hour` | `LumenViaeWeb.Live.Hours.Hour` | One hour read in full: its painting and name, the day and its feast, Latin, English or Both (`?lang=`), the parts of the hour (a rail beside the text from 1024px, a jump list above it on a phone), the hours either side and the Divinum Officium credit linked to the engine's page for the hour. `:hour` is the Office's slug (`matutinum` to `completorium`). |
| `/hours/calendar/:year/:month` | `LumenViaeWeb.Live.Hours.Calendar` | The month by the days' classes, a gold mark brighter for the greater feasts; each day links to its hours, and from 768px each cell carries the day's title. |
| `/missal` | `LumenViaeWeb.Live.Missal.Index` | The Daily Missal, the app's `DailyMissalView`, for the visitor's today: the date pill (opening the month), the feast with what else is remembered, the day's arrows around its vestment colour and class, Latin, English or Both (`?lang=`), a choice where the day has several Masses (`?mass=`), About This Day where there is something to say, the parts of the Mass (a rail beside the text from 1024px, a jump list above it on a phone), each with its posture, the propers' diamond and its Latin name, and the Mass's close: THE MASS IS ENDED, the Order of Mass and the credit. The plate waits, as an empty frame, for the browser's clock. |
| `/missal/:date` | `LumenViaeWeb.Live.Missal.Index` | The same for another day (`YYYY-MM-DD`), with Return to today once the visitor's today is known to be another. |
| `/missal/order-of-mass` | `LumenViaeWeb.Live.Missal.Ordo` | The Order of Mass, the app's `OrdoMissaeView`: EVERY MASS, the fixed parts of every traditional Latin Mass from the Asperges to the Prayers after Mass, in the same language choice (`?lang=`), the priest's rubrics in quiet italic, with the parts' rail and the credit. |
| `/missal/calendar/:year/:month` | `LumenViaeWeb.Live.Missal.Calendar` | Choose a day: the month of the 1962 calendar, each day's vestment colour as a dot (and from 768px its title in the cell), each day opening its Mass. |
| `/true-devotion` | `LumenViaeWeb.Live.TrueDevotion.Index` | St. Louis de Montfort's True Devotion, the book's title page as the app's `TrueDevotionReaderView`: the Marian-blue binding over its halo, Begin Reading (or Continue Reading where this browser left off, with a thread for how far into the chapter), the contents (the Introduction, then Part I and Part II folding open; the chapter last opened marked while it is unfinished, its part open, and a folded part holding it marked on its header), the translator and the edition. From 1024px the binding and the act stand beside the contents. |
| `/true-devotion/:chapter_id` | `LumenViaeWeb.Live.TrueDevotion.Chapter` | A chapter read in place, as the app's chapter reader: the place in the book as a hairline, the part and "8 of 13", the title, the text on night with each paragraph's number in the margin (anchored `#p-3`), a paragraph's Bookmark and Share, the chapters either side or The End, and the contents (a rail from 1024px, a list above the text on a phone) with the reader's bookmarks at their head, each its chapter's title over the passage's opening words (the rail carries the contents sheet's head: the book's title, Contents and "8 of 13"). `:chapter_id` is the book's chapter id (`introduction`, `motives`). |
| `/explore` | `LumenViaeWeb.Live.Explore.Index` | Explore, as the app's `ExploreView`: at rest a directory (the five devotions, the Prayers shelf of occasion orders with All prayers, the Chant tiles with Chant Library, Mass & Hours as two tiles (the Daily Missal and Hours of Prayer), and the Spiritual Reading shelf with All books: True Devotion's cover, then the five books', the ribbon on a book under way in this browser); typed into (`?q=`), the one search over the mysteries, the site's doors (Today's Mass, Spiritual Reading and each of its books among them, a book found by its title, author or translator), the Prayer Book's topics, orders and prayers, the chants and every meditation set: the kinds found as chips, the best match as a painted card (Pray on an order, Listen on a chant), then a section per kind, twelve rows each before "And 3 more". |
| `/spiritual-reading` | `LumenViaeWeb.Live.SpiritualReading.Index` | The Spiritual Reading shelf, as the app's `SpiritualReadingView`: the open book, the shelf's name, "Classic Catholic books to read, or to listen to", Augustine's "Take up and read", the five books as covers in their own cloth (two across on a phone, five on a wide screen; the ribbon on a book with a reading under way in this browser), and the credit. Fetches no text. |
| `/spiritual-reading/:book_id` | `LumenViaeWeb.Live.SpiritualReading.Book` | A book, as the app's `LibraryBookView`: its cover beside the title and author, Begin reading (or "Continue · III.V" where this browser left off), the contents ("Contents · 115 chapters") with each part's name pinned over its chapters and the parts' numerals down the edge, the chapter being read lit, the ones read dimmed and those more than two before it folded into "N earlier chapters", the listen chip on each row a LibriVox track opens on (its length; "31:05 in" where this browser left the voice), and the credit (Gutenberg's text, LibriVox's volunteers). From 1024px the head stands in a column beside the contents. `:book_id` is the catalogue's (`imitation-of-christ`). |
| `/spiritual-reading/:book_id/:chapter` | `LumenViaeWeb.Live.SpiritualReading.Chapter` | A chapter read in place, as the app's `LibraryChapterReaderView`: the place in the book as a hairline, the part and heading over the title with "8 of 115", the text on night with the versal, the edition's footnote markers linked to the notes at the foot, the chapters either side by their headings, and the contents (a rail from 1024px, a list above the text on a phone); where a LibriVox track reads the chapter, Hear this read under the title, and the player. `:chapter` counts from 1. |

All thirty-four are in the `:public` live session in `router.ex`. A set
that does not exist, or is hidden, answers 404, and so do an unknown
category, an unknown chapter, an unknown order, an unknown prayer, an
unknown chant section, an unknown sung set, an unknown chant and an
unknown True Devotion chapter, an unknown Spiritual Reading book or a
chapter that is not a whole number from 1 (or that the book, once its
text is held, does not have), a Consecration day that is not a whole
number from 1 to 34, and on
the Hours pages a date that is not one or that the Office does not serve
(1600 to 2200, `LumenViae.Office.serves?/1`), an unknown hour and a
month that is not one; and on the Missal's pages a date or a month that
is not one, or that it does not serve (the Office's years, 1600 to 2200).

`priv/static/sitemap.xml` lists `/`, `/mysteries`, the five category pages,
`/consecration`, `/consecration/act` and the 34 days' pages, `/prayers`, every chapter's page and every order of prayer's page,
`/chant`, every chant section's shelf (and the Mass of the Angels'),
`/chant/sets` and every sung set's page, every chant's page, `/hours`,
`/missal`, `/missal/order-of-mass`,
`/true-devotion` and each of its thirteen chapters, `/explore` (never a
search), `/spiritual-reading`,
each of its five books and every chapter of each (219, as the catalogue's
rules cut Gutenberg's editions in November 2026), `/app` and
`/privacy-policy`. When a book is added to
`priv/library/spiritual_reading.json`, or its rules change how many
chapters it cuts into, add or remove its pages; the Spiritual Reading
tests check every book is there and Brother Lawrence's twenty chapters
(the one whole edition in the fixtures). When a chant, a section or a sung set is
added to `priv/library/chant_library.json`, add its page; the
Chant tests check every one is there. The
prayers themselves are not listed: every one is linked from its chapter,
and a list of 150 pages would drift from the book. Nor are the Hours'
dated pages, and `robots.txt` asks crawlers to stay out of `/hours/`
(`/hours` itself is welcome): each day, hour and month is assembled by the
Divinum Officium engine the first time it is asked for, across six
centuries of dates, and the calendar's arrows would walk a crawler
through all of them. The Missal's dated pages are kept out the same way
(`Disallow: /missal/`; `/missal` and, by `Allow: /missal/order-of-mass`,
the Order of Mass are welcome): each day is fetched from Missale Meum on
first asking, and the day's arrows would walk a crawler through six
centuries of them. When a chapter or an order is added
to `priv/library/prayer_book.json`, add its page; the Prayers tests check
every chapter and order is there. The prayer pages and the steps of
praying an order are not in it, and `robots.txt` asks crawlers to stay out
of `/meditation-sets/`, `/prayers/orders/*/pray` and a Consecration day's
steps (`/consecration/days/*?step=`). A crawler that walked the
prayer flow once pressed Complete often enough to leave Rosaries nobody had
prayed; see `docs/COMPLETION_ANALYTICS.md`.

## Archived pages

These pages left the site on 7 October 2026. The iPhone app's page left
with them and came back the same day, rewritten. Their code is in `archive/`,
which is outside `lib/` and `test/`, so it is not compiled and its tests are
not run.

| Old path | Page |
| --- | --- |
| `/dashboard` | Prayer dashboard (folded into the home page) |
| `/rosary-methods` | How to Pray the Rosary |
| `/true-devotion` | True Devotion to Mary (the summary page; the address now opens the book) |
| `/saint-carlo` | St. Carlo Acutis |
| `/feedback` | Feedback |

Each old path answers `301 Moved Permanently` and redirects to `/`, through
`LumenViaeWeb.RedirectController`, except `/true-devotion`: since
November 2026 it opens the book itself (`LumenViaeWeb.Live.TrueDevotion`,
new code; the archived summary page of its teaching stays archived, as it
is on iOS). The list is the `for path <- ~w(...)`
loop in `router.ex`. The addresses are linked from outside the site, so
keep the redirects.

**Archived pages are not maintained.** Do not fix them, do not update them
when a shared component changes, and do not link to them or add them to the
sitemap. If one has to come back, follow `archive/README.md`: move it out
of `archive/`, take its path out of the redirect list, add its route to
`:public`, link it, and run the tests, because the shared components it uses
may have moved on.

## The prayer page's link

The place and the choices ride in the query string, so a reload, a shared
link and the back button all keep them. `LumenViaeWeb.Live.Pray.Params`
reads and writes them.

| Parameter | Values | Default (left out of the link) |
| --- | --- | --- |
| `mystery` | `opening`, a decade number from `0`, or `closing` | the beginning |
| `step` | the bead on that page, from `0`; used only with `count=screen` | `0` |
| `form` | on a set: `meditation` or `scriptural`. On a category: `scriptural` or `holy` | `meditation` on a set, `scriptural` on a category |
| `count` | `beads` (on your own rosary, a decade a page) or `screen` (a bead at a time) | `beads` |
| `aloud` | `true` | off |
| `voice` | a narration voice's slug | the default voice |

Rules that hold for every link:

- A default is never written, so ordinary links stay short.
- A value that is not allowed is the default. A decade number out of range
  is held to the nearest decade.
- `mobile` is accepted and ignored. Old links carry it.
- The closing prayers, the language, the text size, the reading page and
  the images are not in the link.
  They are the browser's (below).

Examples:

```
/meditation-sets/26/pray
/meditation-sets/26/pray?mystery=2&count=screen&step=4
/mysteries/sorrowful/pray?form=holy&count=screen
/mysteries/joyful/pray?aloud=true&voice=male
```

`LumenViaeWeb.Live.Mysteries.CategoryList.PrayLinks` builds the links on the
category and home pages, carrying "Your Rosary Today" choices.

## The Prayer Book's links

The Prayers pages keep their state in the link too, and a default is never
written.

| Page | Parameter | Values | Default |
| --- | --- | --- | --- |
| `/prayers` | `q` | the search, as typed | no search: the shelves |
| `/prayers/:prayer_id` | `lang` | `latin` or `both` (only on a prayer with Latin) | English |
| `/prayers/orders/:order_id/pray` | `step` | the prayer, counted from `1`, or `amen` for the close | `1` |
| `/prayers/orders/:order_id/pray` | `lang` | `latin` or `both`, carried from prayer to prayer; a prayer with no Latin is set in English | English |
| `/prayers/orders/:order_id/pray` | `from` | where the prayer was begun, for Done and the close: `prayers` (the Now card) or `topic:<id>` (a topic of the book); carried from prayer to prayer | the order's page |

A `step` past either end is the nearest prayer, and anything else (a
list, `2.5`, a word) is the first; a `lang` that is not one of the three
is English; a `from` that is not one of those (or names no topic) is the
order's page. Examples: `/prayers/orders/night/pray?step=3&lang=both`,
`/prayers/orders/table/pray?step=amen`,
`/prayers/orders/angelus/pray?from=prayers`.

In Both the English leads and the Latin pairs with it line by line, as the
app's Prayer Book sets it (English with Latin), the Latin in quiet
italic: two columns from 768px, the Latin beneath each English line,
stepped in, on a phone. A psalm verse breaks at its mediant (a red star,
the second half hung in), and a long prose prayer opens on a gilt versal.
The origin and the "when it is said" note the book carries are not shown,
as the app no longer shows them. The words, the chapters and the songs to Mary are the
domain's (`LumenViae.Rosary.get_prayer_book!/1`, from
`priv/library/prayer_book.json`); how the pages arrange them (which
prayers open the page, the paintings, the search's ranking) is
`LumenViaeWeb.Live.Prayers.Book`, the app's rules, and the text's grammar
is `LumenViaeWeb.Live.Prayers.PrayerText`. The season's song to Mary is
`LumenViae.LiturgicalCalendar.marian_antiphon_season/1` on the visitor's
date (the `UserTimezone` hook, as home), the server's until it connects.
The paintings are the app's (`PrayerBookPaintings.swift`), each the very
file the app bundles, served beside the mysteries' paintings (see
docs/MYSTERY_PAINTINGS.md); a prayer whose scene the site lacks hangs its
topic's, as the app does.

The orders of prayer (Morning Prayers, Before Confession) are the
book's `orders`; how the pages read them is
`LumenViaeWeb.Live.Prayers.Orders`, the app's rules: the hour's order
(morning from 4 until 11, the Angelus until 20, night after, on the
visitor's clock from the `UserTimezone` hook), the shortcuts, the
Angelus as Queen of Heaven from Easter to the eve of Trinity Sunday
(`LumenViae.LiturgicalCalendar.eastertide?/1`), Night Prayers closing on
the season's song to Mary, the paintings (the app's own, Morning's
falling back to the Presentation as on iOS, any other to the Coronation)
and the search.
Until the visitor's clock is known the Now card is an empty frame of its
size (a crawler, or a browser without JavaScript, never sees the hour in
UTC), and while the page is open it turns at the book's turns, four,
eleven, three and eight o'clock (`Orders.next_turn_in/1`, iOS's
`nextTurn`). The Angelus and Queen of Heaven hang the app's gold bell
over the title, still, since the site makes no sound. The page titles
name the order as the day does (Queen of Heaven in Eastertide, on the
server's date). The app marks an order PRAYED TODAY from what the phone
kept; the site keeps nothing of what a visitor prayed, so it never does,
and Now always offers Pray; nor does its pray-along head say SILENT, as
the site is silent only. The app's For an Occasion is now Pray together at the head
of a topic, here as there.

Not here yet, as the app has them: Saved, Learn by Heart, the app's own
playlists and praying aloud.

## The Chant Library

The Chant pages keep their state in the link too: `/chant?q=` is the
search, and `/chant/:chant_id?words=` the Words, `latin` or `english`;
Both is the default and never written, and anything else is Both.
`/chant/:chant_id?score=full` is the full score open over the page;
anything else is the page alone.

The full score is the app's `ChantScoreSheet` (opened on iOS from the
score on the chant's page or the more menu's Enlarge the Sheet Music):
the chant's painting with its names and DONE at the head, every page of
the score at the width of the glass (a page's width at most, 60rem, on a
wide screen), each named in gold where there is more than one, the notes
in cream and the initials in the rubric red, and a small player floating
at the foot (play, the scrubber, the time) that drives the page's own
recording. A double-click (or a double tap) brings it to twice the width
or back, about the phrase clicked; the zoom buttons beside the player and
the + and - keys (0 for the width of the glass) step it from one to three
times, and the score then scrolls inside its own frame, never the page.
It is a dialog: focus starts on the score and stays within it, and DONE,
Escape or Back close it (opened from the page, DONE and Escape go back in
the history; opened from a link, they go to the chant's page). The pages
of the score are drawn by the `ChantScore` hook
(`assets/js/hooks/chant_score.js`) from the apps' own packed drawings
(`.lvscore`), which the site serves at `/chant/scores/:file` (a file, not
a page: the bucket sends no CORS headers, so the server fetches it; see
docs/ARCHITECTURE.md). A page that cannot be had says "The sheet music
comes with a connection", as the app does. Unlike the app: the web has
no pinch (the browser's own zoom stays the browser's) and no animation
of the zoom, the zoom has buttons and keys besides the double-click, and
the entry is a quiet capsule, The Sheet Music, under the player, as the
page has no score window of its own yet.

The chants, their recordings and their timed lines are the domain's
(`LumenViae.Rosary.get_chant_library!/1`, from
`priv/library/chant_library.json`); how the pages arrange them (the songs
to Mary, the sections' names, which painting each section and chant
hangs, which shelves number their chants, the rows' second lines and the
search) is `LumenViaeWeb.Live.Chants.Library`, the app's rules
(`ChantLibraryData.swift`, `ChantLibraryPages.swift`). The sung sets
(the library's `occasions`) are unrolled for the visitor's day by
`LumenViaeWeb.Live.Chants.Occasions`, the app's `ChantOccasion`: Before
Bed sings tonight's song to Mary, the season's antiphon by
`LumenViae.LiturgicalCalendar.marian_antiphon_season/1` on the browser's
date (the `UserTimezone` hook; the server's until it comes). The
paintings are
the app's own, in `priv/static/images/paintings/` with their credits.

A recording is the public file the apps play, on the site's own bucket
(`s3.us-east-2.amazonaws.com/lumenviae-images/chants/audio/`), played by
the site's one chant player (`assets/js/chant_session.js`, the app's
`ChantPlayer.shared`) through the root layout's `<audio id="site-chant-audio">`,
which the Chant pages' `ChantPlayer` hook (`assets/js/hooks/chant_player.js`)
drives: a disc plays its chant where it stands, Play all sings a shelf in
order, a sung set's Play all (or its card's disc) sings the set unrolled,
every chant as often as it sounds, and lights the step sounding, a row's
Play from Here sings it from that step, and with Pause Between Chants (a
switch on the set's page, kept nowhere) the next chant waits at its start
for Play next; and a chant's page follows the recording line by line. A
recording that will not play is said only once play was pressed; on a
list, Play all passes over it to the next chant and a quiet line says so.
The site's Content-Security-Policy (`base-uri` and `frame-ancestors`
only) does not limit media, so nothing needed widening.

### The mini player

What a Chant page starts goes on singing as the reader moves about the
site, and stands at the foot of the page as the app's `ChantMiniPlayer`
stands at the foot of the whole app (`ContentView.showsChantPlayer`):
the chant's painting, its Latin name, and where it stands (its English
name and "0:42 of 3:10", or the shelf or set and "3 of 74", or "waiting
for you" with "Next: ..." while a set holds the next chant for Pause
Between Chants), its disc, which plays, pauses or sings the chant waiting,
and close ("Stop and close the player"), with a gold line of progress
along its foot. A click on the names opens the chant's page. It is
`LumenViaeWeb.Components.ChantMiniPlayer`, drawn once in the public root
layout, and `assets/js/chant_mini_player.js`; on a wide screen it keeps a
phone's width, centred at the foot, as the Spiritual Reading player does.
While it shows, the footer keeps room beneath it so the page's last line
scrolls clear.

It stands aside, the chant singing on, where the app keeps it off: a
chant's own page, a Rosary prayed (`/meditation-sets/:id/pray`,
`/mysteries/:category/pray`, with its completion), an order of prayer
prayed along (`/prayers/orders/:id/pray`), a Spiritual Reading chapter, a
Consecration day and the Act. Each of those carries
`data-hides-chant-player` on its outermost element. Another recording
taking the speakers (the Rosary said aloud, a meditation's narration, a
Consecration day's chant) puts the chant away and the mini
player with it, as another flow's claim does in the app.

How it survives navigation: every public page is in one `live_session`
and every link between them navigates live (the header, the footer and
the pages' `<.link navigate>`), which never re-renders the root layout,
so the `<audio>` there keeps sounding and a shelf or set goes on to its
next chant from any page. A full page load ends it: a reload, a link
opened in a new tab, an address typed, the console's pages (another
`live_session`), and a deploy that reloads the page. For those, the chant
in hand, the queue under way, the speed and the place in the recording
are kept in this tab's `sessionStorage` (`lv:chant-player`, gone with the
tab, never sent), and the new page brings the mini player back paused
where it stood: its disc goes on. A browser will not start sound on a
page load without a press, so it never plays by itself there.

Unlike the app: no lock screen or headphone controls, no sleep timer;
Repeat on a chant's page is that page's, and leaving the page leaves the
chant singing without it; and the player hides only on the pages above,
as the website has no tour, Chapel or tab bar.

Not here yet, as the app has them: the score window on a chant's page
that follows the line being sung (the full score is here), the
reader's own sets (Make your own set, the bookmark that keeps a sung set,
Share, which the app offers on the reader's own sets alone), and
everything the phone keeps (the chant last sung, Played lately,
favourites, learning a chant, Take turns and the sleep timer).
## The Consecration

The pages follow the iOS app's `app/Views/Consecration` on main
(`ConsecrationOnboardingView`, `ConsecrationDateSelectionView`,
`ConsecrationScheduledView`, `ConsecrationDayOverviewView`,
`ConsecrationDayFlowView` with `ConsecrationDayIndex`,
`ConsecrationCompletionView`; the Android app's `ui/consecration` reads
them line for line). The words are the domain's
(`LumenViae.Rosary.get_consecration!/1`, from
`priv/library/consecration.json`); how the pages read them (a day's
steps, its badge and line, the phases' tints and the chant each prayer is
sung to) is `LumenViaeWeb.Live.Consecration.Days`, and the date
arithmetic (Day 1 thirty-three days before the feast, only preparations
that can still begin on their Day 1, today's day of a plan) is
`LumenViaeWeb.Live.Consecration.Plan`.

The reader's plan is this browser's alone (below), read by the
`ConsecrationPlan` hook, which hands the page what it holds and the
browser's own date when the page connects, and again at the next local
midnight. Nothing is sent anywhere else and nothing is kept on the
server. Until the hook speaks, `/consecration` stands as a still, unseen
frame of the welcome that can't be pressed (a crawler or a browser
without JavaScript reads it), so a plan under way never flashes the
introduction; if the hook never speaks (the socket blocked), the frame
shows itself after about two seconds. The chooser's Begin, Start at any
day's Begin today, Choose another feast and Restart are presses the hook
answers; Restart from a day's page returns to `/consecration`. Amen keeps
the day as prayed only under a plan and only on that day or after, and
returns to today's day; on Consecration Day, when it is today (or with no
plan), it completes the plan and goes on to `/consecration/act`. Every
day stays open to read, but a day ahead's Amen keeps nothing and returns
to it. A finished plan's chooser says "Consecrated November 2, 2026 —
renew whenever you wish", as the app's does.

| Page | Parameter | Values | Default |
| --- | --- | --- | --- |
| `/consecration` | `step` | `devotion`, `day`, `journey` or `choose` | the welcome, or the chooser for a visitor who has reached it before |
| `/consecration/days/:n` | `step` | the step, counted from `1`: the phase's prayers, then the day's readings | the day's page |
| `/consecration/days/:n` | `lang` | `latin` or `both`, for the prayers, carried from step to step | English |

A `step` past either end is the nearest step, and anything else the first;
a `step` or `lang` that is not one never fails the page.

The paintings are the app's own (each phase's, the Coronation, the
Annunciation), all already on the site. A prayer the Chant Library sings
(Veni Creator, Ave Maris Stella, the Magnificat, the Gloria Patri, the
Litany of Loreto, the Litany of the Holy Name) carries its recording,
the first of its settings in the library's order, played by the
`ChantGuest` hook in a box of its own for the step, so turning the page
stops it (the app's ChantGuest; it is not the site's chant player, and
its playing puts away a chant the Chant Library was singing).

Left out, by Abraham's decision ("leave out journal , prayer record and
how to pray guided rosary"): the reflection written in the app's journal
(`ConsecrationJournalView`). The day's question stays, to sit with; the
introduction's Reflect says only that. Also left out, as the website
does not have them: the chant's sheet music, and the days ahead kept
closed (every day is open on the website). The book behind the
consecration links to True Devotion's pages at `/true-devotion` and
`/true-devotion/formula`, which come with PR #149; until it merges
`/true-devotion` still answers the archive's redirect home.

## Today's Prayer on Home

The home page closes on the iOS app's `TodaysPrayerSection` (Home, after
the mysteries; the Android app's `domain/TodaysPrayer.kt` reads it line
for line): "Today's Prayer" with the visitor's date beside it ("MON 2
NOV"), then a row each for the Consecration to Mary, the hour's order of
prayer, Today's Mass and the Hours of Prayer, each a painting, its name,
a line and its fact in small capitals. The rules are
`LumenViaeWeb.Live.Home.TodaysPrayer`, the drawing
`LumenViaeWeb.Live.Home.TodaysPrayer.Section`; a ruled list on a phone,
two columns from 1024px.

| Row | Says | Opens |
| --- | --- | --- |
| Consecration to Mary | No plan: "Give yourself to Jesus through Mary", BEGIN; from 5 November to 8 December each year the line is instead "The 33 days of preparation for consecration on December 8 begin November 5." (`TodaysPrayer.immaculate_note?/1`). Chosen ahead: BEGINS NOV 21. Under way: the day's title, DAY 15 OF 33 (THE DAY OF CONSECRATION on Day 34, READY TO CONSECRATE past it), the phase's painting, the seal once the day is prayed. Made today: CONSECRATED TODAY with the seal; made earlier, BEGIN again | today's day, `/consecration/days/:n`, under a plan; `/consecration` otherwise |
| The hour's order | Morning Prayers, the Angelus (Queen of Heaven in Eastertide) or Night Prayers by the book's hours, its line as the Prayers page's Now card, and ON WAKING, AT NOON, AT 6 PM or AT BEDTIME | the order's page, `/prayers/orders/:id` |
| Today's Mass | the day's feast, "St. Charles Borromeo", and LESSER FEAST · WHITE after the vestment's silk; until the Mass is known (or when Missale Meum cannot be reached), "Prayers and readings for today" and no fact | `/missal` |
| Hours of Prayer | the hour now, "Mid-Morning Prayer (Terce)", with the lit hour and NOW · UNTIL NOON | `/hours` |

All of it is the visitor's. The Consecration's row reads the plan the
`ConsecrationPlan` hook hands over (the same `lv:consecration:*` keys,
read only; the date arithmetic is `Consecration.Plan`'s), the hours read
the browser's clock (`UserTimezone`), and the date the Act was made is
moved by the browser's offset before it is compared with today. Each row
is an empty frame of its size until its source has spoken, so a crawler
or a browser without JavaScript never sees the hour in UTC or a plan
that is not theirs; while the page is open the rows turn on the hour.

Today's Mass is fetched by the server for the visitor's date once the
clock is known (`LumenViae.Office.fetch_mass/1`, the Missal's cache), as
the Missal's page is. Left out: the hour's order is never marked PRAYED, as the Prayers page's Now card never
is: the website keeps nothing about what was prayed there. The row opens
the order's own page rather than the Prayer Book's front, which the app
opens.

## Hours of Prayer

The pages follow the iOS app's `DivineOfficeView`, `OfficeHourView` and
`OfficeCalendarSheet` on main (the Android app's `ui/office` reads them
line for line). The texts are the Office domain's
(`LumenViae.Office.fetch_day/2`, `fetch_hour/3` and `fetch_calendar/3`),
assembled by the Divinum Officium engine on the server and held in the
Office's cache, the same answers `/api/office` gives the apps; the browser
never calls the engine. Each page shows at once and fetches what it needs
after it connects (`start_async`): the landing's hours need nothing, only
the day's feast travels; an hour or a month that cannot be reached says
so quietly with a Try again, and every hour and day stays a link.

| Page | Parameter | Values | Default |
| --- | --- | --- | --- |
| `/hours/:date/:hour` | `lang` | `latin` or `both` | English |

In Both the Latin leads and the English pairs with it line by line, as
the Office is printed: side by side from 768px, the English beneath each
Latin line in quiet italic on a phone; two sides with different numbers
of lines stand as two blocks. Lines are cleaned as the app cleans them (an
antiphon's "Ant." said as "Antiphon:", the Latin's server marks as the
English's, the cross as ✠), and ℣ ℟ ✠ and the rubric notes are red. The
day's class is said in the app's plain words (Great Feast, Feast, Lesser
Feast, Weekday) from the engine's Latin rank
(`LumenViaeWeb.Live.Hours.DayRank`).

"Today" and the hour now are the visitor's (the `UserTimezone` hook, as
home), the server's until it connects; the hour now is read from fixed
clock times (Matins from midnight, Lauds from five, Prime from seven,
Terce from nine, Sext from noon, Nones from two, Vespers from four,
Compline from seven), as the app reads them.

On the landing the day is named in English with its vestment colour
from the Missal, as iOS names it, once the Missal's answer comes (the
server fetches it; see the Daily Missal, below); until then, or when
Missale Meum cannot be reached, the feast is the Office's own Latin
title. An hour's own page keeps the Latin title.

Left out, as the app has them: the text size and the
"line by line" or "side by side" choice (the width decides); and the
calendar's offline row.

## The Daily Missal

The pages follow the iOS app's `DailyMissalView`, `MissalReaderSectionView`,
`OrdoMissaeView` and `MissalCalendarSheet` on main (the Android app's
`ui/missal` and `domain/MissalText.kt` read them line for line). The texts
are Missale Meum's 1962 Missal (missalemeum.com, MIT), which the apps call
directly. On the website the **server** fetches them, never the
visitor's browser: `LumenViae.Office.fetch_mass/1`,
`fetch_missal_calendar/1` and `fetch_order_of_mass/0`
(`LumenViae.Office.Missal`, through `LumenViae.Office.MissaleMeum`). Each
page shows at once and waits for its text after it connects
(`start_async`); a Mass, a month or the Order of Mass that cannot be
reached says so with a Try again, which asks again only after a failure.

How the server keeps from hammering Missale Meum:

- Every answer is held in the Office's cache for a month (the propers of
  a date never change), per machine.
- A miss is fetched in a task of the Office's own supervisor, owned by no
  page: a visitor who closes the tab never aborts a fetch others share,
  and every caller asking for the same key meanwhile waits for that one
  fetch. The task stores what it read before it answers.
- A fetch follows no redirect, reads at most 2 MB, and has 20 seconds in
  all.
- At most 4 fetches run at once and at most 60 start a minute on a
  machine (`LumenViae.Hammer`); past either the page says Missale Meum
  could not be reached, and nothing is held.
- A Mass more than six weeks from today, or a calendar of a year other
  than this one and those either side, is kept an hour, not a month, so a
  walk through the centuries cannot fill memory.
- Anything but the JSON the Missal reads (down, slow, a non-200, a
  redirect, an HTML block page with a 200, JSON of another shape) is a
  failure, held: that key is not asked for again for five minutes. Only
  Missale Meum itself failing (unreachable, past the deadline, a 5xx)
  closes every key, for a minute.

| Page | Parameter | Values | Default |
| --- | --- | --- | --- |
| `/missal`, `/missal/:date` | `lang` | `latin` or `both` | English |
| `/missal`, `/missal/:date` | `mass` | the Mass of a day with several, from `1` | `1` |
| `/missal/order-of-mass` | `lang` | `latin` or `both` | English |
| `/missal/order-of-mass`, `/missal/calendar/:year/:month` | `day` | the day it was opened from, for the way back | today, `/missal` |
| `/missal/calendar/:year/:month` | `lang` | `latin` or `both`, carried to every day it opens | English |

A day's parts are named plainly ("Entrance Chant", "Prayer over the
Gifts"), with the Latin name beside them small and dim; the day's own
texts carry a gold diamond (the Preface travels with them but is the
Ordinary's), and each part the posture kept through it (Stand, Sit,
Kneel), between two fading rules. A line wholly in asterisks is a
citation, set apart in small engraved capitals; the first of the day's
own texts opens on the gilt versal. In Both the Latin leads and the
English pairs with it line by line, side by side from 768px, as Hours of
Prayer sets it (the lines cleaned the same way: "Ant.", the Latin's "S."
and "M.", the cross as ✠, ℣ ℟ ✠ in red); sides with different numbers of
lines stand as two blocks. A passage with one side only is a rubric of
the Order of Mass, set once in quiet italic, and so are its "– Introit
in today Mass –" placeholders. The day's class is the app's plain words
(`LumenViaeWeb.Live.Hours.DayRank`, from the Missal's number), the
vestment colour a dot in the app's muted swatch, said in words to a
screen reader ("Lesser Feast, white vestments"). The rules are
`LumenViaeWeb.Live.Missal.MissalText` and `Missal.Days`; the parts' rail
and jump list are Hours of Prayer's (`Hours.PartsRail`, the `OfficeRail`
hook).

"Today" is the visitor's (the `UserTimezone` hook): `/missal` waits, as
an empty frame, until the browser's clock is known, and fetches nothing
until then.

### With the Ordinary

The day's page reads the Whole Mass by default, as the app does
(`MissalScope.full`, "With the Ordinary"): the Order of Mass's prayers
let into their places among the day's own texts, after iOS's
`MissalOrderData.readerSections` rule for rule
(`LumenViaeWeb.Live.Missal.Ordinary`). Under the language stand the
app's two other choices from its Text options sheet, in the same pill:
Contents, TODAY'S TEXTS ONLY or WHOLE MASS, and, with the Whole Mass,
SPOKEN or SUNG (the app's Sung Mass switch), with the app's line for it
beneath. Both are this browser's own: the `MissalReading` hook keeps them
in localStorage (`lv:missal-reading`) and hands them back on connect;
nothing is kept on the server or written into the link.

Where the Ordinary stands: At the Foot of the Altar before the Introit
(after the Sprinkling with Holy Water, the Asperges, on a sung Sunday);
Lord, Have Mercy and Glory to God after it; the Creed after the Gospel;
the Offertory's dialogue at the head of the day's Offertory verse; the
Offertory Prayers, the Incensing (sung), the Washing of the Hands, the
Prayer to the Holy Trinity and Pray, Brethren before the Secret; Lift Up
Your Hearts before the day's Preface (the Common Preface where the day
has none) and Holy, Holy, Holy after it; the Eucharistic Prayer, the Our
Father, the Breaking of the Host, the Lamb of God, the Communion prayers
and the Cleansing of the Vessels before the Communion verse; The Mass Is
Ended, the Closing Gospel and the Prayers after Mass (spoken only) after
the Postcommunion. The Gloria falls away in violet, black and rose; the
Creed belongs to Sundays and feasts of the first and second class. Each
part of the Ordinary has its plain name, its Latin name, its posture and
no diamond; only its prayers are woven in, its rubrics stay on the Order
of Mass page. The Order of Mass is fetched once beside the day
(`fetch_order_of_mass/0`, the same cache as its page); the day waits for
it ("Finding the day's Mass…") so the page is not rebuilt under the
reader, and without it the day's own texts stand alone, as in the app.

Left out, as the app has them: the text size, the posture switch
and the first-open "line by line or side by side" question (the width
decides; posture is always shown); the collapsing header and its
progress hair (the page scrolls, and the rail lights the part being
read); the week kept for offline and the calendar's Save the month.
Missale Meum's English descriptions were empty on every day checked, so
About This Day shows only where one is served.

There is no link in the header (its eight links fill it): the Missal is
reached from Today's Prayer on Home, from Explore's Mass & Hours (The
Mass, Daily Missal) and its search (Today's Mass, found by "missal"), as
the app keeps it, by its address and the sitemap.

## True Devotion

The pages follow the iOS app's `TrueDevotionReaderView` and
`TrueDevotionChapterReaderView` on main (Android's `ui/truedevotion` reads
them line for line). The words are the domain's
(`LumenViae.Rosary.get_true_devotion!/1`, from
`priv/library/true_devotion.json`, Faber's translation); how the pages set
them (the contents' order, "Part I", the kicker, the versal, the citation
a shared passage carries) is `LumenViaeWeb.Live.TrueDevotion.Book`, and
the binding is `TrueDevotion.Cover`, drawn in CSS in the `marian` token.
The text is on night, as the app reads it, at the reading size and a
measure of about 62 characters.

A chapter's paragraphs are numbered from 1 within the chapter, its
sub-headings not counted, and each number is the paragraph's anchor
(`/true-devotion/motives#p-3`). The book's data carries no paragraph
numbers, and Faber's paragraphs do not fall where the standard numbers of
the treatise do, so these are the chapter's own count, not "paragraph 23"
as the book is usually cited. The number is a button: it, or a tap on the
paragraph, chooses the paragraph, and the bar that rises offers Bookmark
and Share. Share uses the browser's share sheet (the Web Share API) with
the passage, the citation and the paragraph's link where there is one,
and otherwise copies the link.

Nothing the reader does is sent to the server: the place, the chapters
read and the bookmarks are this browser's (below). The place is the
paragraph at the top of the screen once the reader scrolls; reaching a
chapter's foot, or pressing Next chapter, marks it read and puts the
place at its top, as the app does. Continue Reading resumes the chapter
last read if it is unfinished, else the first unfinished one. A chapter
opened any other way (the contents, the rail, the chapters either side)
also resumes its kept paragraph while it is unfinished, unless the
address names a paragraph (`#p-3`).

There is no link to the book in the header or the footer: the app reaches
it from Explore and from the Consecration, and its Prayers tab has no door
to it. On the site, likewise, it stands on Explore's Spiritual Reading
shelf, Explore's search finds it by name, and the Consecration's pages
open it.

Left out, as the app has them: the summary page (the teaching, the short
prayers, his sayings), archived on iOS; the day's reading goal; a note on
a passage kept in the Journal; the text size (the site's reading size is
fixed here); and the reader's chrome that withdraws as it scrolls.

## Spiritual Reading

The pages follow the iOS app's `app/Views/Library` on main
(`SpiritualReadingView`, `LibraryBookView`, `LibraryContentsView`,
`LibraryChapterReaderView`; Android's `ui/library` reads them line for
line). The catalogue, the five books with their Gutenberg numbers and the
rules that cut each edition, is the domain's
(`LumenViae.Rosary.get_spiritual_reading!/1`, from
`priv/library/spiritual_reading.json`), and so is the text
(`LumenViae.Rosary.read_spiritual_book!/2`): the server fetches each
book's plain text from Project Gutenberg
(`https://www.gutenberg.org/cache/epub/<id>/pg<id>.txt`, the file the apps
fetch), cuts it into chapters with a line-for-line port of the app's
`LibraryBookParser`, and holds it in memory on each machine for a month
(`LumenViae.Rosary.SpiritualReading.Text`), so a book is fetched once per
machine and a visitor's browser never calls Gutenberg. The download is
the server's own (a supervised task with a deadline, which a closed tab
never aborts), and Try again answers only on a page that failed. An
unreachable Gutenberg is remembered for a minute and an edition that
cannot be cut for an hour, so neither is asked again by every visitor; a
block or rate-limit page (anything not plain text of at least 50,000
bytes) counts as unreachable. In production the five books are fetched a
while after boot, so the first visitor after a deploy finds them held. How the pages arrange a book (the runs under their parts, a
row's numeral and title, "III.V", the kicker, the footnote markers) is
`LumenViaeWeb.Live.SpiritualReading.Shelf`, the app's rules.

A book or chapter this machine already holds is drawn whole in the first
response, for a crawler too. One it has not fetched yet shows "Fetching
the text from Project Gutenberg." and fetches after the page connects
(`start_async`). When Gutenberg cannot be reached the page says "Couldn't
reach the library" with Try again; an edition that no longer cuts into
chapters says "This edition can't be opened", with no Try again, as the
app does. The covers are True Devotion's binding (`td-cover`) in each
book's cloth, the app's `bindingColor` (`--color-cloth-*`); the chapter's
head, text, rail and foot are True Devotion's reader (`td-*`).

The place is this browser's (below), read and written by the
`SpiritualReadingPlace` hook: opening a chapter makes it the place, the
paragraph at the top of the screen is kept as the reader scrolls (and
resumed when the chapter is opened again, unless the address names a
paragraph, `#p-3`), and reaching a chapter's foot or pressing the next
chapter marks it read. A place is kept against the edition's cut (the
app's `editionFingerprint`, the page's `data-edition`), so a change to a
book's rules lets go of places kept against the old cut, as the app does.

As on the shelf and True Devotion, there is no link to it in the header
or the footer: the app reaches the shelf from Explore, and so does the
site: Explore's Spiritual Reading shelf (All books, and every book's
cover, with its ribbon) and its search, which finds the shelf by its
words and each book by its title, author or translator (the app's search
finds only the shelf, by words naming the books; the site lists the book
itself too). True Devotion is not on the shelf, as it is not on the
app's; on Explore it stands first, as the app's Explore has it.

### The recording

A book with a LibriVox recording (all but the Imitation, whose only
recording puts ten chapters in a file) is heard on its pages, as the
app's `LibraryListeningSession` and `LibraryPlayerViews` have it. Its
track list is the server's (`LumenViae.Rosary.read_spiritual_recording!/2`):
fetched from LibriVox's API
(`https://librivox.org/api/feed/audiobooks/?id=<id>&extended=1&format=json`,
the apps' address) once the book's text is held, held a month per
machine, and lined up with the chapters by a line-for-line port of the
app's `LibraryTrackMap` (`SpiritualReading.TrackMap`), by the book's
`track_mapping` in the catalogue. Only tracks on the Internet Archive
(`archive.org`) are kept. One fetch per book, in a task no page owns, with
a 15-second deadline, at most two at once and twelve a minute; a failure
is held five minutes for that book, or a minute for every book when
LibriVox itself is failing (`SpiritualReading.Recording`). A list the
server holds is drawn in the first response; one it does not is fetched
after the page connects.

The recording itself streams in the visitor's browser from the Internet
Archive, as in the apps, played by the `BookPlayer` hook
(`assets/js/hooks/book_player.js`) through one `<audio>` the hook's module
holds, so a reading begun on the book's page plays on into a chapter and
between chapters. It stops when no page of that book is on the screen
(each page's `data-book-screen`), when another book is opened, or when the
tab closes; each track runs on into the next by itself.

- **A chapter**: Hear this read under the title (the app's
  `hearThisRead`), where a track reads the chapter: it starts the track,
  or says Pause the reading while it sounds; "· from Book I" where the
  track is not this chapter's alone (several tracks to the chapter, or
  several chapters to the track); the track's length at the right, "18
  MIN LEFT" while it is loaded. While a track that reads exactly this
  whole chapter sounds, the page keeps pace with it (paragraph N of M at
  N/M of the track), standing aside for four seconds after the reader
  scrolls, as the app's reader follows the voice. A chapter no track
  reads (Brother Lawrence's preface) has no Hear this read; a track list
  that cannot be had leaves the chapter without it, as the app's reader.
- **A book's page**: the listen chip on each row a track opens on (not
  every row a track covers), with the track's length; it starts the voice
  and opens the chapter, or pauses the track sounding. "31:05 in" beside
  it where this browser left the voice mid-reading (past 20 seconds).
  A track list that cannot be had says "The recording couldn't be
  reached." with Try again (the `retry_recording` event, answered only
  after a failure). The credit adds "Recording: LibriVox volunteers."
- **Before the page connects** (a slow phone: the page is drawn, its
  script not yet run), Hear this read and the listen chips stand dimmed
  and take no tap, since nothing could answer them; they come alive with
  the connection (CSS on LiveView's `phx-connected`). A connection lost
  later leaves them working, since the voice is the browser's own. The
  app has no such moment.
- **The player** (`LumenViaeWeb.Live.SpiritualReading.Player`): the mini
  player over the foot of the screen (the reading's title, which opens
  the player, back fifteen seconds, play and pause), and the player
  above it: Listening to this chapter, the reading's title, the book and
  its author, the scrubber with the time gone and the time left, the
  previous and next readings, fifteen seconds back and on, the gold play,
  and the speed (0.75× to 2×; the catalogue's `preferred_rate` until the
  reader chooses, Thérèse at 1.5×), with the app's note on LibriVox's
  readers. A recording that will not play says "The recording couldn't be
  reached. Check your connection and try again."

The shelf says "Classic Catholic books to read, or to listen to", and its
credit "Texts from Project Gutenberg. Recordings by LibriVox volunteers.
All in the public domain.", as the app's.

Left out, as the app has them: the sleep timer, the lock screen and the
headphones' controls, Save for offline (the recordings are streamed, never
kept), the cover drawn for the lock screen, and a reading that goes on
after the book's pages are left (the app's goes on while any library
screen is open, and the site's player lives on the book's pages); the
fifteen-second arrows carry their 15 beside the arrow, at the site's
12px floor, where the app sets it small inside. Also left out: the search
inside a book; the daily reading goal; bookmarks (MARK), notes kept in the
Journal (NOTE) and Share on a passage; the text size; Home's reading
shelf; and the reader's chrome that withdraws as it scrolls. The app's
"Once opened, this book reads offline" is left out: the site does not
keep the text in the browser. A footnote marker links to its note at the
chapter's foot (its words in the link's title), where the app raises the
note in a sheet.

## Where each setting lives

Nothing about a visitor is kept on the server. Every setting is the URL or
this browser's `localStorage`, and a browser that refuses storage simply
starts from the defaults. The one thing the server writes is a completion.

| Setting | Where | Written by |
| --- | --- | --- |
| Where you are, form, counting, praying aloud, voice | the link, above | `Pray.Params` |
| Traditional or modern weekly schedule | `lv:schedule` | the `MysterySchedule` hook, on the home page |
| "Your Rosary Today": aloud, count, voice | `lumenviae:rosary-choices` | the `RosaryChoices` hook, on the category page |
| The place in a Rosary, for "Continue where you left off" | `lv:pray:<key>:<form>`, for example `lv:pray:set:26:meditation` or `lv:pray:mysteries:joyful:scriptural`, holding `{mystery, step, count, at}` | the `PrayerMemory` hook |
| Closing prayers (Pope's intentions, Memorare, St. Michael) | `lv:pray:extras` | `PrayerMemory` |
| Language of the prayers, English or Latin | `lv:pray:language` | `PrayerMemory` |
| Text size | `lv:pray:text-size` | the `PrayerSurface` hook |
| Reading page, night (the default, as the app's reader) or vellum | `lv:pray:reading-page` | the `DisplayChoices` hook, read by `PrayerSurface` |
| The mystery's painting shown or hidden | `lv:pray:images` | `DisplayChoices`, read by `PrayerSurface` |
| Days in a row | `lv:pray:streak` | the `PrayerStreak` hook |
| Swipe hint already shown | `lv:pray:swipe-hint-seen` | the `SwipeHint` hook |
| The Consecration's plan: Day 1, the feast it ends on, when it was begun and completed | `lv:consecration:plan`, holding `{start, feast_id, started_at, completed_at}` | the `ConsecrationPlan` hook |
| The Consecration's days prayed | `lv:consecration:done`, a list of day numbers | `ConsecrationPlan`, at a day's Amen |
| The Consecration's introduction already walked | `lv:consecration:intro-seen` | `ConsecrationPlan`, on reaching the chooser |
| True Devotion: the place, for Continue Reading | `lv:true-devotion:place`, holding `{chapter, paragraph, at}` (the paragraph's number in the chapter, 0 for its top) | the `TrueDevotionPlace` hook |
| True Devotion: the chapters read | `lv:true-devotion:read`, a list of chapter ids | `TrueDevotionPlace` |
| True Devotion: bookmarks | `lv:true-devotion:marks`, a list of `{chapter, paragraph, words, at}` (the paragraph's first 90 characters, for the contents), at most 200 | `TrueDevotionPlace` |
| Spiritual Reading: the place in a book and the chapters read | `lv:spiritual-reading:<book id>`, holding `{edition, chapter, paragraph, read, at}` (the chapter's index from 0, the paragraph from 1 or 0 for the top, `read` a list of chapter indexes) | the `SpiritualReadingPlace` hook |
| Spiritual Reading: where the voice stopped in a book's recording | `lv:spiritual-reading-listening:<book id>`, holding `{track, seconds, at}` (the LibriVox track's id) | the `BookPlayer` hook |
| Spiritual Reading: the speed chosen for a book's recording | `lv:spiritual-reading-rate:<book id>` | `BookPlayer` |

Details worth knowing:

- The beginning of a Rosary is never saved as a place, so arriving fresh
  does not wipe out the place to offer. A place older than a week is not
  offered. Completing the Rosary clears it.
- Only the prayers change language. Mysteries, Scripture and meditations
  stay in English.
- The hooks live in `assets/js/hooks/`, and each file opens with a comment
  saying what it keeps and why.

## The app page

`/app` describes the iPhone app as it is now, in the app's own names
(Your Rosary Today, the Audio Rosary, Hours of Prayer, Today's Mass,
the Chant Library, the Chapel). Describe nothing the app does not do, and
no ratings, reviews or download counts.

- Every screen is a real screenshot from the iOS Simulator (iPhone 17 Pro,
  the Marian Blue theme, status bar set to
  9:41 and full), in `priv/static/images/app/`: `<name>-390.webp`,
  `<name>-780.webp` (cwebp at quality 85) and a 390 pixel `<name>.jpg`.
  The originals stay out of the repository.
- `LumenViaeWeb.Live.Home.App.PhoneScreen` draws each one in a CSS phone
  (`.phone-frame` in `app.css`), with `width` and `height` and alt text
  saying what the screen shows.
- `og-app.jpg` (1200x630) is three of the screenshots composed for link
  previews.
- The download button is the site's gilt button worded like Apple's badge,
  not the badge itself, which is licensed artwork. Every download link is
  the App Store listing, and `test/lumen_viae_web/live/home/app_test.exs`
  and the smoke test check it.
- When the app changes a screen the page shows, retake that screenshot.

## Completions

A completion is recorded only when the reader presses Complete on a set's
prayer page. Reaching the last bead records nothing.

A Rosary prayed without a set (`/mysteries/:category/pray`) records no
completion, because a completion belongs to a meditation set. The days in a
row still count, in the browser. See `docs/UPCOMING_FEATURES.md`.

## Meta tags and images

- Every public page carries Apple's Smart App Banner
  (`<meta name="apple-itunes-app" content="app-id=6760320749">`, in the root
  layout): Safari on an iPhone or iPad offers Open or Get above the page. The
  console's layout leaves it out.
- A public page calls `LumenViaeWeb.PageMeta.put/3` from `mount/3`. The root
  layout turns the result into the description, canonical link, link
  previews and structured data, in the first server-rendered response.
- A mystery's picture is the app's own old-master painting: the hero's
  arch, the category tiles, the small arches beside each mystery, the head
  of a category page, the decade on the prayer page and the categories on
  `/mysteries`. They are the files the iOS app bundles, served from
  `priv/static/images/paintings/` with their credits in its
  `manifest.json` (see docs/MYSTERY_PAINTINGS.md), and drawn with
  `LumenViaeWeb.Components.MysteryPainting`. The Prayer Book's paintings
  (its topics, scenes and orders) are the app's too, from the same folder. A painting uploaded on a
  mystery or a card in the console wins over the static one.
- Link previews show the same paintings, from each one's
  `<name>-preview.jpg` (a JPEG, at most 800 pixels wide), because not every
  preview crawler reads WebP.
- The woodcuts in `priv/static/images/woodcuts/` and
  `LumenViaeWeb.Components.WoodcutPlate` are no longer shown anywhere; they
  are kept until someone decides to remove them.
- Images ship as WebP with a JPEG or PNG fallback: `name-480.webp` and
  `name-960.webp` beside a 480 pixel `name.jpg` for the paintings, and `-320`, `-512` and similar widths for the other
  images. An uploaded painting (of a set, an author, a mystery or a
  category card) is shown from its WebP variants by
  `LumenViaeWeb.Components.ArtworkPicture`. The widths that exist for it are
  recorded in its `image_variant_widths` column, never guessed from the
  size of the original.

## How the pages look

The site is drawn the way the iOS app draws its Candlelit theme: Cinzel
for every heading, label and button, EB Garamond for reading, gold on a
near-black gradient, ruled ledgers instead of cards, painted tiles for
pictures, one gold pill per screen and quiet gold type for every other
action. When a page changes, check it beside the app's own screen. The
tokens and the shared vocabulary are in the "Design tokens" section of
`docs/ARCHITECTURE.md`.

## Rules for editing a public page

- Go through `LumenViae.Rosary` and pass the actor
  (`actor: socket.assigns.current_admin`). See `docs/ARCHITECTURE.md`.
- The root layout owns the page's only `<main id="main-content">`. A page
  template never renders another.
- A page that wants the whole screen, as the prayer page does, carries
  `data-layout="focused"`. The header, footer and skip link then step aside.
- A page with a transport of its own or a prayer under way carries
  `data-hides-chant-player`, as the app's `showsChantPlayer` lists it; the
  chant mini player then stands aside. Any other recording a page plays
  goes through an `<audio>` in the page, so it puts the chant away (or,
  like the spoken Rosary's detached `Audio`, calls `relinquish` itself).
- Use the design tokens, never raw hex. The "Design tokens" section of
  `docs/ARCHITECTURE.md` is the list.
- No emojis anywhere.
- Keep to the accessibility baseline in `docs/audits/`: labels at least 12
  px, targets at least 44 px, a heading order with no gaps, and a live
  region for anything that changes under the reader.
- If you change a route, a redirect or a page's heading, update the e2e
  test.

## Checking a public page in a browser

The smoke test in `scripts/e2e/` drives the real site in Chrome at a phone
width (390 px) and a desktop width (1280 px). It loads `/`, `/mysteries`,
`/mysteries/joyful`, `/mysteries/seven_sorrows`, `/privacy-policy`,
`/app`, the Prayers pages and the Chant pages, and checks each one answers 200, has an
`h1`, logs no console errors and does not scroll sideways. It follows the
first Pray link on `/mysteries/joyful` and presses ArrowRight, checks every
App Store link and screenshot on `/app`, searches the Prayer Book and
chooses Both on a prayer, searches the Chant Library, presses play on a
chant's page and waits for a line to light, opens Sets of Chants and a sung
set and presses its Play all, begins a Consecration from the chooser and
from Start at any day, steps through a day and says its Amen, checks
that Consecration Day's Amen on Day 1 keeps nothing, opens the
Act's page and a day that is not one, and checks that the five archived paths redirect
to `/`. It saves a screenshot of each page in `scripts/e2e/out/`, which is
`/app`, the Prayers pages, Hours of Prayer, the Daily Missal, True Devotion and Explore, and checks each one answers 200, has an
`h1`, logs no console errors and does not scroll sideways. It follows the
first Pray link on `/mysteries/joyful` and presses ArrowRight, checks every
App Store link and screenshot on `/app`, searches the Prayer Book and
chooses Both on a prayer, opens an hour of the Office in Both, opens
today's Mass (its text, or the line saying Missale Meum could not be
reached), chooses Both, steps a day and opens the Order of Mass and the
month, reads True
Devotion (Begin reading, Next chapter, a bookmark, then Continue reading
on the title page), checks Explore's Daily Missal tile, its reading shelf (six covers, All
books, the ribbon on a book a test place is kept for), searches it
("kempis", "Salve", "ave maria", "PÂTER", "annunciation"), and checks that the four archived paths that still

on the title page), opens the Spiritual Reading shelf and a book (its text
from Gutenberg or the "couldn't reach" state, either passing and the log
saying which; with the text, Begin reading, the next chapter and Continue,
then the recording: the book's listen chips and the LibriVox credit, or
"The recording couldn't be reached", either passing; with the chips, a
chapter's Hear this read bringing up the player and opening it, without
requiring real playback),
and checks that the four archived paths that still
redirect go to `/` while `/true-devotion` answers 200. It saves a screenshot of each page in `scripts/e2e/out/`, which is
gitignored.

It is not part of CI. Run it before you hand in a change to a public page.

Use a copy of the dev database and a port of your own, never 8080:

```bash
createdb -h localhost -U postgres -T lumen_viae_dev lv_e2e
DEV_DATABASE=lv_e2e PORT=8096 ./dev.sh mix ecto.migrate
DEV_DATABASE=lv_e2e PORT=8096 ./dev.sh
```

Then, from another terminal:

```bash
BASE_URL=http://localhost:8096 scripts/e2e/run.sh
```

The exit code is 0 when every check passes, 1 when any fails, 2 when the
script itself breaks. It needs Node and `npx` (with a network the first
time), Google Chrome, and a seeded database with at least one visible
Joyful set. When you are done, stop the server and drop the copy:

```bash
dropdb -h localhost -U postgres lv_e2e
```

`scripts/e2e/README.md` has the rest. The unit tests are separate:
`MIX_TEST_PARTITION=<name> mix test`, with a partition of your own in a
worktree.

## See also

- `docs/ARCHITECTURE.md`: where code goes, the prayer page's modules, the
  design tokens.
- `docs/SPOKEN_ROSARY.md`: the Rosary's words and the recorded clips the
  prayer page speaks.
- `docs/COMPLETION_ANALYTICS.md`: what a completion records.
- `docs/audits/`: the accessibility baseline and re-audit.
- `archive/README.md`: the retired pages.
