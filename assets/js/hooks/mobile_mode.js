export default {
  mounted() {
    const MOBILE_BREAKPOINT = 768
    const isMobileScreen = window.innerWidth < MOBILE_BREAKPOINT

    this.pushEvent("init_mobile_mode", {
      enabled: isMobileScreen
    })
  }
}
