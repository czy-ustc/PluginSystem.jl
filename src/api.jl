module API

using ..Download: download
using ..Install: install
using ..PluginSystem: GLOBAL_DEV_PLUGINS_DIR
using ..Registry: RegistryData
using ..Resolve: resolve
using ..UI
using ..Utils: Workspace, manifest_plugins_toml, parse_plugin_definition, plugin_store_dir,
	project_plugins_toml,
	read_toml_if_exists, read_toml_required, workspace, write_toml

public add, dev, free, instantiate, pin, publish, remove, status, update

_workspace(base_dir::Union{Nothing, String}) =
	base_dir === nothing ? workspace() : workspace(base_dir)

_global_dev_plugin_path(name::String) = joinpath(GLOBAL_DEV_PLUGINS_DIR, name)

function _remove_global_dev_plugin!(name::String)
	path = _global_dev_plugin_path(name)
	ispath(path) || return false
	rm(path; recursive = true, force = true)
	true
end

function _load_manifest_config(workspace::Workspace)
	read_toml_if_exists(manifest_plugins_toml(workspace))
end

function _deps_list(config::Dict{String, Any})
	deps = get!(config, "deps", String[])
	deps isa Vector || error("`deps` must be a string list in Plugins.toml.")
	String[string(dep) for dep in deps]
end

function _set_deps!(config::Dict{String, Any}, deps::Vector{String})
	config["deps"] = unique(deps)
	config
end

function _remove_unused_plugins(old_config::Dict{String, Any}, used_plugins, workspace::Workspace)
	plugin_dir = plugin_store_dir(workspace)
	manifest_path = manifest_plugins_toml(workspace)
	isfile(manifest_path) || return

	config = read_toml_required(manifest_path)
	plugins = get(config, "plugins", Dict{String, String}[])
	new_plugins = Dict{String, String}[]
	for info in plugins
		if info["name"] in used_plugins
			push!(new_plugins, info)
			for p in get(old_config, "plugins", Dict{String, String}[])
				if p["name"] == info["name"] && p["path"] != info["path"]
					rm(joinpath(plugin_dir, dirname(p["path"])); force = true, recursive = true)
					break
				end
			end
		else
			rm(joinpath(plugin_dir, dirname(info["path"])); force = true, recursive = true)
		end
	end
	write_toml(manifest_path, Dict{String, Any}("plugins" => new_plugins))
end

function _manifest_version_map(manifest::Dict{String, Any})
	versions = Dict{String, VersionNumber}()
	for item in get(manifest, "plugins", Any[])
		item isa Dict || continue
		name = get(item, "name", nothing)
		ver = get(item, "version", nothing)
		(name isa String && ver isa String) || continue
		try
			versions[name] = VersionNumber(ver)
		catch
		end
	end
	versions
end

function _log_plugin_changes(old_manifest::Dict{String, Any}, new_plugins; io::Union{Nothing, IO} = nothing)
	io === nothing && return
	old_versions = _manifest_version_map(old_manifest)
	new_map = Dict{String, Any}(p.name => p for p in new_plugins)

	changes = Tuple{Symbol, String}[]
	for plugin in sort(collect(values(new_map)); by = p -> p.name)
		oldv = get(old_versions, plugin.name, nothing)
		if oldv === nothing
			push!(changes, (:add, "$(plugin.name) v$(plugin.version) [$(plugin.namespace)]"))
		elseif oldv != plugin.version
			push!(changes, (:update, "$(plugin.name) v$(oldv) => v$(plugin.version) [$(plugin.namespace)]"))
		end
	end
	for (name, oldv) in sort(collect(old_versions); by = first)
		haskey(new_map, name) && continue
		push!(changes, (:remove, "$(name) v$(oldv)"))
	end

	UI.step(io, "plugin delta")
	if isempty(changes)
		UI.change(io, :none, "no plugin version changes")
	else
		for (kind, line) in changes
			UI.change(io, kind, line)
		end
	end
end

function _parse_name_spec(spec::String)
	name, versions... = split(spec, "@")
	v = isempty(versions) ? nothing : versions[1]
	(name = strip(name), version = v === nothing ? nothing : strip(v))
end

