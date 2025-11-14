// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// LiveView Hooks
const Hooks = {}

Hooks.ScrollToTop = {
  updated() {
    window.scrollTo({top: 120, behavior: 'smooth'})
  }
}

Hooks.UserTimezone = {
  mounted() {
    // Get timezone offset in minutes (e.g., -180 for Argentina UTC-3)
    const timezoneOffset = new Date().getTimezoneOffset()
    // Send to server
    this.pushEvent("set_timezone", { offset: timezoneOffset })
  }
}

Hooks.RosaryProgress = {
  mounted() {
    const setId = this.el.dataset.setId
    const savedProgress = this.getSavedProgress(setId)

    if (savedProgress) {
      // Push the saved index to the server to restore progress
      this.pushEvent("restore_progress", { index: savedProgress.index })
    }
  },

  updated() {
    const setId = this.el.dataset.setId
    const currentIndex = parseInt(this.el.dataset.currentIndex)

    // Save progress with current timestamp
    this.saveProgress(setId, currentIndex)
  },

  destroyed() {
    // Clear progress when user navigates away from prayer page
    // This handles: Complete Rosary, Exit to Mysteries, Home, or any other navigation
    const setId = this.el.dataset.setId
    this.clearProgress(setId)
  },

  getSavedProgress(setId) {
    const key = `rosary_progress_${setId}`
    const saved = localStorage.getItem(key)

    if (!saved) return null

    try {
      const data = JSON.parse(saved)
      const now = Date.now()
      const oneHour = 60 * 60 * 1000 // 1 hour in milliseconds

      // Check if progress is less than 1 hour old
      if (now - data.timestamp < oneHour) {
        return data
      } else {
        // Expired - clear it
        localStorage.removeItem(key)
        return null
      }
    } catch (e) {
      // Invalid data - clear it
      localStorage.removeItem(key)
      return null
    }
  },

  saveProgress(setId, index) {
    const key = `rosary_progress_${setId}`
    const data = {
      index: index,
      timestamp: Date.now(),
      setId: setId
    }

    try {
      localStorage.setItem(key, JSON.stringify(data))
    } catch (e) {
      // localStorage might be full or unavailable - fail silently
      console.warn('Failed to save rosary progress:', e)
    }
  },

  clearProgress(setId) {
    const key = `rosary_progress_${setId}`
    try {
      localStorage.removeItem(key)
    } catch (e) {
      console.warn('Failed to clear rosary progress:', e)
    }
  }
}

Hooks.AudioPlayer = {
  mounted() {
    this.audio = this.el.querySelector('audio')
    this.sourceElement = this.audio ? this.audio.querySelector('source') : null
    this.playButton = this.el.querySelector('[data-audio-play]')
    this.pauseButton = this.el.querySelector('[data-audio-pause]')
    this.introLabel = this.el.querySelector('[data-phase-label-intro]')
    this.mainLabel = this.el.querySelector('[data-phase-label-main]')
    this.autoPlay = this.el.dataset.autoPlay === 'true'
    this.introSrc = this.el.dataset.introSrc || null
    this.mainSrc = this.el.dataset.mainSrc || null
    this.phase = this.introSrc ? 'intro' : 'meditation'

    if (!this.audio || !this.sourceElement) return

    this.handleEnded = this.handleEnded.bind(this)
    this.handlePlay = this.handlePlay.bind(this)
    this.handlePause = this.handlePause.bind(this)

    this.audio.addEventListener('ended', this.handleEnded)
    this.audio.addEventListener('play', this.handlePlay)
    this.audio.addEventListener('pause', this.handlePause)
    this.audio.addEventListener('error', (e) => {
      console.error('Audio error:', e)
      this.toggleButtons('error')
    })

    if (this.playButton) {
      this.playButton.addEventListener('click', () => this.play())
    }

    if (this.pauseButton) {
      this.pauseButton.addEventListener('click', () => this.pause())
    }

    this.setSourceForPhase()
    this.notifyPhase()

    if (this.autoPlay && (this.introSrc || this.mainSrc)) {
      setTimeout(() => this.play(), 500)
    }
  },

  updated() {
    if (!this.audio || !this.sourceElement) return

    const newIntro = this.el.dataset.introSrc || null
    const newMain = this.el.dataset.mainSrc || null
    const introChanged = newIntro !== this.introSrc
    const mainChanged = newMain !== this.mainSrc

    this.autoPlay = this.el.dataset.autoPlay === 'true'
    this.introSrc = newIntro
    this.mainSrc = newMain

    if (introChanged || mainChanged) {
      this.audio.pause()
      this.audio.currentTime = 0
      this.phase = this.introSrc ? 'intro' : 'meditation'
      this.setSourceForPhase()
      this.notifyPhase()
      this.toggleButtons('paused')

      if (this.autoPlay && (this.introSrc || this.mainSrc)) {
        setTimeout(() => this.play(), 500)
      }
    }
  },

  setSourceForPhase() {
    const src = this.phase === 'intro' ? this.introSrc : this.mainSrc
    if (this.sourceElement) {
      this.sourceElement.src = src || ''
      this.audio.load()
    }
    this.updatePhaseUI()
  },

  play() {
    if (!this.audio) return
    const src = this.phase === 'intro' ? this.introSrc : this.mainSrc
    if (!src) return

    this.audio.play().catch(e => {
      console.error('Failed to play audio:', e)
      this.toggleButtons('error')
    })
  },

  pause() {
    if (!this.audio) return
    this.audio.pause()
  },

  handlePlay() {
    this.toggleButtons('playing')
    this.notifyState('playing')
  },

  handlePause() {
    this.toggleButtons('paused')
    this.notifyState('paused')
  },

  handleEnded() {
    this.toggleButtons('ended')
    this.notifyState('ended')

    if (this.phase === 'intro' && this.mainSrc) {
      this.phase = 'meditation'
      this.setSourceForPhase()
      this.notifyPhase()
      this.play()
    } else {
      this.pushEvent('audio_ended', {})
    }
  },

  toggleButtons(state) {
    if (!this.playButton || !this.pauseButton) return

    if (state === 'playing') {
      this.playButton.classList.add('hidden')
      this.pauseButton.classList.remove('hidden')
    } else {
      this.playButton.classList.remove('hidden')
      this.pauseButton.classList.add('hidden')
    }
  },

  updatePhaseUI() {
    if (this.introLabel && this.mainLabel) {
      if (this.phase === 'intro') {
        this.introLabel.classList.remove('hidden')
        this.mainLabel.classList.add('hidden')
      } else {
        this.introLabel.classList.add('hidden')
        this.mainLabel.classList.remove('hidden')
      }
    }
  },

  notifyState(state) {
    window.dispatchEvent(new CustomEvent('meditation-audio-state', {
      detail: {state, phase: this.phase}
    }))
  },

  notifyPhase() {
    window.dispatchEvent(new CustomEvent('meditation-audio-phase', {
      detail: {phase: this.phase}
    }))
  },

  destroyed() {
    if (!this.audio) return

    this.audio.removeEventListener('ended', this.handleEnded)
    this.audio.removeEventListener('play', this.handlePlay)
    this.audio.removeEventListener('pause', this.handlePause)
    this.audio.pause()
    if (this.sourceElement) {
      this.sourceElement.src = ''
    }
    this.audio.src = ''
  }
}

