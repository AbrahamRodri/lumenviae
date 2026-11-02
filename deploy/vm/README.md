# Lumen Viae on one VM (not in use)

Production runs on Fly (`fly.toml`). This folder is the prepared
alternative from the hosting plan, `reports/rig/hosting-migration.md` in
the workspace: one small VM running the app, Postgres 17, the Divine
Office engine and Caddy, about $5 a month. Nothing here runs until
Abraham switches, and the switch is his to start.

## What is here

- `compose.yml`: the four services. The app is the same release image as
  Fly's, started with `/app/bin/server`; only Caddy publishes ports.
- `Caddyfile`: HTTPS for `lumenviae.org` and `www.lumenviae.org`, with
  certificates by DNS-01 through Cloudflare, and `X-Real-IP` replaced
  with the real peer.
- `caddy/Dockerfile`: Caddy with the Cloudflare DNS module.
- `env.example`: the names the VM's `.env` holds. No values, and no
  ElevenLabs key.

## How it is switched on

The deploy lives in `.github/workflows/ci.yml`. The repository variable
`HOSTING` picks the job:

- unset (today): `deploy`, to Fly, exactly as before;
- `vm`: `deploy-vm`, which builds the release image from main's commit,
  pushes it to GHCR, and over SSH (user `deploy`, folder
  `/srv/lumenviae`) migrates and restarts the stack with
  `RELEASE_COMMIT` set, then runs `bin/post-deploy-check` and
  `bin/prod-feature-check` as Fly's job does.

`deploy-vm` needs three repository secrets that do not exist yet:
`VM_HOST`, `VM_SSH_KEY` and `VM_SSH_KNOWN_HOSTS`. The order of the switch
(rehearsal under the real name, the database copy, the DNS flip, setting
`HOSTING=vm`, the watch and the rollback) is the runbook in the hosting
plan. Unsetting `HOSTING` sends the next deploy back to Fly.

## The one code change it needed

`LumenViaeWeb.ClientIP` reads the caller's address from one header the
proxy overwrites. On Fly that is `Fly-Client-IP`, the default; on the VM
the compose file sets `CLIENT_IP_HEADER=x-real-ip`, the header Caddy
writes. Without it every completion would be placed at Caddy.