function _add_or_update(
	plugins::String...;
	update::Bool = false,
	io::Union{Nothing, IO} = nothing,
	base_dir::Union{Nothing, String} = nothing,
)
	isempty(plugins) && !update && error("No plugin specified.")
	workspace = _workspace(base_dir)
	UI.header(io, "plugin", update ? "update" : "add")
	UI.step(io, "collecting project requirements")
	old_manifest = _load_manifest_config(workspace)
	project_path = project_plugins_toml(workspace)
	config = read_toml_if_exists(project_path)

	deps = _deps_list(config)
	compat = get!(config, "compat", Dict{String, String}())
	update_plugins = String[]
	for plugin in plugins
		spec = _parse_name_spec(plugin)
		isempty(spec.name) && error("Plugin name must not be empty.")
		if !update && !(spec.name in deps)
			push!(deps, spec.name)
		end
		push!(update_plugins, spec.name)
		if spec.version !== nothing && spec.version != "*"
			compat[spec.name] = spec.version
		elseif update
			pop!(compat, spec.name, nothing)
		end
	end
	_set_deps!(config, deps)
	write_toml(project_path, config)

	UI.step(io, "resolving plugin graph")
	resolved = resolve(config, update_plugins; workspace = workspace)
	UI.step(io, "installing plugin files")
	install(resolved; workspace = workspace)
	_remove_unused_plugins(old_manifest, Set([p.name for p in resolved]), workspace)
	_log_plugin_changes(old_manifest, resolved; io = io)
	UI.summary(io, "installed $(length(resolved)) plugin(s)")
	(action = update ? "update" : "add", requested = collect(plugins), installed = [(name = p.name, version = string(p.version), namespace = p.namespace) for p in resolved])
end

"""
    add(names...)

Add plugin names to `Plugins.toml` (`deps` list), then resolve/install.
`name@version` constraints are written into `[compat]`.
"""
add(args::String...; io::Union{Nothing, IO} = nothing, base_dir::Union{Nothing, String} = nothing) =
	_add_or_update(args...; update = false, io = io, base_dir = base_dir)

"""
    update(names...)

Re-resolve selected plugins (or all current deps when no name is provided).
"""
function update(args::String...; io::Union{Nothing, IO} = nothing, base_dir::Union{Nothing, String} = nothing)
	workspace = _workspace(base_dir)
	if isempty(args)
		config = read_toml_if_exists(project_plugins_toml(workspace))
		return _add_or_update(_deps_list(config)...; update = true, io = io, base_dir = workspace.root)
	end
	_add_or_update(args...; update = true, io = io, base_dir = workspace.root)
end

"""
    remove(names...)

Remove plugins from project `deps` list and cleanup unused artifacts.
"""
function remove(names::String...; io::Union{Nothing, IO} = nothing, base_dir::Union{Nothing, String} = nothing)
	workspace = _workspace(base_dir)
	UI.header(io, "plugin", "remove")
	UI.step(io, "updating project requirements")
	project_path = project_plugins_toml(workspace)
	isfile(project_path) || error("Plugins.toml not found in current directory.")
	old_manifest = _load_manifest_config(workspace)

	config = read_toml_required(project_path)
	deps = _deps_list(config)
	compat = get(config, "compat", Dict{String, Any}())
	for name in names
		name in deps || error("The plugin $name could not be resolved.")
		filter!(n -> n != name, deps)
		pop!(compat, name, nothing)
	end
	_set_deps!(config, deps)
	write_toml(project_path, config)
	UI.step(io, "resolving plugin graph")
	new_plugins = resolve(config; workspace = workspace)
	UI.step(io, "pruning unused plugin files")
	_remove_unused_plugins(old_manifest, Set([p.name for p in new_plugins]), workspace)
	_log_plugin_changes(old_manifest, new_plugins; io = io)
	UI.summary(io, "remaining direct deps: $(length(deps))")
	(action = "remove", removed = collect(names), remaining = deps)
end

"""
    instantiate()

Install plugins exactly as specified by current `Plugins.toml`.
"""
function instantiate(; io::Union{Nothing, IO} = nothing, base_dir::Union{Nothing, String} = nothing)
	workspace = _workspace(base_dir)
	UI.header(io, "plugin", "instantiate")
	UI.step(io, "resolving plugin graph")
	project_path = project_plugins_toml(workspace)
	isfile(project_path) || error("Plugins.toml not found in current directory.")
	old_manifest = _load_manifest_config(workspace)

	config = read_toml_required(project_path)
	plugins = resolve(config; workspace = workspace)
	UI.step(io, "installing plugin files")
	install(plugins; workspace = workspace)
	_remove_unused_plugins(old_manifest, Set([p.name for p in plugins]), workspace)
	_log_plugin_changes(old_manifest, plugins; io = io)
	UI.summary(io, "installed $(length(plugins)) plugin(s)")
	(action = "instantiate", installed = [(name = p.name, version = string(p.version), namespace = p.namespace) for p in plugins])
