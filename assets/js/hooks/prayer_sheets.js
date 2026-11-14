// The prayer page's sheets (READ, VOICE, TEXT and MORE), which the server
// opens and shuts through data-open. As one opens, the focus moves into
// it; while it is open, Tab and Shift-Tab go round inside it; as it shuts,
// the focus goes back to the row button that opened it. Escape is
// PrayerSurface's, which asks the server to shut the sheet.
//
// Share, in MORE, hands the page's link to the system share sheet where
// there is one, and otherwise copies it.

const FOCUSABLE =
  'button:not([disabled]), a[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

export default {
  mounted() {
    this.open = this.el.dataset.open || ""

    this.onKey = (event) => {
      if (event.key !== "Tab" || !this.open) return
      const sheet = this.sheet()
      if (!sheet) return
      const items = [...sheet.querySelectorAll(FOCUSABLE)]
      if (items.length === 0) return
      const first = items[0]
      const last = items[items.length - 1]
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first.focus()
      } else if (!sheet.contains(document.activeElement)) {
        event.preventDefault()
        first.focus()
      }
    }
    document.addEventListener("keydown", this.onKey)

    this.onClick = (event) => {
      const button = event.target.closest && event.target.closest("[data-share]")
      if (button) this.share(button)
    }
    this.el.addEventListener("click", this.onClick)
  },

  updated() {
    const open = this.el.dataset.open || ""
    if (open === this.open) return
    const was = this.open
    this.open = open

    if (open) {
      const sheet = this.sheet()
      if (!sheet) return
      sheet.scrollTop = 0
      const first = sheet.querySelector(FOCUSABLE)
      if (first) first.focus({ preventScroll: true })
    } else if (was) {
      const opener = document.getElementById(`sheet-button-${was}`)
      if (opener) opener.focus({ preventScroll: true })
    }
  },

  destroyed() {
    document.removeEventListener("keydown", this.onKey)
  },

  sheet() {
    return this.open ? document.getElementById(`sheet-${this.open}`) : null
  },

  async share(button) {
    const url = window.location.origin + window.location.pathname
    const status = this.el.querySelector("[data-share-status]")
    const say = (words) => {
      if (status) status.textContent = words
    }

    if (navigator.share) {
      try {
        await navigator.share({ title: button.dataset.title, url })
      } catch (_cancelled) {
        // The reader closed the share sheet.
      }
      return
    }

    try {
      await navigator.clipboard.writeText(url)
      say("Link copied")
    } catch (_refused) {
      say(url)
    }
  }
}
