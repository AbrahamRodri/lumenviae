// BookPlayer: a Spiritual Reading book's LibriVox recording, heard on the
// book's pages as the app's LibraryListeningSession plays it.
//
// The recording streams from the Internet Archive in this browser (the
// track list, with each track's address, is the page's data-tracks, which
// the server fetched from LibriVox). One <audio>, held by this module, not
// by a page, so a reading begun on the book's page keeps playing into a
// chapter and between chapters; it stops when no page of that book is on
// the screen any more ([data-book-screen]), when another book's reading is
// begun, or when the tab closes. Each track runs on to the next by itself.
//
// What it keeps, in localStorage only (nothing is sent anywhere):
//
//   lv:spiritual-reading-listening:<book id>  {track, seconds, at}
//     where the voice stopped (the track's id and the seconds into it),
//     resumed when that track is played again and shown as "31:05 in" on
//     its chip, as the app keeps lastTrackID and lastTrackSeconds
//   lv:spiritual-reading-rate:<book id>  the speed chosen for this book,
//     which outranks the catalogue's (data-rate), as the app's readingRate
//
// Two pages (data-page):
//
// - "book": each row's listen chip ([data-act=listen]) starts its track
//   and opens the chapter (its row's link), or pauses it while it sounds.
// - "chapter": Hear this read ([data-act=hear]) hands the chapter's track
//   to the voice, or pauses it; while a track reading this whole chapter
//   sounds, the page keeps pace with it (paragraph N of M at N/M of the
//   track), standing aside for four seconds whenever the reader moves it.
//
// Both draw the mini player and the player (Player): the reading's title,
// back and on fifteen seconds, play and pause, the scrubber and clock, the
// previous and next readings, and the speed.

const LISTENING = "lv:spiritual-reading-listening:"
const RATE = "lv:spiritual-reading-rate:"
const RATES = [0.75, 1, 1.25, 1.5, 2]
// A place this close to the start is not worth resuming (restingPosition).
const RESUME_AFTER = 20
// How long the page stays the reader's own after they move it.
const FOLLOW_YIELDS_MS = 4000
const FAILURE = "The recording couldn't be reached. Check your connection and try again."

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

// "3:07", "1:02:03" (LibraryListeningSession.time).
export const clock = (seconds) => {
  if (!Number.isFinite(seconds) || seconds <= 0) return "0:00"
  const whole = Math.floor(seconds)
  const minutes = Math.floor(whole / 60)
  const secs = String(whole % 60).padStart(2, "0")
  if (minutes >= 60) return `${Math.floor(minutes / 60)}:${String(minutes % 60).padStart(2, "0")}:${secs}`
  return `${minutes}:${secs}`
}

// "27 MIN", "1 HR 5 MIN" (ReadingSpans.chipMinutes).
export const chipMinutes = (seconds) => {
  const minutes = Math.max(Math.round(seconds / 60), 1)
  if (minutes < 60) return `${minutes} MIN`
  const rest = minutes % 60
  return rest === 0 ? `${Math.floor(minutes / 60)} HR` : `${Math.floor(minutes / 60)} HR ${rest} MIN`
}

// -- The one voice -------------------------------------------------------------

