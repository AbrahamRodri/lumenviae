// Prays a whole Rosary aloud: every prayer, announcement and meditation of
// the set, one clip after another with a breath between them.
//
// The script comes from the server (LumenViae.Rosary.PrayerAudio.script/3,
// the same order the iOS app prays in) as data-script: a list of
// {url, caption, pause_ms, page, screen}, where page and screen are where
// the prayer page shows that step. The hook owns playback and nothing
// else. Each time the voice reaches another screen it tells the LiveView
// ("spoken_at"), which turns the page, or moves the bead when counting on
// the screen; when the reader moves themselves the LiveView sends
// "spoken_seek" and the voice follows. Seeks are numbered, and every
// "spoken_at" carries the number of the last one heard, so the LiveView can
// tell a report sent before the reader's latest move from one sent after.
//
// Destroyed (the switch turned off, a voice or form changed), the hook lets
// go of everything the page outlives: the clip, the lock-screen controls
// and any timer, and a late callback finds it dead and does nothing.
//
// Clips play through an Audio element rather than fetch(): the audio bucket
// sends no CORS headers, and a media element does not need them.
const MEDIA_ACTIONS = ["play", "pause", "previoustrack", "nexttrack"]

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

    const start = Number(this.el.dataset.startScreen || 0)
    const at = this.steps.findIndex((step) => step.screen >= start)
    if (at >= 0) this.index = at

    this.audio = new Audio()
    this.audio.preload = "auto"
    this.prefetch = new Audio()
    this.prefetch.preload = "auto"

    this.caption = this.el.querySelector("[data-caption]")
    this.bar = this.el.querySelector("[data-progress]")
    this.playButton = this.el.querySelector("[data-play]")
    this.pauseButton = this.el.querySelector("[data-pause]")

    this.playButton.addEventListener("click", () => this.play())
    this.pauseButton.addEventListener("click", () => this.pause())
    this.el.querySelector("[data-back]").addEventListener("click", () => this.step(-1))
    this.el.querySelector("[data-forward]").addEventListener("click", () => this.step(1))

    this.audio.addEventListener("ended", () => this.advance())
    // A clip that will not load is skipped, as the app does, rather than
    // stopping the Rosary on a bead.
    this.audio.addEventListener("error", () => {
      if (this.playing) this.advance()
    })

    this.handleEvent("spoken_seek", ({ screen, seek }) => {
      if (typeof seek === "number") this.seek = seek
      this.seekScreen(screen)
    })
    // Never started on arrival: a browser allows sound only after a tap, so
    // the reader presses Play. When the player appears because of a tap -
    // the switch turned on, another voice, form or closing prayer chosen -
    // the LiveView says so, and it starts; a browser that still refuses
    // leaves the Play button showing.
    this.handleEvent("spoken_play", () => this.play())
    this.setUpMediaSession()
    this.render()
  },

  destroyed() {
    this.dead = true
    this.playing = false
    clearTimeout(this.timer)
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

  // Back and forward move a whole prayer, so a Hail Mary missed while
  // distracted can be said again.
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

    const next = this.steps[this.index + 1]
    if (next && next.url !== step.url) this.prefetch.src = next.url

    if (step.screen !== this.lastScreen) {
      this.lastScreen = step.screen
      this.pushEvent("spoken_at", { page: step.page, screen: step.screen, seek: this.seek })
    }
  },

  render() {
    if (this.dead) return
    const step = this.steps[Math.min(this.index, this.steps.length - 1)]

    this.caption.textContent = this.finished
      ? "Amen. Press Complete to finish your Rosary."
      : step
        ? step.caption
        : "Nothing to play"

    const done = this.finished ? this.steps.length : this.index
    this.bar.style.width = `${this.steps.length ? (done / this.steps.length) * 100 : 0}%`

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
  // forward, the same as the buttons on the page.
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
