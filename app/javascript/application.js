// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Flash messages are ephemeral: never let a stale one come back out of
// Turbo's snapshot cache (e.g. via browser Back after it auto-dismissed).
document.addEventListener("turbo:before-cache", () => {
  document.querySelectorAll(".app-flash, .landing-flash").forEach((el) => el.remove())
})

// Turbo Stream broadcasts are rendered server-side without a browser session,
// so any authenticity_token they embed is invalid for this browser. Before a
// stream is applied, replace every embedded token with the live page's token.
// Otherwise the next submit of a broadcast-re-rendered form fails CSRF
// verification (Rails 8 responds 422) until the page is fully reloaded.
document.addEventListener("turbo:before-stream-render", (event) => {
  const content = event.detail.newStream?.templateElement?.content
  const liveToken = document.querySelector('meta[name="csrf-token"]')?.content
  if (!content || !liveToken) return

  content.querySelectorAll('input[name="authenticity_token"]').forEach((input) => {
    input.value = liveToken
  })
})
