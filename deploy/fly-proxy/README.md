# The Fly pass-through

Installed iPhones on 4.1 and earlier call `https://lumenviae.fly.dev/api`
and `/api/office` directly, not `www.lumenviae.org`. Since production moved
to the Droplet (docs/CUTOVER_DIGITALOCEAN.md), the Fly app `lumenviae` is
this folder: one small Caddy machine that forwards every request to
`https://www.lumenviae.org`, so those iPhones get current content and their
Rosary completions land in the Droplet's database. Abraham, 5 November
2026: "yes, proxy". iPhone 4.2 calls `www.lumenviae.org` itself; once no
installed iPhone is older, the app can go.

- `Caddyfile`: every method, path, query, header and body passed on with
  `Host: www.lumenviae.org`. Redirects go back to the caller as they are,
  never followed. `/_proxy/up` answers `ok` for Fly's machine check and
  says nothing about the Droplet, so a Droplet blip does not take the proxy
  off Fly's router. `/healthz` is the Droplet's own, passed through.
- `Dockerfile`: stock `caddy:2.10` with the Caddyfile.
- `fly.toml`: the app `lumenviae`, `dfw`, one `shared-cpu-1x` 256MB machine,
  always on (no cold start), bluegreen so the switch drops nothing.

## The caller's address

Behind the proxy, every request reaches the Droplet from Fly's address, and
Caddy there writes that into `X-Real-IP`. The proxy also sends the caller's
`Fly-Client-IP` as `X-LV-Client-IP`, with `X-LV-Proxy-Secret`, a secret held
in two places: the Fly secret `FLY_PROXY_SECRET` of `lumenviae` and the same
name in the Droplet's `/srv/lumenviae/.env`. `LumenViaeWeb.ClientIP` believes
`X-LV-Client-IP` only when the secret matches (32 characters or more; unset,
it is never read). The proxy overwrites both headers, so neither a caller of
`lumenviae.fly.dev` nor one of `www.lumenviae.org` can choose them. Without
it, a proxied Rosary would be placed at Fly's proxy, and every old iPhone
would share one address for the completion rate limit.

## Deploying it

Never by CI: no workflow names this folder. `fly-proxy-switch.sh` in the
workspace (`reports/rig/hosting-move-scripts/`) does the first switch with
the final Fly dump around it. A later change to this folder, from Abraham's
own Fly login, at the repository root:

```
fly deploy --config deploy/fly-proxy/fly.toml --local-only
curl -s https://lumenviae.fly.dev/healthz    # the Droplet's commit
```

## Undoing it

`fly-proxy-switch.sh` writes the exact commands to
`fly-state/<UTC time>/UNDO.sh`: start the database and Office machines again,
then deploy the full app on the image Fly ran before the switch:

```
fly machine start <id> -a lumenviae-db
fly deploy -a lumenviae --config fly.toml --image <the image before the switch>
```

`fly releases -a lumenviae --image` lists the images. After
`fly-db-destroy.sh` there is no Fly database to start: a rollback to Fly is
then docs/CUTOVER_DIGITALOCEAN.md's, restoring the Droplet's dump into a new
one. Setting the repository variable `HOSTING` to anything but `vm` makes CI
deploy the full app to `lumenviae` again, over this proxy.
