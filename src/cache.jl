module Cache

using ..Download: delete_git_cache!, list_git_cache
using ..UI

public CacheSpec, remove, status

Base.@kwdef struct CacheSpec
	url::Union{Nothing, String} = nothing
	key::Union{Nothing, String} = nothing
	all::Bool = false
end

function _validate_selector(spec::CacheSpec)
	spec.all && (spec.url !== nothing || spec.key !== nothing) &&
		error("`all=true` cannot be combined with `url` or `key`.")
	spec.url !== nothing && spec.key !== nothing &&
		error("Specify either `url` or `key`, not both.")
	!spec.all && spec.url === nothing && spec.key === nothing &&
		error("Specify `url`, `key`, or set `all=true`.")
	nothing
end

"""
    status(; io=nothing)

List cached git sparse snapshots.
Each item includes `url`, `key`, `size_bytes`, and `mtime`.
"""
function status(; io::Union{Nothing, IO} = nothing)
	entries = list_git_cache()
	if io !== nothing
		UI.header(io, "cache", "status")
		if isempty(entries)
			UI.change(io, :none, "no cache entries found")
			return entries
		end
		for entry in entries
			key = string(entry.key)
			short = length(key) >= 8 ? key[1:8] : key
			url = entry.url === nothing ? "<unknown>" : string(entry.url)
			printstyled(io, "  [$(short)]"; color = :light_black, bold = true)
			printstyled(io, " $(url) ($(entry.size_bytes) bytes)", bold = true)
			println(io)
		end
		UI.summary(io, "cache entries: $(length(entries))"; level = :info)
	end
	entries
end

"""
    remove(specs...; io=nothing)
    remove(; url=nothing, key=nothing, all=false, io=nothing)

Remove cache entries selected by URL, snapshot key, or all entries.
Returns `(action = "cache-remove", removed = N)`.
"""
function remove(specs::CacheSpec...; io::Union{Nothing, IO} = nothing)
	isempty(specs) && error("No cache selector specified.")
	count(s -> s.all, specs) > 1 && error("`all=true` selector can only be used once.")
	any(s -> s.all, specs) && length(specs) > 1 && error("`all=true` cannot be combined with other selectors.")

	UI.header(io, "cache", "remove")
	UI.step(io, "deleting selected cache entries")
	removed = 0
	for spec in specs
		_validate_selector(spec)
		removed += delete_git_cache!(url = spec.url, key = spec.key, all = spec.all)
	end

	UI.summary(io, removed == 0 ? "no cache changes" : "removed $(removed) cache entr$(removed == 1 ? "y" : "ies")"; level = removed == 0 ? :info : :ok)
	(action = "cache-remove", removed = removed)
end

function remove(; url::Union{Nothing, String} = nothing, key::Union{Nothing, String} = nothing, all::Bool = false, io::Union{Nothing, IO} = nothing)
	remove(CacheSpec(url = url, key = key, all = all); io = io)
end

end#= module Cache =#
