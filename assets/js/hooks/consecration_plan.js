// ConsecrationPlan: the reader's 33-day Consecration, kept in this
// browser's localStorage and nowhere else. Nothing is sent to the server
// but what the open page needs to draw itself; nothing is stored there.
//
// It keeps:
//
// - lv:consecration:plan: {start: "YYYY-MM-DD", feast_id, started_at,
//   completed_at}. Day 1 is `start`; Consecration Day is 33 days after it.
//   `feast_id` names the feast of Mary it ends on (null for Start at any
//   day), `completed_at` is set at Consecration Day's Amen.
// - lv:consecration:done: the days prayed, as day numbers [1, 2, ...].
// - lv:consecration:intro-seen: "1" once the introduction reached the
//   feast chooser, so a later visit opens on the chooser, as the app's
//   hasSeenConsecrationOnboarding does.
//
// On mount it pushes "consecration_state" with what it holds and the
// browser's own date (the visitor's today), and again at the next local
// midnight, so a page left open overnight turns to the new day. Presses
// it answers, marked in the page:
//
// - [data-consecration-begin] with data-start (and data-feast): a plan
//   begins, the days prayed are cleared, and the page is told.
// - [data-consecration-restart]: the plan and the days prayed are cleared,
//   and the page is told it was a restart ("restarted": true).
// - [data-consecration-amen] with data-day: the day is kept as prayed
//   only under a plan and only on that day or after (today's day counted
//   from plan.start as the server counts it, held at 34), and Consecration
//   Day's completes the plan only when today is Consecration Day. A day
//   ahead is open to read; its Amen keeps nothing. The press is a link the
//   page then follows, so this runs first.
//
// Every read and write is in try/catch: a browser that refuses storage
// simply has no plan, and every page still draws.

const PLAN = "lv:consecration:plan"
const DONE = "lv:consecration:done"
const INTRO = "lv:consecration:intro-seen"

const read = (key) => {
  try {
    const raw = window.localStorage.getItem(key)
    return raw == null ? null : JSON.parse(raw)
  } catch (_err) {
    return null
  }
}

const write = (key, value) => {
  try {
    window.localStorage.setItem(key, JSON.stringify(value))
  } catch (_err) {
    // Storage refused: the page goes on without it.
  }
}

const remove = (key) => {
  try {
    window.localStorage.removeItem(key)
  } catch (_err) {
    // As above.
  }
}

const pad = (n) => String(n).padStart(2, "0")

const localDate = (date) =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`

const today = () => localDate(new Date())

const LAST_DAY = 34

// Whole days from one "YYYY-MM-DD" to another, NaN if either is not one.
const daysBetween = (from, to) => {
  const utc = (iso) => {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "")
    return m ? Date.UTC(+m[1], +m[2] - 1, +m[3]) : NaN
  }
  return Math.round((utc(to) - utc(from)) / 86400000)
}

// Today's day of a plan, as Plan.current_day/2: from 1, held at 34; null
// before Day 1 or for a start that is not a date.
const currentDay = (plan, on) => {
  const diff = daysBetween(plan.start, on)
  if (!(diff >= 0)) return null
  return Math.min(diff + 1, LAST_DAY)
}

// The local date a plan was completed on, or null.
const completedOn = (plan) => {
  if (!plan || typeof plan.completed_at !== "string") return null
  const date = new Date(plan.completed_at)
  return isNaN(date.getTime()) ? null : localDate(date)
}

export default {
  mounted() {
    this.onClick = (event) => this.click(event)
    this.el.addEventListener("click", this.onClick)
    this.handleEvent("consecration:intro-seen", () => write(INTRO, "1"))
    this.send()
  },

  destroyed() {
    this.el.removeEventListener("click", this.onClick)
    clearTimeout(this.midnight)
  },

  send(extra = {}) {
    const done = read(DONE)
    const plan = read(PLAN)
    this.pushEvent("consecration_state", {
      plan,
      done: Array.isArray(done) ? done : [],
      intro_seen: read(INTRO) === "1",
      today: today(),
      completed_on: completedOn(plan),
      ...extra,
    })
    this.atMidnight()
  },

  // Tell the page the date again just after the next local midnight.
  atMidnight() {
    clearTimeout(this.midnight)
    const now = new Date()
    const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 5)
    this.midnight = setTimeout(() => this.send(), next - now)
  },

  click(event) {
    const begin = event.target.closest("[data-consecration-begin]")
    if (begin && this.el.contains(begin)) {
      write(PLAN, {
        start: begin.dataset.start,
        feast_id: begin.dataset.feast || null,
        started_at: new Date().toISOString(),
        completed_at: null,
      })
      remove(DONE)
      write(INTRO, "1")
      return this.send()
    }

    const restart = event.target.closest("[data-consecration-restart]")
    if (restart && this.el.contains(restart)) {
      remove(PLAN)
      remove(DONE)
      return this.send({ restarted: true })
    }

    const amen = event.target.closest("[data-consecration-amen]")
    if (amen && this.el.contains(amen)) {
      const day = parseInt(amen.dataset.day, 10)
      const plan = read(PLAN)
      if (!plan || plan.completed_at || !(day >= 1 && day <= LAST_DAY)) return
      const current = currentDay(plan, today())
      if (current == null || day > current) return
      const done = read(DONE)
      const days = Array.isArray(done) ? done.filter((d) => d !== day) : []
      days.push(day)
      write(DONE, days.sort((a, b) => a - b))
      if (day === LAST_DAY && current === LAST_DAY) {
        write(PLAN, { ...plan, completed_at: new Date().toISOString() })
      }
    }
  },
}
