// What this browser remembers of the prayer page, in localStorage only:
// where the reader was in a Rosary, so the page can offer "Continue where
// you left off", and which closing prayers they chose. Nothing here is sent
// anywhere but back to the page.
//
// A place is kept per set (or category) and form, under
// lv:pray:<key>, as {mystery, step, count, at}. The beginning is never
// saved, so arriving fresh does not wipe out the place to offer, and a
// place older than a week is not offered. The PrayerStreak hook clears it
// once the Rosary is complete.

const EXTRAS_KEY = "lv:pray:extras"
const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000

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

export default {
  mounted() {
    const extras = storage.get(EXTRAS_KEY)
    if (Array.isArray(extras) && extras.join(",") !== (this.el.dataset.extras || "")) {
      this.pushEvent("restore_extras", { extras })
    }

    this.handleEvent("prayer:extras", ({ extras }) => storage.set(EXTRAS_KEY, extras))

    const saved = storage.get(this.storageKey())
    if (saved && saved.mystery !== undefined && Date.now() - (saved.at || 0) < MAX_AGE_MS) {
      this.pushEvent("resume_available", saved)
    }

    this.save()
  },

  updated() {
    this.save()
  },

  storageKey() {
    return `lv:pray:${this.el.dataset.key}`
  },

  save() {
    const { mystery, step, count } = this.el.dataset
    if (mystery === "opening" && Number(step) === 0) return
    storage.set(this.storageKey(), { mystery, step: Number(step), count, at: Date.now() })
  }
}
