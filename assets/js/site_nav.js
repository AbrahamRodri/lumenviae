// The public header's menus: the desktop Mysteries dropdown and the phone
// menu. The header is in the root layout, outside every LiveView, so this is
// plain DOM code on document-level listeners rather than a hook.
//
// A toggle is a button with `data-menu-toggle` and `aria-controls` naming its
// menu. `aria-expanded` on the button is the single source of truth: the menu
// is shown exactly when it is "true", which is also what the CSS keys the
// chevron and the open/close icons on.

const toggles = () => Array.from(document.querySelectorAll("[data-menu-toggle]"))
const menuFor = (button) => document.getElementById(button.getAttribute("aria-controls"))
const isOpen = (button) => button.getAttribute("aria-expanded") === "true"

function setOpen(button, open) {
  const menu = menuFor(button)
  if (!menu) return
  button.setAttribute("aria-expanded", open ? "true" : "false")
  menu.classList.toggle("hidden", !open)
}

function closeAll(except = null) {
  toggles().forEach((button) => {
    if (button !== except && isOpen(button)) setOpen(button, false)
  })
}

// Live navigation does not re-render the root layout, so the server's
// aria-current would go stale; this moves it to the link for the new path.
function markCurrent() {
  const path = window.location.pathname
  document.querySelectorAll("[data-nav-link]").forEach((link) => {
    if (link.getAttribute("href") === path) {
      link.setAttribute("aria-current", "page")
    } else {
      link.removeAttribute("aria-current")
    }
  })
}

export function initSiteNav() {
  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-menu-toggle]")

    if (button) {
      const open = !isOpen(button)
      closeAll(button)
      setOpen(button, open)
      return
    }

    // A click on a link inside an open menu, or anywhere outside one,
    // closes it. Clicks elsewhere inside the menu (its padding) leave it be.
    toggles().forEach((toggle) => {
      if (!isOpen(toggle)) return
      const menu = menuFor(toggle)
      if (!menu.contains(event.target) || event.target.closest("a")) setOpen(toggle, false)
    })
  })

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return

    const open = toggles().find(isOpen)
    if (!open) return

    setOpen(open, false)
    open.focus()
  })

  // Tabbing out of the desktop dropdown closes it, so it never hangs open
  // over the page behind the focus. The phone menu stays open until closed:
  // it pushes the page down rather than covering it.
  document.addEventListener("focusin", (event) => {
    toggles().forEach((toggle) => {
      if (!isOpen(toggle) || toggle.id === "mobile-menu-button") return
      const menu = menuFor(toggle)
      if (!menu.contains(event.target) && event.target !== toggle) setOpen(toggle, false)
    })
  })

  window.addEventListener("phx:page-loading-stop", () => {
    closeAll()
    markCurrent()
  })

  window.addEventListener("popstate", markCurrent)
}
