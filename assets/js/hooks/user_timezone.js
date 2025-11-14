export default {
  mounted() {
    // Get timezone offset in minutes (e.g., -180 for Argentina UTC-3)
    const timezoneOffset = new Date().getTimezoneOffset()
    // Send to server
    this.pushEvent("set_timezone", { offset: timezoneOffset })
  }
}
