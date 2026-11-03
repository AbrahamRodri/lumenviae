// The site's one chant player, as the app's ChantPlayer.shared: what the
// Chant Library is singing, kept while the reader moves about the site.
//
// The <audio id="site-chant-audio"> and the mini player stand in the root
// layout, outside every LiveView, so a live navigation (every link between
// the public pages, all in one live_session) leaves them sounding. The
// Chant pages' ChantPlayer hook only asks this module to play, and draws
// what it says; the mini player (chant_mini_player.js) draws it at the
// foot of the other pages.
//
// What it holds: the chant in hand (its id, recording and the facts the
// mini player shows), and a queue when a shelf's Play all or a sung set
// is under way (its title, its entries unrolled, the step sounding,
// whether its next chant waits for a tap now). The queue goes on by itself
// from any page.
//
// A full page load (a reload, a link opened anew, a page outside the
// public live_session) ends the <audio>. So the same facts and the place
// in the recording are kept in this tab's sessionStorage, and a new page
// brings the player back paused where it stood: its disc goes on. Nothing
// else is kept and nothing is sent; the tab's storage ends with the tab.
//
// Pause Between Chants is one kept choice, as the app keeps it
// (ChantShelfStore.pausesBetween): true or false in this browser's
// localStorage, read when any queue (a set, a shelf's Play all) comes to
// the end of a chant, so the next waits for a tap.
//
// Another recording on the site (the spoken Rosary, a prayer said aloud,
// a book read) taking the speakers puts the chant away, as another flow's
// claim does in the app.

const KEY = "lv:chant-player"
const PAUSES_KEY = "lv:chant-pauses-between"

const listeners = new Set()

const state = {
  audio: null,
  current: null, // {id, src, facts: {latin, english, href, thumb, position}}
  queue: null, // {kind, id, title, entries: [{id, src, origin}], index, facts}
  waiting: false, // a set's next chant held at its start for a tap
  error: false, // the chant asked for would not play
  pressed: false, // play was pressed: no error is shown before
  started: false, // the chant in hand has sounded
  repeat: null, // the chant sung again at its end (Repeat the chant, from its page)
}

let saveTimer = null

function audio() {
  if (state.audio) return state.audio
  const el = document.getElementById("site-chant-audio")
  if (!el) return null
  state.audio = el
  el.addEventListener("play", () => {
    state.started = true
    state.error = false
    emit("play")
  })
  el.addEventListener("pause", () => {
    emit("pause")
    save()
  })
  el.addEventListener("ended", ended)
  el.addEventListener("error", failed)
  el.addEventListener("timeupdate", () => {
    emit("time")
    if (!saveTimer) saveTimer = setTimeout(save, 2000)
  })
  el.addEventListener("loadedmetadata", () => emit("time"))
  el.addEventListener("ratechange", () => emit("rate"))
  return el
}

function emit(kind) {
  listeners.forEach((fn) => {
    try {
      fn(kind)
    } catch (err) {
      console.warn("chant player listener", err)
    }
  })
}

export function subscribe(fn) {
  listeners.add(fn)
  return () => listeners.delete(fn)
}

// ---- What it says

export const session = {
  get audio() {
    return audio()
  },
  get current() {
    return state.current
  },
  get queue() {
    return state.queue
  },
  get waiting() {
    return state.waiting
  },
  get error() {
    return state.error
  },
  get started() {
    return state.started
  },
  get repeat() {
    return state.repeat
  },
  set repeat(id) {
    state.repeat = id || null
  },
  // Whether it holds a chant, the mini player's whole condition (isActive)
  get active() {
    return !!state.current
  },
  get playing() {
    const a = audio()
    return !!(a && state.current && !a.paused && !a.ended && !state.waiting)
  },
  isCurrent(id) {
    return !!state.current && state.current.id === id
  },
}

// ---- Presses

function start() {
  const a = audio()
  if (!a || !state.current) return
  state.pressed = true
  state.error = false
  const playing = a.play()
  if (playing && playing.catch) {
    playing.catch((err) => {
      if (err.name === "AbortError") return
      // A browser that will not play before a press says NotAllowedError:
      // that is a pause, not a broken recording
      if (err.name === "NotAllowedError") return emit("pause")
      failed()
    })
  }
  emit("state")
}

