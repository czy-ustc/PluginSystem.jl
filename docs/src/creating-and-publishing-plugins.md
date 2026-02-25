# Creating and Publishing Plugins

This page shows a full workflow with two remote repositories:

- plugin source repository (example: `https://github.com/czy-ustc/fixtures-plugins.git`)
- registry metadata repository (example: `https://github.com/czy-ustc/fixtures-registry.git`)

The key idea is simple: clone both repositories locally, develop in the plugin repo, then publish metadata into the registry repo.

## 1. Prepare Local Workspace

```bash
plugin generate project MyApp
```

```text
[scaffold] PROJECT
  -> creating project skeleton
  .. path: C:\Users\maike\code\julia\temp\MyApp
  [ok] generated project `Myapp`
```

```bash
git clone https://github.com/czy-ustc/fixtures-plugins.git
git clone https://github.com/czy-ustc/fixtures-registry.git
```

Local layout:

```text
workspace/
├─ MyApp/
├─ fixtures-plugins/
└─ fixtures-registry/
```

## 2. Develop Plugin Source

Create a plugin branch in the plugin repository and add/update plugin files.

```bash
git -C fixtures-plugins checkout -b feat/tpluginc-v0.1.0
plugin gen plugin fixtures-plugins/fixture/TPluginC/0.1.0/TPluginC --version 0.1.0 --deps TPluginA,TPluginB
```

```text
[scaffold] PLUGIN
  -> creating plugin skeleton
  .. path: C:\Users\maike\code\julia\temp\fixtures-plugins\fixture\TPluginC\0.1.0\TPluginC
  [ok] generated plugin `TPluginC` v0.1.0
```

Commit and push plugin source changes:

```bash
git -C fixtures-plugins add .
git -C fixtures-plugins commit -m "Add TPluginC v0.1.0" --no-gpg-sign
git -C fixtures-plugins push -u origin feat/tpluginc-v0.1.0
```

## 3. Validate in Host Project (`dev` + `add`)

```bash
cd MyApp
plugin dev ../fixtures-plugins --subdir fixture/TPluginC/0.1.0/TPluginC
```

```text
[plugin] DEV
  -> importing development source
  .. global source: C:\Users\maike\.julia\scratchspaces\...\global_plugins\TPluginC
  [ok] registered TPluginC v0.1.0 [global]
```

```bash
plugin add TPluginC
plugin status
```

```text
[plugin] STATUS
  .. project: C:\Users\maike\code\julia\temp\MyApp\Plugins.toml
  [ global] TPluginC v0.1.0
  [info] direct plugins: 1
```

## 4. Publish to Registry Repository

Get the plugin commit SHA:

```bash
git -C ../fixtures-plugins rev-parse HEAD
```

Publish metadata into the cloned registry repository:

```bash
plugin publish ../fixtures-plugins ../fixtures-registry \
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
  .. released development source for TPluginC
  [ok] published TPluginC v0.1.0
```

`publish` now covers the repetitive registry tasks:

- create/update metadata files
- create a registry commit
- optionally push the branch
- optionally create (or print) merge request URL
- automatically release matching `dev` source after successful publish

## 5. Submit and Merge

Recommended order:

1. open and merge plugin source PR (`fixtures-plugins`)
2. open and merge registry PR (`fixtures-registry`)
3. sync consumer projects

After registry PR is merged:

```bash
plugin registry add https://github.com/czy-ustc/fixtures-registry.git
plugin registry update
plugin update TPluginC
plugin status
```

```text
[plugin] STATUS
  .. project: C:\Users\maike\code\julia\temp\MyApp\Plugins.toml
  [fixture] TPluginC v0.1.0
  [info] direct plugins: 1
```

The namespace changes from `global` to `fixture`, showing that the project now consumes registry metadata instead of local `dev` source.

## API Equivalent

```julia
PluginSystem.dev("../fixtures-plugins"; subdir = "fixture/TPluginC/0.1.0/TPluginC")
PluginSystem.publish(
    "../fixtures-plugins",
    "../fixtures-registry";
    subdir = "fixture/TPluginC/0.1.0/TPluginC",
    namespace = "fixture",
    rev = "<PLUGIN_COMMIT_SHA>",
    remote = "origin",
    branch = "feat/tpluginc-v0.1.0",
    base = "main",
    push = true,
    create_merge_request = true,
)
```
