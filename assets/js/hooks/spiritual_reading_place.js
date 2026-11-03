// What this browser keeps of the Spiritual Reading shelf, in localStorage
// only, as the app keeps a BookReadingProgress row per book on the phone
// (LibraryProgressStore). Nothing here is sent anywhere; the pages are
// whole without it.
//
//   lv:spiritual-reading:<book id>  {edition, chapter, paragraph, read, at}
//
//   edition    the cut of the book the place was kept against (the page's
//              data-edition, the app's editionFingerprint): a place kept
//              against another cut is let go, as the app lets it go
//   chapter    the chapter last opened, its index in the book from 0
//   paragraph  the paragraph at the top of the screen, from 1 (0 for the
//              chapter's top)
//   read       the chapters read to the end, by index
//
// On the shelf (data-page="shelf") it hangs the marker ribbon on every book
// with a place. On a book's page (data-page="book") it turns Begin reading
// into "Continue · III.V", lights the chapter being read and dims the ones
// read, lights its part's numeral on the edge, and folds the chapters more
// than two before it into "N earlier chapters", Show. On a chapter
// (data-page="chapter") it makes the chapter the place, resumes its kept
// paragraph, keeps the place as the reader scrolls, and marks the chapter
// read at its foot or on stepping on.

const PREFIX = "lv:spiritual-reading:"
// How many chapters before the one being read the list still shows
// (LibraryBookPlace.leadIn).
const LEAD_IN = 2

const storage = {
  get(key) {
    try {
      return JSON.parse(window.localStorage.getItem(key))
    } catch (_blockedOrUnreadable) {
      return null
    }
  },
  set(key, value) {
    try {
      window.localStorage.setItem(key, JSON.stringify(value))
    } catch (_blocked) {
      // Private windows and blocked storage remember nothing.
    }
  }
}

// The book's place, read back only in the shape it was written in.
function readKept(book) {
  const kept = storage.get(PREFIX + book)
  if (
    kept &&
    typeof kept.edition === "string" &&
    Number.isInteger(kept.chapter) &&
    kept.chapter >= 0 &&
    Number.isInteger(kept.paragraph) &&
    kept.paragraph >= 0
  ) {
    const read = Array.isArray(kept.read) ? kept.read.filter((n) => Number.isInteger(n)) : []
    return { ...kept, read }
  }
  return null
}

// The place, if it was kept against this cut of the book.
function currentKept(book, edition) {
  const kept = readKept(book)
  return kept && edition && kept.edition === edition ? kept : null
}

function writeKept(book, edition, changes) {
  const kept = currentKept(book, edition) || { chapter: 0, paragraph: 0, read: [] }
  storage.set(PREFIX + book, { ...kept, ...changes, edition, at: Date.now() })
}

