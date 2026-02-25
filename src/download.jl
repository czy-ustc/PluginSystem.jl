module Download

using ..PluginSystem: GLOBAL_PLUGINS_DIR, RemotePluginInfo
using ..Utils: is_hex_object_id, with_repo
using Preferences: load_preference, set_preferences!
using Scratch: @get_scratch!
using LibGit2
using SHA: sha1

export set_auth!

const GIT_CACHE_DIR = @get_scratch!("git_cache")
const CACHE_URL_FILE = ".pluginsystem_cache_meta"

function _get_url_host(url::String)
	m = match(r"^[a-zA-Z]+://([^/]+)/", url)
	if m !== nothing
		return lowercase(m.captures[1])
	end
	m = match(r"^[^@]+@([^:]+):", url)
	if m !== nothing
		return lowercase(m.captures[1])
	end
	nothing
end

function _looks_remote_source(source::AbstractString)
	s = strip(source)
	isempty(s) && return false
	occursin("://", s) && return true
	m = match(r"^[^@]+@[^:]+:.*$", s)
	m !== nothing
end

function _normalize_local_source(source::AbstractString)
	p = normpath(abspath(strip(source)))
	p = replace(p, '\\' => '/')
	Sys.iswindows() ? lowercase(p) : p
end

function _normalize_cache_source(source::AbstractString)
	_looks_remote_source(source) ? lowercase(strip(source)) : _normalize_local_source(source)
end

function _cache_key(url::String)
	source = _normalize_cache_source(url)
	bytes2hex(sha1(source))
end

_cache_path(url::String) = joinpath(GIT_CACHE_DIR, _cache_key(url))

function _dir_size(path::String)
	total = Int64(0)
	for (root, _, files) in walkdir(path)
		for file in files
			total += filesize(joinpath(root, file))
		end
	end
	total
end

function _cache_url(path::String)
	meta = joinpath(path, CACHE_URL_FILE)
	isfile(meta) || return nothing
	strip(read(meta, String))
end

function _credentials_for_url(url::String)
	host = _get_url_host(url)
	host === nothing && return nothing

	auths = load_preference("PluginSystem", "git_auth")
	auths === nothing && return nothing
	info = get(auths, host, nothing)
	info === nothing && return nothing
	username = get(info, "username", "")
	password = get(info, "password", "")
	LibGit2.UserPasswordCredential(username, password)
end

function _ensure_cache_repo(url::String)
	cache_path = _cache_path(url)
	mkpath(dirname(cache_path))
	credentials = _credentials_for_url(url)

	if isdir(cache_path)
		with_repo(cache_path) do repo
			LibGit2.fetch(repo; credentials = credentials)
		end
	else
		LibGit2.clone(url, cache_path; isbare = true, credentials = credentials)
	end
	write(joinpath(cache_path, CACHE_URL_FILE), url)

	cache_path
end

function _normalize_git_subpath(subpath::Union{Nothing, String})
	subpath === nothing && return ""
	clean = strip(subpath)
	if isempty(clean) || clean == "."
		return ""
	end

	parts = filter(!isempty, split(replace(clean, '\\' => '/'), '/'))
	any(part -> part == "..", parts) && error("Invalid plugin path `$subpath`: escapes repository root.")
	join(parts, '/')
end

function _glob_to_regex(pattern::String)
	io = IOBuffer()
	write(io, '^')
	i = firstindex(pattern)
	while i <= lastindex(pattern)
		c = pattern[i]
		if c == '*'
			if i < lastindex(pattern) && pattern[nextind(pattern, i)] == '*'
				write(io, ".*")
				i = nextind(pattern, i)
			else
				write(io, "[^/]*")
			end
		elseif c == '?'
			write(io, "[^/]")
		elseif c in ('.', '+', '(', ')', '[', ']', '{', '}', '^', '$', '|', '\\')
			write(io, '\\')
			write(io, c)
		else
			write(io, c)
		end
		i = nextind(pattern, i)
	end
	write(io, '$')
	Regex(String(take!(io)))
end

function _load_gitignore_rules(src::String)
	# Parse all .gitignore files from exported tree and preserve rule order.
	rules = NamedTuple[]
	for (root, dirs, files) in walkdir(src)
		filter!(d -> d != ".git", dirs)
		".gitignore" in files || continue
		base_rel = replace(relpath(root, src), '\\' => '/')
		base_rel == "." && (base_rel = "")
		for raw in eachline(joinpath(root, ".gitignore"))
			line = strip(raw)
			isempty(line) && continue
			startswith(line, "#") && continue
			negated = startswith(line, "!")
			negated && (line = line[2:end])
			line = strip(line)
			isempty(line) && continue
			dir_only = endswith(line, "/")
			dir_only && (line = rstrip(line, '/'))
			anchored = startswith(line, "/")
			anchored && (line = line[2:end])
			pattern = replace(line, '\\' => '/')
			isempty(pattern) && continue
			push!(rules, (base_rel = base_rel, pattern = pattern, regex = _glob_to_regex(pattern), negated = negated, dir_only = dir_only, anchored = anchored))
		end
	end
	rules
