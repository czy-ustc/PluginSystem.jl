using TOML

const TEST_GIT_EMAIL = "tests@example.com"
const TEST_GIT_NAME = "PluginSystemTests"
const TEST_FIXTURE_REGISTRY_REMOTE_URL = get(ENV, "PLUGINSYSTEM_FIXTURE_REGISTRY_REPO", "https://github.com/czy-ustc/fixtures-registry.git")
const TEST_FIXTURE_REGISTRY_REMOTE_REF = get(ENV, "PLUGINSYSTEM_FIXTURE_REGISTRY_REF", "v0.3.0")
const TEST_FIXTURE_PLUGINS_REMOTE_URL = get(ENV, "PLUGINSYSTEM_FIXTURE_PLUGINS_REPO", "https://github.com/czy-ustc/fixtures-plugins.git")
const TEST_FIXTURE_PLUGINS_REMOTE_REF = get(ENV, "PLUGINSYSTEM_FIXTURE_PLUGINS_REF", "v0.3.0")
const _TEST_FIXTURE_ROOTS = Ref{Union{Nothing, NamedTuple{(:registry, :plugins), Tuple{String, String}}}}(nothing)

function _git_cmd(repo::String, args::AbstractString...)
	`git -C $repo $(collect(args))`
end

function git_run_quiet(repo::String, args::AbstractString...)
	run(pipeline(_git_cmd(repo, args...), stdout = devnull, stderr = devnull))
	nothing
end

function git_read_quiet(repo::String, args::AbstractString...)
	String(strip(readchomp(pipeline(_git_cmd(repo, args...), stderr = devnull))))
end

function git_init_repo!(repo::String)
	git_run_quiet(repo, "init")
	git_run_quiet(repo, "config", "core.autocrlf", "false")
	git_run_quiet(repo, "config", "core.safecrlf", "false")
	git_run_quiet(repo, "config", "user.email", TEST_GIT_EMAIL)
	git_run_quiet(repo, "config", "user.name", TEST_GIT_NAME)
	nothing
end

function git_commit_all!(repo::String; message::String = "update")
	git_run_quiet(repo, "add", ".")
	isempty(git_read_quiet(repo, "status", "--porcelain")) || git_run_quiet(repo, "commit", "-m", message, "--no-gpg-sign")
	nothing
end

function git_commit_paths!(repo::String, paths::Vector{String}; message::String = "update")
	isempty(paths) && return nothing
	git_run_quiet(repo, "add", paths...)
	isempty(git_read_quiet(repo, "status", "--porcelain")) || git_run_quiet(repo, "commit", "-m", message, "--no-gpg-sign")
	nothing
end

function git_commit_paths!(repo::String, path::String, more::String...; message::String = "update")
	git_commit_paths!(repo, String[path, more...]; message = message)
end

git_head(repo::String) = git_read_quiet(repo, "rev-parse", "HEAD")

function setup_git_repo_from(src::String; message::String = "fixture")
	repo = mktempdir()
	cp(src, repo; force = true)
	git_init_repo!(repo)
	git_commit_all!(repo; message = message)
	repo
end

function _registry_layout_valid(root::String)
	isfile(joinpath(root, "Registry.toml")) || isfile(joinpath(root, "registries", "FixtureGeneral", "Registry.toml"))
end

function _plugins_layout_valid(root::String)
	isdir(joinpath(root, "fixture")) || isdir(joinpath(root, "plugins", "fixture"))
end

function _clone_fixture_root(url::String, ref::String)
	parent = mktempdir()
	dst = joinpath(parent, "fixtures_repo")
	ref = strip(ref)
	for attempt in 1:3
		try
			if isempty(ref)
				run(pipeline(`git clone --quiet $url $dst`, stdout = devnull, stderr = devnull))
			else
				run(pipeline(`git clone --quiet --depth 1 --branch $ref $url $dst`, stdout = devnull, stderr = devnull))
			end
			return dst
		catch
			rm(dst; recursive = true, force = true)
			attempt == 3 && rethrow()
			sleep(0.5 * attempt)
		end
	end
	error("unreachable")
end

