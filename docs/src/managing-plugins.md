# Managing Plugins

This page covers day-to-day maintenance of `Plugins.toml` and installed plugin state.

## Start from a Registry

```bash
plugin registry add https://github.com/czy-ustc/fixtures-registry.git
```

With a registry in place, plugin commands can resolve versions and transitive dependencies.

## Add and Inspect

```bash
plugin add TPluginB
```

Representative output:

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
  .. project: C:\Users\maike\code\julia\temp\docs-run-20260225-154453\MyProject\Plugins.toml
  [fixture] TPluginB v1.0.0
  [info] direct plugins: 1
```

## Update and Reconcile

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
plugin instantiate
```

```text
[plugin] INSTANTIATE
  -> resolving plugin graph
  -> installing plugin files
  -> plugin delta
  = no plugin version changes
  [ok] installed 2 plugin(s)
```

## Pin and Free

```bash
plugin pin TPluginB
```

Pinned status is shown explicitly:

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

`free` now handles both cases:

- unpin pinned entries
- release matching development sources imported by `dev`

When a dev source is released, PluginSystem re-resolves and reinstalls plugins automatically.

## Remove

```bash
plugin remove TPluginB
```

Representative output:

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

## Conflict Example

Run the following sequence to produce an unsatisfiable dependency set.

```bash
plugin add TPluginE
```

```bash
plugin add TPluginC@1.0
```

```bash
plugin add TPluginF
```

Representative failure output (truncated):

```text
Error: Unsatisfiable requirements detected for package TPluginD [...]
 |- restricted by compatibility requirements with TPluginF [...] to versions: 2.0.0
 '- restricted by compatibility requirements with TPluginE [...] to versions: 1.0.0 -- no versions left
```

## API Equivalents

```julia
PluginSystem.add("TPluginB")
PluginSystem.status()
PluginSystem.pin("TPluginB")
PluginSystem.free("TPluginB")
```