end

function _pin_or_free(
	names::String...;
	pin::Bool = true,
	io::Union{Nothing, IO} = nothing,
	base_dir::Union{Nothing, String} = nothing,
)
	isempty(names) && error(pin ? "pin requires at least one plugin name." : "free requires at least one plugin name.")
	workspace = _workspace(base_dir)
	UI.header(io, "plugin", pin ? "pin" : "free")
	manifest_path = manifest_plugins_toml(workspace)
	config = isfile(manifest_path) ? read_toml_required(manifest_path) : Dict{String, Any}()
	plugins = get(config, "plugins", Dict{String, String}[])

	if pin
		UI.step(io, "marking pinned plugins")
		isfile(manifest_path) || error("Plugins.toml not found in current directory.")
		for name in names
			index = findfirst(p -> p["name"] == name, plugins)
			index === nothing && error("Plugin $name not found in current configuration.")
			plugins[index]["pinned"] = true
		end
		write_toml(manifest_path, config)
		UI.summary(io, "pinned $(length(names)) plugin(s)")
		return (action = "pin", plugins = collect(names))
	end

	UI.step(io, "releasing pinned and developed plugins")
	old_manifest = _load_manifest_config(workspace)
	manifest_changed = false
	unpinned = String[]
	undeveloped = String[]

	for name in names
		seen = false
		index = findfirst(p -> p["name"] == name, plugins)
		if index !== nothing
			seen = true
			if haskey(plugins[index], "pinned")
				pop!(plugins[index], "pinned", nothing)
				push!(unpinned, name)
				manifest_changed = true
			end
		end

		if _remove_global_dev_plugin!(name)
			seen = true
			push!(undeveloped, name)
		end

		seen || error("Plugin $name is neither installed in manifest nor developed in global store.")
	end

	manifest_changed && write_toml(manifest_path, config)

	reinstalled = NamedTuple[]
	if !isempty(undeveloped) && isfile(project_plugins_toml(workspace))
		UI.step(io, "re-resolving plugin graph after releasing dev sources")
		project_config = read_toml_required(project_plugins_toml(workspace))
		plugins_after_free = resolve(project_config; workspace = workspace)
		UI.step(io, "installing plugin files")
		install(plugins_after_free; workspace = workspace)
		_remove_unused_plugins(old_manifest, Set([p.name for p in plugins_after_free]), workspace)
		_log_plugin_changes(old_manifest, plugins_after_free; io = io)
		reinstalled = [(name = p.name, version = string(p.version), namespace = p.namespace) for p in plugins_after_free]
	end

	!isempty(unpinned) && UI.note(io, "unpinned: $(join(unpinned, ", "))")
	!isempty(undeveloped) && UI.note(io, "released dev source: $(join(undeveloped, ", "))")
	count_freed = length(unique(vcat(unpinned, undeveloped)))
	UI.summary(io, count_freed == 0 ? "no plugin changes" : "freed $(count_freed) plugin(s)"; level = count_freed == 0 ? :info : :ok)
	(action = "free", plugins = collect(names), unpinned = unpinned, undeveloped = undeveloped, installed = reinstalled)
end

"""
    pin(names...)

Pin installed plugin versions in `.julia_plugins/Plugins.toml`.
"""
pin(names...; io::Union{Nothing, IO} = nothing, base_dir::Union{Nothing, String} = nothing) =
	_pin_or_free(names...; pin = true, io = io, base_dir = base_dir)

"""
    free(names...)

Release plugin constraints by:
1) removing `pinned = true` markers from manifest entries
2) removing matching development sources from global dev store (`dev` undo)

When dev sources are released and project `Plugins.toml` exists, PluginSystem re-resolves and reinstalls plugins.
"""
free(names...; io::Union{Nothing, IO} = nothing, base_dir::Union{Nothing, String} = nothing) =
	_pin_or_free(names...; pin = false, io = io, base_dir = base_dir)

function _copy_plugin_to_global(path::String; force::Bool = true)
	def = parse_plugin_definition(path)
	dest = _global_dev_plugin_path(def.name)
	if force && ispath(dest)
		rm(dest; recursive = true, force = true)
	end
	mkpath(dest)
	if def.is_dir
		rm(dest; recursive = true, force = true)
		cp(def.path, dest; force = true)
	else
		cp(def.path, joinpath(dest, "$(def.name).jl"); force = true)
	end
	parse_plugin_definition(dest)
	dest