const session = {
  audio: null,
  book: null, // the book whose recording is in the player
  tracks: [],
  rate: 1,
  track: null, // the track loaded, by index
  resume: 0, // seconds to start the loaded track at, once it can seek
  failure: null,
  pressed: false, // whether play was asked for: a load before it is not a failure
  views: new Set(),
  savedAt: 0,

  adopt(book, tracks, preferredRate) {
    if (this.book && this.book !== book) this.stop()
    this.book = book
    this.tracks = tracks
    const kept = Number(storage.get(RATE + book))
    this.rate = RATES.includes(kept) ? kept : RATES.includes(preferredRate) ? preferredRate : 1
  },

  ensureAudio() {
    if (this.audio) return this.audio
    const audio = new Audio()
    audio.preload = "metadata"
    audio.addEventListener("loadedmetadata", () => {
      if (this.resume > 0 && this.resume < audio.duration - 1) audio.currentTime = this.resume
      this.resume = 0
      this.render()
    })
    audio.addEventListener("timeupdate", () => {
      this.persist()
      this.render()
      for (const view of this.views) view.follow()
    })
    for (const event of ["play", "pause", "waiting", "playing", "durationchange", "ratechange"]) {
      audio.addEventListener(event, () => this.render())
    }
    audio.addEventListener("pause", () => this.persist(true))
    // A reading runs on into the next, as the app's onFinish steps.
    audio.addEventListener("ended", () => this.step(1))
    audio.addEventListener("error", () => {
      if (!this.pressed || !audio.getAttribute("src")) return
      this.failure = FAILURE
      this.render()
    })
    this.audio = audio
    return audio
  },

  get active() {
    return this.book !== null && this.track !== null
  },

  get playing() {
    return this.active && this.audio && !this.audio.paused
  },

  loaded(index) {
    return this.active && this.track === index
  },

  sounding(index) {
    return this.loaded(index) && !this.audio.paused
  },

  // Where the voice was left in this track, when it is worth resuming.
  resting(index) {
    const track = this.tracks[index]
    const kept = this.book && storage.get(LISTENING + this.book)
    if (!track || !kept || kept.track !== track.id) return null
    const seconds = Number(kept.seconds)
    return Number.isFinite(seconds) && seconds > RESUME_AFTER ? seconds : null
  },

  play(index, from) {
    const track = this.tracks[index]
    if (!track) return
    this.persist(true)
    const audio = this.ensureAudio()
    this.failure = null
    this.pressed = true
    this.track = index
    this.resume = from ?? this.resting(index) ?? 0
    audio.src = track.url
    audio.playbackRate = this.rate
    audio.defaultPlaybackRate = this.rate
    this.start()
    this.render()
  },

  start() {
    const promise = this.audio.play()
    if (promise) {
      promise.catch((error) => {
        // A play cut short by another load or a pause is not a failure.
        if (error && error.name === "AbortError") return
        if (error && error.name === "NotAllowedError") return this.render()
        this.failure = FAILURE
        this.render()
      })
    }
  },

  // One control: what sounds pauses, what is loaded resumes, anything else
  // is moved to.
  toggle(index) {
    if (this.sounding(index)) return this.pause()
    if (this.loaded(index) && this.audio.getAttribute("src")) {
      this.failure = null
      this.audio.playbackRate = this.rate
      return this.start()
    }
    this.play(index)
  },

  togglePlayPause() {
    if (!this.active) return
    if (this.audio.paused) this.toggle(this.track)
    else this.pause()
  },

  pause() {
    if (this.active) this.audio.pause()
  },

  step(by) {
    if (!this.active) return
    const target = this.track + by
    if (target < 0 || target >= this.tracks.length) {
      this.persist(true)
      return this.render()
    }
    this.play(target, 0)
  },

  seek(seconds) {
    if (!this.active || !Number.isFinite(this.audio.duration)) return
    this.audio.currentTime = Math.min(Math.max(seconds, 0), this.audio.duration)
    this.persist(true)
  },

  skip(by) {
    if (this.active) this.seek(this.audio.currentTime + by)
  },

  setRate(rate) {
    if (!RATES.includes(rate) || !this.book) return
    this.rate = rate
    storage.set(RATE + this.book, rate)
    if (this.audio) {
      this.audio.playbackRate = rate
      this.audio.defaultPlaybackRate = rate
    }
    this.render()
  },

  // The listening place, every five seconds while the voice runs and at
  // once on a pause, a change of track or leaving.
  persist(force = false) {
    if (!this.active || !this.audio) return
    const now = Date.now()
    if (!force && now - this.savedAt < 5000) return
    const seconds = this.audio.currentTime
    if (!Number.isFinite(seconds) || seconds <= 0) return
    this.savedAt = now
    storage.set(LISTENING + this.book, { track: this.tracks[this.track].id, seconds, at: now })
  },

  // Ends the reading: the place written, the player emptied.
  stop() {
    if (this.audio) {
      this.persist(true)
      this.audio.pause()
      this.audio.removeAttribute("src")
      this.audio.load()
    }
    this.book = null
    this.tracks = []
    this.track = null
    this.failure = null
    this.pressed = false
    document.documentElement.removeAttribute("data-book-player")
    this.render()
  },

  // The reading ends when no page of its book is on the screen.
  checkPresence() {
    if (!this.book) return
    const screens = document.querySelectorAll("[data-book-screen]")
    if (!Array.from(screens).some((el) => el.dataset.bookScreen === this.book)) this.stop()
  },

  render() {
    for (const view of this.views) view.render()
  }
}

if (typeof window !== "undefined") {
  // LiveView can say a navigation has stopped loading a moment before the
  // new page is in place, so the reading is looked for a little after.
  window.addEventListener("phx:page-loading-stop", () => {
    clearTimeout(session.presenceCheck)
    session.presenceCheck = setTimeout(() => session.checkPresence(), 600)
  })
  window.addEventListener("pagehide", () => session.persist(true))
}

// -- A page's view of it -------------------------------------------------------

