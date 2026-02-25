# Namespaces

Namespaces describe where a plugin comes from and where it is installed under `.julia_plugins`.

## Source-to-Namespace Mapping

PluginSystem assigns namespaces by source:

1. project-local plugins under `plugins/` -> `project`
2. plugins imported with `plugin dev ...` -> `global`
3. registry plugins -> registry-defined namespace (for example `fixture`, `acme/tools`)

## Install Path Mapping

```text
.julia_plugins/
└─ <namespace-segments>/
   └─ <PluginName>/
      └─ <PluginName>.jl
```

Examples:

- `project` + `LocalTool` -> `project/LocalTool/LocalTool.jl`
- `acme/tools` + `NsDemo` -> `acme/tools/NsDemo/NsDemo.jl`

## Walkthrough

Start with a registry plugin:

```bash
plugin registry add https://github.com/czy-ustc/fixtures-registry.git
```

```bash
plugin add TPluginB
```

```bash
plugin status
```

```text
[plugin] STATUS
  .. project: ...\Plugins.toml
  [fixture] TPluginB v1.0.0
  [info] direct plugins: 1
```

Then add a project-local plugin:

```bash
plugin generate plugin plugins/LocalTool --version 0.3.0
```

```bash
plugin add LocalTool
```

```bash
plugin status
```

```text
[plugin] STATUS
  .. project: ...\Plugins.toml
  [project] LocalTool v0.3.0
  [fixture] TPluginB v1.0.0
  [info] direct plugins: 2
```

Then add a global development plugin:

```bash
plugin dev ../fixtures-plugins-dev/DemoTool
```

```bash
plugin add DemoTool
```

```bash
plugin status
```

```text
[plugin] STATUS
  .. project: ...\Plugins.toml
  [ global] DemoTool v0.1.0
  [project] LocalTool v0.3.0
  [fixture] TPluginB v1.0.0
  [info] direct plugins: 3
```

## Custom Namespace via Publish

You can publish metadata with an explicit namespace:

```bash
plugin publish /path/to/NsDemo /path/to/MyRegistry --subdir . --namespace acme/tools
```

After adding that registry and installing `NsDemo`, `status` will show it under `acme/tools`.