end

function _discover_plugin_path(root::String)
	candidates = String[]
	for entry in sort(readdir(root; join = true))
		b = basename(entry)
		startswith(b, ".") && continue
		if isdir(entry) || endswith(b, ".jl")
			try
				parse_plugin_definition(entry)
				push!(candidates, entry)
			catch
			end
		end
	end
	if isempty(candidates)
		try
			parse_plugin_definition(root)
			return root
		catch
		end
	end
	length(candidates) == 1 || error("Cannot determine plugin root automatically. Specify `subdir` to isolate one plugin.")
	candidates[1]
end

"""
    dev(source; rev=nothing, subdir=nothing, force=true)

Add a development plugin into global plugin store (scratch), similar to `Pkg.dev`.
`source` can be a local plugin path, local git repo, or remote git repo URL.
"""
function dev(source::String; rev::Union{Nothing, String} = nothing, subdir::Union{Nothing, String} = nothing, force::Bool = true, io::Union{Nothing, IO} = nothing)
	UI.header(io, "plugin", "dev")
	UI.step(io, "importing development source")
	dest = if ispath(source) && !isdir(joinpath(source, ".git"))
		_copy_plugin_to_global(source; force = force)
	else
		tmp = mktempdir()
		download(source, rev, subdir, tmp; force = true)
		plugin_path = _discover_plugin_path(tmp)
		_copy_plugin_to_global(plugin_path; force = force)
	end
	def = parse_plugin_definition(dest)
	UI.note(io, "global source: $dest")
	UI.summary(io, "registered $(def.name) v$(def.version) [global]")
	(action = "dev", name = def.name, version = string(def.version), path = dest)
end

function _ensure_registry_checkout(registry::String)
	if ispath(registry)
		return abspath(registry)
	end
	tmp = mktempdir()
	run(`git -C $tmp clone --quiet $registry registry`)
	joinpath(tmp, "registry")
end

_git_read(repo::String, args::Vector{String}) = String(strip(readchomp(pipeline(`git -C $repo $(args)`, stderr = devnull))))

function _git_run_quiet(repo::String, args::Vector{String})
	run(pipeline(`git -C $repo $(args)`, stdout = devnull, stderr = devnull))
	nothing
end

function _git_try_read(repo::String, args::Vector{String})
	try
		_git_read(repo, args)
	catch
		nothing
	end
end

function _default_registry_base_branch(registry_path::String, remote::String)
	ref = _git_try_read(registry_path, String["symbolic-ref", "refs/remotes/$remote/HEAD"])
	if ref !== nothing && occursin('/', ref)
		return last(split(ref, '/'))
	end
	for candidate in ("main", "master")
		ok = _git_try_read(registry_path, String["rev-parse", "--verify", "refs/heads/$candidate"])
		ok !== nothing && return candidate
		ok = _git_try_read(registry_path, String["rev-parse", "--verify", "refs/remotes/$remote/$candidate"])
		ok !== nothing && return candidate
	end
	"main"
end

_url_escape(s::String) = replace(replace(s, "%" => "%25"), "/" => "%2F", " " => "%20")

function _github_repo_slug(remote_url::String)
	m = match(r"^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?$", strip(remote_url))
	m !== nothing && return "$(m.captures[1])/$(m.captures[2])"
	m = match(r"^git@github\.com:([^/]+)/(.+?)(?:\.git)?$", strip(remote_url))
	m !== nothing && return "$(m.captures[1])/$(m.captures[2])"
	nothing
end

function _merge_request_url(remote_url::String, base::String, branch::String)
	url = strip(remote_url)
	if (m = match(r"^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?$", url)) !== nothing
		repo = "https://github.com/$(m.captures[1])/$(m.captures[2])"
		return "$repo/compare/$(_url_escape(base))...$(_url_escape(branch))?expand=1"
	end
	if (m = match(r"^https://gitee\.com/([^/]+)/([^/]+?)(?:\.git)?$", url)) !== nothing
		repo = "https://gitee.com/$(m.captures[1])/$(m.captures[2])"
		return "$repo/pulls/new?target_branch=$(_url_escape(base))&source_branch=$(_url_escape(branch))"
	end
	nothing
end

