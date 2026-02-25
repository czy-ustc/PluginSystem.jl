using Test
using PluginSystem

const _SCRATCH_ROOT = dirname(PluginSystem.GLOBAL_PLUGINS_DIR)
const _UNIT_TESTS = [
	"test_utils.jl",
	"test_scaffold.jl",
	"test_download.jl",
	"test_resolve.jl",
	"test_registry.jl",
	"test_docs_layout.jl",
]
const _INTEGRATION_TESTS = [
	"test_integration_git.jl",
	"test_integration_api.jl",
	"test_api_workspace.jl",
	"test_integration_namespaces.jl",
	"test_integration_resolve_edges.jl",
	"test_integration_fixture_matrix.jl",
	"test_integration_dev_publish.jl",
	"test_integration_publish_workflow.jl",
	"test_integration_workflow.jl",
]
const _INTERFACE_TESTS = [
	"test_cli.jl",
	"test_app.jl",
	"test_load.jl",
]

function _copy_tree(src::AbstractString, dst::AbstractString)
	isdir(src) || return
	mkpath(dst)
	for (root, dirs, files) in walkdir(src)
		rel = relpath(root, src)
		dst_root = rel == "." ? dst : joinpath(dst, rel)
		mkpath(dst_root)
		for dir in dirs
			mkpath(joinpath(dst_root, dir))
		end
		for file in files
			src_file = joinpath(root, file)
			dst_file = joinpath(dst_root, file)
			for attempt in 1:5
				try
					cp(src_file, dst_file; force = true)
					break
				catch
					attempt == 5 || sleep(0.05 * attempt)
				end
			end
		end
	end
end

function _rm_tree_retry(path::AbstractString; retries::Int = 10)
	for attempt in 1:retries
		try
			rm(path; recursive = true, force = true)
			return nothing
		catch
			attempt == retries || sleep(0.05 * attempt)
		end
	end
	try
		rm(path; recursive = true, force = true, allow_delayed_delete = true)
	catch
	end
	nothing
end

scratch_existed_before = isdir(_SCRATCH_ROOT)
scratch_backup = mktempdir()
scratch_existed_before && _copy_tree(_SCRATCH_ROOT, scratch_backup)

try
	include("test_helpers.jl")
	@testset "Unit Tests" begin
		for file in _UNIT_TESTS
			include(file)
		end
	end
	@testset "Integration Tests" begin
		for file in _INTEGRATION_TESTS
			include(file)
		end
	end
	@testset "Interface Tests" begin
		for file in _INTERFACE_TESTS
			include(file)
		end
	end
finally
	if scratch_existed_before
		isdir(_SCRATCH_ROOT) || mkpath(_SCRATCH_ROOT)
		for entry in readdir(_SCRATCH_ROOT; join = true)
			_rm_tree_retry(entry)
		end
		_copy_tree(scratch_backup, _SCRATCH_ROOT)
	else
		isdir(_SCRATCH_ROOT) && _rm_tree_retry(_SCRATCH_ROOT)
	end
	_rm_tree_retry(scratch_backup)
end
