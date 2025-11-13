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
    // Handle audio URL changes
    const newAutoPlay = this.el.dataset.autoPlay === 'true'

    if (newAutoPlay && this.audio && this.audio.src) {
      // Reset and auto-play new audio after small delay
      this.audio.load()
      setTimeout(() => {
        this.play()
      }, 500)
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

