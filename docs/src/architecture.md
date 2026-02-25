# Architecture

This page explains how source modules implement the lifecycle described in [Overview](overview.md).

## Module Responsibilities

- `PluginSystem.jl`: package entry, exports, app entrypoint wiring
- `utils.jl`: workspace discovery, path helpers, shared parsing utilities
- `registry.jl`: registry metadata loading and registry operations
- `resolve.jl`: version graph construction and solver integration
- `download.jl`: git source access, sparse export, auth, cache primitives
- `cache.jl`: user-facing cache operations
- `install.jl`: installation/linking and installed manifest updates
- `api.jl`: high-level user commands
- `load.jl`: runtime loader (`load_plugins!`) plus macro-time static import expansion (`@load_plugins`)
- `app.jl`: CLI command parsing and command dispatch
- `precompile.jl`: workload-driven precompile coverage

## Lifecycle Mapping

```text
declare deps -> resolve versions -> install/link -> load runtime
```

- declare: `api.jl` + `utils.jl`
- resolve: `resolve.jl` + `registry.jl`
- install/link: `install.jl` + `download.jl` + `cache.jl`
- runtime load: `load.jl`

## Workspace Model

Core modules use a unified workspace abstraction:

- root discovery from a starting path
- stable access to `Plugins.toml`, `plugins/`, `.julia_plugins/`
- API commands can run against explicit `base_dir`

## Resolution Internals

For solving details, see [Version Resolution](version-resolution.md).

## Cache Internals

- repository cache: normalized source key -> repo cache directory
- sparse export cache: git object id -> exported subtree/blob snapshot

## Design Intent

- deterministic behavior with explicit file-based state
- compatibility with Pkg mental models where practical
- local/project override capability via namespace and source precedence
