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
    this.playButton = this.el.querySelector('[data-audio-play]')
    this.pauseButton = this.el.querySelector('[data-audio-pause]')
    this.autoPlay = this.el.dataset.autoPlay === 'true'

    if (!this.audio) return

    // Track current source URL for change detection
    const sourceElement = this.audio.querySelector('source')
    this.currentSrc = sourceElement ? sourceElement.src : null

    // Event listeners for audio element
    this.audio.addEventListener('ended', () => {
      this.handleEnded()
    })

    this.audio.addEventListener('play', () => {
      this.updateUI('playing')
    })

    this.audio.addEventListener('pause', () => {
      this.updateUI('paused')
    })

    this.audio.addEventListener('error', (e) => {
      console.error('Audio error:', e)
      this.updateUI('error')
    })

    // Button click handlers
    if (this.playButton) {
      this.playButton.addEventListener('click', () => {
        this.play()
      })
    }

    if (this.pauseButton) {
      this.pauseButton.addEventListener('click', () => {
        this.pause()
      })
    }

    // Auto-play with small delay if enabled
    if (this.autoPlay && this.audio.src) {
      setTimeout(() => {
        this.play()
      }, 500)
    }
  },

  updated() {
    if (!this.audio) return

    // Get the new source URL from the audio element
    const sourceElement = this.audio.querySelector('source')
    const newSrc = sourceElement ? sourceElement.src : null

    // Check if the source has changed
    if (newSrc && newSrc !== this.currentSrc) {
      this.currentSrc = newSrc

      // Pause current playback and reset
      this.audio.pause()
      this.audio.currentTime = 0

      // Load the new audio source
      this.audio.load()

      // Auto-play if enabled
      const shouldAutoPlay = this.el.dataset.autoPlay === 'true'
      if (shouldAutoPlay) {
        setTimeout(() => {
          this.play()
        }, 500)
      }
    }
  },

  play() {
    if (this.audio) {
      this.audio.play().catch(e => {
        console.error('Failed to play audio:', e)
        this.updateUI('error')
      })
    }
  },

  pause() {
    if (this.audio) {
      this.audio.pause()
    }
  },

  handleEnded() {
    this.updateUI('ended')
    // Push event to LiveView when audio finishes
    this.pushEvent('audio_ended', {})
  },

  updateUI(state) {
    if (!this.playButton || !this.pauseButton) return

    switch(state) {
      case 'playing':
        this.playButton.classList.add('hidden')
        this.pauseButton.classList.remove('hidden')
        break
      case 'paused':
      case 'ended':
      case 'error':
        this.playButton.classList.remove('hidden')
        this.pauseButton.classList.add('hidden')
        break
    }
  },

  destroyed() {
    // Clean up
    if (this.audio) {
      this.audio.pause()
      this.audio.src = ''
    }
  }
}

