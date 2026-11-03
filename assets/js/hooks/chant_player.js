// ChantPlayer: plays the Chant Library's recordings on the Chant pages,
// as the app's ChantPlayer does, with one <audio> per page.
//
// It keeps nothing: no storage, no cookie, nothing sent to the server.
// The recordings are the public files on the site's own bucket, named in
// the page (a disc's data-src, the chant page's <audio src>). Leaving the
// page stops what it plays; the site has no player at the foot of every
// page yet.
//
// Two shapes of page:
//
// - A list (/chant, a section's shelf): every [data-play] disc plays its
//   chant where it stands, and a second press pauses it. [data-play-all]
//   sings the discs inside [data-queue] one after another, then Pause and
//   Resume, as the app's PLAY ALL does. The row or card that sounds is
//   marked data-sounding, its disc aria-pressed.
//
// - A sung set ([data-set], on the Chant page's cards and a set's own
//   page): its data-entries is the whole set unrolled, [[chant id,
//   recording, origin], ...], a chant as often as it is sung. Its
//   [data-play-set] sings it from the start, then Pause, Resume, and Play
//   next while a chant waits; a row's [data-play-from=<origin>] sings it
//   from that step's first chant. The row whose step sounds
//   ([data-origin]) is marked data-sounding, data-lit while it is the
//   step under way, sounding or not; a tile or card of the set
//   ([data-set-tile], [data-set]) data-sounding. With the page's
//   [data-pauses-between] checked (Pause Between Chants), the next chant
//   is put under the hand at its start and waits for Play next
//   (ChantQueue.after). The sets have no silences of their own.
//
// - A chant's page ([data-role=player]): the gold play, back and on a
//   line (ten seconds for a chant with no timed lines), the scrubber, the
//   clock and "Line 3 of 12", Repeat this line (or the chant), and
//   three-quarter speed. The line sounding is lit in the Words
//   ([data-line], with data-start and data-end) and written into the now
//   line; a click on a line plays from it.

