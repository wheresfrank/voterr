// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Flash messages are ephemeral: never let a stale one come back out of
// Turbo's snapshot cache (e.g. via browser Back after it auto-dismissed).
document.addEventListener("turbo:before-cache", () => {
  document.querySelectorAll(".app-flash, .landing-flash").forEach((el) => el.remove())
})
