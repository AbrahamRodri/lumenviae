// AppRise: on /app, the painting rows and the tiles rise once into place as
// they come on screen. It keeps nothing.
//
// Only this hook hides them (the .app-c--rise class), so without
// JavaScript, or when the visitor asks for reduced motion (the CSS then
// leaves them alone), every one simply stands in place.
const AppRise = {
  mounted() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    if (!("IntersectionObserver" in window)) return

    const items = this.el.querySelectorAll("[data-rise]")
    this.observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue
          entry.target.classList.add("is-in")
          this.observer.unobserve(entry.target)
        }
      },
      { threshold: 0.15 }
    )

    this.el.classList.add("app-c--rise")
    items.forEach((item) => this.observer.observe(item))
  },

  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

export default AppRise
