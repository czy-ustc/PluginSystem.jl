module App

using ..PluginSystem
using Markdown

const APP_NAME = "plugin"
const PSA = Pair{Symbol, Any}
const REPL_PROMPT = "plugin> "

_decl(pairs::Vector{PSA}) = Dict{Symbol, Any}(pairs)

function _parse_kv_options(args::Vector{String})
	opts = Dict{String, String}()
	rest = String[]
	i = 1
	while i <= length(args)
		arg = args[i]
		if startswith(arg, "--")
			key = arg[3:end]
			if key == "all"
				opts[key] = "true"
				i += 1
				continue
			end
			i == length(args) && error("Missing value for option `$arg`.")
			opts[key] = args[i + 1]
			i += 2
		else
			push!(rest, arg)
			i += 1
		end
	end
	(rest, opts)
end

_bool_opt(opts, key, default) = haskey(opts, key) ? lowercase(opts[key]) in ("1", "true", "yes", "on") : default
_csv_opt(opts, key) = haskey(opts, key) ? String[strip(v) for v in split(opts[key], ",") if !isempty(strip(v))] : String[]

function _print_help_doc(io::IO, doc)
	if doc isa Markdown.MD
		show(io, MIME"text/plain"(), doc)
		println(io)
	else
		println(io, string(doc))
	end
end

function _run_help(args, io, _err)
	if isempty(args)
		_print_help_summary(io)
	else
		_print_command_help(io, join(args, " "))
	end
	0
end

function _run_add(args, io, _err)
	PluginSystem.add(args...; io = io)
	0
end

function _run_update(args, io, _err)
	PluginSystem.update(args...; io = io)
	0
end

function _run_remove(args, io, _err)
	isempty(args) && error("remove requires at least one plugin name.")
	PluginSystem.remove(args...; io = io)
	0
end

function _run_instantiate(_args, io, _err)
	PluginSystem.instantiate(; io = io)
	0
end

function _run_status(_args, io, _err)
	PluginSystem.status(; io = io)
	0
end

function _run_pin(args, io, _err)
	isempty(args) && error("pin requires at least one plugin name.")
	PluginSystem.pin(args...; io = io)
	0
end

function _run_free(args, io, _err)
	isempty(args) && error("free requires at least one plugin name.")
	PluginSystem.free(args...; io = io)
	0
end

function _run_dev(args, io, _err)
	(rest, opts) = _parse_kv_options(args)
	length(rest) == 1 || error("dev requires one source argument.")
	PluginSystem.dev(
		rest[1];
		rev = get(opts, "rev", nothing),
		subdir = get(opts, "subdir", nothing),
		force = _bool_opt(opts, "force", true),
		io = io,
	)
	0
end

function _run_publish(args, io, _err)
	(rest, opts) = _parse_kv_options(args)
	length(rest) == 2 || error("publish requires <repo> <registry>.")
	PluginSystem.publish(
		rest[1],
		rest[2];
		rev = get(opts, "rev", nothing),
		subdir = get(opts, "subdir", nothing),
		namespace = get(opts, "namespace", nothing),
		message = get(opts, "message", nothing),
		remote = get(opts, "remote", "origin"),
		branch = get(opts, "branch", nothing),
		base = get(opts, "base", nothing),
		push = _bool_opt(opts, "push", false),
		create_merge_request = _bool_opt(opts, "merge-request", false),
		io = io,
	)
	0
end

function _run_registry_add(args, io, _err)
	PluginSystem.Registry.add(args...; io = io)
	0
end

function _run_registry_remove(args, io, _err)
	PluginSystem.Registry.remove(args...; io = io)
	0
end

function _run_registry_update(args, io, _err)
	PluginSystem.Registry.update(args...; io = io)
	0
end

function _run_registry_status(_args, io, _err)
	PluginSystem.Registry.status(; io = io)
	0
end

function _run_cache_status(_args, io, _err)
	PluginSystem.Cache.status(; io = io)
	0
end

function _run_cache_remove(args, io, _err)
	(rest, opts) = _parse_kv_options(args)
	!isempty(rest) && error("cache remove does not accept positional arguments.")
	PluginSystem.Cache.remove(
		url = get(opts, "url", nothing),
		key = get(opts, "key", nothing),
		all = _bool_opt(opts, "all", false),
		io = io,
	)
	0
