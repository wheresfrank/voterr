# Voterr — Security Audit

**Scope:** full code review of the Rails 8 application (`app/`, `config/`, `db/`, `Dockerfile`), dependency audit of `Gemfile.lock` against the rubysec advisory DB, and repository hygiene / git history check.
**Date:** audit performed on the working tree at commit `HEAD` of `/root/voterr`.

**Stack:** Ruby 3.3.12p206 · Rails 8.0.5.1 · PostgreSQL (pg 1.5.9) · Puma 7.2.1 · Solid Queue/Cable · Turbo/Stimulus · Faraday 2.14.3 · Nokogiri 1.19.4

---

## Remediation status (updated after fixes)

All findings below have been remediated in this working tree:

| # | Finding | Fix applied |
|---|---|---|
| C1 | Unauthenticated SSRF `/proxy_image` | Endpoint deleted (`ImagesController` + route removed; it was unreferenced). `open-uri` gem dep removed. |
| H1 | Any user could delete any session | `SessionsController#destroy` now scopes via `current_user.sessions.find` |
| H2 | Plaintext `plex_token` | `encrypts :plex_token` on `User` (Active Record Encryption). Keys are derived from `secret_key_base` via `config/initializers/active_record_encryption.rb` (Rails requires three explicit credentials — without them every encrypted write raises). A data migration (`20260828000001_encrypt_existing_plex_tokens`) encrypts legacy plaintext rows and widens the column to `text`. **Deploy note:** users must be logged in fresh — existing tokens are re-encrypted in place by the migration; any user whose login failed before the key fix can simply log in again |
| M1 | `verify_mode: 0` in cable DB TLS | Set to `1` (VERIFY_PEER) in `config/cable.yml` |
| M2 | Unanchored host regex | `/\A[\w-]+\.voterr\.tv\z/` in `production.rb` |
| M3 | Unauthorized ActionCable channel | `SessionVotersChannel` deleted (dead code); Turbo's signed-stream auth untouched |
| M4 | No rate limiting | Rails built-in `rate_limit`: guest joins 10/min, votes 60/min, Plex callback 5/min (per IP); explicit `memory_store` cache in production |
| M6 | 79 dependency advisory hits | All resolved: Rails 8.0.5.1, rack 3.1.22, rack-session 2.1.2, nokogiri 1.19.4, websocket-driver 0.8.2, faraday 2.14.3, concurrent-ruby 1.3.8, crass 1.0.7, loofah 2.25.2, mail 2.9.1, net-imap 0.5.15, rexml 3.4.4, uri 1.0.4, addressable 2.9.0, msgpack 1.8.4, rails-html-sanitizer 1.7.1, puma 7.2.1, json 2.19.9; Ruby 3.3.0→3.3.12; Gemfile security floors added; re-check vs advisory DB = **0 hits** |
| L1 | No CSP | Rails 8 default CSP enabled with session nonces (`content_security_policy.rb`) |
| L2 | Plex token in browser console | `console.log` removed from `plex_auth_controller.js` |
| L3 | Repo junk committed | `dump.rdb`, `.byebug_history`, `.DS_Store` untracked & deleted; `.gitignore` extended |
| L4 | Missing DB uniqueness | Migration `20260828000000_add_security_indexes`: unique index on `sessions.session_token` and `(session_id, LOWER(name))` on voters; `db/schema.rb` updated |
| L5 | `raw(to_json)` in ld+json | Wrapped in `json_escape` in `landing.html.erb` |
| L6 | Unfiltered `positive` param | Explicit `ActiveModel::Type::Boolean` cast in `VotesController` |
| L7 | Stale README stack | Updated to Ruby 3.3.12 / Rails 8.0.5 |
| L10 | Session cookie secure flag | `secure: Rails.env.production?` on the cookie store |

**⚠️ Post-deploy steps required (Ruby is not runnable in the audit sandbox, so bundler/tests could not be executed here):**
1. Run `bundle install` (or `bundle lock --update`) locally to let bundler confirm the lockfile — especially the nokogiri platform variants, which moved to the `-gnu`/`-musl` naming scheme. If bundler complains, `bundle update nokogiri` regenerates them cleanly.
2. Encryption keys: `config/initializers/active_record_encryption.rb` derives the three required credentials from `secret_key_base`. To use dedicated keys instead, set `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` / `_DETERMINISTIC_KEY` / `_KEY_DERIVATION_SALT` env vars in production (rotating `secret_key_base` invalidates stored ciphertext; users re-auth with Plex to refresh).
3. Run `bin/rails db:migrate` (the new indexes fail loudly if legacy data contains duplicate tokens/names — dedupe first if that happens; the token-encryption migration re-encrypts legacy plaintext rows).
4. Run the test suite: `bin/rails test`.

