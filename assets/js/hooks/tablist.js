// Arrow-key navigation for the `role="tablist"` widgets on the learn pages.
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
  },

  destroyed() {
    this.el.removeEventListener("keydown", this.onKeyDown)
  }
}
