export default {
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
