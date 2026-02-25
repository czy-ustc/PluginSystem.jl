# Registries

Registries provide plugin metadata: versions, dependencies, compat ranges, and source locations.

## Add a Registry

```bash
plugin registry add https://github.com/czy-ustc/fixtures-registry.git
```

```text
[registry] ADD
  -> cloning registry sources
  + fixtures-registry
  [ok] added 1 registry(ies)
```

## Check Installed Registries

```bash
plugin registry status
```

```text
[registry] STATUS
  [3575c1d9] FixtureGeneral (https://github.com/czy-ustc/fixtures-registry.git)
  [info] registries: 1
```

## Update Registries

```bash
plugin registry update
```

```text
[registry] UPDATE
  -> fetching registry updates
  ~ FixtureGeneral
  [ok] updated 1 registry(ies)
```

Use this before `plugin add` or `plugin update` when you need fresh metadata.

## Remove Registries

```bash
plugin registry remove FixtureGeneral
```

```text
[registry] REMOVE
  -> removing registry checkouts
  - FixtureGeneral
  [ok] removed 1 registry(ies)
```

This removes the local registry checkout from scratchspace.

## Registry Contribution Workflow (Clone Remote Directly)

When you need to publish plugin metadata, clone the remote registry repo to a local working copy and publish into that clone.

```bash
git clone https://github.com/czy-ustc/fixtures-registry.git MyRegistry
```

```bash
git -C MyRegistry checkout -b feat/tpluginc-v0.1.0
```

```bash
git -C fixtures-plugins rev-parse HEAD
```

```bash
plugin publish ../fixtures-plugins ../MyRegistry \
  --subdir fixture/TPluginC/0.1.0/TPluginC \
  --namespace fixture \
  --rev <PLUGIN_COMMIT_SHA> \
  --branch feat/tpluginc-v0.1.0 \
  --base main \
  --push true \
  --merge-request true
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

Notes:

- `publish` always writes registry metadata and creates a registry commit when files changed.
- `--push true` pushes the publish branch to the configured remote.
- `--merge-request true` returns or prints a merge request URL (and tries `gh pr create` when available).

## Typical Publish Follow-up

```bash
plugin registry update MyRegistry
```

```bash
plugin add CoolTool
```

```text
[plugin] ADD
  -> collecting project requirements
  -> resolving plugin graph
  -> installing plugin files
  -> plugin delta
  = no plugin version changes
  [ok] installed 1 plugin(s)
```

This refreshes local registry data first, then resolves and installs the newly published plugin.

## API Equivalents

```julia
PluginSystem.Registry.add("https://github.com/czy-ustc/fixtures-registry.git")
PluginSystem.Registry.status()
PluginSystem.Registry.update()
PluginSystem.Registry.remove("FixtureGeneral")
```