end

function _run_generate_project(args, io, _err)
	(rest, opts) = _parse_kv_options(args)
	length(rest) == 1 || error("generate project requires one path argument.")
	PluginSystem.scaffold_project(
		rest[1];
		name = get(opts, "name", nothing),
		force = _bool_opt(opts, "force", false),
		io = io,
	)
	0
end

function _run_generate_plugin(args, io, _err)
	(rest, opts) = _parse_kv_options(args)
	length(rest) == 1 || error("generate plugin requires one path argument.")
	PluginSystem.scaffold_plugin(
		rest[1];
		version = get(opts, "version", "0.1.0"),
		deps = _csv_opt(opts, "deps"),
		as_file = _bool_opt(opts, "file", false),
		force = _bool_opt(opts, "force", false),
		io = io,
	)
	0
end

function _run_registry_namespace(args, io, _err)
	if isempty(args)
		_print_command_help(io, "registry")
		return 0
	end
	if args[1] in ("help", "-h", "--help")
		if length(args) == 1
			_print_command_help(io, "registry")
		else
			_print_command_help(io, "registry " * join(args[2:end], " "))
		end
		return 0
	end
	error("Unknown registry subcommand: $(join(args, " ")). Use `help registry`.")
end

function _run_cache_namespace(args, io, _err)
	if isempty(args)
		_print_command_help(io, "cache")
		return 0
	end
	if args[1] in ("help", "-h", "--help")
		if length(args) == 1
			_print_command_help(io, "cache")
		else
			_print_command_help(io, "cache " * join(args[2:end], " "))
		end
		return 0
	end
	error("Unknown cache subcommand: $(join(args, " ")). Use `help cache`.")
end

function _run_generate_namespace(args, io, _err)
	if isempty(args)
		_print_command_help(io, "generate")
		return 0
	end
	if args[1] in ("help", "-h", "--help")
		if length(args) == 1
			_print_command_help(io, "generate")
		else
			_print_command_help(io, "generate " * join(args[2:end], " "))
		end
		return 0
	end
	error("Unknown generate subcommand: $(join(args, " ")). Use `help generate`.")
end

