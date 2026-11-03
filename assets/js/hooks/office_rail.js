// OfficeRail: lights the part of an hour being read in the side rail of
// /hours/:date/:hour, as the app's rail and index light theirs: the last
// named section whose top has risen past the band under the top of the
// screen. Keeps nothing; the rail's links work without it.
export default {
  mounted() {
    this.onScroll = () => {
      if (this.frame) return
      this.frame = requestAnimationFrame(() => {
        this.frame = null
        this.light()
      })
    }
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.light()
  },

  updated() {
    this.light()
  },

  destroyed() {
    window.removeEventListener("scroll", this.onScroll)
    if (this.frame) cancelAnimationFrame(this.frame)
  },

  light() {
    const sections = this.el.querySelectorAll("[data-rail-section]")
    if (!sections.length) return

    const band = window.innerHeight * 0.25
    let current = sections[0].dataset.railSection
    for (const section of sections) {
      if (section.getBoundingClientRect().top <= band) current = section.dataset.railSection
      else break
    }

    for (const link of this.el.querySelectorAll("[data-rail-link]")) {
      if (link.dataset.railLink === current) link.setAttribute("aria-current", "location")
      else link.removeAttribute("aria-current")
    }
  }
}
