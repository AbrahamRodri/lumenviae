// The Daily Missal's reading choices, this browser's own as the app keeps
// them in its settings: the Contents, "whole" (the Mass with the Ordinary,
// the default the server starts from) or "propers" (today's texts only),
// and whether the Mass is sung. On connect the saved choices go to the
// LiveView; a choice made on the page comes back to be saved. Storage
// missing or refused: the defaults.

const KEY = "lv:missal-reading"

export default {
  mounted() {
    let saved = null
    try {
      saved = JSON.parse(window.localStorage.getItem(KEY) || "null")
    } catch (_blocked) {
      saved = null
    }

    if (saved && typeof saved === "object" && !Array.isArray(saved)) {
      const contents = saved.contents === "propers" ? "propers" : "whole"
      const sung = saved.sung === true

      if (contents !== this.el.dataset.contents || String(sung) !== this.el.dataset.sung) {
        this.pushEvent("restore_reading", { contents, sung })
      }
    }

    this.handleEvent("store_missal_reading", ({ contents, sung }) => {
      try {
        window.localStorage.setItem(KEY, JSON.stringify({ contents, sung }))
      } catch (_blocked) {
        // Not remembered; the choice still applies on this page.
      }
    })
  }
}
