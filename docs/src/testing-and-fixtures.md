# Testing and Fixtures

This page summarizes the test layout and the fixture repositories used by integration tests.

## Test Layers

`test/runtests.jl` executes three layers:

1. unit tests
2. integration tests
3. interface tests (`app`, `cli`, `load`)

Run the full suite with:

```bash
julia --project=. test/runtests.jl
```

Typical output contains per-layer summaries, for example `Integration Tests | ...` and `Interface Tests | ...`.

## Core Test Helpers

`test/test_helpers.jl` provides common workflows:

- `with_fixture_registry(...)`: temporary fixture registry + plugin source setup
- `with_registry(name, repo)`: temporary registry install/remove lifecycle
- `with_temp_project(...)`: isolated temporary project directory and `cd`
- git helpers: `git_init_repo!`, `git_commit_all!`, `git_head`, ...

## Fixture Repositories

Fixtures are split into two remote repositories:

- registry metadata: `https://github.com/czy-ustc/fixtures-registry.git`
- plugin sources: `https://github.com/czy-ustc/fixtures-plugins.git`

Both can be pinned by ref/tag through environment variables.

Registry repository layout:

```text
fixtures-registry
├─ Registry.toml
└─ fixture/
   ├─ TPluginA.toml
   ├─ TPluginB.toml
   └─ ...
```

Plugin repository layout:

```text
fixtures-plugins
└─ fixture/
   ├─ TPluginA/
   │  ├─ 1.0.0/
   │  │  └─ TPluginA.jl
   │  └─ ...
   ├─ TPluginB/
   └─ ...
```

## Fixture Configuration

```bash
set PLUGINSYSTEM_FIXTURE_REGISTRY_REPO=https://github.com/czy-ustc/fixtures-registry.git
```

```bash
set PLUGINSYSTEM_FIXTURE_REGISTRY_REF=v0.3.0
```

```bash
set PLUGINSYSTEM_FIXTURE_PLUGINS_REPO=https://github.com/czy-ustc/fixtures-plugins.git
```

```bash
set PLUGINSYSTEM_FIXTURE_PLUGINS_REF=v0.3.0
```

With this configuration, tests resolve metadata from the registry repo and source files from the plugins repo.

## Scratch Safety

Tests may modify PluginSystem scratch directories (`registries`, cache, global plugin dirs). `runtests.jl` snapshots and restores scratch content to avoid polluting user state.
