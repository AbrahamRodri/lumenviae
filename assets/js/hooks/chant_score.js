// ChantScore: a chant's whole score over its page, as the app's
// ChantScoreSheet: every page of the score drawn at the width of the
// glass, brought closer by a double-click (twice the width, or back) or
// the zoom buttons and the + and - keys, from the width of the glass up
// to three times it, the phrase under the pointer kept where it was.
//
// The drawing is the apps' own (ChantScoreDrawing.swift): each page is a
// `.lvscore`, DEFLATE-compressed lines of drawing operations, fetched from
// the site ([data-src], /chant/scores/:file), inflated here and drawn as
// one SVG, so it is vector at any zoom:
//
//     LVSCORE 1
//     <min-x> <min-y> <width> <height>       the engraving's viewBox
//     I <path>|<path>|...                    fill in ink
//     R <path>|...                           fill in red
//     W <path>|...                           erase (a white shape)
//     S<width> <path>|...  /  T<width> ...   stroke in ink / in red
//
// in the order the engraving lays them down. Each <path> is SVG path data
// on its own (its relative moves start from its own origin), so each is
// a <path> of its own. An erase is the glass's own colour, which is what
// the app's clearing shows through to.
//
// The sheet opens by a link (?score=full). Opened from the page, DONE and
// Escape go back in the history, so Back afterwards leaves the chant as
// it would have; opened from a link, they patch to the chant's page.
// The page's ChantPlayer hook drives the small player at the foot (its
// [data-act=toggle] and [data-role=score-scrub]). It keeps nothing and
// sends nothing.

const SVG = "http://www.w3.org/2000/svg"
const MIN = 1
const MAX = 3
const STEPS = [1, 1.5, 2, 3]
// Only path data: digits, commands, separators. Anything else is not a
// score this page can read.
const PATH_DATA = /^[0-9MmLlHhVvCcSsQqTtAaZzEe.,\s+-]*$/

// Set when the page's The Sheet Music link is pressed, so the sheet knows
// the chant's page is the history entry behind it.
let openedFromPage = false
document.addEventListener("click", (event) => {
  if (event.target.closest?.("[data-chant-score-open]")) openedFromPage = true
})

async function inflate(buffer) {
  const stream = new Blob([buffer]).stream().pipeThrough(new DecompressionStream("deflate-raw"))
  return new Response(stream).text()
}

const CLASSES = { I: "score-ink", R: "score-red", W: "score-erase", S: "score-line", T: "score-line score-line--red" }

// The drawing as an <svg>, or null when the text is not a score.
export function drawScore(text) {
  const lines = text.split("\n").filter((line) => line !== "")
  if (lines[0] !== "LVSCORE 1" || lines.length < 2) return null
  const box = lines[1].split(" ").map(Number)
  if (box.length !== 4 || box.some((n) => !isFinite(n)) || box[2] <= 0 || box[3] <= 0) return null

  const svg = document.createElementNS(SVG, "svg")
  svg.setAttribute("viewBox", box.join(" "))
  svg.setAttribute("class", "chant-score__svg")
  svg.setAttribute("aria-hidden", "true")
  svg.setAttribute("focusable", "false")

  for (const line of lines.slice(2)) {
    const space = line.indexOf(" ")
    const kind = line[0]
    if (space < 1 || !CLASSES[kind]) continue
    const group = document.createElementNS(SVG, "g")
    group.setAttribute("class", CLASSES[kind])
    if (kind === "S" || kind === "T") {
      const width = parseFloat(line.slice(1, space))
      group.setAttribute("stroke-width", String(isFinite(width) ? width : 1))
    }
    for (const data of line.slice(space + 1).split("|")) {
      if (!data || !PATH_DATA.test(data)) continue
      const path = document.createElementNS(SVG, "path")
      path.setAttribute("d", data)
      group.appendChild(path)
    }
    svg.appendChild(group)
  }
  return svg
}