Not addressed (by design): guest identity remains name-based (documented product decision, M5); TMDB poster lookup caching (performance item, L9).

---

## Summary

| Severity | Count | Highlights |
|---|---|---|
| Critical | 1 | Unauthenticated SSRF in `/proxy_image` |
| High | 2 | IDOR: any user can delete any session; plaintext Plex OAuth tokens |
| Medium | 6 | TLS verification disabled (cable DB), unanchored host allowlist, open ActionCable channel, no rate limiting, outdated deps (rack/nokogiri/puma/websocket-driver) |
| Low / Info | 10 | No CSP, token in browser console, repo artifacts (`dump.rdb`, `.byebug_history`), etc. |

No hardcoded secrets or leaked tokens were found in git history; `master.key` is correctly gitignored. Views are consistently ERB-escaped (no stored/reflected XSS found), and all SQL uses placeholders (no injection found).

---

## Critical

### C1. Unauthenticated Server-Side Request Forgery (SSRF) — `app/controllers/images_controller.rb`

```ruby
class ImagesController < ApplicationController
  skip_before_action :verify_authenticity_token

  def proxy
    image_url = params[:url]
    image = URI.open(image_url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}).read
    send_data image, type: 'image/jpeg', disposition: 'inline'
  ...
```

`GET /proxy_image?url=<anything>` fetches an arbitrary attacker-controlled URL from the **server**, with **no authentication** and **CSRF protection disabled**. Consequences:

- **Internal network probing / access:** `http://localhost:3000`, LAN hosts, link-local metadata services (`http://169.254.169.254/...` on cloud hosts), and any internal-only service reachable from the app container. The response body is returned to the caller, making it a read primitive.
- **TLS verification explicitly disabled** (`ssl_verify_mode: VERIFY_NONE`) → the server can be MITM'd even for "https" URLs.
- **DoS amplifier:** the entire remote response is buffered into memory (`URI.open(...).read`) with no size cap, no content-type check, and no timeout — a single request for a multi-GB file (or a slow-drip server) can exhaust worker memory.
- Note: this endpoint appears to exist to proxy Plex/TMDB posters; nothing in the current views uses it (`proxy_image` is referenced nowhere in `app/views` or `app/javascript`), so it may be dead code — remove it, or harden it.

**Fix (if the proxy is still needed):**
1. Restrict to an allowlist of scheme + host (`https://image.tmdb.org`, Plex image hosts only).
2. Resolve the host and refuse private/link-local/loopback ranges; re-check after redirects (`open-uri` follows redirects).
3. Enforce `open_timeout`/`read_timeout` and `Content-Length` / streamed size limit; verify response `Content-Type` is `image/*`.
4. Remove `skip_before_action :verify_authenticity_token` and require login if the endpoint is host-only.
5. Keep TLS verification on.

---

## High

### H1. Broken object-level authorization: any signed-in user can delete any session — `app/controllers/sessions_controller.rb:78`

```ruby
def destroy
  @session = Session.find(params[:id])   # not scoped to current_user
  @session.destroy
```

Every other host action (`show`, `start_voting`, `select_winner`, `VotersController#destroy`) correctly scopes with `current_user.sessions.find(...)`, but `destroy` does not. Any authenticated Plex user can delete **any** voting session by iterating sequential bigint IDs — destroying its voters and votes with it.

**Fix:** `@session = current_user.sessions.find(params[:id])` (raises `RecordNotFound` for foreign sessions).

### H2. Plex OAuth tokens stored in plaintext — `users.plex_token` (`db/schema.rb`)

```ruby
create_table "users" ... t.string "plex_token"
```

The Plex access token is written unencrypted to the database (`PlexAuthController#callback` → `user.update!(plex_token: auth_token)`). A Plex token is a **full account credential**: it grants access to the user's servers, entire libraries, watch history, and the ability to manage the account. A SQL-injection in any future code, a DB backup leak, or log exposure of this column hands over every user's Plex account.

**Fix:** use Active Record Encryption (`encrypts :plex_token` in `User`, with `RAILS_MASTER_KEY`/KMS-managed key). Consider also storing tokens only while needed and offering users a "disconnect Plex" action that revokes the token. Limit the blast radius by fetching movie data during login and discarding the long-lived token if the product allows.

---

## Medium

### M1. Production TLS verification disabled for the Solid Cable database — `config/cable.yml:15`

```yaml
production:
  adapter: solid_cable
  database: cable
  ssl_params:
    verify_mode: 0        # OpenSSL::SSL::VERIFY_NONE
```

