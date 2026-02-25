module Registry

using ..PluginSystem: GLOBAL_DEV_PLUGINS_DIR
using ..UI
using ..Utils: Workspace, collect_plugin_definitions, plugin_metadata_entry, plugins_dir,
	read_toml_required, with_repo, workspace
using LibGit2: clone, fetch, head_oid, merge!
using Pkg.Operations: JULIA_UUID
using TOML: parsefile
using Scratch: @get_scratch!
using UUIDs: UUID, uuid4, uuid5

public RegistryData, RegistrySpec, add, remove, status, update

const GLOBAL_REGISTRY_DIR = @get_scratch!("registries")
const PLUGIN_UUID_NAMESPACE = UUID("d0d5b0dc-795b-4c04-a046-30952ac8e2f0")

Base.@kwdef struct RegistrySpec
	name::Union{Nothing, String} = nothing
	uuid::Union{Nothing, UUID} = nothing
	url::Union{Nothing, String} = nothing
	path::Union{Nothing, String} = nothing
end

struct RegistryData
	packages::Dict{String, Dict{String, Any}}
	name_to_uuid::Dict{String, UUID}
	uuid_to_name::Dict{UUID, String}
end

function _read_registry_toml(path::String)
	reg_file = joinpath(path, "Registry.toml")
	read_toml_required(reg_file; error_msg = "Missing Registry.toml in $path")
end

_normalize_repo_name(repo::String) = begin
	name = basename(replace(repo, '\\' => '/'))
	endswith(name, ".git") ? name[1:(end - 4)] : name
end

_stable_plugin_uuid(source::String, plugin_name::String, relpath::String) =
	uuid5(PLUGIN_UUID_NAMESPACE, "source=$(replace(source, '\\' => '/'));plugin=$(plugin_name);path=$(replace(relpath, '\\' => '/'))")

function _absolutize_version_paths!(metadata::Dict{String, Any}, root::String)
	versions = get(metadata, "versions", nothing)
	versions isa Dict || return metadata
	for (_, entry) in versions
		entry isa Dict || continue
		path = get(entry, "path", nothing)
		path isa String || continue
		isabspath(path) && continue
		entry["path"] = abspath(joinpath(root, path))
	end
	metadata
end

function _installed_registries()
	isdir(GLOBAL_REGISTRY_DIR) || return NamedTuple[]
	registries = NamedTuple[]
	for dirname in sort(readdir(GLOBAL_REGISTRY_DIR))
		occursin(".delete.", dirname) && continue
		path = joinpath(GLOBAL_REGISTRY_DIR, dirname)
		isdir(path) || continue
		reg_file = joinpath(path, "Registry.toml")
		isfile(reg_file) || continue
		reg = _read_registry_toml(path)
		push!(registries, (
			name = get(reg, "name", dirname),
			uuid = get(reg, "uuid", nothing),
			repo = get(reg, "repo", nothing),
			path = path,
		))
	end
	registries
end

function _rm_tree_retry(path::String; retries::Int = 20, delay::Float64 = 0.05)
	for attempt in 1:retries
		try
			rm(path; recursive = true, force = true, allow_delayed_delete = true)
			return true
		catch e
			attempt == retries && break
			sleep(delay * attempt)
		end
	end

	# On Windows, git pack files can stay locked briefly.
	# Best effort fallback: move away then request delayed delete.
	fallback = path * ".delete." * string(uuid4())
	try
		mv(path, fallback; force = true)
		rm(fallback; recursive = true, force = true, allow_delayed_delete = true)
		return true
	catch
		return false
	end
end

function _resolve_registry(spec::RegistrySpec)
	registries = _installed_registries()
	for reg in registries
		if spec.name !== nothing && reg.name == spec.name
			return reg
		end
		if spec.uuid !== nothing && reg.uuid == string(spec.uuid)
			return reg
		end
		if spec.url !== nothing && reg.repo == spec.url
			return reg
		end
		if spec.path !== nothing && normpath(reg.path) == normpath(abspath(spec.path))
			return reg
		end
	end
	nothing
