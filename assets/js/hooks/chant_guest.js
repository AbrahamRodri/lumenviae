// ChantGuest: a prayer's chant sung on a Consecration day's step, as the
// app's ChantGuest: its own <audio> in a box of its own, the gold play,
// the scrubber and the clock. Leaving the step stops it, as the app
// unloads it, so it is not the site's chant player (chant_session.js)
// and never stands in the mini player; its playing puts away a chant the
// Chant Library was singing, as the guest takes the player in the app.
//
// It keeps nothing and sends nothing. A recording that will not play is
// said only once play was pressed.

const clock = (seconds) => {
  const whole = Math.max(0, Math.floor(seconds || 0))
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`
}

export default {
  mounted() {
    this.audio = this.el.querySelector("audio")
    if (!this.audio) return
    this.pressed = false
    this.play = this.el.querySelector("[data-act=toggle]")
    this.scrub = this.el.querySelector("[data-role=scrub]")
    this.error = this.el.querySelector("[data-role=error]")

    this.play?.addEventListener("click", () => {
      if (this.audio.paused) return this.start()
      this.audio.pause()
    })
    this.scrub?.addEventListener("input", () => {
      this.audio.currentTime = parseFloat(this.scrub.value)
      this.tick()
    })
    for (const kind of ["play", "pause", "ended"]) this.audio.addEventListener(kind, () => this.paint())
    this.audio.addEventListener("timeupdate", () => this.tick())
    this.audio.addEventListener("loadedmetadata", () => this.tick())
    this.audio.addEventListener("error", () => {
      if (this.pressed && this.error) this.error.hidden = false
      this.paint()
    })
  },

  destroyed() {
    if (!this.audio) return
    this.audio.pause()
    this.audio.removeAttribute("src")
    this.audio.load()
  },

  start() {
    this.pressed = true
    if (this.error) this.error.hidden = true
    const playing = this.audio.play()
    if (playing && playing.catch) {
      playing.catch((err) => {
        if (err.name !== "AbortError" && err.name !== "NotAllowedError" && this.error) this.error.hidden = false
      })
    }
  },

  tick() {
    const time = this.audio.currentTime || 0
    const elapsed = this.el.querySelector("[data-role=elapsed]")
    if (elapsed) elapsed.textContent = clock(time)
    if (this.audio.duration && isFinite(this.audio.duration)) {
      const total = this.el.querySelector("[data-role=total]")
      if (total) total.textContent = clock(Math.round(this.audio.duration))
      if (this.scrub) this.scrub.max = String(this.audio.duration)
    }
    if (!this.scrub) return
    if (document.activeElement !== this.scrub) this.scrub.value = String(time)
    const max = parseFloat(this.scrub.max) || 1
    this.scrub.style.setProperty("--progress", `${Math.min(100, (time / max) * 100)}%`)
    this.scrub.setAttribute("aria-valuetext", `${clock(time)} of ${clock(max)}`)
  },

  paint() {
    const playing = !this.audio.paused && !this.audio.ended
    if (this.play) {
      this.play.setAttribute("aria-pressed", playing ? "true" : "false")
      this.play.setAttribute("aria-label", `${playing ? "Pause" : "Play"} ${this.play.dataset.label}`)
    }
    this.el.toggleAttribute("data-playing", playing)
  },
}
