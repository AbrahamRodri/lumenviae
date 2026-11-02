# Hosting recipe: one Phoenix site on one DigitalOcean Droplet

One recipe for Lumen Viae, Tornado Diet and ClipperHandz. Abraham chose
Hetzner on 2 November 2026, then, once Hetzner's cheap price turned out to
be Europe-only: "okay then we should move everything to use digital ocean
then." Each site runs on one small DigitalOcean Droplet in its owner's
DigitalOcean team: the Phoenix release, its Postgres, and Caddy for HTTPS,
as Docker Compose services. Its database is dumped to a Cloudflare R2
bucket every night (kept 30 days, a missed night emailed), and a restore of
the newest dump is tested every week. About $6 a month a site, Basic 1 GB
(check digitalocean.com/pricing/droplets on the day).

Nothing here is switched on. Creating a server, an account or a bucket,
paying, and changing DNS are the owner's and Abraham's to start, on a day he
names. Lumen Viae's switch-day runbook (the database copy, the DNS flip, the
watch and the rollback) is `reports/rig/hosting-migration.md` in the
workspace; another site writes its own from it.

## The pieces

Everything is in `deploy/vm/` and is copied unchanged apart from names:

| File | What it is |
|---|---|
| `cloud-init.yaml` | Server setup, pasted in when the server is made: Ubuntu 24.04 LTS, users for the owner (a person, sudo; `abraham` for Lumen Viae) and `deploy` (CI, Docker only), SSH by key only, automatic security upgrades with a 04:00 UTC reboot when needed, Docker with capped logs, ufw |
| `compose.yml` | The services: the app's release image (`/app/bin/server`), Postgres 17, Caddy (Lumen Viae also runs the Office engine) |
| `Caddyfile`, `caddy/Dockerfile` | HTTPS for the site's names, certificates by DNS-01 through Cloudflare, `X-Real-IP` set to the real peer |
| `env.example` | The names in the app's `.env` |
| `backup.env.example` | The names in `backup.env`: the R2 bucket, its token, the site's folder |
| `bin/backup` | `pg_dump` to R2, then checks R2 holds every byte and pings the dead man's switch; never deletes |
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
| The person's user | `abraham` (the person's own name, not `admin`) | `cloud-init.yaml` (`users` and `runcmd`) |
| SSH keys | the owner's and the CI deploy key | `cloud-init.yaml` |

Leave out what the site does not have: the `office` service is Lumen
Viae's alone. A site whose DNS is not on Cloudflare (Tornado Diet's is at
GoDaddy) deletes the `tls { dns cloudflare ... }` block from the Caddyfile
and `CLOUDFLARE_API_TOKEN` from `compose.yml`: Caddy then gets certificates
by HTTP-01, which works only once the DNS points at the server, so its
rehearsal uses a test name.

## Setting up a server

1. **Account** (the owner): a DigitalOcean account in the owner's name
   with their card, inviting Abraham to its team as a member.
2. **Firewall** (a DigitalOcean Cloud Firewall, applied to the Droplet; it
   sits in front of Docker, which bypasses ufw for its published ports):
   - TCP 22 from anywhere (SSH takes keys only, and GitHub's runners have
     no fixed addresses);
   - TCP 80 and 443 from All IPv4 and All IPv6 while the DNS is DNS-only
     (grey cloud);
     once Cloudflare's proxy is on, from Cloudflare's ranges only, which
     are in `priv/cloudflare/ips-v4.txt` and `ips-v6.txt`;
   - ICMP from anywhere.
3. **Droplet:** Basic, Regular, 1 GB / 1 vCPU / 25 GB, in SFO3, Ubuntu
   24.04 LTS, IPv6 on, Monitoring on (free: memory and disk graphs, and an
   alert policy at 90% memory that emails the owner), the firewall above,
   and `cloud-init.yaml` (with the two keys put in) as its user data. Pick
   any SSH key at creation; cloud-init turns root login off. A few minutes
   after it boots: `ssh <owner>@<ip> cloud-init status --wait` says `done`.