function _create_merge_request(registry_path::String; remote::String, base::String, branch::String, pushed::Bool, io::Union{Nothing, IO} = nothing)
	remote_url = _git_try_read(registry_path, String["remote", "get-url", remote])
	remote_url === nothing && return nothing

	if pushed && Sys.which("gh") !== nothing
		slug = _github_repo_slug(remote_url)
		if slug !== nothing
			try
				url = strip(readchomp(`gh pr create --repo $slug --base $base --head $branch --fill`))
				!isempty(url) && return url
			catch e
				UI.note(io, "failed to auto-create PR with gh: $(sprint(showerror, e))")
			end
		end
	end

	url = _merge_request_url(remote_url, base, branch)
	if url !== nothing
		if pushed
			UI.note(io, "open merge request: $url")
		else
			UI.note(io, "merge request URL (push branch first): $url")
		end
	end
	url
end

function _publish_metadata!(
	registry_path::String,
	plugin_name::String,
	plugin_module::String,
	version::VersionNumber,
	deps::Vector{String},
	repo::String,
	rev::Union{Nothing, String},
	subdir::Union{Nothing, String},
	namespace::Union{Nothing, String},
)
	registry_toml_path = joinpath(registry_path, "Registry.toml")
	registry_toml = read_toml_required(registry_toml_path)
	packages = get!(registry_toml, "packages", Dict{String, String}())
	relpath = get(packages, plugin_name, joinpath("plugins", plugin_name))
	packages[plugin_name] = relpath
	write_toml(registry_toml_path, registry_toml)

	plugin_meta_path = joinpath(registry_path, relpath * ".toml")
	mkpath(dirname(plugin_meta_path))
	meta = isfile(plugin_meta_path) ? read_toml_required(plugin_meta_path) : Dict{String, Any}()
	meta["name"] = plugin_name
	meta["module_name"] = plugin_module
	meta["namespace"] = namespace === nothing ? get(meta, "namespace", "published") : namespace

	versions = get!(meta, "versions", Dict{String, Any}())
	versions[string(version)] = Dict(
		"url" => repo,
		"rev" => something(rev, string(version)),
		"subdir" => something(subdir, ""),
	)
	if !isempty(deps)
		dep_key = string(version)
		get!(meta, "deps", Dict{String, Any}())[dep_key] = deps
		get!(meta, "compat", Dict{String, Any}())[dep_key] = Dict(d => "*" for d in deps)
	end
	write_toml(plugin_meta_path, meta)
	(registry_toml_path, plugin_meta_path)
end

"""
    publish(repo, registry; rev=nothing, subdir=nothing, namespace=nothing, message=nothing, remote="origin", branch=nothing, base=nothing, push=false, create_merge_request=false)

Publish a plugin from a git repository into a registry:
1) parse plugin metadata from module docstring
2) update registry files
3) create a git commit with the registry changes
4) optionally push a branch and create/print merge request URL
"""
function publish(
	repo::String,
	registry::String;
	rev::Union{Nothing, String} = nothing,
	subdir::Union{Nothing, String} = nothing,
	namespace::Union{Nothing, String} = nothing,
	message::Union{Nothing, String} = nothing,
	remote::String = "origin",
	branch::Union{Nothing, String} = nothing,
	base::Union{Nothing, String} = nothing,
	push::Bool = false,
	create_merge_request::Bool = false,
	io::Union{Nothing, IO} = nothing,
)
	UI.header(io, "plugin", "publish")
	UI.step(io, "loading plugin metadata")

	tmp = mktempdir()
	download(repo, rev, subdir, tmp; force = true)
	plugin_path = _discover_plugin_path(tmp)
	def = parse_plugin_definition(plugin_path)

	UI.step(io, "updating registry metadata")
	registry_path = _ensure_registry_checkout(registry)
	paths = _publish_metadata!(registry_path, def.name, def.module_name, def.version, def.deps, repo, rev, subdir, namespace)

	publish_branch = (push || create_merge_request || branch !== nothing || base !== nothing) ? something(branch, "pluginsystem/$(def.name)-v$(def.version)") : nothing
	if publish_branch !== nothing
		UI.step(io, "preparing registry branch")
		_git_run_quiet(registry_path, String["checkout", "-B", publish_branch])
	end

	UI.step(io, "committing registry changes")
	_git_run_quiet(registry_path, String["add", paths[1], paths[2]])
	change_text = _git_read(registry_path, String["status", "--porcelain", "--", paths[1], paths[2]])
	commit_msg = something(message, "Publish $(def.name) $(def.version)")
	committed = !isempty(change_text)
	committed && _git_run_quiet(registry_path, String["commit", "--quiet", "-m", commit_msg, "--no-gpg-sign"])
	released_dev = _remove_global_dev_plugin!(def.name)
	pushed = false
	if push && publish_branch !== nothing
		UI.step(io, "pushing registry branch")
		_git_run_quiet(registry_path, String["push", "--set-upstream", remote, publish_branch])
		pushed = true
	end
	base_branch = create_merge_request ? something(base, _default_registry_base_branch(registry_path, remote)) : nothing
	merge_request_url = create_merge_request ? _create_merge_request(registry_path; remote = remote, base = base_branch::String, branch = publish_branch::String, pushed = pushed, io = io) : nothing

	committed ? UI.note(io, "registry commit: $commit_msg") : UI.note(io, "no registry metadata changes to commit")
	released_dev && UI.note(io, "released development source for $(def.name)")
	UI.summary(io, "published $(def.name) v$(def.version)")
	(
		action = "publish",
		name = def.name,
		version = string(def.version),
		registry = registry_path,
		released_dev = released_dev,
		branch = publish_branch,
		committed = committed,
		pushed = pushed,
		base = base_branch,
		merge_request_url = merge_request_url,
	)
