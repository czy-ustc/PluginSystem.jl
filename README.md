# PluginSystem.jl

[![CI](https://github.com/czy-ustc/PluginSystem.jl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/czy-ustc/PluginSystem.jl/actions/workflows/ci.yml)
[![Docs](https://github.com/czy-ustc/PluginSystem.jl/actions/workflows/docs.yml/badge.svg?branch=main)](https://github.com/czy-ustc/PluginSystem.jl/actions/workflows/docs.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Julia](https://img.shields.io/badge/julia-1.12%2B-9558B2.svg)](https://julialang.org/)

PluginSystem is a plugin manager for Julia applications with:

- registry-based dependency resolution
- local/global/registry plugin source precedence
- git-backed download cache
- runtime loading via `@load_plugins` and `load_plugins!`

## Quick Start

```julia
using PluginSystem

# Add from registries or local sources in plugins/
add("TPluginB")
add("MyPlugin@1")

# Inspect state
status()

# Reconcile project declaration
instantiate()

# In your app module:
# module MyApp
# using PluginSystem
# @load_plugins
# end
```

## Main API

- project lifecycle: `add`, `update`, `remove`, `instantiate`, `status`, `pin`, `free`
- author/publish: `dev`, `publish`
- registry management: `Registry.add`, `Registry.remove`, `Registry.update`, `Registry.status`
- cache management: `Cache.status`, `Cache.remove`
- auth: `set_auth!`
- scaffolding: `scaffold_project`, `scaffold_plugin`

## CLI

Run commands through app entrypoint:

```bash
julia --project=. -m PluginSystem help
julia --project=. -m PluginSystem add TPluginB
julia --project=. -m PluginSystem registry status
julia --project=. -m PluginSystem cache status
```

## Documentation

Build docs:

```bash
julia --project=docs docs/make.jl
```

Built site entry:

```text
docs/build/index.html
```

Manual pages are organized from [overview](docs/src/overview.md) to detailed
sections such as [getting started](docs/src/getting-started.md),
[hands-on tutorial](docs/src/hands-on-tutorial.md),
[CLI guide](docs/src/cli.md), and [testing and fixtures](docs/src/testing-and-fixtures.md).

## Development

Run tests:

```bash
julia --project=. test/runtests.jl
```

### Test Fixtures Repository

Integration tests read fixture data from two repositories:

```text
registry metadata: https://github.com/czy-ustc/fixtures-registry.git
plugin sources:    https://github.com/czy-ustc/fixtures-plugins.git
```

You can override fixture source with environment variables:

```bash
set PLUGINSYSTEM_FIXTURE_REGISTRY_REPO=https://github.com/czy-ustc/fixtures-registry.git
set PLUGINSYSTEM_FIXTURE_REGISTRY_REF=v0.3.0
set PLUGINSYSTEM_FIXTURE_PLUGINS_REPO=https://github.com/czy-ustc/fixtures-plugins.git
set PLUGINSYSTEM_FIXTURE_PLUGINS_REF=v0.3.0
```

- `PLUGINSYSTEM_FIXTURE_REGISTRY_REPO`: registry repository URL
- `PLUGINSYSTEM_FIXTURE_REGISTRY_REF`: registry tag/branch (default `v0.3.0`)
- `PLUGINSYSTEM_FIXTURE_PLUGINS_REPO`: plugin source repository URL
- `PLUGINSYSTEM_FIXTURE_PLUGINS_REF`: plugin source tag/branch (default `v0.3.0`)
