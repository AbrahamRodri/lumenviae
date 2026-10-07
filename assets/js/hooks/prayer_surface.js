// The prayer page's surface: the keys and swipes that move through the
// Rosary, the text size, and keeping the screen awake while praying.
//
// Keys: counting on the screen, Space, Enter, ArrowDown and ArrowRight
// move a bead on and ArrowUp and ArrowLeft move one back; counting on a
// rosary, only the left and right arrows turn the page, so Space and the
// up and down arrows still scroll a long meditation. A key pressed on a
// button, link or field is that control's, never the page's.
//
// The text size is this browser's alone, kept in localStorage, and set as
// a CSS variable on <html> so a LiveView patch never takes it away.

const ADVANCE = ["ArrowRight", "ArrowDown", " ", "Spacebar", "Enter"]
const BACK = ["ArrowLeft", "ArrowUp"]
const SCALES = [0.9, 1, 1.12, 1.25, 1.4, 1.6]
const SIZE_KEY = "lv:pray:text-size"
const SWIPE_DISTANCE = 50

const storage = {
  get(key) {
    try {
      return window.localStorage.getItem(key)
    } catch (_blocked) {
      return null
    }
  },
  set(key, value) {
    try {
      window.localStorage.setItem(key, value)
    } catch (_blocked) {
      // Private windows and blocked storage: the size lasts the visit.
    }
  }
}

export default {
  mounted() {
    this.sizeIndex = Number(storage.get(SIZE_KEY))
    if (!Number.isInteger(this.sizeIndex) || !SCALES[this.sizeIndex]) this.sizeIndex = 1
    this.applySize()

    this.onKey = (event) => this.key(event)
    window.addEventListener("keydown", this.onKey)

    this.onClick = (event) => {
      const button = event.target.closest("[data-text-size]")
      if (!button) return
      const next = this.sizeIndex + Number(button.dataset.textSize)
      this.sizeIndex = Math.min(Math.max(next, 0), SCALES.length - 1)
      storage.set(SIZE_KEY, String(this.sizeIndex))
      this.applySize()
    }
    this.el.addEventListener("click", this.onClick)

    this.onTouchStart = (event) => {
      const touch = event.changedTouches[0]
      this.touch = { x: touch.clientX, y: touch.clientY }
    }
    this.onTouchEnd = (event) => this.swipe(event)
    this.el.addEventListener("touchstart", this.onTouchStart, { passive: true })
    this.el.addEventListener("touchend", this.onTouchEnd, { passive: true })

    this.handleEvent("prayer:top", () => {
      const smooth = !window.matchMedia("(prefers-reduced-motion: reduce)").matches
      window.scrollTo({ top: 0, behavior: smooth ? "smooth" : "auto" })
    })

    this.onVisibility = () => {
      if (document.visibilityState === "visible") this.keepAwake()
    }
    document.addEventListener("visibilitychange", this.onVisibility)
    this.keepAwake()
  },

  destroyed() {
    window.removeEventListener("keydown", this.onKey)
    document.removeEventListener("visibilitychange", this.onVisibility)
    document.documentElement.style.removeProperty("--prayer-text-scale")
    this.release()
  },

  counting() {
    return this.el.dataset.count
  },

  key(event) {
    if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return
    const target = event.target
    if (target.closest && target.closest("button, a, input, select, textarea, summary, [contenteditable]")) return

    const screen = this.counting() === "screen"
    const moves = screen
      ? ADVANCE.includes(event.key) || BACK.includes(event.key)
      : event.key === "ArrowRight" || event.key === "ArrowLeft"
    if (!moves) return

    event.preventDefault()
    this.pushEvent("key_nav", { key: event.key })
  },

  // Counting on the screen, a swipe left is the next bead and a swipe right
  // the one before; a mostly vertical drag is a scroll and is left alone.
  swipe(event) {
    if (!this.touch || this.counting() !== "screen") return
    const touch = event.changedTouches[0]
    const dx = touch.clientX - this.touch.x
    const dy = touch.clientY - this.touch.y
    this.touch = null
    if (Math.abs(dx) < SWIPE_DISTANCE || Math.abs(dx) < Math.abs(dy) * 1.5) return
    if (event.target.closest && event.target.closest("button, a, input, select, textarea")) return
    this.pushEvent("key_nav", { key: dx < 0 ? "ArrowRight" : "ArrowLeft" })
  },

  applySize() {
    document.documentElement.style.setProperty("--prayer-text-scale", String(SCALES[this.sizeIndex]))
  },

  // The Screen Wake Lock API, where there is one. The browser lets go of
  // the lock whenever the page is hidden, so it is asked for again on the
  // way back. Unsupported or refused, the screen sleeps as it always did.
  async keepAwake() {
    if (!("wakeLock" in navigator) || this.lock) return
    try {
      this.lock = await navigator.wakeLock.request("screen")
      this.lock.addEventListener("release", () => {
        this.lock = null
      })
    } catch (_refused) {
      this.lock = null
    }
  },

  release() {
    if (!this.lock) return
    this.lock.release().catch(() => {})
    this.lock = null
  }
}
