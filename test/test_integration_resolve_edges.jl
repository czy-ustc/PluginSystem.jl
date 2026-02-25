using TOML: parsefile

function _edge_write_plugin(path::String, name::String)
	mkpath(dirname(path))
	write(path, """
	module $name
	end
	""")
end

function _edge_setup_registry_repo()
	repo = mktempdir()
	mkpath(joinpath(repo, "edge"))

	# Registry index.
	write(joinpath(repo, "Registry.toml"), """
	name = "EdgeFixtureGeneral"
	version = "1.0"
	repo = "file:///local/EdgeFixtureGeneral"

	[packages]
	EdgeA = "edge/EdgeA"
	EdgeB = "edge/EdgeB"
	EdgeEmpty = "edge/EdgeEmpty"
	""")

	# EdgeA has two major versions.
	write(joinpath(repo, "edge", "EdgeA.toml"), """
	name = "EdgeA"
	module_name = "EdgeA"
	namespace = "edge"

	[versions]
	"1.0.0" = { path = "edge/EdgeA/1.0.0" }
	"2.0.0" = { path = "edge/EdgeA/2.0.0" }

	[deps]

	[compat]
	""")
	_edge_write_plugin(joinpath(repo, "edge", "EdgeA", "1.0.0", "EdgeA.jl"), "EdgeA")
	_edge_write_plugin(joinpath(repo, "edge", "EdgeA", "2.0.0", "EdgeA.jl"), "EdgeA")

	# EdgeB requires EdgeA major 1.
	write(joinpath(repo, "edge", "EdgeB.toml"), """
	name = "EdgeB"
	module_name = "EdgeB"
	namespace = "edge"

	[versions]
	"1.0.0" = { path = "edge/EdgeB/1.0.0" }

	[deps]
	"1" = ["EdgeA"]

	[compat]
	"1" = { EdgeA = "1" }
	""")
	_edge_write_plugin(joinpath(repo, "edge", "EdgeB", "1.0.0", "EdgeB.jl"), "EdgeB")

	# EdgeEmpty has metadata but no published versions.
	write(joinpath(repo, "edge", "EdgeEmpty.toml"), """
	name = "EdgeEmpty"
	module_name = "EdgeEmpty"
	namespace = "edge"

	[versions]

	[deps]

	[compat]
	""")

	git_init_repo!(repo)
	git_commit_all!(repo; message = "edge-fixture")
	repo
end

function _edge_setup_broken_registry_repo()
	repo = mktempdir()
	mkpath(joinpath(repo, "edge"))
	write(joinpath(repo, "Registry.toml"), """
	name = "EdgeBrokenFixture"
	version = "1.0"
	repo = "file:///local/EdgeBrokenFixture"

	[packages]
	EdgeBrokenDep = "edge/EdgeBrokenDep"
	""")
	write(joinpath(repo, "edge", "EdgeBrokenDep.toml"), """
	name = "EdgeBrokenDep"
	module_name = "EdgeBrokenDep"
	namespace = "edge"

	[versions]
	"1.0.0" = { path = "edge/EdgeBrokenDep/1.0.0" }

	[deps]
	"1" = ["NoSuchDep"]

	[compat]
	"1" = { NoSuchDep = "1" }
	""")
	_edge_write_plugin(joinpath(repo, "edge", "EdgeBrokenDep", "1.0.0", "EdgeBrokenDep.jl"), "EdgeBrokenDep")
	git_init_repo!(repo)
	git_commit_all!(repo; message = "edge-broken-fixture")
	repo
end

function _assert_resolve_error(msg::String, plugin_name::String)
	lower = lowercase(msg)
	@test occursin(lowercase(plugin_name), lower)
	@test occursin("unsatisf", lower) || occursin("resolve", lower) || occursin("version", lower) || occursin("satisf", lower)
end

@testset "Integration: resolve version edge cases" begin
	registry_repo = _edge_setup_registry_repo()
	try
		with_registry("EdgeFixtureGeneral", registry_repo) do
			@testset "solvable constraint picks compatible version" begin
				with_temp_project() do _
					result = PluginSystem.add("EdgeB")
					@test any(p -> p.name == "EdgeB" && p.version == "1.0.0", result.installed)
					@test any(p -> p.name == "EdgeA" && p.version == "1.0.0", result.installed)
				end
			end

			@testset "explicit major selection works when solvable" begin
				with_temp_project() do _
					result = PluginSystem.add("EdgeA@2")
					@test any(p -> p.name == "EdgeA" && p.version == "2.0.0", result.installed)
				end
			end

			@testset "unsatisfiable conflict between direct and transitive constraints" begin
				with_temp_project() do _
					PluginSystem.add("EdgeB")
					msg = capture_error(() -> PluginSystem.add("EdgeA@2"))
					@test msg !== nothing
					_assert_resolve_error(msg, "EdgeA")
				end
			end

			@testset "requesting non-existent version is unsatisfiable" begin
				with_temp_project() do _
					msg = capture_error(() -> PluginSystem.add("EdgeA@3"))
					@test msg !== nothing
					_assert_resolve_error(msg, "EdgeA")
				end
			end

			@testset "missing dependency in registry metadata" begin
				broken_repo = _edge_setup_broken_registry_repo()
				try
					with_registry("EdgeBrokenFixture", broken_repo) do
						with_temp_project() do _
							msg = capture_error(() -> PluginSystem.add("EdgeBrokenDep"))
							@test msg !== nothing
							@test occursin("Missing dependency", msg)
							@test occursin("NoSuchDep", msg)
						end
					end
				finally
					rm(broken_repo; recursive = true, force = true)
				end
			end

			@testset "plugin not found in registries" begin
				with_temp_project() do _
					msg = capture_error(() -> PluginSystem.add("DefinitelyNotExists"))
					@test msg !== nothing
					@test occursin("not found", lowercase(msg))
				end
			end

			@testset "plugin with no published versions is unsatisfiable" begin
				with_temp_project() do _
					msg = capture_error(() -> PluginSystem.add("EdgeEmpty"))
					@test msg !== nothing
					_assert_resolve_error(msg, "EdgeEmpty")
				end
			end

			@testset "invalid deps format in Plugins.toml" begin
				with_temp_project() do _
					write("Plugins.toml", "deps = \"EdgeA\"\n")
					msg = capture_error(() -> PluginSystem.instantiate())
					@test msg !== nothing
					@test occursin("deps", lowercase(msg))
					@test occursin("list", lowercase(msg))
				end
			end
		end
	finally
		rm(registry_repo; recursive = true, force = true)
	end
end
