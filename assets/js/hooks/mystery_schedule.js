// Which weekly schedule today's mysteries follow, this browser's own
// choice as the app keeps it in Settings: "traditional", the default the
// server starts from, or "modern" (Luminous on Thursday, Joyful on
// Saturday). On connect the saved choice goes to the LiveView, as the
// UserTimezone hook sends the offset; a choice made on the page comes back
// to be saved. Storage missing or refused: the traditional schedule.

const KEY = "lv:schedule"

export default {
  mounted() {
    let saved = null
    try {
      saved = window.localStorage.getItem(KEY)
    } catch (_blocked) {
      saved = null
    }

    if (saved && saved !== this.el.dataset.schedule) {
      this.pushEvent("restore_schedule", { schedule: saved })
    }

    this.handleEvent("store_schedule", ({ schedule }) => {
      try {
        window.localStorage.setItem(KEY, schedule)
      } catch (_blocked) {
        // Not remembered; the choice still applies on this page.
      }
    })
  }
}