function fixture_roots()
	if _TEST_FIXTURE_ROOTS[] !== nothing
		return _TEST_FIXTURE_ROOTS[]::NamedTuple{(:registry, :plugins), Tuple{String, String}}
	end

	registry_root = _clone_fixture_root(TEST_FIXTURE_REGISTRY_REMOTE_URL, TEST_FIXTURE_REGISTRY_REMOTE_REF)
	plugins_root = _clone_fixture_root(TEST_FIXTURE_PLUGINS_REMOTE_URL, TEST_FIXTURE_PLUGINS_REMOTE_REF)
	_registry_layout_valid(registry_root) || error("Invalid registry fixture repository layout: $registry_root")
	_plugins_layout_valid(plugins_root) || error("Invalid plugins fixture repository layout: $plugins_root")
	_TEST_FIXTURE_ROOTS[] = (registry = registry_root, plugins = plugins_root)
	_TEST_FIXTURE_ROOTS[]::NamedTuple{(:registry, :plugins), Tuple{String, String}}
end

function _rewrite_registry_to_remote_plugins!(registry_repo::String, plugin_repo::String, plugin_rev::String)
	function _resolve_subdir(path::String)
		candidates = String[
			path,
			startswith(path, "plugins/") ? path[9:end] : path,
			startswith(path, "fixture/") ? path[9:end] : path,
			startswith(path, "plugins/fixture/") ? path[17:end] : path,
		]
		for c in candidates
			rel = replace(normpath(c), '\\' => '/')
			abs = joinpath(plugin_repo, split(rel, '/')...)
			ispath(abs) && return rel
		end
		replace(normpath(path), '\\' => '/')
	end

	registry_file = joinpath(registry_repo, "Registry.toml")
	registry = TOML.parsefile(registry_file)
	for relpath in values(registry["packages"])
		meta_path = joinpath(registry_repo, relpath * ".toml")
		meta = TOML.parsefile(meta_path)
		versions = get(meta, "versions", Dict{String, Any}())
		for (_, entry_any) in versions
			entry = entry_any::Dict{String, Any}
			subdir = get(entry, "path", get(entry, "subdir", nothing))
			subdir isa String || error("Missing path/subdir in $meta_path")
			subdir = _resolve_subdir(subdir)
			pop!(entry, "path", nothing)
			entry["url"] = plugin_repo
			entry["rev"] = plugin_rev
			entry["subdir"] = subdir
		end
		open(meta_path, "w") do io
			TOML.print(io, meta; sorted = true)
		end
	end
	nothing
end

function setup_fixture_registry_repo(; message::String = "fixture")
	roots = fixture_roots()
	registry_repo = setup_git_repo_from(roots.registry; message = message * "-registry")
	plugin_repo = setup_git_repo_from(roots.plugins; message = message * "-plugins")
	plugin_rev = git_head(plugin_repo)
	_rewrite_registry_to_remote_plugins!(registry_repo, plugin_repo, plugin_rev)
	git_commit_all!(registry_repo; message = message * "-registry-remote-links")

	(registry = registry_repo, plugins = plugin_repo)
end

function capture_error(f::Function)
	try
		f()
		return nothing
	catch e
		return sprint(showerror, e)
	end
end

function with_fixture_registry(f::Function; message::String = "fixture")
	roots = setup_fixture_registry_repo(message = message)
	registry_repo = roots.registry
	plugin_repo = roots.plugins
	registry_root = PluginSystem.Registry.GLOBAL_REGISTRY_DIR

	function _clear_registry_checkouts()
		isdir(registry_root) || return nothing
		for entry in readdir(registry_root; join = true)
			for attempt in 1:5
				try
					rm(entry; recursive = true, force = true)
					break
				catch
					attempt == 5 || sleep(0.05 * attempt)
				end
			end
		end
		nothing
	end

	PluginSystem.Registry.remove("FixtureGeneral")
	_clear_registry_checkouts()
	PluginSystem.Registry.add(registry_repo)
	try
		f(registry_repo)
	finally
		PluginSystem.Registry.remove("FixtureGeneral")
		_clear_registry_checkouts()
		rm(registry_repo; recursive = true, force = true)
		rm(plugin_repo; recursive = true, force = true)
	end
	nothing
end

function with_temp_project(f::Function)
	mktempdir() do project
		cd(project) do
			f(project)
		end
	end
	nothing
end

function with_registry(f::Function, name::String, repo::String)
	PluginSystem.Registry.remove(name)
	PluginSystem.Registry.add(repo)
	try
		f()
	finally
		PluginSystem.Registry.remove(name)
	end
	nothing
end

function write_plugin_module(path::String, name::String, version::String; deps::Vector{String} = String[])
	mkpath(dirname(path))
	dep_list = join(["\"$d\"" for d in deps], ", ")
	write(path, """
	\"\"\"
	version = "$version"
	deps = [$dep_list]
	\"\"\"
	module $name
	end
	""")
	path
end
