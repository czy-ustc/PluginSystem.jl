# PluginSystem.jl

PluginSystem is a plugin manager for Julia applications with a Pkg-like workflow.

This documentation is organized for sequential reading first, then reference lookup.

## Read in Order

1. [Overview](overview.md): lifecycle and core mental model
2. [Getting Started](getting-started.md): shortest Hello World path
3. [CLI Guide](cli.md): command entry modes and syntax
4. [Scaffolding](scaffolding.md): generate project/plugin skeletons
5. [Managing Plugins](managing-plugins.md): add/update/remove/pin/free/instantiate/status
6. [Registries](registries.md): registry lifecycle and sync
7. [Namespaces](namespaces.md): source precedence and install paths
8. [Version Resolution](version-resolution.md): dependency and compatibility logic
9. [Hands-on Tutorial](hands-on-tutorial.md): full end-to-end scenario
10. [Creating and Publishing Plugins](creating-and-publishing-plugins.md): author workflow

## Reference

- [Cache and Artifacts](cache-and-artifacts.md): cache behavior and cleanup
- [Testing and Fixtures](testing-and-fixtures.md): fixture source, test layout, scratch safety
- [Use Cases and Benefits](use-cases-and-benefits.md): adoption scenarios
- [Configuration Files](configuration-files.md): file formats and semantics
- [API](api.md): function-level reference
- [Architecture](architecture.md): module-level structure

## Fixture Repository Split

Examples use separated remote repositories:

- registry metadata: `https://github.com/czy-ustc/fixtures-registry.git`
- plugin sources: `https://github.com/czy-ustc/fixtures-plugins.git`

This mirrors production usage where registry and plugin source lifecycles are independent.
