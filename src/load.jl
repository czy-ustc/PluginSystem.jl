module Load

using ..Utils: Workspace, manifest_plugins_toml, plugin_store_dir, read_toml_if_exists, workspace

export @load_plugins, load_plugins!

function _manifest_plugin_entries(workspace::Workspace)
	manifest = read_toml_if_exists(manifest_plugins_toml(workspace))
	plugins = get(manifest, "plugins", Any[])
	plugins isa Vector || error("Installed manifest field `plugins` must be an array.")
	plugins
end

function _entry_name(entry)
	name = get(entry, "name", nothing)
	name isa String || error("Invalid plugin entry: missing string field `name`.")
	name
end

function _entry_path(workspace::Workspace, entry)
	rel = get(entry, "path", nothing)
	rel isa String || error("Invalid plugin entry `$(get(entry, "name", "<unknown>"))`: missing string field `path`.")
	joinpath(plugin_store_dir(workspace), rel)
end

function _loaded_set!(target::Module)
	sym = Symbol("__PLUGIN_SYSTEM_LOADED__")
	if !isdefined(target, sym)
		Base.eval(target, :(const $(sym) = Set{String}()))
	end
	Base.invokelatest(getfield, target, sym)
end

function _mark_loaded!(target::Module, names::AbstractVector{<:AbstractString})
	loaded_set = _loaded_set!(target)
	for name in names
		push!(loaded_set, String(name))
	end
	loaded_set
end

function _macro_source_dir(source_file)
	file = String(source_file)
	(file == "none" || isempty(file)) && return pwd()
	dirname(abspath(file))
end

function _macro_manifest_entries(base_dir::String)
	ws = workspace(base_dir)
	manifest_path = manifest_plugins_toml(ws)
	entry_type = NamedTuple{(:name, :path), Tuple{String, String}}
	isfile(manifest_path) || return (entries = entry_type[], has_manifest = false, missing_files = false)

	entries = entry_type[]
	missing_files = false
	for entry in _manifest_plugin_entries(ws)
		entry isa AbstractDict || continue
		name = _entry_name(entry)
		path = normpath(abspath(_entry_path(ws, entry)))
		if isfile(path)
			push!(entries, (name = name, path = path))
		else
			missing_files = true
		end
	end
	(entries = entries, has_manifest = true, missing_files = missing_files)
end

function _static_load_expr(entries::Vector{<:NamedTuple{(:name, :path), Tuple{String, String}}})
	static_sym = gensym(:PLUGIN_SYSTEM_STATIC_PLUGINS_)
	pairs = [:(($(QuoteNode(Symbol(entry.name))), $(entry.path))) for entry in entries]
	block = Expr(:block, :(const $(static_sym) = ($(pairs...),)))
	loaded_names = String[]
	for entry in entries
		push!(loaded_names, entry.name)
		push!(block.args, :(Base.include(@__MODULE__, $(entry.path))))
		push!(block.args, :(using .$(Symbol(entry.name))))
	end
	push!(block.args, :(PluginSystem.Load._mark_loaded!(@__MODULE__, $(loaded_names))))
	push!(block.args, :(nothing))
	block
end

"""
    load_plugins!(target::Module; base_dir=pwd(), strict=true)

Load plugins listed in `<workspace>/.julia_plugins/Plugins.toml` into `target`.
Returns `(loaded, skipped, workspace)` for observability.
"""
function load_plugins!(target::Module; base_dir::String = pwd(), strict::Bool = true)
	ws = workspace(base_dir)
	loaded = String[]
	skipped = String[]
	loaded_set = _loaded_set!(target)

	for entry in _manifest_plugin_entries(ws)
		entry isa AbstractDict || continue
		name = _entry_name(entry)
		if name in loaded_set
			push!(skipped, name)
			continue
		end

		path = _entry_path(ws, entry)
		if !isfile(path)
			strict && error("Plugin source file not found for `$name`: $path")
			push!(skipped, name)
			continue
		end

		Base.include(target, path)
		Base.eval(target, :(using .$(Symbol(name))))
		push!(loaded_set, name)
		push!(loaded, name)
	end

	(loaded = loaded, skipped = skipped, workspace = ws.root)
end

"""
    @load_plugins

Load plugins from the caller workspace into the caller module.

When `.julia_plugins/Plugins.toml` is available and plugin files exist, this macro
expands to static `Base.include`/`using` statements to improve editor and language
server visibility (for example, JETLS completion and symbol resolution).
Workspace root is discovered from the source file location.
"""
macro load_plugins()
	source_dir = _macro_source_dir(__source__.file)
	macro_data = try
		_macro_manifest_entries(source_dir)
	catch
		nothing
	end

	if macro_data === nothing || !macro_data.has_manifest
		return esc(:(PluginSystem.load_plugins!(@__MODULE__; base_dir = $source_dir, strict = false)))
	end

	if isempty(macro_data.entries)
		return esc(:(PluginSystem.load_plugins!(@__MODULE__; base_dir = $source_dir, strict = $(macro_data.missing_files))))
	end

	expr = _static_load_expr(macro_data.entries)
	if macro_data.missing_files
		push!(expr.args, :(PluginSystem.load_plugins!(@__MODULE__; base_dir = $source_dir, strict = true)))
	end
	esc(expr)
end

end#= module Load =#