end

function _overlay_package!(packages, name_to_uuid, uuid_to_name, source::String, name::String, relpath::String, metadata)
	if haskey(name_to_uuid, name)
		old_uuid = name_to_uuid[name]
		pop!(uuid_to_name, old_uuid, nothing)
	end
	uuid = _stable_plugin_uuid(source, name, relpath)
	name_to_uuid[name] = uuid
	uuid_to_name[uuid] = name
	packages[name] = metadata
end

function _overlay_local_plugins!(packages, name_to_uuid, uuid_to_name, dir::String, source::String, namespace::String)
	for (name, def) in collect_plugin_definitions(dir)
		metadata = plugin_metadata_entry(def; namespace = namespace)
		_overlay_package!(packages, name_to_uuid, uuid_to_name, source, name, def.path, metadata)
	end
end

function RegistryData(workspace::Workspace)
	# Build merged metadata map with priority: project plugins > global dev plugins > registries.
	dirs = isdir(GLOBAL_REGISTRY_DIR) ? filter(d -> !occursin(".delete.", d), sort(readdir(GLOBAL_REGISTRY_DIR))) : String[]
	isempty(dirs) && !isdir(GLOBAL_DEV_PLUGINS_DIR) && !isdir(plugins_dir(workspace)) &&
		error("No registries or local plugins found.")

	name_to_uuid = Dict("julia" => JULIA_UUID)
	uuid_to_name = Dict(JULIA_UUID => "julia")
	packages = Dict{String, Dict{String, Any}}()

	for dirname in dirs
		reg_path = joinpath(GLOBAL_REGISTRY_DIR, dirname)
		reg = _read_registry_toml(reg_path)
		registry_name = get(reg, "name", dirname)
		for (name, relpath) in reg["packages"]
			metadata = parsefile(joinpath(reg_path, relpath * ".toml"))
			_absolutize_version_paths!(metadata, reg_path)
			_overlay_package!(packages, name_to_uuid, uuid_to_name, "registry:$registry_name", name, relpath, metadata)
		end
	end

	_overlay_local_plugins!(packages, name_to_uuid, uuid_to_name, GLOBAL_DEV_PLUGINS_DIR, "global-dev", "global")
	_overlay_local_plugins!(packages, name_to_uuid, uuid_to_name, plugins_dir(workspace), "project", "project")
	RegistryData(packages, name_to_uuid, uuid_to_name)
end

RegistryData(base_dir::String = pwd()) = RegistryData(workspace(base_dir))

function _to_spec(reg::String)
	if ispath(reg) || occursin("://", reg) || occursin("@", reg)
		RegistrySpec(url = reg)
	else
		RegistrySpec(name = reg)
	end
end

_to_spec(spec::RegistrySpec) = spec

function _clone_source(spec::RegistrySpec)
	spec.url !== nothing && return spec.url
	spec.path !== nothing && return abspath(spec.path)
	nothing
end

function _target_name(spec::RegistrySpec, source::Union{Nothing, String})
	spec.name !== nothing && return spec.name
	source === nothing && error("Registry source is required. Provide `url` or `path`.")

	if ispath(source)
		try
			reg = _read_registry_toml(source)
			return get(reg, "name", basename(source))
		catch
			return basename(source)
		end
	end
	_normalize_repo_name(source)
end

