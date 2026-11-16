// ConsecrationSpan: the chooser's two dates above Begin (You begin, You
// consecrate) stand side by side only while each fits on one line; at
// large text, a narrow phone or 200% zoom they stack (design, 16 Nov 2026:
// "never two lines for one date"). CSS cannot know whether two dates of
// different lengths fit, so this measures them: every feast's pair (the
// span's data-pairs), so one layout holds for them all and the foot keeps
// its shape as the reader taps from feast to feast. It keeps nothing.
//
// Without JavaScript the two ends wrap onto their own lines by themselves.
const ConsecrationSpan = {
  mounted() {
    this.measure = () => {
      this.decide()
      this.apply()
    }
    if ("ResizeObserver" in window) {
      this.observer = new ResizeObserver(this.measure)
      this.observer.observe(this.el.parentElement)
    }
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(this.measure)
    this.measure()
  },

  // A tap re-renders the span: put the chosen layout back.
  updated() {
    this.apply()
  },

  apply() {
    this.el.classList.toggle("is-stacked", this.stacked === true)
  },

  // Lays every pair out side by side in a hidden copy and stacks when any
  // would not fit in the span's width.
  decide() {
    let pairs
    try {
      pairs = JSON.parse(this.el.dataset.pairs || "[]")
    } catch (_error) {
      pairs = []
    }

    const copy = this.el.cloneNode(true)
    copy.removeAttribute("id")
    copy.classList.remove("is-stacked")
    copy.setAttribute("aria-hidden", "true")
    Object.assign(copy.style, { position: "absolute", visibility: "hidden", left: "0", top: "0", width: this.el.clientWidth + "px" })
    this.el.parentElement.appendChild(copy)

    // Side by side the span is a grid whose date columns never shrink, so
    // a pair that does not fit makes the copy wider than its box; the two
    // labels share the top row and must fit beside each other too.
    const dates = copy.querySelectorAll(".cons-span__date")
    const labels = copy.querySelectorAll(".cons-span__label")
    const gap = parseFloat(getComputedStyle(copy).columnGap) || 0
    let overflows = labels[0].offsetWidth + labels[1].offsetWidth + gap > copy.clientWidth
    for (const [begin, end] of pairs.length ? pairs : [[dates[0].textContent, dates[1].textContent]]) {
      dates[0].textContent = begin
      dates[1].textContent = end
      if (copy.scrollWidth > copy.clientWidth + 0.5) overflows = true
    }

    copy.remove()
    this.stacked = overflows
  },

  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

export default ConsecrationSpan