export default {
  mounted() {
    this.glass = this.el.querySelector("[data-role=score-glass]")
    this.sheet = this.el.querySelector(".chant-score__sheet")
    this.done = this.el.querySelector("[data-role=score-done]")
    this.zoom = 1

    if (openedFromPage) {
      history.replaceState({ ...(history.state || {}), chantScore: "opened" }, "")
      openedFromPage = false
    }

    this.onClick = (event) => {
      const zoom = event.target.closest("[data-zoom]")
      if (zoom) return this.step(zoom.dataset.zoom === "in" ? 1 : -1)
      if (event.target.closest("[data-role=score-done]") && history.state?.chantScore === "opened") {
        event.preventDefault()
        event.stopPropagation()
        history.back()
      }
    }
    this.onDoubleClick = (event) => {
      event.preventDefault()
      this.zoomTo(this.zoom > 1.2 ? 1 : 2, event.clientX, event.clientY)
    }
    this.onKey = (event) => this.key(event)

    this.el.addEventListener("click", this.onClick)
    this.glass.addEventListener("dblclick", this.onDoubleClick)
    this.el.addEventListener("keydown", this.onKey)

    this.page = document.querySelector("#chant-view > article")
    this.page?.setAttribute("inert", "")

    this.paint()
    this.draw()
    this.glass.focus({ preventScroll: true })
  },

  updated() {
    this.paint()
  },

  destroyed() {
    this.page?.removeAttribute("inert")
    // Back on the page, where the sheet was opened from.
    requestAnimationFrame(() => document.querySelector("[data-chant-score-open]")?.focus({ preventScroll: true }))
  },

  // ---- Drawing

  draw() {
    this.el.querySelectorAll("[data-role=score-drawing]").forEach(async (frame) => {
      if (frame.dataset.drawn) return
      frame.dataset.drawn = "loading"
      try {
        if (typeof DecompressionStream === "undefined") throw new Error("no DecompressionStream")
        const response = await fetch(frame.dataset.src)
        if (!response.ok) throw new Error(`status ${response.status}`)
        const svg = drawScore(await inflate(await response.arrayBuffer()))
        if (!svg) throw new Error("not a score")
        frame.replaceChildren(svg)
        frame.dataset.drawn = "drawn"
      } catch (_error) {
        frame.dataset.drawn = "failed"
        const note = document.createElement("p")
        note.className = "chant-score__unavailable"
        note.textContent = "The sheet music comes with a connection"
        frame.replaceChildren(note)
      }
    })
  },

  // ---- Zoom

  step(direction) {
    const next =
      direction > 0 ? STEPS.find((z) => z > this.zoom + 0.01) : [...STEPS].reverse().find((z) => z < this.zoom - 0.01)
    if (next == null) return
    const rect = this.glass.getBoundingClientRect()
    this.zoomTo(next, rect.left + rect.width / 2, rect.top + rect.height / 2)
  },

  // Lays the score out at `zoom` and keeps the point of the score under
  // (x, y) where it was: a point on one page's engraving, as a fraction
  // of it, since the captions between the pages keep their size.
  zoomTo(zoom, x, y) {
    zoom = Math.min(MAX, Math.max(MIN, zoom))
    if (zoom === this.zoom) return
    const frames = Array.from(this.el.querySelectorAll("[data-role=score-drawing]"))
    const frame = frames.find((f) => y <= f.getBoundingClientRect().bottom) || frames[frames.length - 1]
    let fx = 0.5
    let fy = 0.5
    if (frame) {
      const before = frame.getBoundingClientRect()
      fx = Math.min(1, Math.max(0, (x - before.left) / (before.width || 1)))
      fy = Math.min(1, Math.max(0, (y - before.top) / (before.height || 1)))
    }

    this.zoom = zoom
    this.sheet.style.setProperty("--score-zoom", String(zoom))

    if (frame) {
      const after = frame.getBoundingClientRect()
      this.glass.scrollLeft += after.left + fx * after.width - x
      this.glass.scrollTop += after.top + fy * after.height - y
    }
    this.paint()
  },

  paint() {
    this.el.querySelectorAll("[data-zoom]").forEach((button) => {
      const zoomIn = button.dataset.zoom === "in"
      button.disabled = zoomIn ? this.zoom >= MAX : this.zoom <= MIN
    })
    this.glass?.toggleAttribute("data-zoomed", this.zoom > 1)
  },

  // ---- Keys: Escape closes; + and - zoom, 0 back to the width of the
  // glass; Tab stays within the sheet, which is modal.

  key(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      return this.done?.click()
    }
    if (event.key === "Tab") return this.trap(event)
    if (event.target.matches?.("input")) return
    if (event.metaKey || event.ctrlKey || event.altKey) return
    if (event.key === "+" || event.key === "=") {
      event.preventDefault()
      this.step(1)
    } else if (event.key === "-" || event.key === "_") {
      event.preventDefault()
      this.step(-1)
    } else if (event.key === "0") {
      event.preventDefault()
      const rect = this.glass.getBoundingClientRect()
      this.zoomTo(1, rect.left + rect.width / 2, rect.top + rect.height / 2)
    }
  },

  trap(event) {
    const focusable = Array.from(
      this.el.querySelectorAll("a[href], button:not([disabled]), input, [tabindex='0']"),
    ).filter((el) => el.offsetParent !== null)
    if (focusable.length === 0) return
    const first = focusable[0]
    const last = focusable[focusable.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  },
}
