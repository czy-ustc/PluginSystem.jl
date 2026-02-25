# Cache and Artifacts

PluginSystem keeps git download snapshots in scratchspace so repeated operations are faster and deterministic.

## Scratch Layout

```text
<scratch>
├─ plugins/         # installed global plugin snapshots
├─ global_plugins/  # sources imported by `plugin dev`
├─ registries/      # cloned registries
└─ git_cache/       # git download/export cache
```

## Inspect Cache

```bash
plugin cache status
```

Representative output:

```text
[cache] STATUS
  [5715ae76] https://github.com/czy-ustc/fixtures-plugins.git (155 bytes)
  [f5de3099] https://github.com/czy-ustc/fixtures-plugins.git (228 bytes)
  [536bdefe] https://github.com/czy-ustc/fixtures-plugins.git (183 bytes)
  [info] cache entries: 3
```

## Remove Cache Entries

By key:

```bash
plugin cache remove --key 5715ae76d0a23d53085e0e568461ed020b56ee93
```

```text
[cache] REMOVE
  -> deleting selected cache entries
  [ok] removed 1 cache entry
```

By source URL/path:

```bash
plugin cache remove --url https://github.com/czy-ustc/fixtures-plugins.git
```

Remove all entries:

```bash
plugin cache remove --all
```

These commands are useful when debugging stale checkout state or freeing disk space.

## Authentication

When accessing private repositories, configure git credentials via API:

```julia
set_auth!("github.com"; username = "oauth2", token = "<token>")
set_auth!("gitee.com"; username = "oauth2", token = "<token>")
```

Credentials are stored under Preferences key `PluginSystem.git_auth`.

## Copy Rules

During export/install copy, PluginSystem excludes git internals and respects `.gitignore` patterns. This keeps installed plugin trees clean and reproducible.