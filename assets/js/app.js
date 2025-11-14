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

Hooks.PrayerAudioPlayer = {
  mounted() {
    this.audio = new Audio()
    this.playlist = []
    this.currentSegment = 0
    this.currentPlaylistJSON = null
    this.currentTrigger = null
    this.trackLabel = this.el.querySelector('[data-track-label]')
    this.toggleButton = this.el.querySelector('[data-control="play-toggle"]')
    this.playIcon = this.toggleButton?.querySelector('[data-icon="play"]')
    this.pauseIcon = this.toggleButton?.querySelector('[data-icon="pause"]')
    this.prevSegmentButton = this.el.querySelector('[data-control="segment-previous"]')
    this.nextSegmentButton = this.el.querySelector('[data-control="segment-next"]')

    this.handleEnded = this.handleEnded.bind(this)
    this.handlePlay = this.handlePlay.bind(this)
    this.handlePause = this.handlePause.bind(this)

    this.audio.addEventListener('ended', this.handleEnded)
    this.audio.addEventListener('play', this.handlePlay)
    this.audio.addEventListener('pause', this.handlePause)

    this.toggleButton?.addEventListener('click', () => this.togglePlayback())
    this.prevSegmentButton?.addEventListener('click', () => this.advanceSegment(-1))
    this.nextSegmentButton?.addEventListener('click', () => this.advanceSegment(1))

    this.loadPlaylistFromDataset()
    this.syncControls()
  },

  updated() {
    const playlistChanged = this.loadPlaylistFromDataset()
    const trigger = this.el.dataset.trigger || null

    if (trigger && trigger !== this.currentTrigger) {
      this.currentTrigger = trigger
      if (this.playlist.length > 0) {
        this.startFromBeginning()
      }
    } else if (!trigger) {
      this.currentTrigger = null
    }

    if (playlistChanged) {
      this.syncControls()
    }
  },

  destroyed() {
    this.audio.removeEventListener('ended', this.handleEnded)
    this.audio.removeEventListener('play', this.handlePlay)
    this.audio.removeEventListener('pause', this.handlePause)
    this.audio.pause()
    this.audio.src = ''
  },

  loadPlaylistFromDataset() {
    const json = this.el.dataset.playlist || '[]'

    if (json === this.currentPlaylistJSON) {
      return false
    }

    this.currentPlaylistJSON = json

    try {
      const parsed = JSON.parse(json)
      this.playlist = Array.isArray(parsed) ? parsed : []
    } catch (error) {
      console.error('Failed to parse prayer playlist:', error)
      this.playlist = []
    }

    this.currentSegment = 0
    this.setTrackLabel()

    if (this.playlist.length > 0) {
      this.loadSegment(this.currentSegment)
    } else {
      this.audio.pause()
      this.audio.src = ''
    }

    return true
  },

  loadSegment(index) {
    const segment = this.playlist[index]

    if (!segment) {
      return
    }

    if (this.audio.src !== segment.url) {
      this.audio.src = segment.url
    }

    this.currentSegment = index
    this.setTrackLabel(segment.label)
    this.syncControls()
  },

  togglePlayback() {
    if (this.playlist.length === 0) {
      return
    }

    if (this.audio.paused) {
      this.play()
    } else {
      this.pause()
    }
  },

  play() {
    if (this.playlist.length === 0) {
      return
    }

    const segment = this.playlist[this.currentSegment]
    if (!segment) {
      return
    }

    if (!this.audio.src || this.audio.src !== segment.url) {
      this.loadSegment(this.currentSegment)
    }

    this.audio
      .play()
      .catch(error => console.error('Unable to play audio segment:', error))
  },

  pause() {
    this.audio.pause()
  },

  advanceSegment(direction) {
    if (this.playlist.length === 0) {
      return
    }

    const nextIndex = this.currentSegment + direction

    if (nextIndex < 0 || nextIndex >= this.playlist.length) {
      return
    }

    this.loadSegment(nextIndex)

    if (!this.audio.paused) {
      this.play()
    }
  },

  startFromBeginning() {
    this.currentSegment = 0
    this.loadSegment(this.currentSegment)
    this.play()
  },

  handleEnded() {
    if (this.currentSegment < this.playlist.length - 1) {
      this.advanceSegment(1)
      this.play()
    } else {
      this.pause()
    }
  },

  handlePlay() {
    this.updateToggleButton(true)
  },

  handlePause() {
    this.updateToggleButton(false)
  },

  setTrackLabel(label) {
    if (!this.trackLabel) return

    const text = label || 'Audio Ready'
    this.trackLabel.textContent = text
  },

  updateToggleButton(playing) {
    if (!this.toggleButton) return

    if (this.playlist.length === 0) {
      this.toggleButton.setAttribute('disabled', 'disabled')
    } else {
      this.toggleButton.removeAttribute('disabled')
    }

    if (playing) {
      this.playIcon?.classList.add('hidden')
      this.pauseIcon?.classList.remove('hidden')
    } else {
      this.playIcon?.classList.remove('hidden')
      this.pauseIcon?.classList.add('hidden')
    }
  },

  syncControls() {
    const hasPlaylist = this.playlist.length > 0

    if (this.prevSegmentButton) {
      if (!hasPlaylist || this.currentSegment === 0) {
        this.prevSegmentButton.setAttribute('disabled', 'disabled')
      } else {
        this.prevSegmentButton.removeAttribute('disabled')
      }
    }

    if (this.nextSegmentButton) {
      if (!hasPlaylist || this.currentSegment >= this.playlist.length - 1) {
        this.nextSegmentButton.setAttribute('disabled', 'disabled')
      } else {
        this.nextSegmentButton.removeAttribute('disabled')
      }
    }

    if (!hasPlaylist) {
      this.updateToggleButton(false)
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