end

function _match_ignore_rule(rule, relpath::String, is_dir::Bool)
	rule.dir_only && !is_dir && return false
	base_rel = rule.base_rel
	base_rel_full = isempty(base_rel) ? "" : string(base_rel, '/')
	if !isempty(base_rel_full)
		startswith(relpath, base_rel_full) || return false
	end
	rel_from_base = isempty(base_rel_full) ? relpath : relpath[(lastindex(base_rel_full)+1):end]
	rel_from_base = startswith(rel_from_base, "/") ? rel_from_base[2:end] : rel_from_base
	isempty(rel_from_base) && return false

	candidates = String[rel_from_base]
	if !rule.anchored
		parts = split(rel_from_base, '/')
		for i in 2:length(parts)
			push!(candidates, join(parts[i:end], '/'))
		end
		if !occursin('/', rule.pattern)
			push!(candidates, basename(rel_from_base))
		end
	end
	any(c -> occursin(rule.regex, c), candidates)
end

function _is_ignored(relpath::String, is_dir::Bool, rules)
	# Gitignore semantics: the last matching rule wins.
	ignored = false
	for rule in rules
		if _match_ignore_rule(rule, relpath, is_dir)
			ignored = !rule.negated
		end
	end
	ignored
end

function _is_special_name(name::String)
	name == ".git" || startswith(name, ".git")
end

function _should_copy_entry(rel::String, name::String, is_dir::Bool, rules)
	_is_special_name(name) && return false
	rel_path = isempty(rel) ? name : string(rel, '/', name)
	!_is_ignored(rel_path, is_dir, rules)
end

function _replace_path(path::String)
	path = replace(path, '\\' => '/')
	path == "." ? "" : path
end

function _copy_tree(src::String, dest::String)
	rules = _load_gitignore_rules(src)
	for (root, dirs, files) in walkdir(src)
		rel = _replace_path(relpath(root, src))
		filter!(d -> _should_copy_entry(rel, d, true, rules), dirs)
		target_root = isempty(rel) ? dest : joinpath(dest, rel)
		mkpath(target_root)
		for file in files
			_should_copy_entry(rel, file, false, rules) || continue
			cp(joinpath(root, file), joinpath(target_root, file); force = true)
		end
	end
end

function _write_blob(blob::LibGit2.GitBlob, path::String)
	mkpath(dirname(path))
	open(path, "w") do io
		write(io, LibGit2.rawcontent(blob))
	end
end

function _export_tree(tree::LibGit2.GitTree, dest::String)
	mkpath(dest)
	for i in 1:LibGit2.count(tree)
		entry = tree[i]
		name = LibGit2.filename(entry)
		obj = LibGit2.GitObject(entry)
		try
			if obj isa LibGit2.GitBlob
				_write_blob(obj, joinpath(dest, name))
			elseif obj isa LibGit2.GitTree
				_export_tree(obj, joinpath(dest, name))
			end
		finally
			close(obj)
		end
	end
end

function _resolve_rev(repo::LibGit2.GitRepo, rev::Union{Nothing, String})
	candidates = if rev === nothing || isempty(strip(rev))
		["HEAD", "refs/remotes/origin/HEAD", "refs/remotes/origin/main", "refs/remotes/origin/master"]
	else
		[strip(rev)]
	end
	for candidate in candidates
		try
			return string(LibGit2.revparseid(repo, candidate))
		catch
		end
	end
	error("Cannot resolve git revision: $(rev === nothing ? "default branch" : rev)")
end