export default {
  mounted() {
    this.apply()
  },

  // The book's text can arrive after the page is shown (fetched once it
  // connects), so the hook looks again whenever the page changes.
  updated() {
    this.apply()
  },

  destroyed() {
    if (this.onScroll) window.removeEventListener("scroll", this.onScroll)
    if (this.observer) this.observer.disconnect()
    if (this.frame) cancelAnimationFrame(this.frame)
    if (this.resumeFrame) cancelAnimationFrame(this.resumeFrame)
  },

  apply() {
    const page = this.el.dataset.page
    if (page === "shelf") this.drawShelf()
    else if (page === "book") this.drawBook()
    else if (page === "chapter") this.mountChapter()
  },

  // --- The shelf ------------------------------------------------------------

  drawShelf() {
    for (const ribbon of this.el.querySelectorAll("[data-role=ribbon]")) {
      ribbon.hidden = !readKept(ribbon.dataset.book)
    }
  },

  // --- A book's page --------------------------------------------------------

  drawBook() {
    const contents = this.el.querySelector("[data-role=contents]")
    if (!contents || contents.dataset.drawn) return
    contents.dataset.drawn = ""

    const book = this.el.dataset.book
    const kept = currentKept(book, this.el.dataset.edition)
    if (!kept) return

    const rows = Array.from(contents.querySelectorAll("[data-role=chapter-row]"))
    for (const row of rows) {
      if (kept.read.includes(Number(row.dataset.chapter))) row.dataset.read = ""
    }

    const current = rows.find((row) => Number(row.dataset.chapter) === kept.chapter)
    if (!current) return

    current.dataset.current = ""
    current.setAttribute("aria-current", "true")

    const ribbon = this.el.querySelector("[data-role=ribbon]")
    if (ribbon) ribbon.hidden = false

    // The one gold act: "Continue · III.V", said in full to the ear.
    const act = this.el.querySelector("[data-role=read-act]")
    if (act) {
      act.setAttribute("href", current.getAttribute("href"))
      act.querySelector("[data-role=act-label]").textContent = `Continue · ${current.dataset.short}`
      act.setAttribute("aria-label", `Continue reading, ${current.dataset.spoken}`)
    }

    // The part being read is lit on the edge.
    const run = current.closest("[data-role=run]")
    if (run && run.id) {
      const numeral = contents.querySelector(`[data-role=part-index] [href="#${run.id}"]`)
      if (numeral) numeral.dataset.reading = ""
    }

    this.fold(contents, rows.indexOf(current))
  },

  // The list opens a little before the reader's place, the chapters before
  // it folded into one line that opens them where they stand
  // (LibraryBookPlace.firstShown).
  fold(contents, position) {
    const start = position - LEAD_IN
    if (start <= 0) return

    const items = Array.from(contents.querySelectorAll("[data-role=row-item]"))
    const hidden = items.slice(0, start)
    for (const item of hidden) item.hidden = true
    const runs = Array.from(contents.querySelectorAll("[data-role=run]"))
    const emptied = runs.filter((run) => Array.from(run.querySelectorAll("[data-role=row-item]")).every((i) => i.hidden))
    for (const run of emptied) run.hidden = true

    const button = contents.querySelector("[data-role=earlier]")
    button.querySelector("[data-role=earlier-count]").textContent =
      start === 1 ? "1 earlier chapter" : `${start} earlier chapters`
    button.setAttribute("aria-label", start === 1 ? "Show the earlier chapter" : `Show the ${start} earlier chapters`)
    button.hidden = false

    const unfold = () => {
      for (const item of hidden) item.hidden = false
      for (const run of emptied) run.hidden = false
      button.hidden = true
    }
    button.addEventListener("click", unfold, { once: true })
    // A part's numeral goes to the part's first chapter, so it opens the
    // folded chapters first.
    for (const numeral of contents.querySelectorAll("[data-role=part-index] a")) {
      numeral.addEventListener("click", unfold, { once: true })
    }
  },

  // --- A chapter ------------------------------------------------------------

  mountChapter() {
    const text = this.el.querySelector("[data-role=chapter-text]")
    if (!text || this.reading) return
    this.reading = true

    this.book = this.el.dataset.book
    this.edition = this.el.dataset.edition
    this.chapter = Number(this.el.dataset.chapter)
    this.paragraphs = Array.from(text.querySelectorAll("[data-p]"))
    this.scrolled = false

    const kept = currentKept(this.book, this.edition)
    const resume = this.resumeParagraph(kept)

    // Opening a chapter makes it the place, at the paragraph it resumes.
    writeKept(this.book, this.edition, {
      chapter: this.chapter,
      paragraph: resume ? Number(resume.dataset.p) : 0
    })
    this.lightContents()

    this.onScroll = () => {
      this.scrolled = true
      if (this.frame) return
      this.frame = requestAnimationFrame(() => {
        this.frame = null
        this.keepPlace()
      })
    }

    // LiveView puts a navigated page at its top on the next frame, so the
    // resume waits a frame past that, and keeps the place only after its
    // own scroll has passed.
    if (resume) {
      this.resumeFrame = requestAnimationFrame(() => {
        this.resumeFrame = requestAnimationFrame(() => {
          resume.scrollIntoView({ block: "start" })
          this.resumeFrame = requestAnimationFrame(() => {
            this.resumeFrame = null
            window.addEventListener("scroll", this.onScroll, { passive: true })
          })
        })
      })
    } else {
      window.addEventListener("scroll", this.onScroll, { passive: true })
    }

    // Reaching the foot marks the chapter read, once the reader has moved,
    // or at once when the whole chapter fits on the screen.
    const end = this.el.querySelector("[data-role=chapter-end]")
    if (end && "IntersectionObserver" in window) {
      this.observer = new IntersectionObserver((entries) => {
        const fits = document.documentElement.scrollHeight <= window.innerHeight + 4
        if (entries.some((e) => e.isIntersecting) && (this.scrolled || fits)) this.markRead()
      })
      this.observer.observe(end)
    }

    // Stepping on is how a reader says they finished this one.
    const next = this.el.querySelector("[data-role=next-chapter]")
    if (next) next.addEventListener("click", () => this.markRead())
  },

  // The kept paragraph of this chapter, when the address names none.
  resumeParagraph(kept) {
    if (window.location.hash) return null
    if (!kept || kept.chapter !== this.chapter || kept.paragraph === 0) return null
    return this.el.querySelector(`[data-p="${kept.paragraph}"]`)
  },

  // The paragraph whose top has risen past the band under the top of the
  // screen; 0 above the first.
  keepPlace() {
    const band = window.innerHeight * 0.25
    let paragraph = 0
    for (const p of this.paragraphs) {
      if (p.getBoundingClientRect().top <= band) paragraph = Number(p.dataset.p)
      else break
    }
    writeKept(this.book, this.edition, { chapter: this.chapter, paragraph })
  },

  // Additive: nothing is ever un-read.
  markRead() {
    const kept = currentKept(this.book, this.edition)
    const read = kept ? kept.read : []
    if (!read.includes(this.chapter)) {
      writeKept(this.book, this.edition, { read: [...read, this.chapter] })
    }
    this.lightContents()
  },

  lightContents() {
    const kept = currentKept(this.book, this.edition)
    if (!kept) return
    for (const link of this.el.querySelectorAll(".td-contents [data-chapter]")) {
      if (kept.read.includes(Number(link.dataset.chapter))) link.dataset.read = ""
    }
  }
}
