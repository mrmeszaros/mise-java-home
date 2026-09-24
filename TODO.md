# TODO

## Migrate to Lua env plugin

### Motivation

mise supports a newer Lua-based env plugin type (`metadata.lua` + `hooks/mise_env.lua`)
that can return `watch_files` alongside env vars. This enables per-file mtime-based cache
invalidation — something the asdf-style `bin/exec-env` cannot do.

The main benefit over the current `mise.plugin.toml` `cache-key` approach: editing
`.sdkmanrc` or `.java-version` **in-place** in the same directory would automatically
bust the cache, with no need for `mise cache clear`.

### What changes

| Concern | asdf-style (current) | Lua env plugin |
|---|---|---|
| Language | bash | Lua 5.1 |
| Cache invalidation | `mise.plugin.toml` cache-key (cwd-based) | `watch_files` return value (mtime-based) |
| Same-dir file edits | stale until `mise cache clear` | automatic |
| Version management | `list-all` / `bin/install` / sentinel `auto` | none — env plugins don't manage versions |
| `bin/exec-env` parsing logic | bash, ~65 lines | Lua, similar complexity |
| Tests | bats against bash source | bats can't source Lua; would need rethink |

### What it closes

- Drops all asdf install lifecycle boilerplate (`list-all`, `bin/install`, `bin/post-plugin-add`)
- No `mise.plugin.toml` `cache-key` workaround needed
- No sentinel version `auto` — env plugins don't need an installed version at all

### What it opens / risks

- **Incompatible with the real-versions redesign** (see above) — an env plugin has no
  version management at all; the two directions are mutually exclusive
- **Test infrastructure needs rethinking** — bats tests source `bin/exec-env` directly;
  that approach doesn't apply to Lua hooks
- **`watch_files` requires `env_cache = true`** in user's mise config for full benefit;
  session-level tracking works without it but is less reliable
- **Lua 5.1** — limited standard library; file reading, shell exec, and string ops are
  all available via mise's built-in modules (`file`, `cmd`, `strings`)

### Relationship to other directions

Lua migration and real-versions redesign are **mutually exclusive** — pick one:
- Lua env plugin: simpler install story, better cache invalidation, no version management
- Real versions (asdf-style): richer mise integration (`mise install`, `mise ls-remote`),
  version pinning in `mise.toml`, idiomatic file support — at the cost of more hooks

## External tool registry support in mise

### Motivation

mise currently owns the full install lifecycle — it downloads, installs, and selects tool
versions. There is no plug point for tools installed by other means (Homebrew, system
packages, manual installs, `.pkg` installers).

Concrete gaps hit in practice:
- **Java**: `/usr/libexec/java_home` is a macOS-native registry that knows about all
  installed JDKs including arch (`arm64` vs `x86_64`). No mise/asdf plugin can query it
  for version selection — `mise-java-home` is a workaround, not a solution.
- **Python**: `pyenv --link` can register brew-installed Pythons. mise has no equivalent —
  it only knows about its own installs under `~/.local/share/mise/installs/python/`.
- **Named global virtualenvs**: `pyenv-virtualenv` manages named envs outside any project.
  mise has no equivalent concept.

### Proposed direction

Decouple **install** from **select** by introducing pluggable registries:

```toml
[settings]
python.external_registries = [
  "/opt/homebrew/opt",
  "/usr/local/lib/python*",
]
```

mise would check its own install dir first, then fall back to `external_registries` to
discover versions. A found external install would be used for `exec-env` (setting PATH,
PYTHON_HOME etc.) without mise having downloaded it.

### Open design questions

- **Metadata format** — what does a registry entry look like? Just a path, or structured
  (version, arch, variant, vendor)? `/usr/libexec/java_home` is a good reference — it
  returns structured metadata including version and arch.
- **Location convention** — where does an external installer drop metadata? A well-known
  dir like `~/.local/share/tool-registry/<tool>/<version>.json`? Or does mise scan a
  configured path and infer from directory structure?
- **Discovery protocol** — scan directories, read a manifest, or call a script? A
  `bin/discover` hook in the plugin would be most flexible.
- **Name shadowing** — if mise and brew both have `python@3.13`, which wins? Explicit
  priority, first match, or user-specified preference?
- **Staleness** — external installs can be removed without mise knowing. Validate on every
  activation, or cache and risk serving a stale path?
- **Cross-tool consistency** — does every plugin implement discovery, or is there a generic
  convention that works for most tools?

### Related

- `mise-java-home` is a hand-crafted workaround for the Java case — it delegates entirely
  to `/usr/libexec/java_home` and uses a sentinel version `auto` to satisfy mise's install
  lifecycle. A proper registry abstraction would make this unnecessary.