Hooks.MeditationLyrics = {
  mounted() {
    this.track = this.el.querySelector('[data-lyrics-track]')
    this.segments = this.track
      ? Array.from(this.track.querySelectorAll('[data-lyric-segment]'))
      : []
    this.phase = this.el.dataset.phase
    this.intervalDuration = parseInt(this.el.dataset.interval || '10000', 10)
    this.activeIndex = 0
    this.interval = null

    if (this.track) {
      this.track.style.transform = 'translateY(0)'
      this.track.style.transition = 'transform 0.8s ease'
      this.track.style.willChange = 'transform'
    }

    this.setActive(0)

    this.handleAudioState = (event) => {
      const {phase, state} = event.detail

      if (phase !== this.phase) return

      switch(state) {
        case 'playing':
          this.startCycle()
          break
        case 'paused':
          this.stopCycle()
          break
        case 'ended':
          this.stopCycle()
          this.setActive(this.segments.length - 1)
          break
      }
    }

    this.handlePhaseChange = (event) => {
      const {phase} = event.detail
      if (phase === this.phase) {
        this.reset()
      } else {
        this.stopCycle()
      }
    }

    window.addEventListener('meditation-audio-state', this.handleAudioState)
    window.addEventListener('meditation-audio-phase', this.handlePhaseChange)
  },

  startCycle() {
    if (this.segments.length <= 1) return
    this.stopCycle()
    this.interval = setInterval(() => this.advance(), this.intervalDuration)
  },

  advance() {
    if (this.activeIndex >= this.segments.length - 1) {
      this.stopCycle()
      return
    }

    this.setActive(this.activeIndex + 1)
  },

  stopCycle() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
  },

  reset() {
    this.stopCycle()
    this.setActive(0)
  },

  setActive(index) {
    if (this.segments.length === 0) return
    this.activeIndex = Math.max(0, Math.min(index, this.segments.length - 1))
    this.segments.forEach((segment, idx) => {
      if (idx === this.activeIndex) {
        segment.classList.add('is-active')
      } else {
        segment.classList.remove('is-active')
      }
    })
    this.updateTrackPosition()
  },

  updateTrackPosition() {
    if (!this.track || this.segments.length === 0) return

    const activeSegment = this.segments[this.activeIndex]
    if (!activeSegment) return

    const containerHeight = this.el.clientHeight || 1
    const segmentOffset = activeSegment.offsetTop
    const segmentHeight = activeSegment.offsetHeight
    const centerOffset = segmentOffset - (containerHeight / 2 - segmentHeight / 2)
    const maxOffset = Math.max(0, (this.track.scrollHeight || 0) - containerHeight)
    const clampedOffset = Math.max(0, Math.min(centerOffset, maxOffset))

    this.track.style.transform = `translateY(${-clampedOffset}px)`
  },

  destroyed() {
    window.removeEventListener('meditation-audio-state', this.handleAudioState)
    window.removeEventListener('meditation-audio-phase', this.handlePhaseChange)
    this.stopCycle()
    if (this.track) {
      this.track.style.transform = 'translateY(0)'
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

window.addEventListener("DOMContentLoaded", initializeSiteNav)
window.addEventListener("phx:page-loading-stop", initializeSiteNav)

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

