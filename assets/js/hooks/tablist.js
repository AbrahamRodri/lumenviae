// Arrow-key navigation for the `role="tablist"` widget on /mysteries.
//
// ARIA asks a tablist to behave as a single stop in the tab order: Tab moves
// into and out of the whole group, and the arrow keys move between the tabs
// inside it. The server owns which tab is selected and renders the roving
// tabindex accordingly, so all this hook does is move focus and activate.
//
// Activation follows focus, which is the right pattern here: every panel is
// already rendered from state the LiveView holds, so selecting a tab is cheap
// and there is nothing to be gained by making the user press Enter as well.
const STEP = {
  ArrowRight: 1,
  ArrowDown: 1,
  ArrowLeft: -1,
  ArrowUp: -1
}

export default {
  mounted() {
    this.onKeyDown = (event) => {
      if (event.altKey || event.ctrlKey || event.metaKey) return

      const tabs = Array.from(this.el.querySelectorAll('[role="tab"]'))
      const current = tabs.indexOf(document.activeElement)
      if (current === -1) return

      let next
      if (event.key === "Home") {
        next = 0
      } else if (event.key === "End") {
        next = tabs.length - 1
      } else if (STEP[event.key]) {
        // Wrap around, so End-to-Home is one keystroke either way.
        next = (current + STEP[event.key] + tabs.length) % tabs.length
      } else {
        return
      }

      event.preventDefault()
      tabs[next].focus()
      tabs[next].click()
    }

    this.el.addEventListener("keydown", this.onKeyDown)
    this.revealSelected()
  },

  // On a phone the tablist scrolls sideways; keep the selected tab in view.
  updated() {
    this.revealSelected()
  },

  revealSelected() {
    const selected = this.el.querySelector('[role="tab"][aria-selected="true"]')
    if (!selected || this.el.scrollWidth <= this.el.clientWidth) return

    const list = this.el.getBoundingClientRect()
    const tab = selected.getBoundingClientRect()
    if (tab.left < list.left) {
      this.el.scrollLeft -= list.left - tab.left + 16
    } else if (tab.right > list.right) {
      this.el.scrollLeft += tab.right - list.right + 16
    }
  },

  destroyed() {
    this.el.removeEventListener("keydown", this.onKeyDown)
  }
}
