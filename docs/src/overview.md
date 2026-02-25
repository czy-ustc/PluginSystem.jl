# Overview

PluginSystem lifecycle:

```text
Scaffold -> Declare -> Resolve -> Install/Link -> Load Runtime -> Operate
```

Core idea: treat plugins like lightweight packages with explicit declaration, reproducible install state, and runtime loading.

## Core Concepts

### Workspace

A workspace is the project root discovered from current directory (or explicit base dir).

Key files:

- `Plugins.toml`: declared direct deps + compat
- `plugins/`: project-local plugins (highest precedence)
- `.julia_plugins/Plugins.toml`: resolved/installed state

### Source Precedence

For the same plugin name:

1. `project` (`plugins/`)
2. `global` (`plugin dev ...` imported source)
3. registry namespace (`fixture`, `acme/tools`, ...)

### Runtime Loading

- `@load_plugins` for module-level static-friendly loading
- `load_plugins!` for explicit runtime control

## Recommended Reading Order

1. [Getting Started](getting-started.md)
2. [CLI Guide](cli.md)
3. [Scaffolding](scaffolding.md)
4. [Managing Plugins](managing-plugins.md)
5. [Registries](registries.md)
6. [Namespaces](namespaces.md)
7. [Version Resolution](version-resolution.md)
8. [Hands-on Tutorial](hands-on-tutorial.md)
9. [Creating and Publishing Plugins](creating-and-publishing-plugins.md)
10. [Testing and Fixtures](testing-and-fixtures.md)
