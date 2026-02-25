# Getting Started

This page shows the shortest path from an empty folder to a plugin-enabled project.

If you want an end-to-end flow (including `dev` and `publish`), continue to [Hands-on Tutorial](hands-on-tutorial.md).

## 1. Generate a Project

```bash
plugin generate project MyProject
```

Representative output:

```text
[scaffold] PROJECT
  -> creating project skeleton
  .. path: C:\Users\maike\code\julia\temp\docs-run-20260225-145643\MyProject
  [ok] generated project `Myproject`
```

Generated tree:

```text
MyProject
├─ Plugins.toml
├─ .gitignore
├─ plugins/
└─ src/
   └─ Myproject.jl
```

## 2. Add a Registry

```bash
cd MyProject
```

```bash
plugin registry add https://github.com/czy-ustc/fixtures-registry.git
```

```text
[registry] ADD
  -> cloning registry sources
  + fixtures-registry
  [ok] added 1 registry(ies)
```

## 3. Add a Plugin

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

## 4. Check Status

```bash
plugin status
```

```text
[plugin] STATUS
  .. project: C:\Users\maike\code\julia\temp\docs-run-20260225-145643\MyProject\Plugins.toml
  [fixture] TPluginB v1.0.0
  [info] direct plugins: 1
```

## 5. Load Plugins and Call Plugin Code

`src/Myproject.jl` already contains `@load_plugins`.

```julia
julia> include("src/Myproject.jl")
Main.Myproject

julia> using .Myproject

julia> Myproject.TPluginB.score(1)
112
```

This confirms the dependency chain behind `TPluginB` is loaded.

## Optional Cleanup

```bash
plugin remove TPluginB
```

```bash
plugin registry remove FixtureGeneral
```

## API Equivalent

```julia
PluginSystem.add("TPluginB")
PluginSystem.status()
```

## Next Reading

- [CLI Guide](cli.md)
- [Managing Plugins](managing-plugins.md)
- [Hands-on Tutorial](hands-on-tutorial.md)
- [Version Resolution](version-resolution.md)