function _ensure_sparse_path_cache(cache_path::String, rev::Union{Nothing, String}, subdir::Union{Nothing, String})
	with_repo(cache_path) do repo
		rev_oid = _resolve_rev(repo, rev)
		subpath = _normalize_git_subpath(subdir)
		root_tree = LibGit2.GitTree(repo, "$rev_oid^{tree}")
		try
			obj = isempty(subpath) ? root_tree : root_tree[subpath]
			try
				# Use git object id as cache identifier (tree-sha1 for directories).
				export_key = string(LibGit2.GitHash(obj))
				export_dir = joinpath(cache_path, "sparse", export_key)
				isdir(export_dir) && return export_dir

				mkpath(dirname(export_dir))
				tmp_dir = mktempdir(dirname(export_dir))
				try
					if obj isa LibGit2.GitBlob
						name = basename(subpath)
						isempty(name) && error("Invalid file path `$subdir`.")
						_write_blob(obj, joinpath(tmp_dir, name))
					elseif obj isa LibGit2.GitTree
						_export_tree(obj, tmp_dir)
					else
						error("Unsupported git object at path `$subdir`.")
					end
					mv(tmp_dir, export_dir)
				catch
					ispath(tmp_dir) && rm(tmp_dir; recursive = true, force = true)
					rethrow()
				end
				return export_dir
			finally
				obj === root_tree || close(obj)
			end
		finally
			close(root_tree)
		end
	end
end

function download(
	repo_url::String,
	rev::Union{Nothing, String},
	subdir::Union{Nothing, String},
	dest::String;
	force::Bool = false,
)
	# Download path snapshot from cache into destination directory.
	cache_path = _ensure_cache_repo(repo_url)
	export_dir = _ensure_sparse_path_cache(cache_path, rev, subdir)
	if force && ispath(dest)
		rm(dest; recursive = true, force = true)
	end
	mkpath(dest)
	_copy_tree(export_dir, dest)

	dest
end

function download(plugin::RemotePluginInfo)
	target_dir = joinpath(
		GLOBAL_PLUGINS_DIR,
		split(plugin.namespace)...,
		plugin.name,
		string(plugin.version),
	)
	download(
		plugin.url,
		plugin.rev,
		plugin.subdir,
		target_dir,
		force = true,
	)
end

"""
    set_auth!(host; username="", password="", token=nothing)

Configure git credentials for a host (stored in Preferences under `PluginSystem.git_auth`).
"""
function set_auth!(host::String; username::String = "", password::String = "", token::Union{Nothing, String} = nothing)
	# Store per-host credentials in Preferences so clone/fetch can authenticate automatically.
	host_key = lowercase(strip(host))
	isempty(host_key) && error("Host must not be empty.")

	if token !== nothing
		password = token
		isempty(username) && (username = "oauth2")
	end
	isempty(password) && error("Either `token` or `password` must be provided.")

	auths_raw = load_preference("PluginSystem", "git_auth")
	auths = auths_raw === nothing ? Dict{String, Any}() : Dict{String, Any}(auths_raw)
	auths[host_key] = Dict("username" => username, "password" => password)
	set_preferences!("PluginSystem", "git_auth" => auths; force = true)
end

function list_git_cache()
	isdir(GIT_CACHE_DIR) || return NamedTuple[]
	entries = NamedTuple[]
	for repo_cache in readdir(GIT_CACHE_DIR; join = true)
		isdir(repo_cache) || continue
		repo_key = basename(repo_cache)
		is_hex_object_id(repo_key) || continue

		sparse_dir = joinpath(repo_cache, "sparse")
		isdir(sparse_dir) || continue

		for item in readdir(sparse_dir; join = true)
			isdir(item) || continue
			name = basename(item)
			is_hex_object_id(name) || continue

			stat = lstat(item)
			push!(
				entries,
				(
					url = _cache_url(repo_cache),
					key = name,
					size_bytes = _dir_size(item),
					mtime = stat.mtime,
				),
			)
		end
	end
	sort(entries; by = x -> x.mtime, rev = true)
end

function delete_git_cache!(; url::Union{Nothing, String} = nothing, key::Union{Nothing, String} = nothing, all::Bool = false)
	if all
		isdir(GIT_CACHE_DIR) || return 0
		count = 0
		for item in readdir(GIT_CACHE_DIR; join = true)
			isdir(item) || continue
			rm(item; recursive = true, force = true)
			count += 1
		end
		return count
	end

	url !== nothing && key !== nothing && error("Specify either `url` or `key`, not both.")
	if url !== nothing
		target = _cache_path(url)
		isdir(target) || return 0
		rm(target; recursive = true, force = true)
		return 1
	elseif key !== nothing
		isdir(GIT_CACHE_DIR) || return 0
		count = 0
		for repo_cache in readdir(GIT_CACHE_DIR; join = true)
			target = joinpath(repo_cache, "sparse", key)
			isdir(target) || continue
			rm(target; recursive = true, force = true)
			count += 1
			# Prune empty cache repository directories after removing sparse snapshot.
			sparse_dir = joinpath(repo_cache, "sparse")
			if !isdir(sparse_dir) || isempty(readdir(sparse_dir))
				rm(repo_cache; recursive = true, force = true)
			end
		end
		return count
	else
		error("Specify `url`, `key`, or set `all=true`.")
	end
end

end#= module Download =#