const command_declarations = Dict{Symbol, Any}[
	_decl(PSA[
		:name => "help",
		:aliases => ["?", "-h", "--help"],
		:run => _run_help,
		:description => "show this message",
		:help => md"""
        help [command]

        Show command summary, or detailed help for one command.
        Examples:
          help add
          help registry remove
        """,
	]),
	_decl(PSA[
		:name => "add",
		:run => _run_add,
		:description => "add plugins to project",
		:help => md"""
        add <name[@version]> ...

        Add plugin names to current project `Plugins.toml`, resolve dependencies, and install artifacts.
        Version constraints can be specified with `name@version` and are stored under `[compat]`.
        """,
	]),
	_decl(PSA[
		:name => "update",
		:aliases => ["up"],
		:run => _run_update,
		:description => "update plugin requirements",
		:help => md"""
        [update|up] [name ...]

        Re-resolve selected plugins. If no names are provided, update all currently declared project deps.
        """,
	]),
	_decl(PSA[
		:name => "remove",
		:aliases => ["rm"],
		:run => _run_remove,
		:description => "remove plugins from project",
		:help => md"""
        [remove|rm] <name ...>

        Remove plugin names from project `deps` list and clean unused installed artifacts.
        """,
	]),
	_decl(PSA[
		:name => "instantiate",
		:run => _run_instantiate,
		:description => "install plugins for current project",
		:help => md"""
        instantiate

        Install plugins exactly as specified by current `Plugins.toml`.
        """,
	]),
	_decl(PSA[
		:name => "status",
		:aliases => ["st"],
		:run => _run_status,
		:description => "show plugin status",
		:help => md"""
        [status|st]

        Show installed/resolved plugin status with markers:
          `^` upgradable
          `~` held back
          `!` missing
        """,
	]),
	_decl(PSA[
		:name => "pin",
		:run => _run_pin,
		:description => "pin plugins",
		:help => md"""
        pin <name ...>

        Pin installed plugin entries in `.julia_plugins/Plugins.toml`.
        """,
	]),
	_decl(PSA[
		:name => "free",
		:run => _run_free,
		:description => "free pinned or developed plugins",
		:help => md"""
        free <name ...>

        Release plugin constraints by removing pin markers and/or development sources.
        This is similar to `Pkg.free` for pinned/dev packages.
        """,
	]),
	_decl(PSA[
		:name => "develop",
		:aliases => ["dev"],
		:run => _run_dev,
		:description => "develop plugin into global plugin store",
		:help => md"""
        [develop|dev] <source> [--rev REV] [--subdir DIR] [--force true|false]

        Import a development plugin from local path or git repository into global plugin storage.
        Similar to `Pkg.dev`.
        """,
	]),
	_decl(PSA[
		:name => "publish",
		:run => _run_publish,
		:description => "publish plugin metadata to registry",
		:help => md"""
        publish <repo> <registry> [--rev REV] [--subdir DIR] [--namespace NS] [--message MSG] [--remote NAME] [--branch BRANCH] [--base BRANCH] [--push true|false] [--merge-request true|false]

        Publish plugin metadata from a git repository into a registry and commit registry changes.
        Optionally push a registry branch and create a merge request/pull request.
        """,
	]),
	_decl(PSA[
		:name => "generate",
		:aliases => ["gen"],
		:run => _run_generate_namespace,
		:description => "scaffold subcommands",
		:help => md"""
        [generate|gen] project <path> [--name NAME] [--force true|false]
        [generate|gen] plugin <path> [--version V] [--deps A,B] [--file true|false] [--force true|false]
        """,
	]),
	_decl(PSA[
		:name => "generate project",
		:aliases => ["gen project"],
		:run => _run_generate_project,
		:description => "generate a plugin project skeleton",
		:help => md"""
        [generate|gen] project <path> [--name NAME] [--force true|false]

        Create a project with `Plugins.toml`, `src/<Module>.jl`, and `plugins/`.
        """,
	]),
	_decl(PSA[
		:name => "generate plugin",
		:aliases => ["gen plugin"],
		:run => _run_generate_plugin,
		:description => "generate a plugin skeleton",
		:help => md"""
        [generate|gen] plugin <path> [--version V] [--deps A,B] [--file true|false] [--force true|false]

        Create a plugin skeleton that satisfies PluginSystem plugin definition rules.
        If `--file true` is set (or path ends with `.jl`), a single-file plugin is generated.
        """,
	]),
	_decl(PSA[
		:name => "registry",
		:run => _run_registry_namespace,
		:description => "registry subcommands",
		:help => md"""
        registry add <url-or-path> ...
        registry remove <name-or-spec> ...
        registry update [name-or-spec ...]
        registry status
        """,
	]),
	_decl(PSA[
		:name => "registry add",
		:run => _run_registry_add,
		:description => "add registries",
		:help => md"""
        registry add <url-or-path> ...

        Add one or more registries from local path or git URL.
        """,
	]),
	_decl(PSA[
		:name => "registry remove",
		:aliases => ["registry rm"],
		:run => _run_registry_remove,
		:description => "remove registries",
		:help => md"""
        registry [remove|rm] <name-or-spec> ...

        Remove one or more installed registries.
        """,
	]),
	_decl(PSA[
		:name => "registry update",
		:aliases => ["registry up"],
		:run => _run_registry_update,
		:description => "update registries",
		:help => md"""
        registry [update|up] [name-or-spec ...]

        Update all registries when no argument is given, or only selected ones.
        """,
	]),
	_decl(PSA[
		:name => "registry status",
		:aliases => ["registry st"],
		:run => _run_registry_status,
		:description => "show registry status",
		:help => md"""
        registry [status|st]

        Show installed registries and their HEAD short hash.
        """,
	]),
	_decl(PSA[
		:name => "cache",
		:run => _run_cache_namespace,
		:description => "cache subcommands",
		:help => md"""
        cache status
        cache st
        cache remove [--url URL | --key KEY | --all]
        cache rm [--url URL | --key KEY | --all]
        """,
	]),
	_decl(PSA[
		:name => "cache status",
		:aliases => ["cache st"],
		:run => _run_cache_status,
		:description => "show git cache status",
		:help => md"""
        cache [status|st]

        List cached git sparse snapshots.
        """,
	]),
	_decl(PSA[
		:name => "cache remove",
		:aliases => ["cache rm"],
		:run => _run_cache_remove,
		:description => "remove git cache entries",
		:help => md"""
        cache [remove|rm] [--url URL | --key KEY | --all]

        Delete cached git data by URL, snapshot key, or all entries.
        """,
	]),
]

