# woocommerce-runner

A disposable Docker environment for WooCommerce plugins. `wc-runner` has two
jobs: it runs a plugin's PHPUnit suite and exits with the result (the
default action), or it boots a throwaway, fully seeded store for manual QA
(`--demo`). It is the WooCommerce sibling of `odoo-runner` — same shape, same
exit-code contract, kept easy to maintain as a pair.

Plugins under test are always bind-mounted read-only. `wc-runner` cannot
write to your plugin source, and it is not a live development server.

## Prerequisites

Docker with the compose plugin, and Python 3.13+. On Arch:

```
sudo pacman -S docker docker-compose
sudo systemctl enable --now docker.service
sudo usermod -aG docker $USER   # then re-login
```

## Run a test suite

```
./wc-runner -d examples/hello-wc-runner                  # one plugin
./wc-runner -d ~/dev/plugin-a -d ~/dev/plugin-b           # several, in order
./wc-runner -p ~/dev/plugin-a,~/dev/plugin-b              # same, comma-form
./wc-runner -d ~/dev/my-plugin -- --filter=TestOrders     # phpunit passthrough
```

Exit code is the test result — non-zero if any plugin's suite fails. Never
parse the log output for pass/fail; check `$?`. With more than one plugin
dir, the exit code is the worst of the individual runs.

`-d/--plugin-dir` and `-p/--plugins` both accumulate and merge into one
list, so mix them freely. Each plugin dir must satisfy the contract below;
`wc-runner` validates every dir before it touches Docker and fails fast,
naming the offending directory, if one doesn't.

### Plugin repo contract

A plugin repo directory must contain:

- A top-level `*.php` file with a standard WordPress plugin header
  (`Plugin Name: ...` in the first 8 KB — the same rule WordPress core
  uses to discover plugins).
- `composer.json` with `require-dev` entries for `wp-phpunit/wp-phpunit`,
  `yoast/phpunit-polyfills` (`^2`), and `phpunit/phpunit` (`^9.6`).
- `phpunit.xml` or `phpunit.xml.dist` pointing `bootstrap` at a PHP file
  (conventionally `tests/bootstrap.php`).
- A bootstrap that loads WooCommerce, then the plugin under test, on the
  `muplugins_loaded` hook, before handing off to wp-phpunit's own
  bootstrap. See `examples/hello-wc-runner/tests/bootstrap.php` for a
  working reference — copy it as a starting point.

`wc-runner` provides the rest: WordPress core and WooCommerce at a pinned
version, a dedicated `wordpress_test` database (rendered into
`wp-tests-config.php` for wp-phpunit), and Composer with a persistent
package cache.

## Flags

| Flag | Default | Meaning |
| --- | --- | --- |
| `-d`, `--plugin-dir DIR` | — | plugin directory (repeatable) |
| `-p`, `--plugins D1,D2` | — | comma-separated plugin directories (repeatable, merges with `-d`) |
| `-V`, `--wc-version VER` | latest | WooCommerce version to pin |
| `--wp-version VER` | latest | WordPress core version |
| `--php-version VER` | `8.3` | PHP version for the base image |
| `--port PORT` | `8080` | host port for `--demo` |
| `--with-cache` | off | start a Valkey object cache alongside the store |
| `--persist` | off | keep the database in a named volume instead of tmpfs |
| `--demo` | off | boot the seeded browsable store instead of running tests |
| `--down` | — | stop containers, keep named volumes |
| `--destroy [--yes]` | — | stop containers and delete all volumes; confirms unless `--yes` |
| `-- args...` | — | passed straight to phpunit (default test mode only) |

`--demo`, `--down`, and `--destroy` are mutually exclusive. `--down` and
`--destroy` need no plugin dirs — they read the last run's settings from
saved state and tear down accordingly, falling back to defaults if that
state is missing.

## Demo a store

```
./wc-runner --demo -d examples/hello-wc-runner
./wc-runner --demo                              # WooCommerce alone, no plugin
./wc-runner --demo --with-cache --persist --port 8090
```

Prints a banner with the store URL, the wp-admin URL, and admin
credentials (`admin` / `woocommerce-runner`) once seeding finishes.
Re-running `--demo` against the same state is fast and idempotent — it
does not re-import sample products or reinstall WooCommerce unless the
pinned version changed.

Poke the running store directly with WP-CLI:

```
docker compose exec -u www-data wordpress wp plugin list --status=active
docker compose exec -u www-data wordpress wp option get woocommerce_currency
```

### Persist and destroy semantics

- Default: the database lives in tmpfs. `./wc-runner --down` then
  `./wc-runner --demo` again starts from an empty store.
- `--persist`: the database lives in a named volume and survives `--down`.
- `--destroy [--yes]`: stops everything and deletes every
  `woocommerce-runner_*` volume — `wp-data` (core + WooCommerce cache),
  `composer-cache`, and `db-data` if it exists. There is no undo; it
  confirms first unless you pass `--yes`.

## GitHub Actions (plugin CI)

This repo doubles as a composite GitHub Action (`action.yml`), so a plugin
repo can run its suite before a release or tag with two steps — GitHub's
Ubuntu runners already have Docker with compose v2:

```yaml
name: tests
on:
  pull_request:
  push:
    tags: ["v*"]

jobs:
  phpunit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: JorDunn/woocommerce-runner@v1
        with:
          wc-version: "9.8.5"
```

The step fails when the suite fails — the exit code is the result, same as
locally. To test against several WooCommerce versions, put `wc-version` in
a matrix:

```yaml
    strategy:
      matrix:
        wc: ["9.8.5", ""]        # pinned + latest
    steps:
      - uses: actions/checkout@v4
      - uses: JorDunn/woocommerce-runner@v1
        with:
          wc-version: ${{ matrix.wc }}
```

Inputs: `plugin-dir` (default `.`), `plugins`, `wc-version`, `wp-version`,
`php-version` (default `8.3`), `phpunit-args`. Pin the action to a tag
(`@v1`) — tag this repo when the contract changes.

## Out of scope

File-watching, Xdebug, MailHog, and multisite are not supported. This is a
disposable validation environment, not a development server.