export default {
  mounted() {
    this.book = this.el.dataset.book
    this.page = this.el.dataset.page
    this.chapter = Number(this.el.dataset.chapter)
    let tracks = []
    try {
      tracks = JSON.parse(this.el.dataset.tracks || "[]")
    } catch (_unreadable) {
      tracks = []
    }
    this.tracks = Array.isArray(tracks) ? tracks : []
    this.preferredRate = Number(this.el.dataset.rate) || 1

    // The page's own controls: the player inside this element, and on a
    // book's page the chips in the contents beside it.
    this.player = this.el.querySelector("[data-role=player]")
    this.panel = this.el.querySelector("[data-role=panel]")
    this.scope = this.page === "book" ? this.el.closest("[data-book-screen]") || this.el : this.el

    this.onClick = (event) => this.click(event)
    this.scope.addEventListener("click", this.onClick)

    this.scrub = this.el.querySelector("[data-role=scrub]")
    this.scrubbing = false
    if (this.scrub) {
      this.onScrub = () => {
        this.scrubbing = true
        this.drawClock(Number(this.scrub.value))
      }
      this.onScrubbed = () => {
        this.scrubbing = false
        session.seek(Number(this.scrub.value))
      }
      this.scrub.addEventListener("input", this.onScrub)
      this.scrub.addEventListener("change", this.onScrubbed)
    }

    // The reader's own hand on the page, which following stands aside for.
    this.readerMovedAt = 0
    this.onReaderMove = () => {
      this.readerMovedAt = Date.now()
    }
    if (this.page === "chapter") {
      for (const event of ["wheel", "touchmove", "keydown"]) {
        window.addEventListener(event, this.onReaderMove, { passive: true })
      }
    }
    this.followTarget = null

    // A page of another book is not this reading's: it stops, and this book
    // is adopted (the app's adopt).
    if (session.book && session.book !== this.book) session.stop()
    session.views.add(this)
    this.render()
  },

  destroyed() {
    session.views.delete(this)
    this.scope.removeEventListener("click", this.onClick)
    if (this.scrub) {
      this.scrub.removeEventListener("input", this.onScrub)
      this.scrub.removeEventListener("change", this.onScrubbed)
    }
    for (const event of ["wheel", "touchmove", "keydown"]) {
      window.removeEventListener(event, this.onReaderMove)
    }
    // A full page change ends nothing until the next page has come; a
    // page of another kind ends the reading (checked at page-loading-stop).
  },

  adopt() {
    session.adopt(this.book, this.tracks, this.preferredRate)
  },

  click(event) {
    const target = event.target.closest("[data-act]")
    if (!target || !this.scope.contains(target)) return
    const act = target.dataset.act
    const track = Number(target.dataset.track)

    switch (act) {
      case "listen": {
        event.preventDefault()
        this.adopt()
        if (session.sounding(track)) return session.pause()
        session.toggle(track)
        // The chip opens the chapter its reading begins on, as the app's.
        const row = target.closest("li")?.querySelector("a[data-role=chapter-row]")
        if (row) row.click()
        return
      }
      case "hear":
        this.adopt()
        if (session.sounding(track)) return session.pause()
        this.followTarget = null
        return session.toggle(track)
      case "toggle":
        return session.togglePlayPause()
      case "back":
        return session.skip(-15)
      case "forward":
        return session.skip(15)
      case "previous":
        return session.step(-1)
      case "next":
        return session.step(1)
      case "rate":
        return session.setRate(Number(target.dataset.rate))
      case "expand": {
        const open = this.panel.hidden
        this.panel.hidden = !open
        target.setAttribute("aria-expanded", String(open))
        return
      }
    }
  },

  // Keeps the page with the voice, where a track reads this whole chapter
  // and nothing else (canFollowText).
  follow() {
    if (this.page !== "chapter" || !session.playing || session.book !== this.book) return
    const track = session.tracks[session.track]
    if (!track || track.chapter !== this.chapter) return
    if (Date.now() - this.readerMovedAt < FOLLOW_YIELDS_MS) return
    const duration = session.audio.duration
    const paragraphs = document.querySelectorAll("[data-role=chapter-text] [data-p]")
    if (!(duration > 0) || paragraphs.length === 0) return
    const fraction = Math.min(Math.max(session.audio.currentTime / duration, 0), 1)
    const target = Math.min(paragraphs.length - 1, Math.floor(fraction * paragraphs.length))
    if (target === this.followTarget) return
    this.followTarget = target
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    paragraphs[target].scrollIntoView({ block: "start", behavior: reduce ? "auto" : "smooth" })
  },

  render() {
    const mine = session.book === this.book
    const audio = session.audio

    // Hear this read.
    for (const hear of this.el.querySelectorAll("[data-act=hear]")) {
      const index = Number(hear.dataset.track)
      const sounding = mine && session.sounding(index)
      hear.querySelector("[data-icon=play]").hidden = sounding
      hear.querySelector("[data-icon=pause]").hidden = !sounding
      hear.querySelector("[data-role=hear-label]").textContent = sounding ? "Pause the reading" : "Hear this read"
      const from = hear.querySelector("[data-role=hear-from]")
      if (from) from.hidden = sounding
      hear.setAttribute("aria-label", sounding ? "Pause the reading" : hear.dataset.label)
      hear.dataset.sounding = sounding ? "true" : "false"

      const left = this.el.querySelector("[data-role=hear-left]")
      if (left) {
        const loaded = mine && session.loaded(index) && audio && audio.duration > 0
        left.textContent = loaded
          ? `${chipMinutes(Math.max(audio.duration - audio.currentTime, 0))} LEFT`
          : chipMinutes(Number(left.dataset.seconds))
      }
    }

    // The contents' chips.
    if (this.page === "book") {
      for (const chip of this.scope.querySelectorAll("[data-act=listen]")) {
        const index = Number(chip.dataset.track)
        const sounding = mine && session.sounding(index)
        chip.dataset.sounding = sounding ? "true" : "false"
        chip.querySelector("[data-icon=play]").hidden = sounding
        chip.querySelector("[data-icon=pause]").hidden = !sounding
        chip.setAttribute("aria-label", sounding ? chip.dataset.pauseLabel : chip.dataset.label)
      }
      for (const resting of this.scope.querySelectorAll("[data-role=resting]")) {
        const index = Number(resting.dataset.track)
        const kept = mine && session.loaded(index) ? null : this.restingFor(index)
        resting.hidden = kept === null
        resting.textContent = kept === null ? "" : `${clock(kept)} in`
      }
    }

    this.drawPlayer(mine)
  },

  // Where this browser left the voice in a track of this book, read
  // whether or not the book is the one in the player.
  restingFor(index) {
    const track = this.tracks[index]
    const kept = storage.get(LISTENING + this.book)
    if (!track || !kept || kept.track !== track.id) return null
    const seconds = Number(kept.seconds)
    return Number.isFinite(seconds) && seconds > RESUME_AFTER ? seconds : null
  },

  drawPlayer(mine) {
    if (!this.player) return
    const shown = mine && session.active
    this.player.hidden = !shown
    this.el.toggleAttribute("data-listening", shown)
    document.documentElement.toggleAttribute("data-book-player", shown)

    const error = this.player.querySelector("[data-role=error]")
    error.hidden = !(mine && session.failure)
    error.textContent = mine && session.failure ? session.failure : ""
    if (!shown) return

    const track = session.tracks[session.track] || {}
    const title = track.title || "The reading"
    this.player.querySelector("[data-role=mini-title]").textContent = title
    this.player.querySelector("[data-role=track-title]").textContent = title
    const open = this.player.querySelector("[data-act=expand]")
    open.setAttribute("aria-label", `The reading: ${title}. Opens the player.`)

    const playing = session.playing
    const play = this.player.querySelector("[data-role=play]")
    play.setAttribute("aria-pressed", String(playing))
    play.setAttribute("aria-label", playing ? "Pause the reading" : "Play the reading")
    const mini = this.player.querySelector("[data-role=mini-play]")
    mini.setAttribute("aria-pressed", String(playing))
    mini.setAttribute("aria-label", playing ? "Pause" : "Play")
    mini.querySelector("[data-icon=play]").hidden = playing
    mini.querySelector("[data-icon=pause]").hidden = !playing

    this.player.querySelector("[data-act=previous]").disabled = session.track <= 0
    this.player.querySelector("[data-act=next]").disabled = session.track + 1 >= session.tracks.length

    for (const pill of this.player.querySelectorAll("[data-act=rate]")) {
      pill.setAttribute("aria-pressed", String(Number(pill.dataset.rate) === session.rate))
    }

    const duration = session.audio && Number.isFinite(session.audio.duration) ? session.audio.duration : 0
    if (this.scrub && !this.scrubbing) {
      this.scrub.disabled = !(duration > 0)
      this.scrub.max = String(Math.floor(duration))
      this.scrub.value = String(Math.floor(session.audio.currentTime || 0))
      this.drawClock(session.audio.currentTime || 0)
    }
  },

  drawClock(at) {
    const duration = session.audio && Number.isFinite(session.audio.duration) ? session.audio.duration : 0
    const progress = duration > 0 ? Math.min(at / duration, 1) * 100 : 0
    this.scrub.style.setProperty("--progress", `${progress}%`)
    this.scrub.setAttribute("aria-valuetext", `${clock(at)} of ${clock(duration)}`)
    this.player.querySelector("[data-role=elapsed]").textContent = clock(at)
    this.player.querySelector("[data-role=remaining]").textContent = `−${clock(Math.max(duration - at, 0))}`
  }
}
