// The one-time hint that a bead is swiped, as the app's PrayerSwipeHint
// teaches it. Shown only on a touch screen, a moment after the bead screen
// settles, and only once in this browser: it is spent the moment it is
// shown, not when it is dismissed, so leaving early does not earn a second
// showing. It leaves after five seconds, at the first bead moved (the
// LiveView changes data-place), or when dismissed.

const SEEN_KEY = "lv:pray:swipe-hint-seen"
const SETTLE_MS = 800
const SHOWN_MS = 5000

const storage = {
  seen() {
    try {
      return window.localStorage.getItem(SEEN_KEY) === "1"
    } catch (_blocked) {
      // Unreadable storage: never shown, rather than shown every visit.
      return true
    }
  },
  spend() {
    try {
      window.localStorage.setItem(SEEN_KEY, "1")
    } catch (_blocked) {
      // Private windows: shown this once.
    }
  }
}

export default {
  mounted() {
    this.place = this.el.dataset.place
    this.hint = this.el.querySelector("[data-hint]")
    if (!this.hint || storage.seen() || !window.matchMedia("(pointer: coarse)").matches) return

    this.el.querySelector("[data-dismiss]")?.addEventListener("click", () => this.dismiss())

    this.settle = window.setTimeout(() => {
      storage.spend()
      this.hint.hidden = false
      this.expire = window.setTimeout(() => this.dismiss(), SHOWN_MS)
    }, SETTLE_MS)
  },

  updated() {
    if (this.el.dataset.place !== this.place) this.dismiss()
  },

  destroyed() {
    this.clear()
  },

  dismiss() {
    this.clear()
    if (this.hint) this.hint.hidden = true
  },

  clear() {
    window.clearTimeout(this.settle)
    window.clearTimeout(this.expire)
  }
}
