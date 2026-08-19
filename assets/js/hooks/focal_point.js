// Focal point picker for meditation set artwork.
//
// Clicking or dragging on the painting reports where the subject is, as a
// normalized pair the server stores and the phone reads back: (0.5, 0.24)
// means "the faces are 24% down the canvas", which is true at every crop
// size. The pair is pushed to the LiveView, which persists it.
//
// The push is debounced. Every push writes to the database and re-renders,
// so a curator dragging the crosshair would otherwise produce a burst of
// updates whose replies land out of order, and the crosshair would settle
// wherever the last reply happened to say rather than where the pointer is.
const DEBOUNCE_MS = 150

export default {
  mounted() {
    this.pending = null
    this.timer = null

    this.onPointerDown = (event) => {
      this.dragging = true
      this.el.setPointerCapture(event.pointerId)
      this.report(event)
    }

    this.onPointerMove = (event) => {
      if (this.dragging) this.report(event)
    }

    this.onPointerUp = (event) => {
      if (!this.dragging) return
      this.dragging = false
      this.report(event)
      this.flush()
    }

    this.el.addEventListener('pointerdown', this.onPointerDown)
    this.el.addEventListener('pointermove', this.onPointerMove)
    this.el.addEventListener('pointerup', this.onPointerUp)
    this.el.addEventListener('pointercancel', this.onPointerUp)
  },

  destroyed() {
    if (this.timer) clearTimeout(this.timer)
    this.el.removeEventListener('pointerdown', this.onPointerDown)
    this.el.removeEventListener('pointermove', this.onPointerMove)
    this.el.removeEventListener('pointerup', this.onPointerUp)
    this.el.removeEventListener('pointercancel', this.onPointerUp)
  },

  report(event) {
    const box = this.el.getBoundingClientRect()
    if (!box.width || !box.height) return

    this.pending = {
      x: clamp((event.clientX - box.left) / box.width),
      y: clamp((event.clientY - box.top) / box.height)
    }

    this.moveCrosshair(this.pending)

    if (this.timer) return
    this.timer = setTimeout(() => this.flush(), DEBOUNCE_MS)
  },

  flush() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }

    if (!this.pending) return

    this.pushEvent('set_focal_point', this.pending)
    this.pending = null
  },

  // Moved here rather than waiting for the server round trip: at 150ms the
  // crosshair would visibly lag the pointer, and the reply repaints it in
  // the same place anyway.
  moveCrosshair({x, y}) {
    const crosshair = this.el.querySelector('[data-focal-crosshair]')
    if (!crosshair) return

    crosshair.style.left = `${x * 100}%`
    crosshair.style.top = `${y * 100}%`
  }
}

function clamp(value) {
  return Math.round(Math.min(1, Math.max(0, value)) * 1000) / 1000
}
