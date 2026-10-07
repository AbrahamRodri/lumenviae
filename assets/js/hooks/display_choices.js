// How the prayer page looks, chosen in its settings pane: the meditation
// on a vellum page or on night, and the mystery's woodcut shown or not.
// Like the text size, the choice is this browser's alone (localStorage)
// and lives as an attribute on <html>, which a LiveView patch never
// touches; the CSS reads data-reading-page and data-prayer-images.
//
// PrayerSurface calls applyDisplay() as the page mounts and clearDisplay()
// as it leaves. DisplayChoices sits on the pane's buttons (inside
// phx-update="ignore", so the server never resets aria-pressed) and keeps
// them true to the attributes.

export const DISPLAY = {
  "reading-page": { key: "lv:pray:reading-page", attr: "readingPage", values: ["vellum", "night"] },
  "prayer-images": { key: "lv:pray:images", attr: "prayerImages", values: ["on", "off"] }
}

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
      // Private windows and blocked storage: the choice lasts the visit.
    }
  }
}

const current = (name) => {
  const setting = DISPLAY[name]
  const value = document.documentElement.dataset[setting.attr]
  return setting.values.includes(value) ? value : setting.values[0]
}

export function applyDisplay() {
  for (const [name, setting] of Object.entries(DISPLAY)) {
    const stored = storage.get(setting.key)
    document.documentElement.dataset[setting.attr] = setting.values.includes(stored) ? stored : current(name)
  }
}

export function clearDisplay() {
  for (const setting of Object.values(DISPLAY)) delete document.documentElement.dataset[setting.attr]
}

export default {
  mounted() {
    this.sync()
    this.onClick = (event) => {
      const button = event.target.closest("[data-display]")
      if (!button) return
      const setting = DISPLAY[button.dataset.display]
      if (!setting || !setting.values.includes(button.dataset.value)) return
      document.documentElement.dataset[setting.attr] = button.dataset.value
      storage.set(setting.key, button.dataset.value)
      this.sync()
    }
    this.el.addEventListener("click", this.onClick)
  },

  sync() {
    this.el.querySelectorAll("[data-display]").forEach((button) => {
      button.setAttribute("aria-pressed", String(current(button.dataset.display) === button.dataset.value))
    })
  }
}