function load(chant, { play = true, at = 0 } = {}) {
  const a = audio()
  if (!a) return
  state.current = { id: chant.id, src: chant.src, facts: chant.facts || {} }
  state.started = false
  state.error = false
  const rate = a.playbackRate
  a.src = chant.src
  // A new source takes the default rate; the chosen speed stays the player's
  a.defaultPlaybackRate = rate
  a.playbackRate = rate
  if (at > 0) {
    const seek = () => {
      a.currentTime = at
      emit("time")
    }
    if (a.readyState >= 1) seek()
    else a.addEventListener("loadedmetadata", seek, { once: true })
  }
  if (play) start()
  else a.preload = "metadata"
  emit("state")
  save()
}

// A chant on its own, from a disc or a chant's page: a second press pauses
// it, and a shelf or set under way is put down.
export function playOne(chant) {
  const a = audio()
  if (!a) return
  if (state.current && state.current.id === chant.id && !state.queue) return toggle()
  state.queue = null
  state.waiting = false
  load(chant)
}

// Loads a chant without sounding it, at a place (a chant's page scrubbed
// before play): the player is taken, the queue put down.
export function hold(chant, at) {
  state.queue = null
  state.waiting = false
  load(chant, { play: false, at })
}

export function toggle() {
  const a = audio()
  if (!a || !state.current) return
  if (state.waiting) return goOn()
  if (a.paused || a.ended) return start()
  // Drawn at once: the pause event comes a task later
  a.pause()
  emit("state")
}

// A shelf's Play all or a sung set from a step: entries [{id, src, origin}]
// with the facts of each chant by id.
export function playQueue({ kind, id, title, entries, facts }, index = 0) {
  if (!entries || !entries[index]) return
  state.queue = { kind, id, title, entries, index, facts: facts || {} }
  state.waiting = false
  load(entryChant(entries[index]))
}

export function isQueue(kind, id) {
  return !!state.queue && state.queue.kind === kind && state.queue.id === id
}

// Pause Between Chants, the one kept choice: off until it is turned on
export function pausesBetween() {
  try {
    return JSON.parse(localStorage.getItem(PAUSES_KEY) || "false") === true
  } catch (_err) {
    return false
  }
}

export function setPausesBetween(on) {
  try {
    localStorage.setItem(PAUSES_KEY, JSON.stringify(on === true))
  } catch (_err) {}
  emit("pauses")
}

function entryChant(entry) {
  const facts = (state.queue && state.queue.facts[entry.id]) || {}
  return { id: entry.id, src: entry.src, facts }
}

export function goOn() {
  const a = audio()
  if (!a) return
  state.waiting = false
  a.currentTime = 0
  start()
}

// Puts the chant away and the player with it: the mini player's close,
// and another recording taking the speakers.
export function relinquish() {
  const a = audio()
  state.current = null
  state.queue = null
  state.waiting = false
  state.error = false
  state.started = false
  state.repeat = null
  if (a) {
    a.pause()
    a.removeAttribute("src")
    a.load()
  }
  try {
    sessionStorage.removeItem(KEY)
  } catch (_err) {}
  emit("state")
}

// ---- What happens by itself

function ended() {
  const a = audio()
  if (state.repeat && !state.queue && state.current && state.repeat === state.current.id) {
    a.currentTime = 0
    return start()
  }
  const q = state.queue
  if (q && q.index + 1 < q.entries.length) {
    q.index += 1
    const next = entryChant(q.entries[q.index])
    if (pausesBetween()) {
      // Held at its very start, so nothing of it is heard before the tap
      state.current = { id: next.id, src: next.src, facts: next.facts }
      state.started = false
      state.waiting = true
      a.src = next.src
      emit("state")
      return save()
    }
    return load(next)
  }
  // The queue sung through: the last chant stays in hand, at its end
  state.queue = null
  state.waiting = false
  emit("state")
  save()
}

// A recording that will not play, said only once play was pressed. A queue
// goes on to its next chant, so one missing file never stops Play all.
function failed() {
  const a = audio()
  if (!a || !a.getAttribute("src") || !state.pressed || !state.current) return
  if (state.waiting) return
  const q = state.queue
  if (q && q.index + 1 < q.entries.length) {
    emit("passed-over")
    q.index += 1
    return load(entryChant(q.entries[q.index]))
  }
  state.error = true
  emit("failed")
  emit("state")
}

