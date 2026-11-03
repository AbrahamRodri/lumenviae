// What this browser keeps of True Devotion, in localStorage only, as the
// app keeps it on the phone (TrueDevotionReaderViewModel). Nothing here is
// sent anywhere; the pages are whole without it.
//
//   lv:true-devotion:place  {chapter, paragraph, at}: the chapter last read
//                           and the paragraph at the top of the screen (its
//                           number in the chapter, 0 for the top)
//   lv:true-devotion:read   [chapter id, ...]: the chapters read to the end
//   lv:true-devotion:marks  [{chapter, paragraph, words, at}, ...]: the
//                           reader's bookmarks, with their opening words
//
// On the title page (data-page="book") it turns Begin Reading into
// Continue Reading where the reader left off, rings the ribbon on the
// cover, marks the rows read and bookmarked, puts the "where you are" dot
// on the chapter last opened while it is unfinished, and opens its part.
// On a chapter (data-page="chapter") it resumes the kept paragraph
// however the chapter was opened, keeps the place once the reader
// scrolls, marks the chapter read at its foot or on stepping on, and
// gives a paragraph Bookmark and Share.

const PLACE_KEY = "lv:true-devotion:place"
const READ_KEY = "lv:true-devotion:read"
const MARKS_KEY = "lv:true-devotion:marks"
const MAX_MARKS = 200
const WORDS = 90

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

// Each value is read back only in the shape it was written in.
function readPlace() {
  const place = storage.get(PLACE_KEY)
  if (place && typeof place.chapter === "string" && Number.isInteger(place.paragraph) && place.paragraph >= 0) {
    return place
  }
  return null
}

function readRead() {
  const read = storage.get(READ_KEY)
  return Array.isArray(read) ? read.filter((id) => typeof id === "string") : []
}

function readMarks() {
  const marks = storage.get(MARKS_KEY)
  if (!Array.isArray(marks)) return []
  return marks.filter(
    (m) => m && typeof m.chapter === "string" && Number.isInteger(m.paragraph) && m.paragraph > 0
  )
}

function chapterHref(chapter, paragraph) {
  const path = `/true-devotion/${encodeURIComponent(chapter)}`
  return paragraph > 0 ? `${path}#p-${paragraph}` : path
}

function excerpt(text) {
  const words = text.replace(/\s+/g, " ").trim()
  return words.length > WORDS ? `${words.slice(0, WORDS).trimEnd()}…` : words
}

