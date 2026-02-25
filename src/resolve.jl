module Resolve

using ..PluginSystem: AbstractPluginInfo, LocalPluginInfo, RemotePluginInfo
using ..Registry: RegistryData
using ..Utils: Workspace, manifest_plugins_toml, read_toml_if_exists, workspace
using Pkg.Resolve: Fixed, Graph, resolve as pkg_resolve, simplify_graph!
using Pkg.Types: VersionSpec
using UUIDs: UUID

export resolve, topological_sort

_filter_spec(specs, version) = filter(spec -> version in VersionSpec(spec), specs)

function _plugin_metadata(registry::RegistryData, name::String)
	get(registry.packages, name, nothing)
end

# Build a Pkg-compatible dependency graph from plugin registry metadata and resolve versions.
function plugin_resolve(registry::RegistryData, reqs::Dict{String, VersionSpec}, fixed::Dict{String, Fixed})
	compat = Dict{UUID, Dict{VersionNumber, Dict{UUID, VersionSpec}}}()
	name_to_uuid = registry.name_to_uuid
	uuid_to_name = registry.uuid_to_name
	for (uuid, name) in uuid_to_name
		name == "julia" && continue
		info = _plugin_metadata(registry, name)
		info === nothing && continue

		compat[uuid] = Dict{VersionNumber, Dict{UUID, VersionSpec}}()
		plugin_versions = get(info, "versions", Dict{String, Any}())
		plugin_deps = get(info, "deps", Dict{String, Any}())
		plugin_compat = get(info, "compat", Dict{String, Any}())

		for v_str in keys(plugin_versions)
			version = VersionNumber(v_str)
			compat[uuid][version] = Dict{UUID, VersionSpec}()
			version_deps = vcat(String[], [plugin_deps[k] for k in _filter_spec(keys(plugin_deps), version)]...)
			version_compat = merge(Dict{String, String}(),
				[plugin_compat[k] for k in _filter_spec(keys(plugin_compat), version)]...)
			for dep in version_deps
				haskey(name_to_uuid, dep) || error("Missing dependency `$dep` required by `$name`.")
				compat[uuid][version][name_to_uuid[dep]] = VersionSpec(get(version_compat, dep, "*"))
			end
		end
	end

	graph = Graph(
		compat,
		Dict{UUID, Dict{VersionNumber, Set{UUID}}}(),
		uuid_to_name,
		Dict(name_to_uuid[k] => v for (k, v) in reqs),
		Dict(name_to_uuid[k] => v for (k, v) in fixed),
	)
	simplify_graph!(graph)
	sol = pkg_resolve(graph)

	plugins = Dict{String, AbstractPluginInfo}()
	for (uuid, version) in sol
		name = uuid_to_name[uuid]
		info = registry.packages[name]
		plugin_info = info["versions"][string(version)]
		module_name = get(info, "module_name", name)
		namespace = get(info, "namespace", "")
		deps = [uuid_to_name[d] for d in keys(compat[uuid][version])]

		if haskey(plugin_info, "path")
			plugins[name] = LocalPluginInfo(
				name,
				version,
				module_name,
				namespace,
				deps,
				plugin_info["path"],
			)
		else
			plugins[name] = RemotePluginInfo(
				name,
				version,
				module_name,
				namespace,
				deps,
				plugin_info["url"],
				get(plugin_info, "rev", string(version)),
				get(plugin_info, "subdir", ""),
			)
		end
	end

	plugins
end

function topological_sort(plugins::Dict{String, AbstractPluginInfo})
	in_degree = Dict{String, Int}()
	graph = Dict{String, Vector{String}}()

	for (name, info) in plugins
		in_degree[name] = length(info.deps)
		for dep in info.deps
			push!(get!(graph, dep, String[]), name)
		end
	end

	queue = sort([name for (name, degree) in in_degree if degree == 0])
	result = String[]
	while !isempty(queue)
		node = popfirst!(queue)
		push!(result, node)
		for neighbor in get(graph, node, String[])
			in_degree[neighbor] -= 1
			if in_degree[neighbor] == 0
				push!(queue, neighbor)
			end
		end
	end

	[plugins[name] for name in result]
end

function _deps_list(config::Dict{String, Any})
	deps = get(config, "deps", String[])
	deps isa Vector || error("`Plugins.toml` field `deps` must be a list of plugin names.")
	String[string(dep) for dep in deps]
end

function _load_direct_deps(deps::Vector{String}, workspace::Workspace)
	path = manifest_plugins_toml(workspace)
	Dict(
		p["name"] => p["version"] for p in get(read_toml_if_exists(path), "plugins", [])
		if p["name"] in deps
	)
end

function _get_pin_plugins(workspace::Workspace)
	path = manifest_plugins_toml(workspace)
	config = read_toml_if_exists(path)
	plugins = get(config, "plugins", [])
	Dict{String, String}(p["name"] => p["version"] for p in plugins if get(p, "pinned", false))
end

function targeted_resolve(config::Dict{String, Any}; workspace::Workspace = workspace())
	registry = RegistryData(workspace)
	deps = _deps_list(config)
	compat = merge(get(config, "compat", Dict{String, String}()), _get_pin_plugins(workspace))

	reqs = Dict{String, VersionSpec}()
	fixed = Dict{String, Fixed}()
	for name in deps
		haskey(registry.name_to_uuid, name) || error("Plugin `$name` not found in registries or local plugin sources.")
		reqs[name] = VersionSpec(get(compat, name, "*"))
	end

	plugins = plugin_resolve(registry, reqs, fixed)
	topological_sort(plugins)
end

function resolve(
	config::Dict{String, Any},
	update_plugins::Vector{String} = String[];
	preserve::Bool = true,
	workspace::Workspace = workspace(),
)
	if !preserve
		return targeted_resolve(config; workspace = workspace)
	end

	try
		new_config = deepcopy(config)
		deps = _deps_list(new_config)
		compat = get!(new_config, "compat", Dict{String, String}())
		new_config["compat"] = merge(_load_direct_deps(setdiff(deps, update_plugins), workspace), compat)
		targeted_resolve(new_config; workspace = workspace)
	catch
		targeted_resolve(config; workspace = workspace)
	end
end

end#= module Resolve =#