function _command_names(cmd)
	String[cmd[:name]; get(cmd, :aliases, String[])]
end

function _find_command(args::Vector{String})
	best_cmd = nothing
	best_len = 0
	for cmd in command_declarations
		for name in _command_names(cmd)
			parts = split(name)
			if length(args) >= length(parts) && all(args[i] == parts[i] for i in eachindex(parts))
				if length(parts) > best_len
					best_len = length(parts)
					best_cmd = cmd
				end
			end
		end
	end
	(best_cmd, best_len)
end

function _find_help_matches(topic::String)
	topic = strip(topic)
	exact = Dict{Symbol, Any}[]
	partial = Dict{Symbol, Any}[]
	for cmd in command_declarations
		names = _command_names(cmd)
		if topic in names
			push!(exact, cmd)
		elseif any(n -> startswith(n, topic), names)
			push!(partial, cmd)
		end
	end
	isempty(exact) ? partial : exact
end

function _command_name_with_aliases(cmd)
	aliases = get(cmd, :aliases, String[])
	isempty(aliases) ? cmd[:name] : string(cmd[:name], " (", join(aliases, ", "), ")")
end

function _print_help_summary(io::IO)
	println(io, "Usage:")
	for cmd in command_declarations
		is_subcommand = occursin(' ', cmd[:name])
		aliases = is_subcommand ? get(cmd, :aliases, String[]) : [last(split(alias, " ")) for alias in get(cmd, :aliases, String[])]
		name = join([cmd[:name]; aliases], ", ")
		padding = max(1, 24 - length(name))
		printstyled(io, "  $name", color = :cyan)
		print(io, repeat(" ", padding))
		println(io, cmd[:description])
	end
	println(io, "\nRun `", APP_NAME, " help <command>` for detailed help.")
end

function _print_command_help(io::IO, topic::String)
	matches = _find_help_matches(topic)
	if isempty(matches)
		println(io, "No command matches `$topic`.")
		return
	end
	for cmd in matches
		println(io, _command_name_with_aliases(cmd))
		println(io, repeat("-", 40))
		_print_help_doc(io, get(cmd, :help, cmd[:description]))
		println(io)
	end
end

function _run_repl(; input::IO = stdin, io::IO = stdout, err::IO = stderr)::Int
	println(io, "PluginSystem REPL mode. Type `help` for commands, `exit` to quit.")
	while true
		printstyled(io, REPL_PROMPT, color = :cyan)
		flush(io)
		line = try
			readline(input)
		catch e
			if e isa EOFError
				println(io)
				println(io, "Leaving PluginSystem REPL.")
				return 0
			end
			rethrow(e)
		end
		stripped = strip(line)
		isempty(stripped) && continue
		if stripped in ("exit", "quit")
			println(io, "Leaving PluginSystem REPL.")
			return 0
		end
		args = try
			Base.shell_split(stripped)
		catch e
			println(err, "Error: ", sprint(showerror, e))
			continue
		end
		isempty(args) && continue
		run_command(args; io = io, err = err, input = input)
	end
end

function run_command(args::Vector{String}; io::IO = stdout, err::IO = stderr, input::IO = stdin)::Int
	if isempty(args)
		return _run_repl(; input = input, io = io, err = err)
	end

	cmd, nconsumed = _find_command(args)
	cmd === nothing && (println(err, "Error: Unknown command: $(join(args, ' '))"); return 1)
	rest = args[(nconsumed + 1):end]

	try
		cmd[:run](rest, io, err)
	catch e
		println(err, "Error: ", sprint(showerror, e))
		1
	end
end

end#= module App =#