end

struct PackageStatusData
	name::String
	version::VersionNumber
	namespace::String
	installed::Bool
	upgradable::Bool
	heldback::Bool
	pinned::Bool
	path::Union{String, Nothing}
end

function _status_data(workspace::Workspace)
	project_path = project_plugins_toml(workspace)
	isfile(project_path) || error("Plugins.toml not found in current directory.")
	config = read_toml_required(project_path)

	manifest = read_toml_if_exists(manifest_plugins_toml(workspace))
	installed_plugins = get(manifest, "plugins", Dict{String, String}[])
	registry = RegistryData(workspace)
	packages = registry.packages
	deps = Set(_deps_list(config))

	plugins = resolve(config; workspace = workspace)
	unpreserved_plugins = resolve(config; preserve = false, workspace = workspace)

	data = PackageStatusData[]
	for plugin in plugins
		plugin.name in deps || continue
		meta = get(packages, plugin.name, nothing)

		upgradable = false
		heldback = false
		if meta !== nothing
			max_version = maximum(VersionNumber.(keys(meta["versions"])))
			if plugin.version < max_version
				idx = findfirst(p -> p.name == plugin.name, unpreserved_plugins)
				if idx !== nothing
					unpreserved_plugin = unpreserved_plugins[idx]
					if unpreserved_plugin.version == plugin.version
						heldback = true
					else
						upgradable = true
					end
				end
			end
		end

		index = findfirst(p -> p["name"] == plugin.name, installed_plugins)
		installed = index !== nothing
		pinned = installed ? get(installed_plugins[index], "pinned", false) : false

		push!(data, PackageStatusData(
			plugin.name,
			plugin.version,
			plugin.namespace,
			installed,
			upgradable,
			heldback,
			pinned,
			nothing,
		))
	end
	data
end

"""
    status(; io=nothing)

Return plugin status entries. When `io` is provided, prints a status table.
"""
function status(; io::Union{Nothing, IO} = nothing, base_dir::Union{Nothing, String} = nothing)
	workspace = _workspace(base_dir)
	data = _status_data(workspace)
	if io !== nothing
		path = project_plugins_toml(workspace)
		UI.header(io, "plugin", "status")
		UI.note(io, "project: $path")

		if isempty(data)
			UI.change(io, :none, "no plugins")
			return NamedTuple[]
		end

		max_length = maximum(length, [d.namespace for d in data])
		for item in data
			if !item.installed
				printstyled(io, "!", color = :light_red)
			elseif item.upgradable
				printstyled(io, "^", color = :green)
			elseif item.heldback
				printstyled(io, "~", color = :yellow)
			else
				print(io, " ")
			end

			printstyled(io, " [$(lpad(item.namespace, max_length))]", color = :light_black, bold = true)
			printstyled(io, " $(item.name) v$(item.version)", bold = true)
			item.pinned && print(io, " [pinned]")
			println(io)
		end
		UI.summary(io, "direct plugins: $(length(data))"; level = :info)
	end
	[(name = d.name, version = string(d.version), namespace = d.namespace, installed = d.installed, upgradable = d.upgradable, heldback = d.heldback, pinned = d.pinned) for d in data]
end

end#= module API =#
