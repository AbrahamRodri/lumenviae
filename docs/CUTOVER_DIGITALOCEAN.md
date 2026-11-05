# Lumen Viae: moving from Fly to a DigitalOcean Droplet

Abraham, 2 November 2026: "move lumen viae to digital ocean guide me
through using chrome". This is the order of the move, step by step. The
server's setup is `docs/HOSTING_RECIPE.md`; this file adds what is Lumen
Viae's own: the data copy from Fly, the DNS switch in Cloudflare, the watch
and the rollback. Fly stays live, and is what visitors and the apps reach,
until step 9 is checked. Every step is Abraham's, or run with him watching.

The installed apps must not notice anything. Android and the website call
`https://www.lumenviae.org` (`/api` and `/api/v2`). Installed iPhones on
4.1 and earlier call `https://lumenviae.fly.dev/api` and `/api/office`
directly, not `www.lumenviae.org`, so they reach Fly whatever the DNS says;
4.2 moves them to `www.lumenviae.org`. The site's pages must keep working,
and HSTS is on, so a certificate error would be unclickable. The order
below is built around those three.

## Before the day

1. **The Droplet** (recipe steps 1 to 3): Basic 1 GB, SFO3, Ubuntu 24.04,
   IPv6 and Monitoring on, weekly backups on, `deploy/vm/cloud-init.yaml`
   as user data. Then the Cloud Firewall (Networking, Firewalls): inbound
   SSH, HTTP and HTTPS, each from All IPv4 and All IPv6, applied to the
   Droplet. SSH stays open to all because CI's deploys come from GitHub's
   runners; it takes keys only. A Droplet made without the firewall is
   still covered by ufw for SSH, but Docker's published ports (80 and
   443) bypass ufw, so the firewall is what limits them. Check:
   `ssh abraham@<ip> cloud-init status --wait` says `done`, `swapon --show`
   lists `/swapfile`, `docker compose version` answers.
   - Made without the cloud-init (root with Abraham's key only): run its
     steps by hand as root before anything else. The recipe's file is the
     list.
2. **Cloudflare token for certificates:** an API token limited to Zone,
   DNS, Edit on `lumenviae.org` (My Profile, API Tokens). It goes in `.env`
   as `CLOUDFLARE_API_TOKEN`; Caddy uses it to get certificates by DNS-01,
   so they exist before DNS points at the Droplet.
3. **The stack folder** (as `deploy`): `/srv/lumenviae` holds `.env` (mode
   600, the names in `deploy/vm/env.example`) and a copy of `deploy/vm/`
   from main (`compose.yml`, `Caddyfile`, `caddy/`, `bin/`, `systemd/`).
   Where each `.env` value comes from:
   - `SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET`: new ones
     (`openssl rand -base64 48`); admins are signed out once.
   - `POSTGRES_PASSWORD`: new; `DATABASE_URL` uses it.
   - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`: a new key for the app's
     S3 user, made in the AWS console; `AWS_REGION=us-east-2`,
     `AWS_S3_BUCKET=lumenviae-audio`.
   - `ADMIN_PASSWORD`, `OPS_STATUS_TOKEN` (the same value as the GitHub
     secret), `CLOUDFLARE_API_TOKEN` (step 2).
   - Any of these set on Fly (`fly secrets list -a lumenviae` shows the
     names): `GEOLOCATION_ENABLED`, `GEOLOCATION_PROVIDER`,
     `PUBLIC_ASSET_BASE_URL`, `AUDIO_URL_TTL_SECONDS`.
   - **Not** `ELEVEN_LABS_API_KEY`: the copied jobs table would send any
     pending narration to ElevenLabs from the Droplet. Without the key a
     narration job cancels before any call.
4. **The release image:** once `HOSTING=vm` is set (step 8) every push
   builds it in CI. The first one comes from the Mac, built for the
   Droplet's CPU and loaded straight onto it, with no registry login:
   `docker buildx build --platform linux/amd64 -t lumenviae:<commit> --load .`
   at main's commit, then
   `docker save lumenviae:<commit> | gzip | ssh deploy@<ip> 'gunzip | docker load'`.
   On an Apple Silicon Mac, if the build crashes (a `beam.smp` segfault),
   turn on Rosetta in Docker Desktop's settings and build again.
   `IMAGE=lumenviae:<commit>` below means that image.
5. **Backups:** recipe step 5. It needs R2 enabled on Abraham's Cloudflare
   account. Until it is, the weekly Droplet backup is the only backup:
   enable R2 before the day, or keep Fly's database (step 11) until the
   first R2 dump and restore test pass.
6. **The day before:** in Cloudflare, set the TTL on `@` and `www` to 60
   seconds. Write down the current records for the rollback: A
   66.241.124.96 and AAAA 2a09:8280:1::a9:b34:0 (check them on the day).

## On the day (about 30 minutes)

7. **Rehearse under the real name**, with yesterday's data:
   - Dump Fly's database (read-only on Fly):
     `fly proxy 15432:5432 -a lumenviae-db`, then, in another terminal,
     `docker run --rm -it -v ~/:/out postgres:17 pg_dump -Fc -h host.docker.internal -p 15432 -U postgres -f /out/lv.dump lumenviae`
     (writes `~/lv.dump`). Fly's database is `lumenviae`; the Droplet's is
     `lumen_viae`, and the restore below (`-d lumen_viae --no-owner
     --no-acl`) handles the difference. Dump with the `postgres:17` image
     because Fly runs Postgres 17 and the Mac's Homebrew `pg_dump` is 14,
     which refuses a newer server. The `postgres` password is the
     `lumenviae-db` app's `OPERATOR_PASSWORD` secret; reading it needs
     Abraham's own Fly login. Never print it.
   - Copy it up: `scp ~/lv.dump deploy@<ip>:/srv/lumenviae/`, then on the
     Droplet, in `/srv/lumenviae`: `export IMAGE=lumenviae:<commit>
     RELEASE_COMMIT=<commit>` (compose refuses to start without IMAGE, and
     `/healthz` reports RELEASE_COMMIT), `docker compose up -d db`, then
     `docker compose exec -T db pg_restore --no-owner --no-acl -U lumen_viae -d lumen_viae < lv.dump`.
   - Migrate, then start the stack: `docker compose run --rm app /app/bin/migrate`,
     `docker compose up -d --wait`.
     Caddy gets the certificates for `lumenviae.org` and
     `www.lumenviae.org` while DNS still points at Fly.
   - On the Mac, point both names at the Droplet in `/etc/hosts`, run
     `EXPECT_COMMIT=<main's commit> bin/prod-feature-check` (every feature
     ok), open the site and `/admin`, then remove the hosts lines.
   - Over IPv6 too (the Cloud Firewall must allow 80 and 443 from All
     IPv6 as well as All IPv4):
     `curl -6 --resolve 'www.lumenviae.org:443:[<droplet IPv6>]' https://www.lumenviae.org/healthz`.
   - `docker stats --no-stream`: note memory. Above about 85% of 1 GB with
     swap busy: resize to 2 GB before going on.
   - `docker compose stop app`, so the rehearsal's copy takes no jobs or
     writes before the day.
