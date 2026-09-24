// Prays a whole Rosary aloud: every prayer, announcement and meditation of
// the set, one clip after another with a breath between them.
//
// The script comes from the server (LumenViae.Rosary.PrayerAudio.script/3,
// the same order the iOS app prays in) as data-script: a list of
// {url, caption, pause_ms, decade}. The hook owns playback and nothing
// else. When the voice reaches a new decade it tells the LiveView, which
// turns the page to that mystery; when the reader turns the page
// themselves the LiveView sends "spoken_seek" and the voice follows.
//
// Clips play through an Audio element rather than fetch(): the audio bucket
// sends no CORS headers, and a media element does not need them.
export default {
  mounted() {
    this.steps = JSON.parse(this.el.dataset.script || "[]")
    this.index = 0
    this.loadedIndex = null
    this.lastDecade = null
    this.playing = false
    this.finished = false
    this.timer = null

    const start = this.el.dataset.startDecade
    if (start) {
      const at = this.steps.findIndex((step) => step.decade === Number(start))
      if (at >= 0) {
        this.index = at
        this.lastDecade = Number(start)
      }
    }

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

    this.handleEvent("spoken_seek", ({ decade }) => this.seekDecade(decade))
    this.setUpMediaSession()
    this.render()

    // Turning the switch on is the gesture that allows sound; a browser
    // that still refuses leaves the Play button showing.
    this.play()
  },

  destroyed() {
    clearTimeout(this.timer)
    this.audio.pause()
    this.audio.removeAttribute("src")
    this.prefetch.removeAttribute("src")
    if ("mediaSession" in navigator) navigator.mediaSession.metadata = null
  },

  play() {
    if (this.steps.length === 0) return
    if (this.finished) {
      this.finished = false
      this.index = 0
      this.lastDecade = null
    }
    if (this.loadedIndex !== this.index) this.load()
    this.playing = true
    this.audio.play().catch(() => {
      this.playing = false
      this.render()
    })
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
    const next = Math.min(Math.max(this.index + offset, 0), this.steps.length - 1)
    clearTimeout(this.timer)
    this.finished = false
    this.index = next
    this.load()
    if (this.playing) this.audio.play().catch(() => {})
    this.render()
  },

  advance() {
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
      if (!this.playing) return
      this.load()
      this.audio.play().catch(() => {})
      this.render()
    }, pause)
    this.render()
  },

  seekDecade(decade) {
    const at = this.steps.findIndex((step) => step.decade === decade)
    if (at < 0) return
    clearTimeout(this.timer)
    this.finished = false
    this.index = at
    this.lastDecade = decade
    this.load()
    if (this.playing) this.audio.play().catch(() => {})
    this.render()
  },

  load() {
    const step = this.steps[this.index]
    if (!step) return
    this.loadedIndex = this.index
    this.audio.src = step.url

    const next = this.steps[this.index + 1]
    if (next && next.url !== step.url) this.prefetch.src = next.url

    if (step.decade !== null && step.decade !== this.lastDecade) {
      this.lastDecade = step.decade
      this.pushEvent("spoken_at", { decade: step.decade })
    }
  },

  render() {
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
