# Configuration Files

For shared TOML conventions, see [Pkg TOML files](https://pkgdocs.julialang.org/v1/toml-files/).

This page maps PluginSystem files to lifecycle stages.

Related pages:

- [Overview](overview.md)
- [Version Resolution](version-resolution.md)
- [Registries](registries.md)

## Lifecycle File Map

```text
declare -> resolve/install -> load/runtime -> auth/cache
```

## 1) Project Declaration: `Plugins.toml`

Path: `<project>/Plugins.toml`

```toml
deps = ["TPluginB"]

[compat]
TPluginB = "1"
```

Meaning:

- `deps`: direct plugin names
- `compat`: optional direct constraints

## 2) Installed Manifest: `.julia_plugins/Plugins.toml`

Path: `<project>/.julia_plugins/Plugins.toml`

```toml
[[plugins]]
name = "TPluginA"
version = "1.1.0"
namespace = "fixture"
path = "fixture/TPluginA/TPluginA.jl"

[[plugins]]
name = "TPluginB"
version = "1.0.0"
namespace = "fixture"
path = "fixture/TPluginB/TPluginB.jl"
pinned = true
```

Meaning:

- resolved concrete versions and source namespace
- relative plugin load path
- optional `pinned` flag

## 3) Registry Root: `Registry.toml`

Path: `<registry>/Registry.toml`

```toml
name = "FixtureGeneral"
version = "1.0"
repo = "file:///local/FixtureGeneral"

[packages]
TPluginA = "fixture/TPluginA"
```

Meaning:

- registry identity
- package name -> metadata file prefix mapping

## 4) Plugin Metadata: `<plugin>.toml`

Path: `<registry>/<prefix>.toml`

```toml
name = "TPluginB"
module_name = "TPluginB"
namespace = "fixture"

[versions]
"1.0.0" = { path = "fixture/TPluginB/1.0.0" }

[deps]
"1" = ["TPluginA"]

[compat]
"1" = { TPluginA = "1" }
```

Meaning:

- available versions
- version-scoped deps and compat
- namespace shown in status/change output

## 5) Auth Preferences: `LocalPreferences.toml`

Typical path: `~/.julia/environments/v1.x/LocalPreferences.toml`

```toml
[PluginSystem.git_auth."github.com"]
username = "oauth2"
password = "ghp_xxx"
```

## 6) JETLS Project Config: `.JETLSConfig.toml` (Optional)

Path: `<project>/.JETLSConfig.toml`

```toml
[full_analysis]
auto_instantiate = true
debounce = 1.0

[diagnostic]
enabled = true
all_files = true
```

Meaning:

- controls JETLS analysis behavior for this project
- works across editors without client-specific settings
- pairs with `@load_plugins` static expansion to improve plugin symbol completion

See JETLS documentation for full schema:
https://github.com/aviatesk/JETLS.jl

## 7) Scratchspace Directories

Path pattern: `~/.julia/scratchspaces/<PluginSystem-uuid>/`

- `plugins/`: installed global plugin snapshots
- `global_plugins/`: sources imported by `dev`
- `registries/`: local registry clones
- `git_cache/`: download cache store

## PluginSystem-Specific Differences

- project declaration file is `Plugins.toml` (not `Project.toml`)
- installed state is `.julia_plugins/Plugins.toml` (not `Manifest.toml`)
- source precedence allows project plugins to shadow global/registry plugins
