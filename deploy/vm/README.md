# Lumen Viae on one VM

Production runs here: a DigitalOcean Droplet, `lumenviae-prod-2`
(Abraham's choice on 2 November 2026; the plan is
`reports/rig/hosting-migration.md` in the workspace), switched on in
November 2026 with the repository variable `HOSTING=vm`. One small VM runs
the app, Postgres 17, the Divine Office engine and Caddy, about $6 a month.
Fly keeps only a proxy for installed apps (deploy/fly-proxy); its database
was destroyed on 23 Nov 2026.

## What is here

- `compose.yml`: the four services. The app is the same release image as
  Fly's, started with `/app/bin/server`; only Caddy publishes ports.
- `Caddyfile`: HTTPS for `lumenviae.org` and `www.lumenviae.org`, with
  certificates by DNS-01 through Cloudflare, and `X-Real-IP` replaced
  with the real peer.
- `caddy/Dockerfile`: Caddy with the Cloudflare DNS module.
- `env.example`: the names the VM's `.env` holds. No values, and no
  ElevenLabs key.
- `cloud-init.yaml`: the server's setup (users, SSH by key only, automatic
  security upgrades, Docker, ufw).
- `bin/backup`, `bin/restore-test`, `systemd/`, `backup.env.example`: the
  nightly `pg_dump` to R2 and the weekly restore test.
- `bin/prune-images`: run by each deploy after its checks, removes old
  release images (keeping the running one and the two newest others) and the build
  cache, so the disk does not fill.
- `bin/system-check`, `systemd/system-check@.*`, `system-check.env.example`:
  the server checked every 15 minutes (disk, memory, containers, `/healthz`),
  pinging healthchecks.io (docs/DEPLOY_WATCH.md, "Watch and rollback").
- `bin/write-status`: each of those three timers writes what it found to
  `status/<name>.json` (ok, when, a short detail; disk and memory for the
  system check). compose.yml mounts `status/` read-only into the app as
  `OPS_STATUS_DIR`, and the console's System page shows it under Server.
  The deploy makes the folder as `deploy` before compose runs.

This folder is also the shared recipe Tornado Diet and ClipperHandz copy:
`docs/HOSTING_RECIPE.md` says how to set a server up and which names to
change.

## How it is switched on

The deploy lives in `.github/workflows/ci.yml`. The repository variable
`HOSTING` picks the job:

- unset: `deploy`, to Fly, as before the move (it can no longer work:
  Fly's database is gone);
- `vm`: `deploy-vm`, which builds the release image from main's commit,
  pushes it to GHCR, copies the pinned Office engine image into our own
  GHCR copy if it is not there yet (docs/OFFICE_API.md, "Updating the
  engine"), and over SSH (user `deploy`, folder
  `/srv/lumenviae`) migrates and restarts the stack with
  `RELEASE_COMMIT` set, then runs `bin/post-deploy-check` and
  `bin/prod-feature-check` as Fly's job does.

`HOSTING` is `vm` today. `deploy-vm` uses three repository secrets:
`VM_HOST`, `VM_SSH_KEY` and `VM_SSH_KNOWN_HOSTS`. The order of the switch
(rehearsal under the real name, the database copy, the DNS flip, setting
`HOSTING=vm`, the watch and the rollback) is the runbook in the hosting
plan. Unsetting `HOSTING` would send the next deploy back to Fly, which no
longer has a database; whether to remove that path is on Desk card
lv-fly-deploy-leftovers.

## The one code change it needed

`LumenViaeWeb.ClientIP` reads the caller's address from one header the
proxy overwrites. On Fly that is `Fly-Client-IP`, the default; on the VM
the compose file sets `CLIENT_IP_HEADER=x-real-ip`, the header Caddy
writes. Without it every completion would be placed at Caddy.
