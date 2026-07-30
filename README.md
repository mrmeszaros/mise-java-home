# mise-java-home

A [mise](https://mise.jdx.dev) plugin for macOS that sets `JAVA_HOME` using the native
`/usr/libexec/java_home` discovery mechanism. It does not download or install JDKs — JDKs
must already be present on the system (e.g. via [Azul Zulu](https://www.azul.com/downloads/)).

Unlike other mise Java plugins, this one supports selecting a JDK by **architecture**
(`arm64` vs `x86_64`). On Apple Silicon this matters when you need to run a JDK under
Rosetta 2 — for example to match a Linux production environment or use x86-only native libraries.

## Getting started

### Installation

Requires macOS with [mise](https://mise.jdx.dev) and one or more JDKs installed.
To list available JDKs: `/usr/libexec/java_home -V`

```shell
mise plugins install java-home git@github.com:mrmeszaros/mise-java-home.git
```

### Usage

- `JAVA_VERSION`
	- version prefix passed to the discovery command (`"17"` matches any 17.x)
	- default: system default (highest)
- `JAVA_ARCH`
	- `arm64` or `x86_64`
	- default: system default
- `JAVA_HOME_CMD`
	- discovery command, override only if needed
	- default: `/usr/libexec/java_home`

```toml
[tools]
java-home = "auto"

[env]
JAVA_VERSION = "17"
JAVA_ARCH = "x86_64"
```

All three variables can be set at any configuration level: per project in `mise.toml` or
globally in `~/.config/mise/config.toml` (See [mise configuration](https://mise.jdx.dev/configuration.html)).

### Caveats

mise caches the resolved `JAVA_HOME`. If you change `JAVA_VERSION`, `JAVA_ARCH`, or `JAVA_HOME_CMD` in your
shell after the cache is warm, mise will keep serving the stale value until you run:

```shell
mise cache clear
```

To avoid this, always set `JAVA_VERSION`, `JAVA_ARCH`, and `JAVA_HOME_CMD` in `mise.toml [env]` rather than
as shell exports. The cache invalidates correctly when `mise.toml` changes.

## Development

### How it works

The plugin implements three mise hooks:

- `bin/post-plugin-add`:
	- creates the `auto` marker directory so mise considers the version installed without a separate `mise install` step
- `bin/list-all`:
	- returns the single sentinel version `auto`; real version selection happens via env vars at runtime
- `bin/exec-env`:
	- calls `JAVA_HOME_CMD` with `JAVA_VERSION` and `JAVA_ARCH` from the environment, then exports `JAVA_HOME`

See the [mise plugin development guide](https://mise.jdx.dev/plugins.html) for the full hook interface.

### Running tests

Install [bats](https://github.com/bats-core/bats-core):

```shell
brew install bats-core
```

Run the test suite:

```shell
make test
```

Tests use a mock `java_home` script via `JAVA_HOME_CMD` and do not require any JDKs to be installed.

### Local install

```shell
make install
make uninstall
```