Hooks.MeditationPlayer = {
  mounted() {
    this.handlePlayClick = () => this.playCurrent()
    this.handlePauseClick = () => this.pauseCurrent()
    this.introHandlers = {
      play: () => this.onAudioPlay('intro'),
      pause: () => this.onAudioPause('intro'),
      ended: () => this.onIntroEnded(),
      loadedmetadata: () => this.onMetadataLoaded('intro')
    }
    this.meditationHandlers = {
      play: () => this.onAudioPlay('meditation'),
      pause: () => this.onAudioPause('meditation'),
      ended: () => this.onMeditationEnded(),
      loadedmetadata: () => this.onMetadataLoaded('meditation')
    }

    this.currentMeditationId = null
    this.stage = null
    this.hasAutoPlayed = false
    this.animationFrame = null
    this.activeTrackInner = null

    this.initialize()
  },

  updated() {
    this.initialize()
  },

  initialize() {
    this.refreshElements()

    const meditationId = this.el.dataset.meditationId
    const meditationChanged = this.currentMeditationId !== meditationId

    if (meditationChanged) {
      this.currentMeditationId = meditationId
      this.hasAutoPlayed = false
      this.pauseAll()
      this.resetAudioPositions()
      this.resetTrackPositions()

      const initialStage = this.hasIntroAudio() ? 'intro' : 'meditation'
      this.setStage(initialStage, {force: true})
    } else if (!this.stage) {
      const initialStage = this.hasIntroAudio() ? 'intro' : 'meditation'
      this.setStage(initialStage, {force: true})
    }

    if (this.autoPlay && !this.hasAutoPlayed) {
      this.playCurrent()
    } else {
      const state = this.activeAudio && !this.activeAudio.paused ? 'playing' : 'paused'
      this.updateControls(state)
    }
  },

  refreshElements() {
    this.autoPlay = this.el.dataset.autoPlay === 'true'

    this.introAudio = this.updateAudioReference(
      this.introAudio,
      '[data-intro-audio]',
      this.introHandlers
    )

    this.meditationAudio = this.updateAudioReference(
      this.meditationAudio,
      '[data-meditation-audio]',
      this.meditationHandlers
    )

    this.playButton = this.updateButtonReference(
      this.playButton,
      '[data-player-play]',
      this.handlePlayClick
    )

    this.pauseButton = this.updateButtonReference(
      this.pauseButton,
      '[data-player-pause]',
      this.handlePauseClick
    )
  },

  updateAudioReference(current, selector, handlers) {
    if (current) {
      const stillConnected = current.closest('#' + this.el.id)
      if (!stillConnected || current !== this.el.querySelector(selector)) {
        this.detachAudioListeners(current, handlers)
        current = null
      }
    }

    const element = this.el.querySelector(selector)
    if (element && current !== element) {
      this.attachAudioListeners(element, handlers)
      current = element
    }

    return element || null
  },

  attachAudioListeners(element, handlers) {
    Object.entries(handlers).forEach(([event, handler]) => {
      element.addEventListener(event, handler)
    })
  },

  detachAudioListeners(element, handlers) {
    Object.entries(handlers).forEach(([event, handler]) => {
      element.removeEventListener(event, handler)
    })
  },

  updateButtonReference(current, selector, handler) {
    if (current) {
      const stillConnected = current.closest('#' + this.el.id)
      if (!stillConnected || current !== this.el.querySelector(selector)) {
        current.removeEventListener('click', handler)
        current = null
      }
    }

    const element = this.el.querySelector(selector)
    if (element && current !== element) {
      element.addEventListener('click', handler)
      current = element
    }

    return element || null
  },

  hasIntroAudio() {
    return !!(this.introAudio && this.introAudio.getAttribute('src'))
  },

  setStage(stage, opts = {}) {
    const force = !!opts.force
    let nextStage = stage === 'intro' && this.hasIntroAudio() ? 'intro' : 'meditation'

    if (!force && this.stage === nextStage) {
      this.showTrack(nextStage)
      return
    }

    this.stopTextSync(true)
    this.stage = nextStage
    this.activeAudio = nextStage === 'intro' ? this.introAudio : this.meditationAudio
    this.showTrack(nextStage)
  },

  showTrack(stage) {
    const tracks = this.el.querySelectorAll('[data-track]')
    tracks.forEach((track) => {
      if (track.dataset.track === stage) {
        track.classList.remove('opacity-0', 'pointer-events-none')
        track.classList.add('opacity-100')
      } else {
        track.classList.add('opacity-0', 'pointer-events-none')
        track.classList.remove('opacity-100')
      }
    })
  },

  playCurrent() {
    if (!this.activeAudio) {
      this.setStage(this.hasIntroAudio() ? 'intro' : 'meditation', {force: true})
    }

    if (!this.activeAudio) {
      return
    }

    this.activeAudio.play().then(() => {
      this.hasAutoPlayed = true
    }).catch((error) => {
      console.warn('Unable to start playback automatically:', error)
      this.updateControls('paused')
    })
  },

  pauseCurrent() {
    if (this.activeAudio) {
      this.activeAudio.pause()
    }
  },

  pauseAll() {
    if (this.introAudio) {
      this.introAudio.pause()
    }
    if (this.meditationAudio) {
      this.meditationAudio.pause()
    }
  },

  resetAudioPositions() {
    if (this.introAudio) {
      this.introAudio.currentTime = 0
    }
    if (this.meditationAudio) {
      this.meditationAudio.currentTime = 0
    }
  },

  resetTrackPositions() {
    this.el.querySelectorAll('[data-track-inner]').forEach((inner) => {
      inner.style.transform = 'translateY(0px)'
    })
  },

  startTextSync(stage) {
    this.stopTextSync(false)

    const track = this.el.querySelector(`[data-track="${stage}"]`)
    const audio = stage === 'intro' ? this.introAudio : this.meditationAudio

    if (!track || !audio) {
      return
    }

    const inner = track.querySelector('[data-track-inner]')
    if (!inner) {
      return
    }

    this.activeTrackInner = inner

    const update = () => {
      if (!this.activeTrackInner || !audio) {
        return
      }

      const duration = audio.duration
      if (!duration || !isFinite(duration) || duration <= 0) {
        this.animationFrame = requestAnimationFrame(update)
        return
      }

      const distance = Math.max(0, inner.scrollHeight - track.clientHeight)
      const progress = Math.min(1, audio.currentTime / duration)
      inner.style.transform = `translateY(-${distance * progress}px)`

      this.animationFrame = requestAnimationFrame(update)
    }

    this.animationFrame = requestAnimationFrame(update)
  },

  stopTextSync(reset = false) {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
      this.animationFrame = null
    }

    if (reset && this.activeTrackInner) {
      this.activeTrackInner.style.transform = 'translateY(0px)'
    }

    if (reset) {
      this.activeTrackInner = null
    }
  },

  onAudioPlay(stage) {
    if (stage === this.stage) {
      this.updateControls('playing')
      this.startTextSync(stage)
    }
  },

  onAudioPause(stage) {
    if (stage === this.stage) {
      this.updateControls('paused')
      this.stopTextSync(false)
    }
  },

  onIntroEnded() {
    if (this.stage !== 'intro') {
      return
    }

    this.stopTextSync(true)
    this.setStage('meditation', {force: true})
    this.playCurrent()
  },

  onMeditationEnded() {
    if (this.stage !== 'meditation') {
      return
    }

    this.stopTextSync(false)
    this.updateControls('paused')
    this.pushEvent('audio_ended', {})
  },

  onMetadataLoaded(stage) {
    if (stage === this.stage && this.activeAudio && !this.activeAudio.paused) {
      this.startTextSync(stage)
    }
  },

  updateControls(state) {
    if (!this.playButton || !this.pauseButton) {
      return
    }

    if (state === 'playing') {
      this.playButton.classList.add('hidden')
      this.pauseButton.classList.remove('hidden')
    } else {
      this.playButton.classList.remove('hidden')
      this.pauseButton.classList.add('hidden')
    }
  },

  destroyed() {
    this.pauseAll()
    this.stopTextSync(true)
    if (this.introAudio) {
      this.detachAudioListeners(this.introAudio, this.introHandlers)
    }
    if (this.meditationAudio) {
      this.detachAudioListeners(this.meditationAudio, this.meditationHandlers)
    }
    if (this.playButton) {
      this.playButton.removeEventListener('click', this.handlePlayClick)
    }
    if (this.pauseButton) {
      this.pauseButton.removeEventListener('click', this.handlePauseClick)
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