4. **The stack** (as `deploy`, in `/srv/<name>`): `.env` from
   `env.example`, mode 600. The first `docker compose up -d` comes from the
   rehearsal in the switch-day runbook, then every deploy from CI.
5. **Backups:**
   - In Cloudflare (the owner's account, R2 enabled): a bucket (one bucket
     can hold every site the owner has, each under its own folder); a
     lifecycle rule that deletes objects under `db/` after 30 days; a bucket
     lock rule on `db/` for 7 days, so nothing (the token included) can
     delete a recent dump; an R2 API token, Object Read & Write, for that
     bucket only.
   - A check at healthchecks.io (free), expecting a ping every day; its URL
     is `BACKUP_PING_URL`. `bin/backup` refuses to run without one, because
     a backup that fails quietly for 30 days leaves nothing to restore.
   - On the server, `/srv/<name>/backup.env` from `backup.env.example`,
     mode 600, owner `deploy`.
   - As the owner's user, once (each deploy copies `deploy/vm/` to the server, so the
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

## Size, region and Droplet backups

- **1 GB is enough with swap, but only just for Lumen Viae.** The app ran
  out of memory at 512MB on Fly and runs in 1GB there today; on the Droplet
  it shares 1GB with Postgres, Caddy and (Lumen Viae only) the Office
  engine. `cloud-init.yaml` adds a 2GB swap file, and Lumen Viae's Office
  engine runs 2 workers instead of 4, which its traffic (a few Rosaries a
  day) never fills. Check `docker stats` and the Monitoring graph in the
  rehearsal and in the first week. If memory stays above about 85%, resize
  to Basic 2 GB (about $12) from the control panel: a few minutes down,
  nothing to reinstall. Tornado Diet and ClipperHandz have no Office engine
  and more room.
- **Region SFO3**, close to Fresno, unless a site's users are elsewhere.
  Lumen Viae's are not known from anything a seat can read: Fly's logs name
  only the machine's own region (dfw), and the completions' approximate
  places are in the production database. The admin's completions page
  shows them, and Abraham can glance at it before the day. The iOS and
  Android apps call the API from wherever their users are, so if most of
  them are in the East, NYC3 or ATL1 would serve them better. That is a
  choice made on the day, not built in.
- **DigitalOcean's own Droplet backups: weekly, yes, for Lumen Viae.**
  Weekly backups cost 20% of the Droplet ($1.20, making $7.20); daily cost
  30% ($1.80, making the $7.80). The R2 dumps are the data backup either
  way: nightly, kept 30 days, tested weekly. A Droplet backup adds the rest
  of the server: `.env` and `backup.env` (secrets that would otherwise be
  gathered again by hand), Caddy's certificates, and the setup. That makes
  a dead server a restore of minutes instead of an hour's rebuild from
  this recipe. Daily adds little to that, since the data is already
  nightly. For Tornado Diet and ClipperHandz it is their owners' $1.20 to
  weigh; the recipe works without it.

## Running it

- **Logs:** `ssh deploy@<ip>`, `cd /srv/<name>`, `docker compose logs -f app`.
- **A console on the release:** `docker compose exec app /app/bin/<app> remote`
  (Lumen Viae: `/app/bin/lumen_viae`).
- **Backups:** `systemctl list-timers` shows the next runs;
  `journalctl -u backup@<name>` the last ones. A failed run exits non-zero,
  shows as failed in `systemctl status`, and sends no ping, so
  healthchecks.io emails.
- **Restoring for real:** stop the app (`docker compose stop app`), then
  pipe the chosen dump into the live database the way `bin/restore-test`
  pipes it into the scratch one, with `pg_restore --clean --if-exists`, and
  start the app again. Practise on the scratch database first.
- **Upgrades:** the OS patches itself. A new Postgres major version is a
  dump, a new `postgres:<n>` image on an empty volume, and a restore.
