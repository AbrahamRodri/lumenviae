// Prays a whole Rosary aloud: every prayer, announcement and meditation of
// the set, one clip after another with a breath between them.
//
// The script comes from the server (LumenViae.Rosary.PrayerAudio.script/3,
// the same order the iOS app prays in) as data-script: a list of
// {url, kind, lines, caption, pause_ms, page, screen}, where page and
// screen are where the prayer page shows that step, kind is what is heard
// (a meditation, a prayer, a verse, an announcement) and lines its timed
// lines ({text, start, end}, in seconds), or null where the recording has
// none. The hook owns playback. Each time the voice reaches another screen
// it tells the LiveView
// ("spoken_at"), which turns the page, or moves the bead when counting on
// the screen; when the reader moves themselves the LiveView sends
// "spoken_seek" and the voice follows. Seeks are numbered, and every
// "spoken_at" carries the number of the last one heard, so the LiveView can
// tell a report sent before the reader's latest move from one sent after.
//
// As the app's simple Rosary does, it starts on its own (the tap on Pray
// that opened the page lets a browser play; a page opened cold waits for
// Play); the prayers are heard at the reader's speed, kept in this browser,
// and a meditation always at its own; and the speaker mutes it without
// stopping it, the Rosary moving on at the recording's pace. Where a
// recording is timed, the line being read is lit on the page
// ([data-timed] [data-line], from LumenViaeWeb.Live.Pray.PrayerText) and
// kept in view, whether muted or not; with no timings nothing is lit.
//
// Destroyed (a voice, form or closing prayer changed), the hook lets
// go of everything the page outlives: the clip, the lock-screen controls
// and any timer, and a late callback finds it dead and does nothing.
//
// Clips play through an Audio element rather than fetch(): the audio bucket
// sends no CORS headers, and a media element does not need them.
import { relinquish as putAwayChant, session as chantSession } from "../chant_session"

const MEDIA_ACTIONS = ["play", "pause", "previoustrack", "nexttrack"]
const RATE_KEY = "lv:pray:prayer-rate"
const RATES = [0.8, 0.9, 1, 1.1, 1.2, 1.3]

// A read that fails (private mode, storage off) is no choice made.
function savedRate() {
  try {
    const rate = Number(window.localStorage.getItem(RATE_KEY))
    return RATES.includes(rate) ? rate : 1
  } catch (_blocked) {
    return 1
  }
}

function saveRate(rate) {
  try {
    window.localStorage.setItem(RATE_KEY, String(rate))
  } catch (_blocked) {
    // Kept for this page only.
  }
}

