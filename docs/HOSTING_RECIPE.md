# Hosting recipe: one Phoenix site on one Hetzner server

One recipe for Lumen Viae, Tornado Diet and ClipperHandz (Abraham, 2 November
2026: "lets do hetzner for all three"). Each site runs on one small Hetzner
Cloud server in its owner's Hetzner account: the Phoenix release, its
Postgres, and Caddy for HTTPS, as Docker Compose services. Its database is
dumped to a Cloudflare R2 bucket every night, and a restore of the newest
dump is tested every week. About $5 to $6 a month a site (check
hetzner.com/cloud on the day).

Nothing here is switched on. Creating a server, an account or a bucket,
paying, and changing DNS are the owner's and Abraham's to start, on a day he
names. Lumen Viae's switch-day runbook (the database copy, the DNS flip, the
watch and the rollback) is `reports/rig/hosting-migration.md` in the
workspace; another site writes its own from it.

## The pieces

Everything is in `deploy/vm/` and is copied unchanged apart from names:

| File | What it is |
|---|---|
| `cloud-init.yaml` | Server setup, pasted in when the server is made: Ubuntu 24.04 LTS, users `admin` (a person, sudo) and `deploy` (CI, Docker only), SSH by key only, automatic security upgrades with a 04:00 UTC reboot when needed, Docker with capped logs, ufw |
| `compose.yml` | The services: the app's release image (`/app/bin/server`), Postgres 17, Caddy (Lumen Viae also runs the Office engine) |
| `Caddyfile`, `caddy/Dockerfile` | HTTPS for the site's names, certificates by DNS-01 through Cloudflare, `X-Real-IP` set to the real peer |
| `env.example` | The names in the app's `.env` |
| `backup.env.example` | The names in `backup.env`: the R2 bucket, its token, the site's folder |
| `bin/backup` | `pg_dump` to R2, then checks R2 holds every byte; never deletes |
| `bin/restore-test` | Restores the newest dump into a scratch database, checks its `schema_migrations` against the live one, prints the biggest tables, drops it |
| `systemd/` | `backup@.timer` (nightly, 03:30 UTC) and `restore-test@.timer` (Sundays, 04:30 UTC), one instance per folder under `/srv` |

The CI side is the `deploy-vm` job in `.github/workflows/ci.yml`. It runs
only when the repository variable `HOSTING` is `vm`: it builds the release
image, pushes it to GHCR, copies `deploy/vm/` (compose file, Caddyfile, `bin/`, `systemd/`) to the server, migrates and
restarts the stack, and runs the post-deploy checks. With `HOSTING` unset,
deploys go where they went before.

## Names to change for another site

| What | Lumen Viae | Where |
|---|---|---|
| Folder on the server | `/srv/lumenviae` | `cloud-init.yaml` (last line), `ci.yml` (`deploy-vm`), the timers' instance name |
| Compose project | `name: lumenviae` | `compose.yml` |
| Database and user | `lumen_viae` | `compose.yml` (`db`), `env.example` (`DATABASE_URL`) |
| Domains | `lumenviae.org, www.lumenviae.org` | `Caddyfile`, `PHX_HOST` in `compose.yml` |
| Image | `ghcr.io/abrahamrodri/lumenviae` | `ci.yml` (`IMAGE`) |
| Backup folder | `db/lumenviae` | `backup.env` (`BACKUP_PREFIX`) |
| SSH keys | the owner's and the CI deploy key | `cloud-init.yaml` |

Leave out what the site does not have: the `office` service is Lumen
Viae's alone. A site whose DNS is not on Cloudflare (Tornado Diet's is at
GoDaddy) deletes the `tls { dns cloudflare ... }` block from the Caddyfile
and `CLOUDFLARE_API_TOKEN` from `compose.yml`: Caddy then gets certificates
by HTTP-01, which works only once the DNS points at the server, so its
rehearsal uses a test name.

## Setting up a server

1. **Account** (the owner): a Hetzner account in the owner's name with
   their card, inviting Abraham as a project member. Hetzner may ask for
   identity verification at sign-up.
2. **Firewall** (Hetzner Cloud Firewall, applied to the server; it sits in
   front of Docker, which bypasses ufw for its published ports):
   - TCP 22 from anywhere (SSH takes keys only, and GitHub's runners have
     no fixed addresses);
   - TCP 80 and 443 from anywhere while the DNS is DNS-only (grey cloud);
     once Cloudflare's proxy is on, from Cloudflare's ranges only, which
     are in `priv/cloudflare/ips-v4.txt` and `ips-v6.txt`;
   - ICMP from anywhere.
3. **Server:** CPX11 (2 vCPU, 2GB) in Ashburn, Ubuntu 24.04, an IPv4 and an
   IPv6 address, the firewall above, and `cloud-init.yaml` (with the two
   keys put in) as its cloud config. A few minutes after it boots:
   `ssh admin@<ip> cloud-init status --wait` says `done`.
4. **The stack** (as `deploy`, in `/srv/<name>`): `.env` from
   `env.example`, mode 600. The first `docker compose up -d` comes from the
   rehearsal in the switch-day runbook, then every deploy from CI.
5. **Backups:**
   - In Cloudflare (the owner's account, R2 enabled): a bucket (one bucket
     can hold every site the owner has, each under its own folder); a
     lifecycle rule on it that deletes objects under `db/` after 7 days; an
     R2 API token, Object Read & Write, for that bucket only.
   - On the server, `/srv/<name>/backup.env` from `backup.env.example`,
     mode 600, owner `deploy`.
   - As `admin`, once (each deploy copies `deploy/vm/` to the server, so the
     units are in `/srv/<name>/systemd/`; before the first deploy, copy that
     folder by hand):
     `sudo cp /srv/<name>/systemd/* /etc/systemd/system/`,
     `sudo systemctl daemon-reload`,
     `sudo systemctl enable --now backup@<name>.timer restore-test@<name>.timer`.
   - Run one of each now and read the result:
     `sudo systemctl start backup@<name>.service restore-test@<name>.service`,
     then `journalctl -u backup@<name> -u restore-test@<name> -n 30`.
     The restore test must end `restore-test: ok`.
6. **CI** (repository settings): secrets `VM_HOST`, `VM_SSH_KEY` (the
   private half of the deploy key) and `VM_SSH_KNOWN_HOSTS`
   (`ssh-keyscan <ip>`). Setting the variable `HOSTING=vm` is a step of
   switch day, not of setup.

## Running it

- **Logs:** `ssh deploy@<ip>`, `cd /srv/<name>`, `docker compose logs -f app`.
- **A console on the release:** `docker compose exec app /app/bin/<app> remote`
  (Lumen Viae: `/app/bin/lumen_viae`).
- **Backups:** `systemctl list-timers` shows the next runs;
  `journalctl -u backup@<name>` the last ones. A failed run exits non-zero
  and shows as failed in `systemctl status`; with `BACKUP_PING_URL` set, a
  missed night also sends an email.
- **Restoring for real:** stop the app (`docker compose stop app`), then
  pipe the chosen dump into the live database the way `bin/restore-test`
  pipes it into the scratch one, with `pg_restore --clean --if-exists`, and
  start the app again. Practise on the scratch database first.
- **Upgrades:** the OS patches itself. A new Postgres major version is a
  dump, a new `postgres:<n>` image on an empty volume, and a restore.