const clock = (seconds) => {
  const whole = Math.max(0, Math.floor(seconds || 0))
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`
}

export default {
  mounted() {
    this.player = this.el.querySelector("[data-role=player]")
    this.audio = this.el.querySelector("audio")
    if (!this.audio) return

    this.current = null // the chant id sounding (list pages)
    this.queue = null // entries left to sing after the current one
    this.queued = false // whether Play all is under way
    this.setId = null // the sung set under way, if Play all is one
    this.origin = null // the set's step the current chant was unrolled from
    this.waiting = false // the next chant waits for a tap (Pause Between Chants)
    this.repeat = false
    this.raf = null
    this.pressed = false // whether play was pressed: no error is shown before
    this.started = false // whether the chant's page has played: back and on wait for it

    this.onClick = (event) => this.click(event)
    this.el.addEventListener("click", this.onClick)

    this.audio.addEventListener("play", () => {
      this.started = true
      this.paint()
    })
    this.audio.addEventListener("pause", () => this.paint())
    this.audio.addEventListener("ended", () => this.ended())
    this.audio.addEventListener("error", () => this.failed())
    this.audio.addEventListener("loadedmetadata", () => this.tick())
    this.audio.addEventListener("timeupdate", () => this.tick())

    if (this.player) this.mountChant()
  },

  updated() {
    // A patch (the Words chosen, a search typed) redraws what the hook
    // marked; mark it again.
    this.paint()
    if (this.player) this.tick(true)
  },

  destroyed() {
    if (this.audio) {
      this.audio.pause()
      this.audio.removeAttribute("src")
      this.audio.load()
    }
    cancelAnimationFrame(this.raf)
  },

  // ---- A chant's page

  mountChant() {
    this.lines = Array.from(this.el.querySelectorAll("[data-line]")).map((el) => ({
      el,
      start: parseFloat(el.dataset.start),
      end: parseFloat(el.dataset.end),
      latin: el.querySelector(".chant-line__latin")?.textContent || "",
      english: el.querySelector(".chant-line__english")?.textContent || "",
    }))
    this.hasLines = this.lines.length > 0
    this.lineIndex = this.hasLines ? 0 : null
    this.scrub = this.player.querySelector("[data-role=scrub]")
    this.scrub?.addEventListener("input", () => {
      this.audio.currentTime = parseFloat(this.scrub.value)
      // The line under the new place, so Repeat holds that one, not the
      // line the scrub left
      this.lineIndex = this.lineAt(this.audio.currentTime)
      this.tick(true)
    })
    this.current = this.el.dataset.chant
  },

  // ---- Presses

  click(event) {
    const setPlay = event.target.closest("[data-play-set]")
    if (setPlay) return this.playSet(setPlay.closest("[data-set]"))

    const from = event.target.closest("[data-play-from]")
    if (from) return this.playSet(from.closest("[data-set]"), parseInt(from.dataset.playFrom, 10))

    const disc = event.target.closest("[data-play]")
    if (disc && this.el.contains(disc)) return this.toggleChant(disc.dataset.play, disc.dataset.src)

    if (event.target.closest("[data-play-all]")) return this.playAll()

    const line = event.target.closest("[data-line]")
    if (line && this.player) return this.playFromLine(parseInt(line.dataset.line, 10))

    const act = event.target.closest("[data-act]")
    if (act && this.player) {
      switch (act.dataset.act) {
        case "toggle":
          return this.audio.paused ? this.start() : this.audio.pause()
        case "back":
          return this.back()
        case "on":
          return this.on()
        case "repeat":
          this.repeat = !this.repeat
          // Repeat this line starts the chant, as the app's does; Repeat
          // the chant only switches on
          if (this.repeat && this.hasLines && !this.started) this.start()
          return this.paint()
        case "speed":
          this.audio.playbackRate = this.audio.playbackRate < 1 ? 1 : 0.75
          return this.paint()
      }
    }
  },

  start() {
    this.pressed = true
    this.hideError()
    const playing = this.audio.play()
    if (playing && playing.catch) playing.catch((err) => err.name !== "AbortError" && this.failed())
  },

  toggleChant(id, src) {
    if (this.current === id && this.audio.getAttribute("src")) {
      if (this.audio.paused) this.start()
      else this.audio.pause()
      return
    }
    // A disc pressed while a shelf is sung puts the shelf down.
    this.queued = false
    this.queue = null
    this.setId = null
    this.waiting = false
    this.load(id, src)
  },

  load(id, src, origin = null) {
    this.current = id
    this.origin = origin
    this.audio.src = src
    this.audio.currentTime = 0
    this.start()
    this.paint()
  },

  discs() {
    const seen = new Set()
    return Array.from(this.el.querySelectorAll("[data-queue] [data-play]")).filter((disc) => {
      if (seen.has(disc.dataset.play)) return false
      seen.add(disc.dataset.play)
      return true
    })
  },

  playAll() {
    if (this.queued) {
      if (this.audio.paused) this.start()
      else this.audio.pause()
      return
    }
    const discs = this.discs()
    if (discs.length === 0) return
    this.queued = true
    this.setId = null
    this.waiting = false
    this.queue = discs.slice(1).map((d) => ({ id: d.dataset.play, src: d.dataset.src }))
    this.load(discs[0].dataset.play, discs[0].dataset.src)
  },

  entries(set) {
    try {
      return JSON.parse(set.dataset.entries || "[]").map(([id, src, origin]) => ({ id, src, origin }))
    } catch (_err) {
      return []
    }
  },

  // A sung set: from its start, or from a step (Play from Here). Pressed
  // again while it is under way, Play all pauses and resumes it, or sings
  // the chant waiting for a tap.
  playSet(set, origin = null) {
    if (!set) return
    if (origin == null && this.queued && this.setId === set.dataset.set) {
      if (this.waiting) return this.goOn()
      if (this.audio.paused) this.start()
      else this.audio.pause()
      return
    }
    const entries = this.entries(set)
    const start = origin == null ? 0 : entries.findIndex((entry) => entry.origin === origin)
    if (start < 0 || entries.length === 0) return
    this.queued = true
    this.setId = set.dataset.set
    this.waiting = false
    this.queue = entries.slice(start + 1)
    this.load(entries[start].id, entries[start].src, entries[start].origin)
  },

  goOn() {
    this.waiting = false
    this.audio.currentTime = 0
    this.start()
  },

  pausesBetween() {
    const box = this.el.querySelector("[data-pauses-between]")
    return !!(box && box.checked)
  },

  ended() {
    if (this.player) {
      if (this.repeat && !this.hasLines) {
        this.audio.currentTime = 0
        return this.start()
      }
      return this.paint()
    }
    if (this.queued && this.queue && this.queue.length > 0) {
      const next = this.queue.shift()
      if (this.setId && this.pausesBetween()) {
        // Held at its very start, so nothing of it is heard before the tap
        this.current = next.id
        this.origin = next.origin
        this.waiting = true
        this.audio.src = next.src
        return this.paint()
      }
      return this.load(next.id, next.src, next.origin)
    }
    this.queued = false
    this.queue = null
    this.setId = null
    this.origin = null
    this.waiting = false
    this.current = null
    this.paint()
  },

  // A recording that will not play. The chant's page says so once play
  // was pressed (its metadata may fail before, unasked). A list says so
  // and goes on to the next chant of what it sings, so one missing file
  // never stops Play all.
  failed() {
    if (!this.audio.getAttribute("src") || !this.pressed) return
    // A chant held at its start by Pause Between Chants waits for its tap,
    // even when its file will not load: the tap then says so.
    if (this.waiting) return
    const error = this.el.querySelector("[data-role=error]")
    if (error) error.hidden = false
    if (!this.player && this.queued && this.queue && this.queue.length > 0) {
      const next = this.queue.shift()
      return this.load(next.id, next.src, next.origin ?? null)
    }
    if (!this.player) {
      this.queued = false
      this.queue = null
      this.setId = null
      this.origin = null
      this.waiting = false
    }
    this.paint()
  },

  hideError() {
    const error = this.el.querySelector("[data-role=error]")
    if (error) error.hidden = true
  },

  // ---- Lines

  // The line sounding at a time, or the one just sung while the
  // recording rests between two (Chant.lineIndex).
  lineAt(time) {
    if (!this.hasLines) return null
    let index = 0
    this.lines.forEach((line, i) => {
      if (line.start <= time + 0.05) index = i
    })
    return index
  },

  seekToLine(index) {
    if (!this.hasLines) return
    const i = Math.max(0, Math.min(this.lines.length - 1, index))
    this.audio.currentTime = this.lines[i].start
    this.lineIndex = i
    this.tick(true)
  },

  playFromLine(index) {
    this.seekToLine(index)
    if (this.audio.paused) this.start()
  },

  // Within the first two seconds of a line, the line before; later, this
  // line from its start, as a track's back button does.
  back() {
    if (this.hasLines) {
      const i = this.lineIndex ?? 0
      const into = this.audio.currentTime - this.lines[i].start
      this.seekToLine(into > 2 ? i : i - 1)
    } else {
      this.audio.currentTime = Math.max(0, this.audio.currentTime - 10)
      this.tick(true)
    }
  },

  on() {
    if (this.hasLines) {
      const i = (this.lineIndex ?? -1) + 1
      if (i < this.lines.length) this.seekToLine(i)
    } else {
      const end = (this.audio.duration || 0) - 0.5
      this.audio.currentTime = Math.min(Math.max(0, end), this.audio.currentTime + 10)
      this.tick(true)
    }
  },

  // ---- What the page shows

  tick(force) {
    if (!this.player) return
    const time = this.audio.currentTime || 0

    // Repeat this line: at its end, back to its start.
    if (this.repeat && this.hasLines && !this.audio.paused && this.lineIndex != null) {
      const line = this.lines[this.lineIndex]
      const next = this.lines[this.lineIndex + 1]
      const end = next ? Math.min(line.end, next.start) : line.end
      if (time >= end - 0.05) {
        this.audio.currentTime = line.start
        return
      }
    }

    const index = this.lineAt(time)
    if (force || index !== this.shownLine) {
      this.lineIndex = index
      this.showLine(index)
    }

    const elapsed = this.player.querySelector("[data-role=elapsed]")
    if (elapsed) elapsed.textContent = clock(time)
    if (this.audio.duration && isFinite(this.audio.duration)) {
      const total = this.player.querySelector("[data-role=total]")
      if (total) total.textContent = clock(Math.round(this.audio.duration))
      if (this.scrub) this.scrub.max = String(this.audio.duration)
    }
    if (this.scrub && document.activeElement !== this.scrub) this.scrub.value = String(time)
    if (this.scrub) {
      const max = parseFloat(this.scrub.max) || 1
      this.scrub.style.setProperty("--progress", `${Math.min(100, (time / max) * 100)}%`)
      this.scrub.setAttribute("aria-valuetext", `${clock(time)} of ${clock(max)}`)
    }
  },

  showLine(index) {
    this.shownLine = index
    if (index == null) return
    this.lines.forEach((line, i) => {
      if (i === index) line.el.setAttribute("aria-current", "true")
      else line.el.removeAttribute("aria-current")
    })
    const line = this.lines[index]
    const latin = this.player.querySelector("[data-now=latin]")
    const english = this.player.querySelector("[data-now=english]")
    if (latin) latin.textContent = line.latin
    if (english) english.textContent = line.english
    const count = this.player.querySelector("[data-role=line-count]")
    if (count) count.textContent = `Line ${index + 1} of ${this.lines.length}`
  },

  frame() {
    cancelAnimationFrame(this.raf)
    if (this.audio.paused) return
    this.tick()
    this.raf = requestAnimationFrame(() => this.frame())
  },

  paint() {
    const playing = !this.audio.paused && !this.audio.ended

    this.el.querySelectorAll("[data-chant-row]").forEach((row) => {
      if (row.dataset.chantRow === this.current && playing) row.setAttribute("data-sounding", "")
      else row.removeAttribute("data-sounding")
    })
    this.el.querySelectorAll("[data-play]").forEach((disc) => {
      const on = disc.dataset.play === this.current && playing
      disc.setAttribute("aria-pressed", on ? "true" : "false")
      disc.setAttribute("aria-label", `${on ? "Pause" : "Play"} ${disc.dataset.label}`)
    })

    this.el.querySelectorAll("[data-set]").forEach((set) => {
      const mine = this.queued && this.setId === set.dataset.set
      if (mine && playing) set.setAttribute("data-sounding", "")
      else set.removeAttribute("data-sounding")
      set.querySelectorAll("[data-origin]").forEach((row) => {
        const lit = mine && Number(row.dataset.origin) === this.origin
        row.toggleAttribute("data-lit", lit)
        row.toggleAttribute("data-sounding", lit && playing)
      })
      set.querySelectorAll("[data-play-set]").forEach((button) => {
        const going = mine && playing && !this.waiting
        const word = !mine ? "Play all" : this.waiting ? "Play next" : going ? "Pause" : "Resume"
        const text = button.querySelector("[data-play-set-word]")
        if (text) {
          text.textContent = word
          button.setAttribute("aria-label", mine ? word : `Play all of ${button.dataset.label}`)
        } else {
          button.setAttribute("aria-label", `${going ? "Pause" : "Play"} ${button.dataset.label}`)
        }
        button.setAttribute("aria-pressed", going ? "true" : "false")
      })
    })
    this.el.querySelectorAll("[data-set-tile]").forEach((tile) => {
      const on = this.queued && this.setId === tile.dataset.setTile && playing
      tile.toggleAttribute("data-sounding", on)
    })

    const all = this.el.querySelector("[data-play-all]")
    if (all) {
      const word = all.querySelector("[data-play-all-word]")
      const label = !this.queued ? "Play all" : playing ? "Pause" : "Resume"
      if (word) word.textContent = label
      all.setAttribute("aria-pressed", this.queued && playing ? "true" : "false")
    }

    if (this.player) {
      this.player.querySelectorAll("[data-act=back], [data-act=on]").forEach((step) => {
        step.disabled = !this.started
      })
      const play = this.player.querySelector("[data-act=toggle]")
      if (play) {
        play.setAttribute("aria-pressed", playing ? "true" : "false")
        play.setAttribute("aria-label", `${playing ? "Pause" : "Play"} ${play.dataset.label}`)
      }
      const repeat = this.player.querySelector("[data-act=repeat]")
      if (repeat) repeat.setAttribute("aria-pressed", this.repeat ? "true" : "false")
      const speed = this.player.querySelector("[data-act=speed]")
      const slow = this.audio.playbackRate < 1
      if (speed) speed.setAttribute("aria-pressed", slow ? "true" : "false")
      const label = this.player.querySelector("[data-role=speed-label]")
      if (label) label.textContent = slow ? "¾×" : "1×"
      this.el.toggleAttribute("data-playing", playing)
      if (playing) this.frame()
    }
  },
}