export default {
  mounted() {
    this.steps = JSON.parse(this.el.dataset.script || "[]")
    this.index = 0
    this.loadedIndex = null
    this.lastScreen = null
    this.playing = false
    this.finished = false
    this.timer = null
    this.seek = 0
    this.dead = false
    this.rate = savedRate()
    this.litLine = null

    const start = Number(this.el.dataset.startScreen || 0)
    const at = this.steps.findIndex((step) => step.screen >= start)
    if (at >= 0) this.index = at

    this.audio = new Audio()
    this.audio.preload = "auto"
    this.prefetch = new Audio()
    this.prefetch.preload = "auto"

    this.playButton = this.el.querySelector("[data-play]")
    this.pauseButton = this.el.querySelector("[data-pause]")
    this.playButton.addEventListener("click", () => this.play())
    this.pauseButton.addEventListener("click", () => this.pause())

    // The speaker sits in the top bar, outside the player, and outlives it:
    // a player remounted for another voice takes up its state.
    this.muteButton = document.querySelector("[data-mute]")
    this.onMuteClick = () => this.toggleMute()
    if (this.muteButton) {
      this.audio.muted = this.muteButton.getAttribute("aria-pressed") === "true"
      this.muteButton.addEventListener("click", this.onMuteClick)
    }

    // The speed buttons sit in the settings pane, outside the player.
    this.onRateClick = (event) => {
      const button = event.target.closest && event.target.closest("[data-prayer-rate]")
      if (!button) return
      const rate = Number(button.dataset.prayerRate)
      if (!RATES.includes(rate)) return
      this.rate = rate
      saveRate(rate)
      this.applyRate()
      this.showRate()
    }
    document.addEventListener("click", this.onRateClick)
    this.showRate()

    this.audio.addEventListener("timeupdate", () => this.light())

    this.audio.addEventListener("ended", () => this.advance())
    // The Rosary aloud takes the speakers: a chant still singing from the
    // Chant Library is put away, as the app's claim does. This Audio is not
    // in the page, so the site's document-wide listener does not hear it.
    this.audio.addEventListener("play", () => {
      if (chantSession.active) putAwayChant()
    })
    // A clip that will not load is skipped, as the app does, rather than
    // stopping the Rosary on a bead.
    this.audio.addEventListener("error", () => {
      if (this.playing) this.advance()
    })

    this.handleEvent("spoken_seek", ({ screen, seek }) => {
      if (typeof seek === "number") this.seek = seek
      this.seekScreen(screen)
    })
    // Remounted by a tap (another voice, form or closing prayer chosen),
    // the LiveView says so, and it starts.
    this.handleEvent("spoken_play", () => this.play())
    this.setUpMediaSession()
    this.render()
    // Starts on its own. A browser that refuses sound before a tap (a page
    // opened from a link or a reload) leaves the Play button showing.
    this.play()
  },

  destroyed() {
    this.dead = true
    this.playing = false
    clearTimeout(this.timer)
    document.removeEventListener("click", this.onRateClick)
    if (this.muteButton) this.muteButton.removeEventListener("click", this.onMuteClick)
    this.unlight()
    this.audio.pause()
    for (const audio of [this.audio, this.prefetch]) {
      audio.removeAttribute("src")
      audio.load()
    }
    if ("mediaSession" in navigator) {
      const session = navigator.mediaSession
      for (const action of MEDIA_ACTIONS) {
        try {
          session.setActionHandler(action, null)
        } catch (_unsupported) {
          // Never set, so nothing to clear.
        }
      }
      session.metadata = null
      session.playbackState = "none"
    }
  },

  // Starts the loaded clip. A browser that will not play without a gesture
  // stops the Rosary and shows Play; a clip interrupted by the next one
  // loading (AbortError) is not a refusal and leaves it playing.
  start() {
    this.audio.play().catch((error) => {
      if (this.dead || error?.name === "AbortError") return
      this.playing = false
      this.render()
    })
  },

  play() {
    if (this.dead || this.steps.length === 0) return
    if (this.finished) {
      this.finished = false
      this.index = 0
      this.lastScreen = null
    }
    if (this.loadedIndex !== this.index) this.load()
    this.playing = true
    this.start()
    this.render()
  },

  pause() {
    this.playing = false
    clearTimeout(this.timer)
    this.audio.pause()
    this.render()
  },

  // The lock screen's back and forward move a whole prayer, so a Hail Mary
  // missed while distracted can be said again.
  step(offset) {
    if (this.dead) return
    const next = Math.min(Math.max(this.index + offset, 0), this.steps.length - 1)
    clearTimeout(this.timer)
    this.finished = false
    this.index = next
    this.load()
    if (this.playing) this.start()
    this.render()
  },

  advance() {
    if (this.dead) return
    const pause = this.steps[this.index]?.pause_ms ?? 700
    this.index += 1
    this.unlight()

    if (this.index >= this.steps.length) {
      this.playing = false
      this.finished = true
      this.render()
      return
    }

    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      if (!this.playing || this.dead) return
      this.load()
      this.start()
      this.render()
    }, pause)
    this.render()
  },

  // A screen with nothing to play (a meditation with no narration) starts
  // the voice at the next one that has.
  seekScreen(screen) {
    if (this.dead || typeof screen !== "number") return
    const at = this.steps.findIndex((step) => step.screen >= screen)
    if (at < 0) return
    clearTimeout(this.timer)
    this.finished = false
    this.index = at
    this.lastScreen = this.steps[at].screen
    this.load()
    if (this.playing) this.start()
    this.render()
  },

  load() {
    const step = this.steps[this.index]
    if (this.dead || !step) return
    this.loadedIndex = this.index
    this.audio.src = step.url
    this.applyRate()
    this.unlight()

    const next = this.steps[this.index + 1]
    if (next && next.url !== step.url) this.prefetch.src = next.url

    if (step.screen !== this.lastScreen) {
      this.lastScreen = step.screen
      this.pushEvent("spoken_at", { page: step.page, screen: step.screen, seek: this.seek })
    }
  },

  // The prayers at the reader's speed; a meditation always at its own, as
  // the app hears it. Its pitch is kept, so a faster prayer is not higher.
  applyRate() {
    const step = this.steps[this.index]
    const rate = step && step.kind === "meditation" ? 1 : this.rate
    this.audio.preservesPitch = true
    this.audio.playbackRate = rate
    this.audio.defaultPlaybackRate = rate
  },

  showRate() {
    for (const button of document.querySelectorAll("[data-prayer-rate]")) {
      button.setAttribute("aria-pressed", String(Number(button.dataset.prayerRate) === this.rate))
    }
  },

  toggleMute() {
    if (!this.muteButton) return
    this.audio.muted = !this.audio.muted
    this.muteButton.setAttribute("aria-pressed", String(this.audio.muted))
    this.muteButton.setAttribute("aria-label", this.audio.muted ? "Unmute" : "Mute")
    this.muteButton.querySelector("[data-speaker-on]").classList.toggle("hidden", this.audio.muted)
    this.muteButton.querySelector("[data-speaker-off]").classList.toggle("hidden", !this.audio.muted)
  },

  // The line the recording is on, lit where the page shows those words: on
  // the screen this step belongs to, in the block of its kind of words.
  // Between lines the last one read stays lit; before the first, none.
  light() {
    if (this.dead) return
    const step = this.steps[this.index]
    if (!step || !step.lines || this.loadedIndex !== this.index) return this.unlight()

    const block = document.querySelector(
      `[data-screen="${step.screen}"] [data-timed="${step.kind}"]`
    )
    if (!block) return this.unlight()

    const time = this.audio.currentTime
    let line = -1
    step.lines.forEach((timed, index) => {
      if (timed.start <= time) line = index
    })
    if (line < 0) return this.unlight()

    const key = `${step.screen}:${step.kind}:${line}`
    const words = block.querySelectorAll(`[data-line="${line}"]`)
    // Re-lit each time, since a render of the page clears the class.
    for (const word of block.querySelectorAll("[data-line].is-read")) {
      if (word.dataset.line !== String(line)) word.classList.remove("is-read")
    }
    for (const word of words) word.classList.add("is-read")

    if (key !== this.litLine && words.length > 0) {
      this.litLine = key
      // A long prayer is not shrunk to fit: the page moves with the line.
      const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
      words[0].scrollIntoView({ block: "center", behavior: reduce ? "auto" : "smooth" })
    }
  },

  unlight() {
    this.litLine = null
    for (const word of document.querySelectorAll("[data-timed] [data-line].is-read")) {
      word.classList.remove("is-read")
    }
  },

  render() {
    if (this.dead) return
    const step = this.steps[Math.min(this.index, this.steps.length - 1)]

    this.playButton.classList.toggle("hidden", this.playing)
    this.pauseButton.classList.toggle("hidden", !this.playing)

    if ("mediaSession" in navigator && step && typeof MediaMetadata !== "undefined") {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: this.finished ? "Amen" : step.caption,
        artist: this.el.dataset.setName || "Lumen Viae",
        album: "The Holy Rosary"
      })
      navigator.mediaSession.playbackState = this.playing ? "playing" : "paused"
    }
  },

  // Lock screen and headphone controls: play, pause, and a prayer back or
  // forward (on the page, Back and Next move a bead and the voice follows).
  setUpMediaSession() {
    if (!("mediaSession" in navigator)) return
    const session = navigator.mediaSession
    const handlers = {
      play: () => this.play(),
      pause: () => this.pause(),
      previoustrack: () => this.step(-1),
      nexttrack: () => this.step(1)
    }
    for (const [action, handler] of Object.entries(handlers)) {
      try {
        session.setActionHandler(action, handler)
      } catch (_unsupported) {
        // Not every browser knows every action.
      }
    }
  }
}
