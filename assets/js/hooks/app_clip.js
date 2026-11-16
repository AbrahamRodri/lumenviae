// AppClip: one silent loop of the app on /app. It keeps nothing.
//
// The video loads nothing until it comes on screen, plays only while it is
// on screen, and never plays by itself when the visitor asks for reduced
// motion: the poster stands, and the button offers Play. The button pauses
// and plays it (a loop that runs on needs a way to stop it), and once the
// visitor pauses one it stays paused.
const AppClip = {
  mounted() {
    this.video = this.el.querySelector("video")
    this.button = this.el.querySelector("[data-role=clip-toggle]")
    if (!this.video || !this.button) return

    const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.held = still
    this.button.hidden = false
    this.label()

    this.button.addEventListener("click", () => {
      if (this.video.paused) {
        this.held = false
        this.play()
      } else {
        this.held = true
        this.video.pause()
      }
      this.label()
    })

    this.video.addEventListener("play", () => this.label())
    this.video.addEventListener("pause", () => this.label())

    this.observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !this.held) this.play()
        else if (!entry.isIntersecting) this.video.pause()
      },
      { threshold: 0.25 }
    )
    this.observer.observe(this.el)
  },

  play() {
    if (this.video.preload === "none") this.video.preload = "auto"
    const started = this.video.play()
    if (started && started.catch) started.catch(() => this.label())
  },

  label() {
    const playing = !this.video.paused
    this.button.textContent = playing ? this.el.dataset.pause : this.el.dataset.play
    this.button.setAttribute("aria-pressed", playing ? "false" : "true")
  },

  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

export default AppClip
