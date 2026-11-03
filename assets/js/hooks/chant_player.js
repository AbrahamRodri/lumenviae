// ChantPlayer: the Chant pages' presses on the site's one chant player
// (chant_session.js, the app's ChantPlayer.shared), and what those pages
// show of it. The <audio> is the root layout's, so what a page starts
// goes on singing when the reader leaves it, with the mini player at the
// foot of the other pages; the queue of a Play all goes on there too.
//
// The hook keeps nothing of its own beyond the page: the session keeps
// the chant in hand in this tab's sessionStorage (see chant_session.js),
// and nothing is sent. The recordings are the public files on the site's
// own bucket, named in the page (a disc's data-src, the chant page's
// [data-role=player] data-src), with the facts the mini player shows
// (data-facts on a disc and the player, data-chants on a set).
//
// Three shapes of page:
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
//   ([data-set-tile], [data-set]) data-sounding. A [data-pauses-between]
//   box is Pause Between Chants, the one kept choice (chant_session.js):
//   drawn from it, written by it. While it is on, the next chant of any
//   queue is put under the hand at its start and waits for Play next
//   (ChantQueue.after). The sets have no silences of their own.
//
// - A chant's page ([data-role=player]): the gold play, back and on a
//   line (ten seconds for a chant with no timed lines), the scrubber, the
//   clock and "Line 3 of 12", Repeat this line (or the chant), and
//   three-quarter speed. The line sounding is lit in the Words
//   ([data-line], with data-start and data-end) and written into the now
//   line; a click on a line plays from it. The full score's small player
//   (ChantScore, over the page) drives the same recording: its
//   [data-act=toggle] plays and pauses, its [data-role=score-scrub]
//   moves through the chant, and [data-role=score-time] tells the time.
//   While another chant is in hand, the page shows its own at its start
//   and the other sings on until this page's play, a line or the
//   scrubber takes the player.

import {
  session,
  subscribe,
  playOne,
  hold,
  toggle,
  playQueue,
  isQueue,
  pausesBetween,
  setPausesBetween,
  goOn,
} from "../chant_session"

