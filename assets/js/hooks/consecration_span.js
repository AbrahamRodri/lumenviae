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

  // Lays every pair out side by side in a hidden copy and stacks when the
  // widest would not fit in the span's width.
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

    const ends = copy.querySelectorAll(".cons-span__end")
    const dates = copy.querySelectorAll(".cons-span__date")
    const arrow = copy.querySelector(".cons-span__arrow")
    const box = getComputedStyle(copy)
    const gap = parseFloat(box.columnGap) || 0
    const room = copy.clientWidth - (parseFloat(box.paddingLeft) || 0) - (parseFloat(box.paddingRight) || 0)
    const arrowWidth = arrow ? parseFloat(getComputedStyle(arrow).minWidth) || 0 : 0

    let widest = 0
    for (const [begin, end] of pairs.length ? pairs : [[dates[0].textContent, dates[1].textContent]]) {
      dates[0].textContent = begin
      dates[1].textContent = end
      widest = Math.max(widest, ends[0].offsetWidth + ends[1].offsetWidth + arrowWidth + 2 * gap)
    }

    copy.remove()
    this.stacked = widest > room
  },

  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

export default ConsecrationSpan
