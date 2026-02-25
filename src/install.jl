module Install

using ..PluginSystem: AbstractPluginInfo, GLOBAL_PLUGINS_DIR, InstalledPluginInfo,
	LocalPluginInfo, RemotePluginInfo
using ..Download: download
using ..Utils: Workspace, plugin_store_dir, read_toml_if_exists, workspace, write_toml

export install

function _manifest_entry(plugin::InstalledPluginInfo)
	Dict(
		"name" => plugin.name,
		"version" => string(plugin.version),
		"namespace" => plugin.namespace,
		"path" => joinpath(split(plugin.namespace)..., plugin.name, "$(plugin.name).jl"),
	)
end

function _upsert_manifest_plugin!(plugins::Vector, plugin_info::Dict{String, String})
	index = findfirst(p -> get(p, "name", nothing) == plugin_info["name"], plugins)
	if index === nothing
		push!(plugins, plugin_info)
	else
		plugins[index] = plugin_info
	end
	plugins
end

function link(plugin::InstalledPluginInfo, plugin_dir::String; islink::Bool = true)
	name = plugin.name
	namespace = plugin.namespace
	path = plugin.path

	dir = joinpath(plugin_dir, split(namespace)..., name)
	linkname = isdir(path) ? dir : joinpath(dir, "$name.jl")
	mkpath(dirname(linkname))
	ispath(linkname) && rm(linkname; force = true, recursive = true)
	try
		if islink
			symlink(path, linkname)
		else
			cp(path, linkname; force = true)
		end
	catch e
		@warn "Failed to create symlink for plugin $name: $e"
		cp(path, linkname; force = true)
	end

	config_file = joinpath(plugin_dir, "Plugins.toml")
	config = read_toml_if_exists(config_file)
	plugins = get!(config, "plugins", Dict{String, String}[])
	_upsert_manifest_plugin!(plugins, _manifest_entry(plugin))
	write_toml(config_file, config)

	plugin
end

function get_installed(plugin::AbstractPluginInfo, plugin_dir::String; islink::Bool = true)
	name = plugin.name
	version = plugin.version
	namespace = plugin.namespace
	dir = joinpath(GLOBAL_PLUGINS_DIR, split(namespace)..., name, string(version))
	ispath(dir) || return nothing

	installed_plugin = InstalledPluginInfo(name, version, plugin.module_name, namespace, plugin.deps, dir)
	link(installed_plugin, plugin_dir; islink = islink)
end

function install(plugin::RemotePluginInfo, plugin_dir::String; islink::Bool = true)::InstalledPluginInfo
	installed = get_installed(plugin, plugin_dir; islink = islink)
	installed !== nothing && return installed
	download(plugin)
	get_installed(plugin, plugin_dir; islink = islink)
end

function install(plugin::LocalPluginInfo, plugin_dir::String; islink::Bool = true)::InstalledPluginInfo
	link(
		InstalledPluginInfo(
			plugin.name,
			plugin.version,
			plugin.module_name,
			plugin.namespace,
			plugin.deps,
			abspath(plugin.path),
		),
		plugin_dir;
		islink = islink,
	)
end

install(plugin::InstalledPluginInfo, plugin_dir::String; islink::Bool = true)::InstalledPluginInfo =
	get_installed(plugin, plugin_dir; islink = islink)

install(plugin::AbstractPluginInfo; workspace::Workspace = workspace(), islink::Bool = true)::InstalledPluginInfo =
	install(plugin, plugin_store_dir(workspace); islink = islink)

install(
	plugins::Vector{<:AbstractPluginInfo};
	workspace::Workspace = workspace(),
	islink::Bool = true,
) = map(plugin -> install(plugin, plugin_store_dir(workspace); islink = islink), plugins)

install(
	plugins::Vector{<:AbstractPluginInfo},
	plugin_dir::String;
	islink::Bool = true,
) = map(plugin -> install(plugin, plugin_dir; islink = islink), plugins)

end#= module Install =#
