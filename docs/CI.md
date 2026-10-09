# CI and the deploy gate

Every pull request, and every push to `main`, runs
`.github/workflows/ci.yml`. A push to `main` that passes the blocking checks
then deploys to Fly from the same run. Nothing else deploys: there is no
second workflow to race it.

## What runs

| Job | PR | Push to main | Gates the deploy | Catches |
| --- | --- | --- | --- | --- |
| Test | yes | yes | yes | Compile warnings, `mix.lock` drift or unused entries, resources out of step with migrations and snapshots, any failing test (including the GraphQL schema pin and the architecture rules) |
| Assets build | yes | yes | yes | A broken Tailwind or esbuild build |
| Release build (docker) | yes | yes | yes | A break only the production build shows: `docker build .` runs the Dockerfile, which compiles with `MIX_ENV=prod`, builds the assets and assembles the release |
| Dependency audit | yes | yes | no | Retired Hex packages and known-vulnerable dependencies |
| Format (changed files) | yes | no | no | Files the PR touched that are not formatted |
| Credo, Sobelow | yes | yes | no | Report only: counts in the run summary, never a failure |

Versions come from the `Dockerfile` (`ELIXIR_VERSION`, `OTP_VERSION`), so CI
builds with what production builds with. The database is Postgres 17, the
version production runs. Dependencies and `_build` are cached per toolchain
and `mix.lock`.

### Why the deploy is a job in the same workflow

`deploy` is a job with `needs: [test, assets, docker]`, in `ci.yml`. The alternative,
a separate workflow started by `workflow_run`, would work too but is worse
here: the two runs are separate objects in the Actions tab, the deploy has to
check out the right commit by hand, and two quick merges can finish their CI
out of order and deploy the older commit last. In one workflow the graph shows
the gate and a failing check leaves `deploy` skipped.

The audit is left out of `needs` on purpose. Advisory databases change daily,
so that check can turn red with no change of ours, and an unrelated hotfix
should not wait on it. To make it a condition, add `audit` to `needs` on the
`deploy` job.

### The deploy only ever moves forward

Every deploy runs `/app/bin/migrate` first (`release_command` in `fly.toml`).
Re-running an older run of `main` would therefore deploy its commit over a
newer one, after the newer one's migrations had already run. So the deploy job
starts with `.github/scripts/is-main-tip.sh`, which compares the run's commit
with the tip of `main` on GitHub. If they differ it logs a notice, "Not
deploying <sha>: main is now at <tip>", skips the Fly steps and the job still
shows green. If the tip cannot be read it fails and nothing deploys. The
newer run owns the deploy.

The job has a 20 minute timeout, and every action, including
`setup-flyctl`, is pinned to a full commit SHA with its version in a comment.

### Repository settings the workflow cannot set

The gate stops a red `main` from deploying. To stop a red PR from reaching
`main` at all, protect the branch: Settings, Branches, a rule for `main`,
"Require status checks to pass", and select `Test`, `Assets build`,
`Release build (docker)`, `Dependency audit` and `Format (changed files)`.

## Reading a failure

Open the failed run, open the red job, and expand the red step. The step name
says which gate failed.

| Step | Meaning | Fix |
| --- | --- | --- |
| Fetch dependencies | `mix.exs` and `mix.lock` disagree | Run `mix deps.get` and commit `mix.lock`. After a rebase, regenerate it the same way; never hand-merge it |
| No unused entries in mix.lock | A dependency was removed from `mix.exs` but not the lock | `mix deps.unlock --unused` |
| Compile with warnings as errors | A compiler warning, printed above the failure | Fix the warning |
| Resources, migrations and snapshots agree | A resource changed without `mix ash.codegen <name>`, or generated files were edited by hand | Run `mix ash.codegen <name>`, read the generated migration, commit it |
| Test | A test failed; the failing test and its diff are in the log | Reproduce with the commands below |
| Assets build | Tailwind or esbuild failed; its error is in the log | Run `mix assets.deploy` locally |
| Build the image from the Dockerfile | The production build failed; the failing Dockerfile step is the last one in the log. CI pulls the base images from `mirror.gcr.io` (the `REGISTRY` build arg) and uses Docker Hub only if the step before warns that the mirror lacks them; a `429 Too Many Requests` then is Docker Hub's rate limit, so re-run the job | Run `docker build .` locally, then `docker rmi` the image. `MIX_ENV=prod` is blocked in this repo's tooling, so build through Docker rather than `mix`. CI and Fly build amd64 natively; on Apple Silicon `docker build .` builds arm64, and `--platform linux/amd64` builds under emulation, which the builder stage's `ERL_FLAGS="+JMsingle true"` makes work |
| Is this commit still the tip of main? | Not a failure: a notice that the run was skipped because `main` moved on. A real failure means GitHub could not be reached | Re-run the job, or see Re-running |
| Dependency audit | A dependency is retired or has a published advisory; the log names it | Upgrade it; Dependabot usually has the PR open |
| Format (changed files) | The log lists the files and prints the `mix format` command | Run that command and push |