const clock = (seconds) => {
  const whole = Math.max(0, Math.floor(seconds || 0))
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`
}

const parse = (json, fallback) => {
  try {
    return JSON.parse(json || "") ?? fallback
  } catch (_err) {
    return fallback
  }
}

export default {
  mounted() {
    this.player = this.el.querySelector("[data-role=player]")
    this.audio = session.audio
    if (!this.audio) return

    this.raf = null
    this.lineRepeat = false // Repeat this line (or the chant), the page's own

    this.onClick = (event) => this.click(event)
    this.el.addEventListener("click", this.onClick)

    // Pause Between Chants: the box writes the one kept choice
    this.el.addEventListener("change", (event) => {
      if (event.target.matches?.("[data-pauses-between]")) setPausesBetween(event.target.checked)
    })

    this.unsubscribe = subscribe((kind) => {
      if (kind === "passed-over" || kind === "failed") this.showError(kind)
      if (kind === "time") return this.tick()
      this.paint()
    })

    if (this.player) this.mountChant()
    this.paint()
  },

  updated() {
    // A patch (the Words chosen, a search typed) redraws what the hook
    // marked; mark it again.
    this.paint()
  },

  destroyed() {
    this.unsubscribe?.()
    cancelAnimationFrame(this.raf)
    // Repeat is the chant page's tool: the chant sings on without it
    if (this.player && session.repeat === this.chant?.id) session.repeat = null
  },

  // ---- A chant's page

  mountChant() {
    this.chant = {
      id: this.el.dataset.chant,
      src: this.player.dataset.src,
      facts: parse(this.player.dataset.facts, {}),
    }
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
    this.scrub?.addEventListener("input", () => this.seek(parseFloat(this.scrub.value)))
    // The full score's scrubber, which comes and goes with the sheet.
    this.el.addEventListener("input", (event) => {
      if (event.target.matches?.("[data-role=score-scrub]")) this.seek(parseFloat(event.target.value))
    })
  },

  // Whether the chant in hand is this page's
  mine() {
    return !!this.chant && session.isCurrent(this.chant.id)
  },

  // The scrubber moved: the place in this chant, taking the player if
  // another chant holds it
  seek(time) {
    if (!this.mine()) hold(this.chant, time)
    else this.audio.currentTime = time
    // The line under the new place, so Repeat holds that one, not the
    // line the scrub left
    this.lineIndex = this.lineAt(time)
    this.tick(true, time)
  },

  // ---- Presses

  click(event) {
    const setPlay = event.target.closest("[data-play-set]")
    if (setPlay) return this.playSet(setPlay.closest("[data-set]"))

    const from = event.target.closest("[data-play-from]")
    if (from) return this.playSet(from.closest("[data-set]"), parseInt(from.dataset.playFrom, 10))

    const disc = event.target.closest("[data-play]")
    if (disc && this.el.contains(disc)) return playOne(this.discChant(disc))

    const all = event.target.closest("[data-play-all]")
    if (all) return this.playAll(all)

    const line = event.target.closest("[data-line]")
    if (line && this.player) return this.playFromLine(parseInt(line.dataset.line, 10))

    const act = event.target.closest("[data-act]")
    if (act && this.player) {
      switch (act.dataset.act) {
        case "toggle":
          return this.mine() ? toggle() : playOne(this.chant)
        case "back":
          return this.mine() && this.back()
        case "on":
          return this.mine() && this.on()
        case "repeat":
          this.lineRepeat = !this.lineRepeat
          // Repeat the chant, for a chant with no timed lines, is the
          // player's: it sings this chant again at its end
          session.repeat = this.lineRepeat && !this.hasLines ? this.chant.id : null
          // Repeat this line starts the chant, as the app's does; Repeat
          // the chant only switches on
          if (this.lineRepeat && this.hasLines && !(this.mine() && session.started)) {
            if (this.mine()) toggle()
            else playOne(this.chant)
          }
          return this.paint()
        case "speed": {
          const rate = this.audio.playbackRate < 1 ? 1 : 0.75
          this.audio.defaultPlaybackRate = rate
          this.audio.playbackRate = rate
          return this.paint()
        }
      }
    }
  },

  discChant(disc) {
    return { id: disc.dataset.play, src: disc.dataset.src, facts: parse(disc.dataset.facts, {}) }
  },

  discs() {
    const seen = new Set()
    return Array.from(this.el.querySelectorAll("[data-queue] [data-play]")).filter((disc) => {
      if (seen.has(disc.dataset.play)) return false
      seen.add(disc.dataset.play)
      return true
    })
  },

  shelfId(button) {
    return button.dataset.queueId || window.location.pathname
  },

  // A shelf's Play all: pressed again while it is under way, it pauses
  // and resumes.
  playAll(button) {
    const id = this.shelfId(button)
    if (isQueue("shelf", id)) return toggle()
    const chants = this.discs().map((disc) => this.discChant(disc))
    if (chants.length === 0) return
    playQueue({
      kind: "shelf",
      id,
      title: button.dataset.queueTitle || "Play all",
      entries: chants.map(({ id, src }) => ({ id, src, origin: null })),
      facts: Object.fromEntries(chants.map((c) => [c.id, c.facts])),
    })
  },

  // A sung set: from its start, or from a step (Play from Here). Pressed
  // again while it is under way, Play all pauses and resumes it, or sings
  // the chant waiting for a tap.
  playSet(set, origin = null) {
    if (!set) return
    if (origin == null && isQueue("set", set.dataset.set)) {
      if (session.waiting) return goOn()
      return toggle()
    }
    const entries = parse(set.dataset.entries, []).map(([id, src, origin]) => ({ id, src, origin }))
    const start = origin == null ? 0 : entries.findIndex((entry) => entry.origin === origin)
    if (start < 0 || entries.length === 0) return
    playQueue(
      {
        kind: "set",
        id: set.dataset.set,
        title: set.dataset.title || "",
        entries,
        facts: parse(set.dataset.chants, {}),
      },
      start
    )
  },

  // A list says a chant was passed over; the chant's page says its own
  // would not play
  showError(kind) {
    const error = this.el.querySelector("[data-role=error]")
    if (!error) return
    if (kind === "passed-over" && !this.player) error.hidden = false
    if (kind === "failed" && (!this.player || this.mine())) error.hidden = false
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
    this.tick(true, this.lines[i].start)
  },

  playFromLine(index) {
    if (!this.mine()) playOne(this.chant)
    this.seekToLine(index)
    if (this.audio.paused) toggle()
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

  tick(force, at) {
    if (!this.player) return
    const mine = this.mine()
    const time = at ?? (mine ? this.audio.currentTime || 0 : 0)

    // Repeat this line: at its end, back to its start.
    if (mine && this.lineRepeat && this.hasLines && !this.audio.paused && this.lineIndex != null) {
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
    if (mine && this.audio.duration && isFinite(this.audio.duration)) {
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
    this.el.querySelectorAll("[data-role=score-scrub]").forEach((scrub) => {
      const max = parseFloat(this.scrub?.max || scrub.max) || 1
      scrub.max = String(max)
      if (document.activeElement !== scrub) scrub.value = String(time)
      scrub.style.setProperty("--progress", `${Math.min(100, (time / max) * 100)}%`)
      scrub.setAttribute("aria-valuetext", `${clock(time)} of ${clock(max)}`)
    })
    const scoreTime = this.el.querySelector("[data-role=score-time]")
    if (scoreTime && mine && session.started) scoreTime.textContent = clock(time)
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
    if (!this.mine() || this.audio.paused) return
    this.tick()
    this.raf = requestAnimationFrame(() => this.frame())
  },

  paint() {
    const playing = session.playing
    const current = session.current?.id ?? null
    const q = session.queue

    if (playing) this.hideError()

    const pauses = pausesBetween()
    this.el.querySelectorAll("[data-pauses-between]").forEach((box) => {
      box.checked = pauses
    })

    this.el.querySelectorAll("[data-chant-row]").forEach((row) => {
      if (row.dataset.chantRow === current && playing) row.setAttribute("data-sounding", "")
      else row.removeAttribute("data-sounding")
    })
    this.el.querySelectorAll("[data-play]").forEach((disc) => {
      const on = disc.dataset.play === current && playing
      disc.setAttribute("aria-pressed", on ? "true" : "false")
      disc.setAttribute("aria-label", `${on ? "Pause" : "Play"} ${disc.dataset.label}`)
    })

    this.el.querySelectorAll("[data-set]").forEach((set) => {
      const mine = isQueue("set", set.dataset.set)
      const origin = mine ? q.entries[q.index]?.origin : null
      if (mine && playing) set.setAttribute("data-sounding", "")
      else set.removeAttribute("data-sounding")
      set.querySelectorAll("[data-origin]").forEach((row) => {
        const lit = mine && Number(row.dataset.origin) === origin
        row.toggleAttribute("data-lit", lit)
        row.toggleAttribute("data-sounding", lit && playing)
      })
      set.querySelectorAll("[data-play-set]").forEach((button) => {
        const going = mine && playing
        const word = !mine ? "Play all" : session.waiting ? "Play next" : going ? "Pause" : "Resume"
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
      tile.toggleAttribute("data-sounding", isQueue("set", tile.dataset.setTile) && playing)
    })

    const all = this.el.querySelector("[data-play-all]")
    if (all) {
      const mine = isQueue("shelf", this.shelfId(all))
      const word = all.querySelector("[data-play-all-word]")
      const label = !mine ? "Play all" : session.waiting ? "Play next" : playing ? "Pause" : "Resume"
      if (word) word.textContent = label
      all.setAttribute("aria-pressed", mine && playing ? "true" : "false")
    }

    if (this.player) {
      const mine = this.mine()
      const sounding = mine && playing
      this.player.querySelectorAll("[data-act=back], [data-act=on]").forEach((step) => {
        step.disabled = !(mine && session.started)
      })
      // The page's gold play, and the full score's disc when it is open
      this.el.querySelectorAll("[data-act=toggle]").forEach((play) => {
        play.setAttribute("aria-pressed", sounding ? "true" : "false")
        play.setAttribute("aria-label", `${sounding ? "Pause" : "Play"} ${play.dataset.label}`)
      })
      const repeat = this.player.querySelector("[data-act=repeat]")
      if (repeat) repeat.setAttribute("aria-pressed", this.lineRepeat ? "true" : "false")
      const speed = this.player.querySelector("[data-act=speed]")
      const slow = this.audio.playbackRate < 1
      if (speed) speed.setAttribute("aria-pressed", slow ? "true" : "false")
      const label = this.player.querySelector("[data-role=speed-label]")
      if (label) label.textContent = slow ? "¾×" : "1×"
      this.el.toggleAttribute("data-playing", sounding)
      this.tick(true)
      if (sounding) this.frame()
    }
  },
}