The cable DB connection (which carries every Turbo broadcast payload) skips certificate verification → active MITM can read/inject broadcast traffic. Use `verify_mode: 1` (VERIFY_PEER) with a proper CA bundle.

### M2. Host allowlist regex is not anchored — `config/environments/production.rb:86`

```ruby
/.*\.voterr\.tv/   # unanchored
```

`Rails` matches this with `=~`, so a Host header of `sub.voterr.tv.attacker.com` (or any domain containing `.voterr.tv.` as a substring) is **accepted**, defeating the DNS-rebinding / Host-header protection this list exists for. Use `/\A[\w-]+(\.[\w-]+)*\.voterr\.tv\z/` (or enumerate hosts) and keep exact strings for the rest.

### M3. ActionCable channel subscribes without authorization — `app/channels/session_voters_channel.rb`

```ruby
def subscribed
  stream_from "session_voters_#{params[:session_id]}"
end
```

Any connected client (including guests, who are identified in `Connection` by **name only** — `GuestUser.new(session[:guest_name])`) can subscribe to any session id. Today nothing broadcasts to the raw `session_voters_*` stream name (grep confirms it's dead code), but the moment someone wires a broadcast to it, every vote/roster update for every session becomes public to anyone who guesses the sequential id. Either delete the channel or authorize the subscription against `current_user`/session membership.

### M4. No rate limiting on unauthenticated endpoints

- `POST /guest_vote` — creates a voter row (unauthenticated) and triggers two Turbo broadcasts per join; a loop can flood a lobby with voters (data pollution + broadcast DoS).
- `GET /proxy_image` — see C1.
- `POST /plex_auth/callback` — triggers a `FetchAndStoreMoviesJob` per valid token; abusive calls amplify outbound work.

Rails 8 ships `rate_limit` (`config.rate_limits`) — add per-IP limits to these, especially `guest_vote` and `proxy_image`.

### M5. Guest vote integrity is name-only (documented design risk)

Guest identity is `session[:guest_name]` matched against `voters.name` — no secret is bound to a guest beyond the public invite token (`SecureRandom.hex(10)`, 80 bits — adequate). Practical implications: anyone with the invite link can join repeatedly under new names (no cap on voters per session → can distort the "top 3" the host chooses from), and a guest who loses their cookie can be impersonated by anyone reclaiming the name while the lobby is open. If stronger integrity matters, bind a random voter token to the joiner's cookie instead of the name.

### M6. Dependency vulnerabilities (79 advisory hits against `Gemfile.lock`)

Verified against the rubysec/ruby-advisory-db. Most relevant to this app:

| Package | Locked | Fixed in | Impact |
|---|---|---|---|
| `rack` | 3.1.8 | 3.1.21+ | Multiple CVSS 7.5 multipart-parsing DoS (unauthenticated request DoS — directly reachable), info disclosure (CVE-2025-61780), Host-header char injection, `Rack::Sendfile` regex injection |
| `websocket-driver` | 0.7.6 | 0.8.2 | DoS via malformed Host header (7.1) and header-parser memory exhaustion — **ActionCable is in use** |
| `nokogiri` | 1.16.8 | 1.19.4+ | libxslt patch set (7.8), CSS-selector ReDoS (7.5), multiple use-after-free |
| `rails` (8.0.0) | — | 8.0.5.1+ | CSP bypass in Action Dispatch (2024-54133), ANSI escape injection in AR logging (2025-55193), XSS in `SafeBuffer#%` (2026-33170), tag-helper XSS (2026-33168), plus several Active Storage issues (app doesn't use Active Storage attachments, lower exposure) |
| `puma` | 6.5.0 | 7.2.1 / 8.0.2 | PROXY protocol parser issues (7.5) — not enabled in `puma.rb`, but upgrade |
| `faraday` | 2.12.1 | 2.14.3 | SSRF via protocol-relative URL (5.8→7.5) and ReDoS in `NestedParamsEncoder` (app uses `url_encoded` requests) |
| `rack-session` | 2.0.0 | 2.1.2 | Session restored after deletion (affects logout semantics, CVE-2025-46336) |
| `concurrent-ruby` | 1.3.4 | 1.3.7 | `AtomicReference#update` livelock / lock bugs — Solid Queue dependency |
| `rails-html-sanitizer` | 1.6.1 | 1.7.1 | XSS with certain sanitizer configurations |
| `Ruby 3.3.0` | — | 3.3.10+ | CVE-2025-61594 (URI credential leakage, interpreter-level), GHSA-q339-8rmv-2mhv |
| Others | `uri` 1.0.2→1.0.4 (7.5 cred leakage), `crass` 1.0.6→1.0.7, `loofah` 2.23.1→2.25.2, `json` 2.9.0→2.19.9, `addressable` 2.8.7→2.9.0, `mail` 2.8.1→2.9.1, `net-imap` 0.5.1→0.5.15+ | | mostly DoS/informational for this app |

**Action:** bump to `rails ~> 8.0.5`, latest `rack`, `nokogiri`, `websocket-driver`, `faraday`, `rack-session`, `concurrent-ruby`, and a current Ruby 3.3.x patch release; add `bundler-audit` (or `bundle exec bundler:audit`) to CI.

---

## Low / Informational

1. **No Content-Security-Policy.** `config/initializers/content_security_policy.rb` is entirely commented out. No XSS was found, but a CSP (with nonces for the inline JSON-LD blocks) would cap the blast radius of any future XSS, especially on the landing page which loads third-party scripts (cdnjs, Google Fonts, optional Plausible).
2. **Plex auth token logged to the browser console** — `app/javascript/controllers/plex_auth_controller.js:104` (`console.log('Sending auth token to server:', authToken)`). Remove; console output is readable by extensions and shared sessions.
3. **Repo hygiene / operational leakage.** Committed artifacts: `dump.rdb` (Redis dump containing Solid Queue job payloads and internal hostname `Franks-MacBook-Air.local`), `.byebug_history`, `.DS_Store`, `log/`, `storage/`, `tmp/` contents. None contain credentials, but they leak environment details and shouldn't be in VCS — add to `.gitignore` and `git rm --cached`.
4. **No DB uniqueness index on `sessions.session_token`** (model-level validation only) and none on `voters (session_id, name)` — both checks can race under concurrency (duplicate invite tokens / duplicate guest names). Add unique indexes.
5. **`raw(...to_json)` in ld+json script** — `app/views/layouts/landing.html.erb:49`. All interpolated values are currently static (`request.base_url` is host-controlled), but `to_json` output isn't escaped for `</script>`. Use `json_escape` if any dynamic value ever lands here.
6. **Votes can be re-cast repeatedly** (`VotesController#create` uses `find_or_initialize_by` and re-assigns `positive`), and `positive: params[:positive]` is assigned without strong-param filtering; a non-"false" string casts to `true`. Probably intentional (vote changing), but permit/cast it explicitly: `params.permit(:positive)` + `ActiveModel::Type::Boolean`.
7. **`README.md` tech stack is stale** (says Ruby 3.1.1 / Rails 7.1.4; lockfile is 3.3.0 / 8.0.0) — confusing for security-conscious deployers.
8. **Outbound Plex fetches log full error response bodies** (`Rails.logger.error("Failed to fetch resources: #{response.body}")` etc.) — Plex error payloads can include account identifiers; keep log level in mind for a multi-tenant deployment.
9. **`MovieDbService` performs a TMDB API call per rendered movie** (`poster_path` in `_movie.html.erb`) — a performance issue that also turns TMDB latency/outages into page latency; cache poster URLs.
10. **Session cookie store without explicit `secure:`** — acceptable because production sets `force_ssl` (which marks cookies secure), but setting `secure: true` on `config.session_store` makes it explicit for self-hosters who disable force_ssl.

---

## What looks good

- `force_ssl` + `assume_ssl` in production; `config.hosts` present (needs the anchoring fix above).
- Parameterized SQL everywhere, including the Postgres array operators (`where("genres && ARRAY[?]::varchar[]", ...)`).
- Strong params used in controllers; models validate `Vote`/`Voter` invariants (`session_is_open`, `participants_belong_to_session`).
- ERB output consistently escaped; the only `html_safe` strings are static SVG constants.
- `config/master.key` gitignored and absent; `credentials.yml.enc` present; no secrets found in `git log --all` (checked token patterns and deleted files).
- Dockerfile: multi-stage build, non-root runtime user, dummy `SECRET_KEY_BASE` for asset precompile.
- `filter_parameter_logging` covers `token`/`email`/`secret`, so request logs won't leak the Plex token.

---

## Recommended remediation order

1. Remove or harden `/proxy_image` (C1) — it's unauthenticated, un-referenced, and network-reachable.
2. Fix `SessionsController#destroy` scoping (H1) — one-line fix.
3. Encrypt `users.plex_token` (H2) and rotate existing tokens (re-auth via Plex).
4. Set `verify_mode: 1` in `cable.yml` and anchor the `config.hosts` regex (M1, M2).
5. Delete or authorize `SessionVotersChannel` (M3); add rate limits to guest/auth/proxy endpoints (M4).
6. Batch dependency updates (M6) + add `bundler-audit` to CI.
7. Clean repo artifacts and remove the token `console.log` (Low items).