// ---- This tab's storage

function save() {
  clearTimeout(saveTimer)
  saveTimer = null
  const a = audio()
  if (!a) return
  try {
    if (!state.current) return sessionStorage.removeItem(KEY)
    sessionStorage.setItem(
      KEY,
      JSON.stringify({
        current: state.current,
        queue: state.queue,
        waiting: state.waiting,
        time: a.currentTime || 0,
        rate: a.playbackRate || 1,
      })
    )
  } catch (_err) {}
}

// What is read back is checked before it is used: a recording or painting
// only from this site or the chant files' own origin (the <audio>'s
// data-origin), a chant's page only under /chant/.
// A recording or painting is trusted only where the browser itself would
// fetch it from: this site, or the chant files' origin. Resolved as the
// browser resolves it, so "/\host/x", "/<tab>/host/x" and the like, which a
// browser reads as another host, are refused.
function trustedUrl(url) {
  if (typeof url !== "string" || (!url.startsWith("/") && !/^https:\/\//.test(url))) return false
  let resolved
  try {
    resolved = new URL(url, window.location.origin)
  } catch (_unreadable) {
    return false
  }
  if (url.startsWith("/")) return resolved.origin === window.location.origin
  const origin = audio()?.dataset.origin
  return !!origin && resolved.origin === origin && url.startsWith(`${origin}/`)
}

const text = (value) => (typeof value === "string" ? value : undefined)

function cleanFacts(facts) {
  if (!facts || typeof facts !== "object") return {}
  return {
    latin: text(facts.latin),
    english: text(facts.english),
    href: typeof facts.href === "string" && /^\/chant\/[\w-]+$/.test(facts.href) ? facts.href : undefined,
    thumb: trustedUrl(facts.thumb) ? facts.thumb : undefined,
    position: typeof facts.position === "string" && /^[\d.]+% [\d.]+%$/.test(facts.position) ? facts.position : undefined,
  }
}

const cleanEntry = (entry) =>
  entry && typeof entry.id === "string" && trustedUrl(entry.src)
    ? { id: entry.id, src: entry.src, origin: Number.isInteger(entry.origin) ? entry.origin : null }
    : null

function cleanQueue(q) {
  if (!q || typeof q !== "object" || !Array.isArray(q.entries) || !Number.isInteger(q.index)) return null
  const entries = q.entries.map(cleanEntry)
  // One bad entry and the queue is not trusted; the chant in hand stays
  if (entries.length === 0 || entries.some((entry) => !entry) || !entries[q.index]) return null
  const facts = {}
  if (q.facts && typeof q.facts === "object") {
    for (const id of new Set(entries.map((entry) => entry.id))) facts[id] = cleanFacts(q.facts[id])
  }
  return { kind: text(q.kind), id: text(q.id), title: text(q.title) || "", entries, index: q.index, facts }
}

function restore() {
  let saved = null
  try {
    saved = JSON.parse(sessionStorage.getItem(KEY) || "null")
  } catch (_err) {
    saved = null
  }
  const a = audio()
  if (!a || !saved || typeof saved !== "object" || !saved.current) return
  const { id, src } = saved.current
  if (typeof id !== "string" || !trustedUrl(src)) return
  const rate = saved.rate === 0.75 ? 0.75 : 1
  a.defaultPlaybackRate = rate
  a.playbackRate = rate
  state.queue = cleanQueue(saved.queue)
  state.waiting = !!(state.queue && saved.waiting === true)
  const time = Number(saved.time)
  const at = !state.waiting && Number.isFinite(time) && time >= 0 ? time : 0
  load({ id, src, facts: cleanFacts(saved.current.facts) }, { play: false, at })
}

export function initChantSession() {
  const a = audio()
  if (!a) return
  // Another recording on the page takes the speakers: the chant is put away
  document.addEventListener(
    "play",
    (event) => {
      const el = event.target
      if (el !== a && el instanceof HTMLMediaElement && state.current) relinquish()
    },
    true
  )
  window.addEventListener("pagehide", save)
  restore()
}
