# Hands-on Tutorial

This is a continuous scenario from project bootstrap to cleanup.

You will:

1. create a host project
2. add registry plugins
3. add a project-local plugin
4. add a global development plugin
5. inspect cache and clean up

Host project name used below: `DemoHost`.

## Prerequisites

- `plugin` CLI available (or `julia -m PluginSystem ...`)
- git available

## 0. Discover Commands

```bash
plugin help
```

Representative output (truncated):

```text
Usage:
  add                     add plugins to project
  update, up              update plugin requirements
  remove, rm              remove plugins from project
  registry add            add registries
  cache status, cache st  show git cache status
```

## 1. Generate Host Project

```bash
plugin generate project DemoHost
```

```text
[scaffold] PROJECT
  -> creating project skeleton
  .. path: C:\Users\maike\code\julia\temp\docs-run-20260225-154453\DemoHost
  [ok] generated project `Demohost`
```

```bash
cd DemoHost
```

Project tree:

```text
DemoHost
├─ Plugins.toml
├─ .gitignore
├─ plugins/
└─ src/
   └─ Demohost.jl
```

## 2. Add Registry

```bash
plugin registry add https://github.com/czy-ustc/fixtures-registry.git
```

```text
[registry] ADD
  -> cloning registry sources
  + fixtures-registry
  [ok] added 1 registry(ies)
```

```bash
plugin registry status
```

```text
[registry] STATUS
  [3575c1d9] FixtureGeneral (https://github.com/czy-ustc/fixtures-registry.git)
  [info] registries: 1
```

## 3. Add First Plugin

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
plugin status
```

```text
[plugin] STATUS
  .. project: C:\Users\maike\code\julia\temp\docs-run-20260225-154453\DemoHost\Plugins.toml
  [fixture] TPluginB v1.0.0
  [info] direct plugins: 1
```

Installed tree:

```text
DemoHost
└─ .julia_plugins/
   ├─ Plugins.toml
   └─ fixture/
      ├─ TPluginA/
      │  └─ TPluginA.jl
      └─ TPluginB/
         └─ TPluginB.jl
```

## 4. Pin and Free

```bash
plugin pin TPluginB
```

`pin` introduces a new state (`[pinned]`) in `status`:

```bash
plugin status
```

```text
[plugin] STATUS
  .. project: C:\Users\maike\code\julia\temp\docs-run-20260225-154453\FlowProject\Plugins.toml
  [fixture] TPluginB v1.0.0 [pinned]
  [info] direct plugins: 1
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

`free` can now undo both `pin` and `dev` state.

## 5. Instantiate and Update

```bash
plugin instantiate
```

```bash
plugin update TPluginB
```

Both commands re-resolve the graph; in a stable setup they typically report `no plugin version changes`.

## 6. Add Project-local Plugin

```bash
plugin generate plugin plugins/LocalTool --version 0.3.0
```

```bash
plugin add LocalTool
```

```bash
plugin status
```

Representative output (new namespace appears):

```text
[plugin] STATUS
  .. project: C:\Users\maike\code\julia\temp\docs-run-20260225-154453\MyProject\Plugins.toml
  [project] LocalTool v0.3.0
  [fixture] TPluginB v1.0.0
  [info] direct plugins: 2
```

## 7. Add Global Development Plugin

```bash
cd ..
```

```bash
git clone https://github.com/czy-ustc/fixtures-plugins.git fixtures-plugins-dev
```

```bash
plugin generate plugin fixtures-plugins-dev/DemoTool --version 0.1.0
```

```bash
cd DemoHost
```

```bash
plugin dev ../fixtures-plugins-dev/DemoTool
```

```bash
plugin add DemoTool
```

```bash
plugin status
```

Representative output (global namespace appears):

```text
[plugin] STATUS
  .. project: C:\Users\maike\code\julia\temp\docs-run-20260225-154453\MyProject\Plugins.toml
  [ global] DemoTool v0.1.0
  [project] LocalTool v0.3.0
  [fixture] TPluginB v1.0.0
  [info] direct plugins: 3
```

## 8. Inspect and Clean Cache

```bash
plugin cache status
```

```text
[cache] STATUS
  [5715ae76] https://github.com/czy-ustc/fixtures-plugins.git (155 bytes)
  [f5de3099] https://github.com/czy-ustc/fixtures-plugins.git (228 bytes)
  [536bdefe] https://github.com/czy-ustc/fixtures-plugins.git (183 bytes)
  [info] cache entries: 3
```

```bash
plugin cache remove --all
```

```text
[cache] REMOVE
  -> deleting selected cache entries
  [ok] removed 1 cache entry
```

## 9. Cleanup

```bash
plugin remove DemoTool
```

```bash
plugin remove LocalTool
```

```bash
plugin remove TPluginB
```

```bash
plugin registry remove FixtureGeneral
```

## Wrap-up

You have exercised the core PluginSystem workflow:

- registry lifecycle
- dependency resolution and installation
- namespace precedence (`fixture`, `project`, `global`)
- cache maintenance

## API Equivalent

```julia
PluginSystem.add("TPluginB")
PluginSystem.status()
PluginSystem.dev("../fixtures-plugins-dev/DemoTool")
```