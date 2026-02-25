# Use Cases and Benefits

This page explains where PluginSystem gives the most value in real projects.

Lifecycle position: it is a decision/support page around all lifecycle stages from [Overview](overview.md).

## Core Benefits

- controlled plugin version rollout
- reusable business capability modules
- plug-and-play feature composition
- consistent dev-to-publish workflow

## Scenario 1: Version Governance

Problem:

- multiple projects share plugin dependencies
- production and development have different upgrade pace

How PluginSystem helps:

- declare desired direct set in `Plugins.toml`
- use `pin/free` for risk control
- use `status` for upgrade visibility

Outcome:

- predictable releases and safer rollbacks

## Scenario 2: Reuse Across Projects

Problem:

- duplicated adapters/services in multiple codebases

How PluginSystem helps:

- publish shared plugins to a registry
- consume via `add(...)`
- maintain compat constraints centrally

Outcome:

- less duplication and lower maintenance cost

## Scenario 3: Plug-and-Play Features

Problem:

- host app needs optional features without hard wiring

How PluginSystem helps:

- install into `.julia_plugins/`
- load via `@load_plugins` or `load_plugins!`
- use namespace precedence for controlled overrides

Outcome:

- modular feature delivery and cleaner boundaries

## Scenario 4: Team Development to Release

Problem:

- local iteration and published release are disconnected

How PluginSystem helps:

- iterate with `dev(...)`
- publish with `publish(...)`
- consume downstream with `add/update`

Outcome:

- shorter path from prototype to shared artifact

## Executable Example (jldoctest)

```jldoctest usecases_load_plugins; setup = :(using PluginSystem)
julia> mktempdir() do project
           plugin_src = joinpath(project, ".julia_plugins", "project", "MyLocal")
           mkpath(plugin_src)
           write(joinpath(plugin_src, "MyLocal.jl"), "module MyLocal\nend\n")
           write(
               joinpath(project, ".julia_plugins", "Plugins.toml"),
               "[[plugins]]\nname = \"MyLocal\"\nversion = \"0.1.0\"\nnamespace = \"project\"\npath = \"project/MyLocal/MyLocal.jl\"\n",
           )
           host = Module(:DocUseCaseHost)
           loaded = PluginSystem.load_plugins!(host; base_dir = project)
           isdefined(host, :MyLocal) && ("MyLocal" in loaded.loaded)
       end
true
```

## Next Reads

- [Getting Started](getting-started.md)
- [Managing Plugins](managing-plugins.md)
- [Creating and Publishing Plugins](creating-and-publishing-plugins.md)
