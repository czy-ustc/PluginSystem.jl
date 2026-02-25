module PluginSystem

using Scratch: @get_scratch!

export @load_plugins, load_plugins!
public Registry, Cache, Scaffold, add, dev, free, instantiate, pin, publish, remove, scaffold_plugin, scaffold_project, set_auth!, status, update

abstract type AbstractPluginInfo end

struct LocalPluginInfo <: AbstractPluginInfo
	name::String
	version::VersionNumber
	module_name::String
	namespace::String
	deps::Vector{String}

	path::String
end

struct RemotePluginInfo <: AbstractPluginInfo
	name::String
	version::VersionNumber
	module_name::String
	namespace::String
	deps::Vector{String}

	url::String
	rev::String
	subdir::String
end

struct InstalledPluginInfo <: AbstractPluginInfo
	name::String
	version::VersionNumber
	module_name::String
	namespace::String
	deps::Vector{String}

	path::String
end

const GLOBAL_PLUGINS_DIR = @get_scratch!("plugins")
const GLOBAL_DEV_PLUGINS_DIR = @get_scratch!("global_plugins")

include("utils.jl")
include("ui.jl")
include("registry.jl")
include("resolve.jl")
include("download.jl")
include("cache.jl")
include("scaffold.jl")
include("install.jl")
include("api.jl")
include("load.jl")

using .Resolve: resolve
using .Download: set_auth!
using .Install: install
using .Scaffold: scaffold_plugin, scaffold_project
using .API: add, dev, free, instantiate, pin, publish, remove, status, update
using .Load: @load_plugins, load_plugins!

include("app.jl")

using .App: run_command

include("precompile.jl")

(@main)(ARGS) = run_command(ARGS, io = stdout, err = stderr)

end#= module PluginSystem =#
