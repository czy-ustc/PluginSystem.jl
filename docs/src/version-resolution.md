# Version Resolution Logic

For general package resolution background, see [Pkg: Compatibility](https://pkgdocs.julialang.org/v1/compatibility/) and [Pkg: Managing Packages](https://pkgdocs.julialang.org/v1/managing-packages/).

This page covers the **resolve versions** stage in the Overview lifecycle.

Related pages:

- [Overview](overview.md)
- [Managing Plugins](managing-plugins.md)
- [Configuration Files](configuration-files.md)

## Resolution Objective

The resolver computes a single compatible version set that:

- satisfies direct requirements from `Plugins.toml` (`deps` + `compat`)
- satisfies transitive `deps`/`compat` constraints from plugin metadata
- respects pinned versions in `.julia_plugins/Plugins.toml`
- tries to preserve existing direct versions during routine updates

## Inputs by Priority

1. project declaration (`Plugins.toml`)
2. installed manifest (`.julia_plugins/Plugins.toml`)
3. registry/global/project plugin metadata (`versions`, `deps`, `compat`)
4. source precedence (`project > global > registry`)

## Graph Build and Solve

Implementation source: `src/resolve.jl`

Pipeline:

1. map plugin names to stable UUIDs
2. build per-version dependency constraints (`VersionSpec`)
3. merge version-scoped metadata rules
4. simplify graph and solve via Pkg's resolver backend
5. topologically sort solution for deterministic install order

## Preserve Strategy

Default API path uses `resolve(...; preserve=true)`.

Behavior:

- for direct deps not explicitly targeted by update, current installed versions are injected as temporary compat constraints
- this reduces unnecessary version churn

Fallback:

- if the preserve attempt fails, resolver retries without preserve constraints

`resolve(...; preserve=false)` performs a fresh solve from declaration + metadata.

## Pin Strategy

Pinned entries are converted to exact version constraints before solving.

Effects:

- pinned plugin cannot move until `free(...)`
- conflicting new requirements produce unsatisfiable resolution

## Failure Classes

1. plugin not found in available sources
2. missing transitive dependency metadata
3. incompatible compatibility ranges

## Practical Conflict Example

Given:

- `TPluginB@1` requires `TPluginA@1`
- `TPluginD@2` requires `TPluginA@2`

Then:

- `add("TPluginB"); add("TPluginD@2")` is unsatisfiable
- if `TPluginB` is pinned, constraints requiring `TPluginA@2` also fail

Covered by integration tests:

- `test/test_integration_resolve_edges.jl`
- `test/test_integration_fixture_matrix.jl`