export default {
  mounted() {
    if (this.el.dataset.page === "chapter") this.mountChapter()
    else this.mountBook()
  },

  destroyed() {
    if (this.onScroll) window.removeEventListener("scroll", this.onScroll)
    if (this.onKey) document.removeEventListener("keydown", this.onKey)
    if (this.observer) this.observer.disconnect()
    if (this.frame) cancelAnimationFrame(this.frame)
    if (this.resumeFrame) cancelAnimationFrame(this.resumeFrame)
    clearTimeout(this.toastTimer)
  },

  // --- The title page -----------------------------------------------------

  mountBook() {
    const rows = Array.from(this.el.querySelectorAll("[data-role=chapter-row]"))
    const place = readPlace()
    const read = readRead()
    const marks = readMarks()
    const started = Boolean(place) || read.length > 0

    for (const row of rows) {
      if (read.includes(row.dataset.chapter)) row.dataset.read = ""
      const count = marks.filter((m) => m.chapter === row.dataset.chapter).length
      if (count > 0) {
        row.querySelector("[data-role=row-marks-count]").textContent = String(count)
        row.querySelector("[data-role=row-marks]").hidden = false
      }
    }

    if (!started) return

    // The app's continueChapter: the chapter last opened if it is
    // unfinished, otherwise the first unfinished one.
    let row = place && !read.includes(place.chapter) && rows.find((r) => r.dataset.chapter === place.chapter)
    if (!row) row = rows.find((r) => !read.includes(r.dataset.chapter))
    // The whole book read: it opens again on its first chapter.
    if (!row) row = rows[0]
    const ribbon = this.el.querySelector("[data-role=ribbon]")
    if (ribbon) ribbon.hidden = false

    const act = this.el.querySelector("[data-role=read-act]")
    if (!row || !act) return

    const paragraph = place && place.chapter === row.dataset.chapter ? place.paragraph : 0
    const total = Number(row.dataset.paragraphs) || 1
    act.setAttribute("href", chapterHref(row.dataset.chapter, paragraph))
    act.querySelector("[data-role=act-kicker]").textContent = "Continue reading"
    act.querySelector("[data-role=act-destination]").textContent = row.dataset.title
    act.querySelector("[data-role=act-fill]").style.width = `${Math.min(paragraph / total, 1) * 100}%`
    act.querySelector("[data-role=act-meta]").hidden = true
    act.setAttribute("aria-label", `Continue reading: ${row.dataset.title}`)

    // As the app's chapter rows and seedExpansion: the dot stays on the
    // chapter last opened while it is unfinished, and its part stands open
    // (the first part when it is the Introduction). A closed part holding
    // it shows the dot on its header.
    const last = place && rows.find((r) => r.dataset.chapter === place.chapter)
    if (!last) return
    if (!read.includes(last.dataset.chapter)) last.dataset.current = ""
    const part = last.closest("details[data-part]")
    if (part) {
      part.dataset.holdsCurrent = ""
      for (const other of this.el.querySelectorAll("details[data-part]")) other.open = other === part
    }
  },

  // --- A chapter ------------------------------------------------------------

  mountChapter() {
    this.chapter = this.el.dataset.chapter
    this.paragraphs = Array.from(this.el.querySelectorAll("[data-p]"))
    this.bar = this.el.querySelector("[data-role=passage-bar]")
    this.toast = this.el.querySelector("[data-role=toast]")
    this.selected = null
    this.scrolled = false

    this.lightContents()
    this.drawMarks()

    this.onScroll = () => {
      this.scrolled = true
      if (this.frame) return
      this.frame = requestAnimationFrame(() => {
        this.frame = null
        this.keepPlace()
      })
    }

    // As the app's resumeParagraph: opened from the contents, the rail or
    // the chapters either side (no #p-N in the address), the chapter
    // resumes its kept paragraph. LiveView puts a navigated page at its top
    // on the next frame, so this waits a frame past that, and keeps the
    // place only after its own scroll has passed, so it never writes the
    // chapter's top over the paragraph it resumed.
    const resume = this.resumeParagraph()
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

    this.el.addEventListener("click", (event) => this.onClick(event))
    this.onKey = (event) => {
      if (event.key === "Escape" && this.selected !== null) this.select(null)
    }
    document.addEventListener("keydown", this.onKey)
  },

  // The kept paragraph of this chapter, when the address names none and
  // the chapter is unfinished; else null.
  resumeParagraph() {
    if (window.location.hash) return null
    const place = readPlace()
    if (!place || place.chapter !== this.chapter || place.paragraph === 0) return null
    if (readRead().includes(this.chapter)) return null
    return this.paragraph(place.paragraph)
  },

  // The paragraph whose top has risen past the band under the top of the
  // screen; 0 above the first.
  keepPlace() {
    const read = readRead()
    if (read.includes(this.chapter)) return

    const band = window.innerHeight * 0.25
    let paragraph = 0
    for (const p of this.paragraphs) {
      if (p.getBoundingClientRect().top <= band) paragraph = Number(p.dataset.p)
      else break
    }
    storage.set(PLACE_KEY, { chapter: this.chapter, paragraph, at: Date.now() })
  },

  markRead() {
    const read = readRead()
    if (!read.includes(this.chapter)) {
      read.push(this.chapter)
      storage.set(READ_KEY, read)
    }
    // As the app's completeChapter: the place stays on the chapter, at its top.
    storage.set(PLACE_KEY, { chapter: this.chapter, paragraph: 0, at: Date.now() })
    this.lightContents()
  },

  lightContents() {
    const read = readRead()
    for (const link of this.el.querySelectorAll(".td-contents [data-chapter]")) {
      if (read.includes(link.dataset.chapter)) link.dataset.read = ""
    }
  },

  // --- Choosing a passage ---------------------------------------------------

  onClick(event) {
    const act = event.target.closest("[data-act]")
    if (act && this.bar.contains(act)) {
      if (act.dataset.act === "mark") this.toggleMark()
      else if (act.dataset.act === "share") this.share()
      else this.select(null)
      return
    }

    const number = event.target.closest("[data-select]")
    if (number) {
      const n = Number(number.dataset.select)
      this.select(this.selected === n ? null : n)
      return
    }

    const paragraph = event.target.closest("[data-p]")
    if (!paragraph || event.target.closest("a")) return
    // A reader selecting words to copy has not asked for the bar.
    const selection = window.getSelection && window.getSelection()
    if (selection && !selection.isCollapsed) return
    const n = Number(paragraph.dataset.p)
    this.select(this.selected === n ? null : n)
  },

  select(n) {
    if (this.selected !== null) {
      const before = this.paragraph(this.selected)
      if (before) delete before.dataset.selected
    }
    this.selected = n
    const now = n === null ? null : this.paragraph(n)
    if (now) now.dataset.selected = ""
    this.bar.hidden = !now
    if (now) this.labelBar()
  },

  paragraph(n) {
    return this.el.querySelector(`[data-p="${n}"]`)
  },

  words(n) {
    const p = this.paragraph(n)
    if (!p) return ""
    const button = p.querySelector("[data-select]")
    const text = Array.from(p.childNodes)
      .filter((node) => node !== button)
      .map((node) => node.textContent)
      .join("")
    return text
  },

  labelBar() {
    const marked = readMarks().some((m) => m.chapter === this.chapter && m.paragraph === this.selected)
    const mark = this.bar.querySelector("[data-act=mark]")
    // The app's passage bar: BOOKMARK, or REMOVE on a kept one.
    mark.textContent = marked ? "Remove" : "Bookmark"
    mark.setAttribute("aria-label", marked ? "Remove bookmark" : "Bookmark")
    mark.setAttribute("aria-pressed", marked ? "true" : "false")
  },

  toggleMark() {
    const n = this.selected
    if (n === null) return
    let marks = readMarks()
    const marked = marks.some((m) => m.chapter === this.chapter && m.paragraph === n)
    if (marked) {
      marks = marks.filter((m) => !(m.chapter === this.chapter && m.paragraph === n))
    } else {
      marks.push({ chapter: this.chapter, paragraph: n, words: excerpt(this.words(n)), at: Date.now() })
      marks = marks.slice(-MAX_MARKS)
    }
    storage.set(MARKS_KEY, marks)
    this.say(marked ? "Bookmark removed" : "Bookmarked")
    this.select(null)
    this.drawMarks()
  },

  async share() {
    const n = this.selected
    if (n === null) return
    const url = new URL(chapterHref(this.chapter, n), window.location.origin).toString()
    const words = this.words(n).replace(/\s+/g, " ").trim()

    if (navigator.share) {
      try {
        await navigator.share({
          title: this.el.dataset.title,
          text: `“${words}”\n${this.el.dataset.citation}`,
          url
        })
        this.select(null)
      } catch (_cancelled) {
        // The reader closed the share sheet.
      }
      return
    }

    try {
      await navigator.clipboard.writeText(url)
      this.say("Link copied")
    } catch (_refused) {
      window.history.replaceState(window.history.state, "", `#p-${n}`)
      this.say("The link is in the address bar")
    }
    this.select(null)
  },

  say(words) {
    this.toast.textContent = words
    this.toast.dataset.shown = ""
    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => {
      delete this.toast.dataset.shown
      this.toast.textContent = ""
    }, 2200)
  },

  // The ribbons in the margin, and the bookmarks at the head of the
  // contents, each as the app's LibraryMarkSheetRow: the chapter's title,
  // the passage's opening words under it, the ribbon. A "Chapters" label
  // ends them, where the contents open on the Introduction.
  drawMarks() {
    const marks = readMarks()
    for (const p of this.paragraphs) {
      const marked = marks.some((m) => m.chapter === this.chapter && m.paragraph === Number(p.dataset.p))
      if (marked) p.dataset.marked = ""
      else delete p.dataset.marked
    }

    for (const box of this.el.querySelectorAll("[data-role=marks]")) {
      box.replaceChildren()
      box.hidden = marks.length === 0
      if (marks.length === 0) continue

      const label = document.createElement("p")
      label.className = "td-contents__part"
      label.textContent = `Your bookmarks · ${marks.length}`
      const list = document.createElement("ul")
      for (const mark of marks) {
        const item = document.createElement("li")
        const link = document.createElement("a")
        link.className = "td-mark"
        link.href = chapterHref(mark.chapter, mark.paragraph)
        const text = document.createElement("span")
        text.className = "td-mark__text"
        const title = document.createElement("span")
        title.className = "td-mark__chapter"
        const row = this.el.querySelector(`.td-contents [data-chapter="${CSS.escape(mark.chapter)}"]`)
        const rowTitle = row && row.querySelector("[data-role=row-title]")
        title.textContent = rowTitle ? rowTitle.textContent.trim() : mark.chapter
        const words = document.createElement("span")
        words.className = "td-mark__words"
        words.textContent = typeof mark.words === "string" && mark.words ? mark.words : `Paragraph ${mark.paragraph}`
        text.append(title, words)
        const ribbon = document.createElement("span")
        ribbon.className = "td-ribbon"
        ribbon.setAttribute("aria-hidden", "true")
        link.append(text, ribbon)
        link.addEventListener("click", () => {
          const details = link.closest("details")
          if (details) details.open = false
        })
        item.append(link)
        list.append(item)
      }
      const chapters = document.createElement("p")
      chapters.className = "td-contents__part"
      chapters.textContent = "Chapters"
      box.append(label, list, chapters)
    }
  }
}
