// The completion screen's count of days in a row, as the app keeps it but
// in this browser only: localStorage holds the last day a Rosary was
// completed here and the run of days up to it. Nothing is sent to the
// server. It also lets go of the place saved for "Continue where you left
// off" (PrayerMemory), since this Rosary is finished.
//
// On the day's first Rosary, the one that moves the count on, it shows the
// devotional milestone the count has just reached, if there is one: the
// completion screen carries them all, hidden, as [data-milestone="<days>"].

const STREAK_KEY = "lv:pray:streak"

function today(offsetDays = 0) {
  const date = new Date()
  date.setDate(date.getDate() + offsetDays)
  const pad = (n) => String(n).padStart(2, "0")
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

export default {
  mounted() {
    let streak = { last: null, days: 0 }
    try {
      streak = JSON.parse(window.localStorage.getItem(STREAK_KEY)) || streak
    } catch (_blockedOrUnreadable) {
      // Counted from today.
    }

    const firstToday = streak.last !== today()
    if (firstToday) {
      streak = { last: today(), days: streak.last === today(-1) ? (streak.days || 0) + 1 : 1 }
    }

    try {
      window.localStorage.setItem(STREAK_KEY, JSON.stringify(streak))
      const prefix = `lv:pray:${this.el.dataset.key}:`
      for (let i = window.localStorage.length - 1; i >= 0; i--) {
        const key = window.localStorage.key(i)
        if (key && key.startsWith(prefix)) window.localStorage.removeItem(key)
      }
    } catch (_blocked) {
      // Private windows: today's count is still shown.
    }

    const line = this.el.querySelector("[data-streak]")
    if (line) {
      line.textContent = streak.days === 1 ? "1 day so far" : `${streak.days} days in a row`
    }

    const milestone = firstToday && this.el.querySelector(`[data-milestone="${streak.days}"]`)
    if (milestone) milestone.hidden = false

    // The Complete button that was pressed is gone; without this focus falls
    // to the top of the page and a screen reader never hears the Amen.
    this.el.focus({ preventScroll: true })
  }
}
