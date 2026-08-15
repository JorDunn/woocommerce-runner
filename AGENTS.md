# Agent notes — woocommerce-runner

Disposable Docker WooCommerce environment for validating plugins. Full usage
and flag reference: [README.md](README.md). This file covers only what an
automated agent needs beyond that.

## What this directory is (and isn't)

- This is **infrastructure only**: the `wc-runner` CLI, compose file,
  Dockerfile, and provisioning scripts. Plugin source lives elsewhere and is
  bind-mounted **read-only** into every container. Never edit plugin code
  here, and never try to write into `/var/www/html/wp-content/plugins/*` or
  `/mnt/plugins-src/*` inside a container.
- Not a development server: no file-watching, no Xdebug, no live reload.
  Restart the run to pick up plugin source changes.

## Running tests

- `./wc-runner -d <plugin-dir>` is the entry point for the default action.
  Its **exit code is the test result** (non-zero on any failure) — check it
  rather than parsing phpunit output. With multiple `-d`/`-p` dirs, the exit
  code is the worst of the individual runs.
- Each plugin dir must satisfy the contract in README.md § Plugin repo
  contract (a `Plugin Name:` header, `composer.json`, `phpunit.xml(.dist)`,
  and a WooCommerce-then-plugin bootstrap). `wc-runner` validates this
  **before touching Docker** and fails fast naming the offending dir — that
  error is almost always the actual problem, not a Docker fault.
- Cold run (fresh image build + WordPress core extract + WooCommerce
  download) is **10+ minutes**; warm runs (cached `wp-data`,
  `composer-cache` volumes) are well under a minute. Set Bash timeouts
  accordingly.
- Args after `--` go straight to phpunit and are passed to **every** plugin's
  run when more than one `-d`/`-p` dir is given — e.g.
  `./wc-runner -d <dir> -- --filter=TestOrders`.

## Safety rails

- `./wc-runner --destroy` deletes the `wp-data`, `composer-cache`, and (if
  `--persist` was used) `db-data` volumes. It's the documented full reset,
  but confirm with the user before running it if they didn't ask — it
  prompts interactively unless `--yes` is also passed.
- `./wc-runner --demo` binds host port 8080 by default; check it's free
  (or pass `--port`) before starting.
- Admin login is `admin` / `woocommerce-runner`, DB creds are
  `wordpress`/`wordpress`, DB root password is `wc-runner` — all throwaway,
  fine to use, reachable only inside the compose network (except the store
  itself on the published port).
- To inspect the database directly:
  `docker compose exec db mysql -u root -pwc-runner wordpress`.

## Debug flag (not documented in README)

Setting `WC_RUNNER_DRY_RUN=1` makes `wc-runner` print the `docker compose`
command and environment it would run instead of running it — useful for
checking the generated override without spinning up containers, e.g.:

```
WC_RUNNER_DRY_RUN=1 ./wc-runner -d examples/hello-wc-runner
```

## Commits and releases

- Commit messages MUST follow [Conventional Commits](https://www.conventionalcommits.org/):
  `feat:`, `fix:`, `perf:`, `refactor:`, `docs:`, `ci:`, `chore:`, `test:`,
  `build:`, `revert:`, `security:`, `deprecate:`. Breaking changes to the
  action inputs or the plugin-repo test contract use `!` (e.g. `feat!:`)
  and produce a new major.
- Releases are fully automated by release-please
  (`.github/workflows/release-please.yml`): it maintains a release PR from
  the commits on `main`; merging that PR bumps `version.txt`, updates
  `CHANGELOG.md` (Keep a Changelog sections), tags `vX.Y.Z`, publishes the
  GitHub release, and re-points the floating `v1` tag.
- Never hand-edit released `CHANGELOG.md` sections, `version.txt`,
  `.release-please-manifest.json`, or move tags manually — release-please
  owns all of them.

## Common tasks

```sh
./wc-runner -d <plugin-dir>                          # run one plugin's suite
./wc-runner -d <a> -d <b>                             # several, in order
./wc-runner --demo -d <plugin-dir>                    # browsable store + plugin
docker compose exec -u www-data wordpress wp <cmd>    # poke a running demo
./wc-runner --down                                    # stop, keep volumes
./wc-runner --destroy --yes                           # stop, wipe everything
```
