// How the prayer page looks, chosen in its settings pane: the meditation
// on night (the default, as the app reads it) or on a vellum page, and the
// mystery's woodcut shown or not, and the prayer's words and beads shown
// or not. The first value of each is the default.
// Like the text size, the choice is this browser's alone (localStorage)
// and lives as an attribute on <html>, which a LiveView patch never
// touches; the CSS reads data-reading-page and data-prayer-images.
//
// PrayerSurface calls applyDisplay() as the page mounts and clearDisplay()
// as it leaves. DisplayChoices sits on the pane's buttons (inside
// phx-update="ignore", so the server never resets aria-pressed) and keeps
// them true to the attributes. A button with data-toggle is a switch
// (role="switch"): pressing it flips the setting between its two values,
// and aria-checked is true while it is on, the first value.

export const DISPLAY = {
  "reading-page": { key: "lv:pray:reading-page", attr: "readingPage", values: ["night", "vellum"] },
  "prayer-images": { key: "lv:pray:images", attr: "prayerImages", values: ["on", "off"] },
  "prayer-words": { key: "lv:pray:words", attr: "prayerWords", values: ["on", "off"] }
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
      if (!setting) return
      const value = button.hasAttribute("data-toggle")
        ? setting.values.find((v) => v !== current(button.dataset.display))
        : button.dataset.value
      if (!setting.values.includes(value)) return
      document.documentElement.dataset[setting.attr] = value
      storage.set(setting.key, value)
      this.sync()
    }
    this.el.addEventListener("click", this.onClick)
  },

  sync() {
    this.el.querySelectorAll("[data-display]").forEach((button) => {
      if (button.hasAttribute("data-toggle")) {
        const on = current(button.dataset.display) === DISPLAY[button.dataset.display].values[0]
        button.setAttribute("aria-checked", String(on))
      } else {
        button.setAttribute("aria-pressed", String(current(button.dataset.display) === button.dataset.value))
      }
    })
  }
}