- This is worth raising as a feature request on the mise GitHub once the design is more
  concrete. The current gaps are good motivating examples but not yet enough to fully
  specify the protocol.

## Replace `auto` sentinel with real version strings

### Motivation

The current plugin uses a sentinel version `auto` to satisfy mise's install lifecycle
while doing all real version selection at runtime in `bin/exec-env`. This has a
caching problem: the `ExternalPluginCache` keys on `ToolRequest` (tool + version), so
all projects share one cache slot (`java-home@auto`) and exec-env output from one
directory leaks into another.

Replacing `auto` with real Java version strings would:
- Give each installed version its own cache slot for free (no `mise.plugin.toml` hack needed)
- Simplify `bin/exec-env` to ~5 lines (read `ASDF_INSTALL_VERSION`, pass to `/usr/libexec/java_home`)
- Let mise handle `.sdkmanrc` / `.java-version` natively via `list-idiomatic-filenames`
- Make `mise install java-home@17.0.11` mean "register the already-installed 17.0.11 JDK"

### Key findings from `/usr/libexec/java_home` testing

- **Vendor suffix is silently ignored**: `-v 17-zulu`, `-v 17-tem`, `-v 17-open` all fall
  back to the highest installed JVM — vendor is not a filter. Do not carry vendor in the
  version string; only export `JAVA_VENDOR` as informational.
- **Prefix matching works**: `-v 17` picks the highest 17.x across all vendors and arches
  (by version number). `-v 17.0.11` pins to an exact JDK.
- **`JAVA_ARCH` remains the only way to select arch**: `-v 17` on a machine with both
  `17.0.20.1 arm64` and `17.0.18 x86_64` picks the arm64 one (higher version). Only
  `JAVA_ARCH=x86_64` forces the x86_64 JDK.
- **`list-all` should be dynamic**: enumerate installed JDKs via
  `/usr/libexec/java_home --xml`, return patch-level version strings (`17.0.11`,
  `17.0.18`, `17.0.20.1`, ...). This is a local-JDK plugin — there is no remote registry.

### Proposed hook layout

| Hook | Change |
|---|---|
| `bin/list-all` | parse `--xml`, emit one version per JDK |
| `bin/install` | `mkdir -p "$ASDF_INSTALL_PATH/marker"` — no download |
| `bin/exec-env` | read `ASDF_INSTALL_VERSION`, set `JAVA_VERSION`, call `java_home` |
| `bin/parse-legacy-file` (new) | strip vendor from `.sdkmanrc` value, return bare version |
| `mise.plugin.toml` | `[list-idiomatic-filenames]` declares `.sdkmanrc`, `.java-version` |
| `bin/post-plugin-add` | drop — no longer needed |

### Open questions

- `list-all` returning only locally-installed versions means `mise ls-remote java-home`
  is machine-specific. Is that acceptable, or should we maintain a known static version
  list as fallback?
- Future extension: `VERSION:ARCH` syntax (e.g. `17.0.18:x86_64`) to encode arch in the
  version string, removing the need for `JAVA_ARCH` env var entirely. `:` is a safe
  separator — it doesn't appear in version strings or vendor names.
- Vendor-aware selection (matching `21.0.4-tem` to a specific JDK) would require the
  `--xml` path; `JVMBundleID` or `JVMVendor` filtering. Deferred — see below.
- **Foojay Disco API** — IntelliJ IDEA and Gradle toolchains use
  `https://api.foojay.io/disco/v3.0` to discover and download JDKs by version, vendor,
  arch, and OS. If `list-all` queries this API instead of (or in addition to) the local
  `--xml` output, `bin/install` could actually download and install the requested JDK
  rather than requiring it to be pre-installed. This would make the plugin a full JDK
  installer — a significantly larger scope, but technically straightforward given the
  foojay API is well-documented and free.

## Improve java_home integration

### --failfast on explicit version/arch

Currently if `JAVA_VERSION=25` is set but no JDK 25 is installed,
`/usr/libexec/java_home` silently falls back to the system default.
Passing `-F` when a version or arch filter is active would fail loudly
instead — consistent with how other mise tools behave.

Candidate: only pass `-F` when `JAVA_VERSION` or `JAVA_ARCH` is set,
not on the no-filter system-default path.

### --xml for vendor-aware selection

`/usr/libexec/java_home --xml` returns structured metadata per JVM:
`JVMVersion`, `JVMArch`, `JVMVendor`, `JVMHomePath`, `JVMBundleID`.
This could enable vendor-aware selection — e.g. matching `java=21.0.4-tem`
against `JVMBundleID` rather than ignoring the vendor suffix.
Currently vendor is parsed from `.sdkmanrc` but not used for selection.
