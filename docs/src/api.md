# API

This page is the reference layer of the Overview documentation model.

Before API details, read:

1. [Overview](overview.md)
2. [Getting Started](getting-started.md)
3. [Managing Plugins](managing-plugins.md)

## Lifecycle-Oriented API Groups

## 1) Declare / Resolve / Install / Load

```@docs
PluginSystem.add
PluginSystem.update
PluginSystem.remove
PluginSystem.instantiate
PluginSystem.pin
PluginSystem.free
PluginSystem.status
PluginSystem.load_plugins!
PluginSystem.@load_plugins
```

## 2) Author / Publish

```@docs
PluginSystem.scaffold_project
PluginSystem.scaffold_plugin
PluginSystem.dev
PluginSystem.publish
```

## 3) Registry Management

```@docs
PluginSystem.Registry.add
PluginSystem.Registry.remove
PluginSystem.Registry.update
PluginSystem.Registry.status
```

## 4) Cache and Authentication

```@docs
PluginSystem.set_auth!
PluginSystem.Cache.status
PluginSystem.Cache.remove
```
