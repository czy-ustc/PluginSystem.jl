# Scaffolding

Scaffolding commands create minimal project and plugin structures that follow PluginSystem conventions.

## Generate a Project

```bash
plugin generate project MyProject
```

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

## Generate a Directory Plugin

```bash
plugin generate plugin MyPlugin --version 0.1.0 --deps BaseTool
```

```text
[scaffold] PLUGIN
  -> creating plugin skeleton
  .. path: C:\Users\maike\code\julia\temp\docs-run-20260225-145643\MyPlugin
  [ok] generated plugin `MyPlugin` v0.1.0
```

Generated tree:

```text
MyPlugin
└─ MyPlugin.jl
```

## Generate a Single-file Plugin

```bash
plugin gen plugin SinglePlugin.jl --file true
```

Use this mode when you want one plugin file instead of a plugin directory.

## API Equivalents

```julia
PluginSystem.scaffold_project("MyProject")
PluginSystem.scaffold_plugin("MyPlugin"; version = "0.1.0", deps = ["BaseTool"])
```

## Notes

- generated plugin files include required metadata docstring fields (`version`, `deps`)
- plugin/module/file naming must remain consistent
- use `--force true` to overwrite an existing target