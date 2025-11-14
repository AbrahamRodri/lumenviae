export default {
  mounted() {
    this.audio = this.el.querySelector('audio')
    this.playButton = this.el.querySelector('[data-audio-play]')
    this.pauseButton = this.el.querySelector('[data-audio-pause]')

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