8. **The cutover:**
   - **Freeze:** no merges to main, no console edits. Note the time.
   - **Fresh dump** from Fly as in step 7; note
     `SELECT max(id) FROM rosary_completions` (the max at the dump).
   - On the Droplet: `docker compose stop app`, drop and re-create the
     database (`docker compose exec db dropdb -U lumen_viae lumen_viae`,
     then `createdb`), restore the fresh dump, compare row counts of
     `rosary_completions`, `meditations`, `meditation_sets` with Fly's, and
     move the completion ids clear of Fly's:
     `SELECT setval(pg_get_serial_sequence('rosary_completions','id'), <max at dump> + 1000);`
   - `docker compose run --rm app /app/bin/migrate` (it should find nothing),
     `docker compose up -d --wait`, then the `/etc/hosts` and IPv6 checks
     again.
   - **DNS** in Cloudflare: `@` and `www` A to the Droplet's IPv4, AAAA to
     its IPv6. Keep them DNS-only (grey cloud) for now.
   - **Deploys:** in the repository's settings, add the secrets `VM_HOST`,
     `VM_SSH_KEY`, `VM_SSH_KNOWN_HOSTS` (recipe step 6) and set the variable
     `HOSTING=vm`.
   - **Catch up**, and again after 15 minutes, that evening and the next
     morning (stale DNS keeps sending a few visitors to Fly for a while):
     `COPY (SELECT * FROM rosary_completions WHERE id > <max at dump>) TO STDOUT`
     on Fly, then on the Droplet copy that into a temp table
     (`CREATE TEMP TABLE c (LIKE rosary_completions)`, `COPY c FROM STDIN`)
     and `INSERT INTO rosary_completions SELECT * FROM c ON CONFLICT (id) DO NOTHING`,
     so a row already copied is skipped, not an error.
9. **The watch:** `bin/prod-feature-check` with `EXPECT_COMMIT` right after
   the switch, after 15 minutes and that evening; `/ops/status` with the
   token (database, office engine, queues); on the Droplet,
   `docker compose logs -f app | grep -E '\[error\]|request_failed|job_failed'`;
   one completion from the iPhone app and one from the site, each placed
   where the device is, not at the Droplet; the next morning, the first
   R2 backup in `journalctl -u backup@lumenviae`.

## Rollback to Fly (any time in the first week)

1. Cloudflare: `@` and `www` back to A 66.241.124.96 and AAAA
   2a09:8280:1::a9:b34:0. Fly still holds its certificates, so HTTPS works
   at once.
2. Unset `HOSTING`, so deploys go to Fly again.
3. Copy back completions written on the Droplet since the switch, the same
   `COPY` the other way, after moving Fly's sequence clear of the
   Droplet's ids.

Fly stays up for that week (about $2.50). After a quiet week, and only
with Abraham's yes: scale `lumenviae` to zero, then destroy `lumenviae`,
`lumenviae-db` (after a final dump kept in R2) and `lumenviae-office`.

## What a seat would need on the Droplet

None of this is needed for the move: every step above is Abraham's, typed
by him or read out to him. Seats in this rig do not deploy, do not read
secrets and do not touch production. If Abraham wants a seat to look at
the Droplet with him (logs, `docker stats`, a failed check), that is his
decision, and it needs:

- **Which seat:** `api-build@lumenviae`.
- **As which user:** `deploy`, never `abraham` or root.
- **What Abraham does:** the seat makes its own key pair and gives him only
  the public half. He adds it to `/home/deploy/.ssh/authorized_keys`, and
  removes the line when the session is over.
- **The catch:** `deploy` is in the `docker` group, which can read `.env`
  through a container and is root-equivalent. So "look only" is a promise
  the seat keeps, not a limit the server enforces. A narrower, read-only
  user (no Docker, logs through `journalctl` only) can be made instead if
  he wants a real limit.