To reproduce the blocking checks locally, with your own test partition so you
do not touch another worktree's database, `mix check` runs the compile, the
codegen check, the format check on the files the branch changed and the
suite, in that order. By hand:

```
export MIX_TEST_PARTITION=<yours> MIX_ENV=test
mix deps.get --check-locked
mix deps.unlock --check-unused
mix compile --force --warnings-as-errors
mix ash.codegen --check
mix test --warnings-as-errors
mix assets.deploy   # then: git clean -fdq priv/static
```

If a test fails on CI and passes locally, check for a seed-dependent or
ordering-dependent test first: re-run with the seed printed at the top of the
log, `mix test --seed <n>`.

## Re-running

- A flaky or infrastructure failure on a pull request: open the run and
  choose "Re-run failed jobs".
- A flaky failure on a run for `main`: re-run it only while that run's commit
  is still the tip of `main`. Then "Re-run failed jobs" re-evaluates `deploy`,
  and a retry that passes deploys without a new commit. If `main` has moved
  on, the re-run still passes its checks but `deploy` logs "Not deploying" and
  does nothing, by design: the newer commit's run owns the deploy.
- A deploy that failed after the checks passed (a Fly outage, say): the same
  rule. While the commit is the tip, "Re-run failed jobs" re-runs only
  `deploy`. Once `main` has moved, merge or re-run the newer commit instead.
- To redeploy an older commit on purpose, revert on `main`: the revert is the
  new tip and deploys like any other commit.
- Stale cache suspected: Actions, Caches, delete the entry beginning `mix-`,
  then re-run. The next run rebuilds it.

## Formatting

The repo is not format-clean, so a repo-wide check would fail every PR. The
format job checks only the `.ex`, `.exs` and `.heex` files the PR changed. If
a PR touches a file that is not yet formatted, that PR formats that file.

Never run a bare `mix format` in an unrelated PR; it rewrites dozens of files.

To retire this check, land one commit that formats everything, then replace
the job's body with `mix format --check-formatted`:

```
git switch -c chore/format-repo origin/main && mix format && git commit -am "Format the whole repo" && echo "$(git rev-parse HEAD)  # mix format" >> .git-blame-ignore-revs
```

Do it when no other branch is open, since it conflicts with all of them. After
it merges, `git config blame.ignoreRevsFile .git-blame-ignore-revs` keeps
`git blame` useful.

## Report-only tools

Credo and Sobelow run on every run and never fail it. Open the run's Summary
tab for the counts and the job log for each finding. Each is a candidate to
become blocking once its current findings are fixed or consciously accepted.
Sobelow records accepted ones with `mix sobelow --mark-skip-all`, which writes
`.sobelow-skips`; it then blocks with
`mix sobelow --skip --exit --threshold medium`. Credo blocks with
`mix credo` (its exit status is non-zero on any issue) once the current ones
are fixed.

## Dependabot

`.github/dependabot.yml` opens weekly pull requests, on Mondays, for Hex
dependencies (the Ash and Phoenix families grouped, minor and patch only) and
for GitHub Actions, including the local `setup-elixir` action. Actions are
pinned to a commit SHA with a `# vX.Y.Z` comment, and Dependabot updates both
together, so review its action PRs like any dependency change. They run the
same CI as any PR. Merging one to `main` deploys it, like any other merge.

## Not done yet

- **A Fly HTTP health check.** Today `fly.toml` has none, so Fly keeps a
  machine in rotation as long as it accepts connections. A wrong check can
  take production down, so it needs its own PR and a deploy watched by a
  person. `GET /healthz` exists (`LumenViaeWeb.HealthController`,
  `LumenViae.Ops.Health`), but it is for an uptime monitor, not for this:
  it asks the database `SELECT 1` and answers 503 when that fails, and the
  database is one small machine, so a blip there would pull every app
  machine out of rotation at once. Proposal: a second path that answers 200
  and touches nothing else (no database), served before the router in the
  endpoint and excluded from `force_ssl` as `/healthz` is (config/prod.exs),
  so a check over the private network gets its answer rather than a
  redirect, then in `fly.toml`:

  ```
  [[http_service.checks]]
    grace_period = "30s"
    interval = "15s"
    method = "GET"
    path = "<that path, not /healthz>"
    timeout = "5s"
  ```

  `force_https` is set on the service, and how it interacts with a check is
  not verified here: try it on a copy of the app before production.
- **The deploy token in a protected environment.** The `FLY_API_TOKEN`
  secret is readable by any workflow in the repository. Moving it to a
  `production` environment limited to `main` needs the owner to create a
  narrower token; the steps are in the pull request that added this section.
