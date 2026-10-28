// Keeps the category page's "Your Rosary Today" choices in this browser.
// On connect it hands the saved copy to the LiveView; on every change the
// LiveView sends the new choices back to be saved. Storage can be missing
// or refused (private windows, blocked site data): the page then simply
// starts from its defaults.
const KEY = "lumenviae:rosary-choices"

export default {
  mounted() {
    let saved = null

    try {
      saved = JSON.parse(window.localStorage.getItem(KEY) || "null")
    } catch (_error) {
      saved = null
    }

    if (saved && typeof saved === "object" && !Array.isArray(saved)) {
      this.pushEvent("restore_choices", saved)
    }

    this.handleEvent("store_choices", (choices) => {
      try {
        window.localStorage.setItem(KEY, JSON.stringify(choices))
      } catch (_error) {
        // Not remembered this time; the choice still applies on this page.
      }
    })
  }
}
