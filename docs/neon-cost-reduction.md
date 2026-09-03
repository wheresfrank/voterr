# Neon cost reduction

The database usage report that prompted this change describes a different
Next.js/Prisma application. Voterr does not contain its dashboard polling,
Inngest jobs, `/api/user/me` route, or Prisma client. The equivalent idle-load
audit of this Rails app found two more direct sources of continuous queries.

## What changed

- Solid Queue was configured to run both inside Puma and as a separate Procfile
  worker. Its workers polled PostgreSQL every 100 ms, its dispatcher every
  second, and every process wrote a heartbeat once per minute.
- Solid Cable also used a PostgreSQL polling adapter with a default interval of
  100 ms after its listener started.
- Active Job and Action Cable now use their in-process `async` adapters. Voterr
  has a small job volume and only uses jobs for Plex imports and Turbo Stream
  broadcasts, so a permanently polling database queue is not cost-effective.
- Puma now defaults to one worker. This is required because the async Action
  Cable adapter broadcasts only within its own process. Puma's threads still
  handle concurrent requests.
- The database pool can be set independently with `DB_POOL`, and idle
  connections are reaped after `DB_IDLE_TIMEOUT` seconds (300 by default).

The tradeoff is that jobs queued in memory can be lost when the web process is
restarted or redeployed. If import volume grows or durable jobs become a product
requirement, use a queue that blocks for work instead of continuously polling
the Neon database.

## Render deployment checklist

Code changes alone do not delete an existing Render background-worker service.
After deploying this branch:

1. Suspend or delete the existing Solid Queue worker in Render. Confirm there
   is only the `web` process from the Procfile.
2. Set `WEB_CONCURRENCY=1`. Values greater than one will make Turbo Stream
   delivery intermittent with the in-process Action Cable adapter.
3. Replace `DATABASE_URL` with the pooled Neon connection string. Its hostname
   contains `-pooler` in the Neon dashboard. Keep the direct connection string
   available outside the web service for migrations if a migration tool needs
   session-level PostgreSQL features.
4. Remove the unused `QUEUE_DATABASE_URL` environment variable.
5. Set Neon auto-suspend to five minutes, then compare compute hours and active
   time over at least 24 hours with a similar traffic period.

Suggested starting values are `RAILS_MAX_THREADS=3`, `DB_POOL=5`, and
`DB_IDLE_TIMEOUT=300`.
