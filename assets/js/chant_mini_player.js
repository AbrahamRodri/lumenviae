// The chant mini player at the foot of the site, as the app's
// ChantMiniPlayer: the chant's painting, its Latin name and where it
// stands, its disc, and close. A tap on the names opens the chant's page.
// While a queue waits between chants it names the next ("Next: ...",
// "<set> · waiting for you") and its disc sings it.
//
// It stands in the root layout, outside every LiveView, and draws what
// chant_session.js holds. It shows while a chant is in hand, except over a
// page that carries its own transport or a prayer under way, which marks
// itself [data-hides-chant-player] (the app's showsChantPlayer: the
// chant's own page, a Rosary prayed, a pray-along, a chapter read, a
// consecration day other than today's under a plan). While it shows,
// <html data-chant-mini> keeps room at the page's foot so the last of it
// scrolls clear.

import { session, subscribe, toggle, relinquish } from "./chant_session"

const clock = (seconds) => {
  const whole = Math.max(0, Math.floor(seconds || 0))
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`
}

const spoken = (seconds) => {
  const whole = Math.max(0, Math.floor(seconds || 0))
  const m = Math.floor(whole / 60)
  const s = whole % 60
  const parts = []
  if (m) parts.push(`${m} minute${m === 1 ? "" : "s"}`)
  if (s || !m) parts.push(`${s} second${s === 1 ? "" : "s"}`)
  return parts.join(" ")
}

let el = null
let raf = null
let shownThumb = null

function part(role) {
  return el.querySelector(`[data-role=mini-${role}]`)
}

function shows() {
  return session.active && !document.querySelector("[data-hides-chant-player]")
}

function title() {
  const facts = session.current.facts || {}
  const latin = facts.latin || "Chant"
  return session.waiting ? `Next: ${latin}` : latin
}

function subtitle() {
  const a = session.audio
  const facts = session.current.facts || {}
  const q = session.queue
  if (session.error) return { text: "The chant couldn't be played." }
  if (session.waiting && q) return { text: `${q.title} · waiting for you` }
  if (q) return { text: `${q.title} · ${q.index + 1} of ${q.entries.length}` }
  const english = facts.english || ""
  if (a && a.duration && isFinite(a.duration)) {
    return {
      text: `${english} · ${clock(a.currentTime)} of ${clock(a.duration)}`,
      spoken: `${english}, ${spoken(a.currentTime)} of ${spoken(a.duration)}`,
    }
  }
  return { text: english }
}

function paint() {
  if (!el) return
  const visible = shows()
  el.hidden = !visible
  document.documentElement.toggleAttribute("data-chant-mini", visible)
  if (!visible) return cancelAnimationFrame(raf)

  const facts = session.current.facts || {}
  const open = part("open")
  open.setAttribute("href", facts.href || "/chant")
  part("title").textContent = title()
  paintSubtitle()

  const thumb = part("thumb")
  if (facts.thumb !== shownThumb) {
    shownThumb = facts.thumb
    if (facts.thumb) {
      thumb.src = facts.thumb
      thumb.style.objectPosition = facts.position || "50% 50%"
      thumb.hidden = false
    } else {
      thumb.removeAttribute("src")
      thumb.hidden = true
    }
  }

  const playing = session.playing
  const disc = part("play")
  // While a queue waits, the next chant by its spoken name, "Latin, English"
  const name = session.waiting
    ? [facts.latin, facts.english].filter(Boolean).join(", ") || "the next chant"
    : title()
  disc.setAttribute("aria-pressed", playing ? "true" : "false")
  disc.setAttribute("aria-label", `${playing ? "Pause" : "Play"} ${name}`)
  el.toggleAttribute("data-playing", playing)
  progress()
}

function paintSubtitle() {
  const sub = subtitle()
  const line = part("subtitle")
  if (line.textContent !== sub.text) line.textContent = sub.text
  if (sub.spoken) line.setAttribute("aria-label", sub.spoken)
  else line.removeAttribute("aria-label")
}

function progress() {
  cancelAnimationFrame(raf)
  const a = session.audio
  const bar = part("progress")
  if (!a || !bar) return
  const fraction = a.duration && isFinite(a.duration) ? Math.min(1, a.currentTime / a.duration) : 0
  // While a queue waits, the chant just sung stays full
  bar.style.transform = `scaleX(${session.waiting ? 1 : fraction})`
  if (session.playing) raf = requestAnimationFrame(progress)
}

export function initChantMiniPlayer() {
  el = document.getElementById("chant-mini")
  if (!el) return

  el.addEventListener("click", (event) => {
    const act = event.target.closest("[data-act]")
    if (!act) return
    if (act.dataset.act === "toggle") toggle()
    if (act.dataset.act === "close") {
      relinquish()
      // Focus would fall to the page's top with the player gone
      document.getElementById("main-content")?.focus({ preventScroll: true })
    }
  })

  subscribe((kind) => {
    // The time: the words beside it; the line is drawn by the frame
    if (kind === "time" && !el.hidden && session.active) {
      paintSubtitle()
      if (!session.playing) progress()
      return
    }
    paint()
  })
  window.addEventListener("phx:page-loading-stop", paint)
  // A page that comes to stand aside, or stops, without a navigation
  // (today's Consecration day, once the plan is read)
  new MutationObserver(paint).observe(document.body, {
    subtree: true,
    attributes: true,
    attributeFilter: ["data-hides-chant-player"],
  })
  paint()
}