"""
    add(specs...)

Add one or more registries from URL/path/name-like specifications.
"""
function add(specs::Union{RegistrySpec, String}...; io::Union{Nothing, IO} = nothing)
	isempty(specs) && error("No registry specified.")
	UI.header(io, "registry", "add")
	UI.step(io, "cloning registry sources")
	added = String[]
	for raw in specs
		spec = _to_spec(raw)
		source = _clone_source(spec)
		target_name = _target_name(spec, source)
		target_path = joinpath(GLOBAL_REGISTRY_DIR, target_name)

		source === nothing && error("Registry `$target_name` requires `url` or `path`.")
		isdir(target_path) && continue
		mkpath(dirname(target_path))
		repo = clone(source, target_path)
		close(repo)
		push!(added, target_name)
		UI.change(io, :add, target_name)
	end
	UI.summary(io, isempty(added) ? "no registry changes" : "added $(length(added)) registry(ies)"; level = isempty(added) ? :info : :ok)
	(action = "registry-add", added = added)
end

"""
    remove(specs...)

Remove one or more installed registries by name or `RegistrySpec`.
"""
function remove(specs::Union{RegistrySpec, String}...; io::Union{Nothing, IO} = nothing)
	isempty(specs) && error("No registry specified.")
	UI.header(io, "registry", "remove")
	UI.step(io, "removing registry checkouts")
	removed = String[]
	for raw in specs
		spec = raw isa String ? RegistrySpec(name = raw) : raw
		reg = _resolve_registry(spec)
		reg === nothing && continue
		if _rm_tree_retry(reg.path)
			push!(removed, reg.name)
			UI.change(io, :remove, reg.name)
		else
			UI.note(io, "skipped busy registry path: $(reg.path)")
		end
	end
	UI.summary(io, isempty(removed) ? "no registry changes" : "removed $(length(removed)) registry(ies)"; level = isempty(removed) ? :info : :ok)
	(action = "registry-remove", removed = removed)
end

"""
    status([io])

Print installed registry status including current HEAD short hash.
"""
function status(; io::Union{Nothing, IO} = nothing)
	registries = _installed_registries()
	rows = NamedTuple[]
	for reg in registries
		head = try
			with_repo(reg.path) do repo
				string(head_oid(repo))[1:8]
			end
		catch
			"????????"
		end
		push!(rows, (name = reg.name, head = head, repo = reg.repo, path = reg.path))
	end
	if io !== nothing
		UI.header(io, "registry", "status")
		if isempty(rows)
			UI.change(io, :none, "no registries found")
			return rows
		end
		for reg in rows
			printstyled(io, "  [$(reg.head)]"; color = :light_black, bold = true)
			repo_str = reg.repo === nothing ? "" : " ($(reg.repo))"
			printstyled(io, " $(reg.name)$repo_str", bold = true)
			println(io)
		end
		UI.summary(io, "registries: $(length(rows))"; level = :info)
	end
	rows
end

function _update_one(path::String)
	with_repo(path) do repo
		fetch(repo)
		merge!(repo)
	end
	nothing
end

"""
    update(specs...)

Update selected registries, or all installed registries when no arguments are provided.
"""
function update(specs::Union{RegistrySpec, String}...; io::Union{Nothing, IO} = nothing)
	UI.header(io, "registry", "update")
	UI.step(io, "fetching registry updates")
	updated = String[]
	if isempty(specs)
		for reg in _installed_registries()
			_update_one(reg.path)
			push!(updated, reg.name)
			UI.change(io, :update, reg.name)
		end
		UI.summary(io, isempty(updated) ? "no registry changes" : "updated $(length(updated)) registry(ies)"; level = isempty(updated) ? :info : :ok)
		return (action = "registry-update", updated = updated)
	end

	for raw in specs
		spec = raw isa String ? RegistrySpec(name = raw) : raw
		reg = _resolve_registry(spec)
		reg === nothing && error("Registry not found: $(raw)")
		_update_one(reg.path)
		push!(updated, reg.name)
		UI.change(io, :update, reg.name)
	end
	UI.summary(io, isempty(updated) ? "no registry changes" : "updated $(length(updated)) registry(ies)"; level = isempty(updated) ? :info : :ok)
	(action = "registry-update", updated = updated)
end

end#= module Registry =#
