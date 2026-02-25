module Scaffold

using ..UI
using ..Utils: parse_plugin_definition, write_toml

public scaffold_plugin, scaffold_project

const _MODULE_NAME_RE = r"^[A-Za-z][A-Za-z0-9_]*$"

function _validate_module_name(name::String; what::String)
	isempty(name) && error("$what must not be empty.")
	occursin(_MODULE_NAME_RE, name) || error("$what `$name` is not a valid Julia module name.")
	name
end

function _sanitize_module_name(raw::String)
	normalized = strip(replace(raw, r"[^A-Za-z0-9]+" => " "))
	parts = split(normalized)
	isempty(parts) && return "MyProject"
	name = join(uppercasefirst.(lowercase.(parts)))
	isempty(name) && return "MyProject"
	isdigit(first(name)) && return "Project$name"
	name
end

function _prepare_target(path::String; force::Bool)
	if ispath(path)
		force || error("Target already exists: $path. Pass `force=true` to overwrite.")
		rm(path; recursive = true, force = true)
	end
	nothing
end

function _quote_string(s::String)
	"\"" * replace(s, "\\" => "\\\\", "\"" => "\\\"") * "\""
end

function _render_toml_string_array(items::Vector{String})
	isempty(items) && return "[]"
	"[" * join(_quote_string.(items), ", ") * "]"
end

function _write_project_module(path::String, module_name::String)
	write(
		path,
		"""
		module $module_name
		using PluginSystem

		@load_plugins

		end # module $module_name
		""",
	)
end

function _write_plugin_module(path::String, plugin_name::String, version::VersionNumber, deps::Vector{String})
	deps_toml = _render_toml_string_array(deps)
	write(
		path,
		"""
		\"\"\"
		version = "$(version)"
		deps = $deps_toml
		\"\"\"
		module $plugin_name

		\"\"\"
		Entry point of plugin `$plugin_name`.
		\"\"\"
		function activate()
		    nothing
		end

		end # module $plugin_name
		""",
	)
end

"""
    scaffold_project(path; name=nothing, force=false, io=nothing)

Generate a project skeleton with:
- `Plugins.toml`
- `src/<ModuleName>.jl`
- `plugins/`
- `.gitignore` (ignores `.julia_plugins/`)
"""
function scaffold_project(
	path::String;
	name::Union{Nothing, String} = nothing,
	force::Bool = false,
	io::Union{Nothing, IO} = nothing,
)
	target = abspath(path)
	module_name = _validate_module_name(_sanitize_module_name(something(name, basename(target))); what = "Project module name")

	UI.header(io, "scaffold", "project")
	UI.step(io, "creating project skeleton")
	_prepare_target(target; force = force)
	mkpath(joinpath(target, "src"))
	mkpath(joinpath(target, "plugins"))

	write_toml(joinpath(target, "Plugins.toml"), Dict{String, Any}("deps" => String[]))
	_write_project_module(joinpath(target, "src", "$(module_name).jl"), module_name)
	write(joinpath(target, ".gitignore"), ".julia_plugins/\n")

	UI.note(io, "path: $target")
	UI.summary(io, "generated project `$module_name`")
	(action = "generate-project", path = target, module_name = module_name)
end

"""
    scaffold_plugin(path; version="0.1.0", deps=String[], as_file=false, force=false, io=nothing)

Generate a plugin skeleton. By default, creates a directory plugin:
- `<path>/<Name>.jl`

Set `as_file=true` (or pass a `.jl` path) to create a single-file plugin.
"""
function scaffold_plugin(
	path::String;
	version::Union{String, VersionNumber} = "0.1.0",
	deps::Vector{String} = String[],
	as_file::Bool = false,
	force::Bool = false,
	io::Union{Nothing, IO} = nothing,
)
	ver = version isa VersionNumber ? version : VersionNumber(version)
	file_layout = as_file || endswith(lowercase(path), ".jl")

	target_path = if file_layout
		endswith(lowercase(path), ".jl") ? abspath(path) : abspath(path * ".jl")
	else
		abspath(path)
	end

	plugin_name = if file_layout
		name = basename(target_path)
		name[1:(end - 3)]
	else
		basename(target_path)
	end
	_validate_module_name(plugin_name; what = "Plugin name")

	UI.header(io, "scaffold", "plugin")
	UI.step(io, "creating plugin skeleton")
	_prepare_target(target_path; force = force)

	entry_file = if file_layout
		mkpath(dirname(target_path))
		target_path
	else
		mkpath(target_path)
		joinpath(target_path, "$(plugin_name).jl")
	end

	clean_deps = unique(String[strip(dep) for dep in deps if !isempty(strip(dep))])
	_write_plugin_module(entry_file, plugin_name, ver, clean_deps)
	def = parse_plugin_definition(file_layout ? entry_file : target_path)

	UI.note(io, "path: $(file_layout ? entry_file : target_path)")
	UI.summary(io, "generated plugin `$(def.name)` v$(def.version)")
	(
		action = "generate-plugin",
		name = def.name,
		version = string(def.version),
		path = file_layout ? entry_file : target_path,
		entry = def.entry_file,
		deps = copy(def.deps),
		layout = file_layout ? "file" : "directory",
	)
end

end#= module Scaffold =#
