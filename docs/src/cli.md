# CLI Guide

This page summarizes PluginSystem CLI usage in a task-first style.

## Entry Modes

PluginSystem supports two entry modes:

1. one-shot mode
2. interactive REPL mode

## REPL Mode

```bash
julia --project=. -m PluginSystem
```

Representative startup output:

```text
PluginSystem REPL mode. Type `help` for commands, `exit` to quit.
plugin>
```

Interactive example:

```text
plugin> help
plugin> status
plugin> registry status
plugin> cache status
plugin> exit
Leaving PluginSystem REPL.
```

## One-shot Mode

```bash
julia --project=. -m PluginSystem help
```

If you install an alias/wrapper, this is equivalent to:

```bash
plugin help
```

## Command Form

```text
plugin <command> [args] [--option value]
```

Command families:

- plugin operations: `add`, `update`, `remove`, `instantiate`, `status`, `pin`, `free`, `develop`, `publish`
- scaffold operations: `generate project`, `generate plugin`
- registry operations: `registry add/remove/update/status`
- cache operations: `cache status/remove`
- help operations: `help`, `help <command>`

## Baseline Setup

```bash
plugin registry add https://github.com/czy-ustc/fixtures-registry.git
```

```text
[registry] ADD
  -> cloning registry sources
  + fixtures-registry
  [ok] added 1 registry(ies)
```

## Scaffolding

```bash
plugin generate project MyProject
```

```text
[scaffold] PROJECT
  -> creating project skeleton
  .. path: C:\Users\maike\code\julia\temp\docs-run-20260225-154453\MyProject
  [ok] generated project `Myproject`
```

```bash
plugin gen plugin plugins/LocalTool --version 0.3.0 --force true
```

```text
[scaffold] PLUGIN
  -> creating plugin skeleton
  .. path: C:\Users\maike\code\julia\temp\docs-run-20260225-154453\MyProject\plugins\LocalTool
  [ok] generated plugin `LocalTool` v0.3.0
```

```bash
plugin gen plugin LocalTool.jl --file true --force true
```

```text
[scaffold] PLUGIN
  -> creating plugin skeleton
  .. path: C:\Users\maike\code\julia\temp\docs-run-20260225-154453\MyProject\LocalTool.jl
  [ok] generated plugin `LocalTool` v0.1.0
```

## Plugin Operations

```bash
plugin add TPluginB
```

```text
[plugin] ADD
  -> collecting project requirements
  -> resolving plugin graph
  -> installing plugin files
  -> plugin delta
  + TPluginA v1.1.0 [fixture]
  + TPluginB v1.0.0 [fixture]
  [ok] installed 2 plugin(s)
```

```bash
plugin update TPluginB
```

```text
[plugin] UPDATE
  -> collecting project requirements
  -> resolving plugin graph
  -> installing plugin files
  -> plugin delta
  = no plugin version changes
  [ok] installed 2 plugin(s)
```

```bash
plugin status
```

```text
[plugin] STATUS
  .. project: C:\Users\maike\code\julia\temp\docs-run-20260225-154453\MyProject\Plugins.toml
  [fixture] TPluginB v1.0.0
  [info] direct plugins: 1
```

```bash
plugin pin TPluginB
```

```text
[plugin] PIN
  -> marking pinned plugins
  [ok] pinned 1 plugin(s)
```

```bash
plugin free TPluginB
```

```text
[plugin] FREE
  -> releasing pinned and developed plugins
  .. unpinned: TPluginB
  [ok] freed 1 plugin(s)
```

`free` can rollback either `pin` or `dev` state.

```bash
plugin remove TPluginB
```

```text
[plugin] REMOVE
  -> updating project requirements
  -> resolving plugin graph
  -> pruning unused plugin files
  -> plugin delta
  - TPluginA v1.1.0
  - TPluginB v1.0.0
  [ok] remaining direct deps: 0
```

## Registry Operations

```bash
plugin registry update
```

```text
[registry] UPDATE
  -> fetching registry updates
  ~ FixtureGeneral
  [ok] updated 1 registry(ies)
```

```bash
plugin registry status
```

```text
[registry] STATUS
  [3575c1d9] FixtureGeneral (https://github.com/czy-ustc/fixtures-registry.git)
  [info] registries: 1
```

```bash
plugin registry remove FixtureGeneral
```

```text
[registry] REMOVE
  -> removing registry checkouts
  - FixtureGeneral
  [ok] removed 1 registry(ies)
```

## Publish with Branch Push and Merge Request

```bash
plugin publish ../fixtures-plugins ../fixtures-registry --subdir fixture/TPluginC/0.1.0/TPluginC --namespace fixture --rev <PLUGIN_SHA> --branch feat/tpluginc-v0.1.0 --base main --push true --merge-request true
```

```text
[plugin] PUBLISH
  -> loading plugin metadata
  -> updating registry metadata
  -> preparing registry branch
  -> committing registry changes
  -> pushing registry branch
  .. registry commit: Publish TPluginC 0.1.0
  .. open merge request: https://github.com/czy-ustc/fixtures-registry/compare/main...feat%2Ftpluginc-v0.1.0?expand=1
  [ok] published TPluginC v0.1.0
```

## Cache Operations

```bash
plugin cache status
```

```text
[cache] STATUS
  [ee1acc40] ..\CoolTool (154 bytes)
  [info] cache entries: 1
```

```bash
plugin cache remove --key <git-tree-sha1>
```

```bash
plugin cache remove --all
```

Representative remove output:

```text
[cache] REMOVE
  -> deleting selected cache entries
  [ok] removed 1 cache entry
```

## Help and Discovery

```bash
plugin help
```

```bash
plugin help add
```

```bash
plugin help registry remove
```

```bash
plugin help generate plugin
```

## Related Pages

- [Getting Started](getting-started.md)
- [Hands-on Tutorial](hands-on-tutorial.md)
- [Managing Plugins](managing-plugins.md)
- [Registries](registries.md)
- [Cache and Artifacts](cache-and-artifacts.md)
