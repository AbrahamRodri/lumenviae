export default {
  mounted() {
    this.MOBILE_BREAKPOINT = 768
    this.SWIPE_THRESHOLD = 50
    this.SWIPE_TIME_THRESHOLD = 500
    this.RESIZE_DEBOUNCE = 200

    const preference = this.getPreference()
    const isMobileScreen = window.innerWidth < this.MOBILE_BREAKPOINT
    const enabled = this.calculateInitialState(preference, isMobileScreen)

    this.pushEvent("init_mobile_mode", {
      enabled: enabled,
      preference: preference
    })

    this.setupSwipeListeners()
    this.setupResizeListener()
  },

  updated() {
    const enabled = this.el.dataset.mobileModeEnabled === "true"

    if (enabled && !this.swipeListenersActive) {
      this.setupSwipeListeners()
    } else if (!enabled && this.swipeListenersActive) {
      this.removeSwipeListeners()
    }
  },

  destroyed() {
    this.removeSwipeListeners()

    if (this.resizeListener) {
      window.removeEventListener('resize', this.resizeListener)
    }

    if (this.resizeTimeout) {
      clearTimeout(this.resizeTimeout)
    }
  },

  calculateInitialState(preference, isMobileScreen) {
    switch (preference) {
      case 'on':
        return true
      case 'off':
        return false
      default:
        return isMobileScreen
    }
  },

  getPreference() {
    try {
      return localStorage.getItem('rosary_mobile_mode_preference') || 'auto'
    } catch (e) {
      console.warn('Failed to read mobile mode preference:', e)
      return 'auto'
    }
  },

  savePreference(preference) {
    try {
      localStorage.setItem('rosary_mobile_mode_preference', preference)
    } catch (e) {
      console.warn('Failed to save mobile mode preference:', e)
    }
  },

  setupSwipeListeners() {
    if (this.swipeListenersActive) return

    this.handleTouchStart = this.handleTouchStart.bind(this)
    this.handleTouchEnd = this.handleTouchEnd.bind(this)

    this.el.addEventListener('touchstart', this.handleTouchStart, { passive: true })
    this.el.addEventListener('touchend', this.handleTouchEnd, { passive: false })

    this.swipeListenersActive = true
  },

  removeSwipeListeners() {
    if (!this.swipeListenersActive) return

    this.el.removeEventListener('touchstart', this.handleTouchStart)
    this.el.removeEventListener('touchend', this.handleTouchEnd)

    this.swipeListenersActive = false
  },

  handleTouchStart(e) {
    this.swipeStartX = e.touches[0].clientX
    this.swipeStartY = e.touches[0].clientY
    this.swipeStartTime = Date.now()
  },

  handleTouchEnd(e) {
    if (!this.swipeStartX || !this.swipeStartY) return

    const endX = e.changedTouches[0].clientX
    const endY = e.changedTouches[0].clientY
    const deltaX = this.swipeStartX - endX
    const deltaY = this.swipeStartY - endY
    const deltaTime = Date.now() - this.swipeStartTime

    const isHorizontal = Math.abs(deltaX) > Math.abs(deltaY)

    if (
      isHorizontal &&
      Math.abs(deltaX) > this.SWIPE_THRESHOLD &&
      deltaTime < this.SWIPE_TIME_THRESHOLD
    ) {
      if (deltaX > 0) {
        this.pushEvent("next", {})
      } else {
        this.pushEvent("previous", {})
      }
    }

    this.swipeStartX = null
    this.swipeStartY = null
    this.swipeStartTime = null
  },

  setupResizeListener() {
    this.resizeListener = this.debounce(() => {
      const preference = this.el.dataset.mobileModePreference

      if (preference === 'auto') {
        const isMobileScreen = window.innerWidth < this.MOBILE_BREAKPOINT
        this.pushEvent("update_mobile_mode_auto", { enabled: isMobileScreen })
      }
    }, this.RESIZE_DEBOUNCE)

    window.addEventListener('resize', this.resizeListener)
  },

  debounce(func, wait) {
    return (...args) => {
      clearTimeout(this.resizeTimeout)
      this.resizeTimeout = setTimeout(() => func.apply(this, args), wait)
    }
  }
}
