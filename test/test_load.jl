using Random: randstring

@testset "@load_plugins" begin
	with_fixture_registry(message = "load-fixture") do _
		@testset "load installed plugin modules" begin
			mktempdir() do project
				cd(project) do
					PluginSystem.add("TPluginB")

					mod_name = "LoadCase_" * randstring(8)
					script = joinpath(project, "load_case.jl")
					write(script, """
					module $mod_name
					using PluginSystem
					@load_plugins
					const HAS_A = isdefined(@__MODULE__, :TPluginA)
					const HAS_B = isdefined(@__MODULE__, :TPluginB)
					const A_VERSION = TPluginA.VERSION
					const B_VERSION = TPluginB.VERSION
					const AFTER_LOAD = PluginSystem.load_plugins!(@__MODULE__; base_dir = $(repr(project)))
					const SKIPPED_AFTER = Set(AFTER_LOAD.skipped)
					end
					""")

					Base.include(Main, script)
					m = Base.invokelatest(getfield, Main, Symbol(mod_name))
					@test Base.invokelatest(getproperty, m, :HAS_A)
					@test Base.invokelatest(getproperty, m, :HAS_B)
					@test Base.invokelatest(getproperty, m, :B_VERSION) == v"1.0.0"
					@test Base.invokelatest(getproperty, m, :A_VERSION) == v"1.1.0"
					@test Base.invokelatest(getproperty, m, :SKIPPED_AFTER) == Set(["TPluginA", "TPluginB"])
				end
			end
		end

		@testset "macro emits static include/using for installed manifest" begin
			mktempdir() do project
				src_dir = joinpath(project, "src")
				mkpath(src_dir)
				script = joinpath(src_dir, "Host.jl")
				write(script, "module Host\nend\n")

				plugin_dir = joinpath(project, ".julia_plugins", "project", "StaticOnly")
				mkpath(plugin_dir)
				plugin_file = joinpath(plugin_dir, "StaticOnly.jl")
				write(
					plugin_file,
					"""
					\"\"\"
					version = "0.1.0"
					deps = []
					\"\"\"
					module StaticOnly
					const VALUE = 42
					end
					""",
				)
				write(
					joinpath(project, ".julia_plugins", "Plugins.toml"),
					"""
					[[plugins]]
					name = "StaticOnly"
					version = "0.1.0"
					namespace = "project"
					path = "project/StaticOnly/StaticOnly.jl"
					""",
				)

				ex = Expr(:macrocall, Symbol("@load_plugins"), LineNumberNode(1, script))
				expanded = Base.invokelatest(macroexpand, PluginSystem, ex)
				expanded_text = sprint(show, expanded)
				normalize = s -> replace(replace(s, '\\' => '/'), r"/+" => "/")
				normalized = normalize(expanded_text)
				normalized_path = normalize(normpath(abspath(plugin_file)))

				@test occursin("Base.include", expanded_text)
				@test occursin("using .StaticOnly", expanded_text)
				@test occursin(normalized_path, normalized)
				@test !occursin("load_plugins!(", expanded_text)
			end
		end

		@testset "no manifest does not load plugin modules" begin
			mktempdir() do project
				mod_name = "LoadEmpty_" * randstring(8)
				script = joinpath(project, "load_empty.jl")
				write(script, """
				module $mod_name
				using PluginSystem
				@load_plugins
				const HAS_A = isdefined(@__MODULE__, :TPluginA)
				end
				""")

				Base.include(Main, script)
				m = Base.invokelatest(getfield, Main, Symbol(mod_name))
				@test !Base.invokelatest(getproperty, m, :HAS_A)
			end
		end

		@testset "load_plugins! supports explicit workspace and idempotent load" begin
			mktempdir() do project
				cd(project) do
					PluginSystem.add("TPluginB")
				end

				host = Module(Symbol("LoadHost_" * randstring(8)))
				first = PluginSystem.load_plugins!(host; base_dir = project)
				second = PluginSystem.load_plugins!(host; base_dir = project)

				@test Set(first.loaded) == Set(["TPluginA", "TPluginB"])
				@test isempty(first.skipped)
				@test isempty(second.loaded)
				@test Set(second.skipped) == Set(["TPluginA", "TPluginB"])
				@test first.workspace == project
				@test isdefined(host, :TPluginA)
				@test isdefined(host, :TPluginB)
			end
		end

		@testset "load_plugins! strict=false skips missing files" begin
			mktempdir() do project
				store = joinpath(project, ".julia_plugins")
				mkpath(store)
				write(
					joinpath(store, "Plugins.toml"),
					"""
					[[plugins]]
					name = "MissingDemo"
					version = "0.1.0"
					namespace = "project"
					path = "project/MissingDemo/MissingDemo.jl"
					""",
				)
				host = Module(Symbol("LoadSkip_" * randstring(8)))
				result = PluginSystem.load_plugins!(host; base_dir = project, strict = false)
				@test isempty(result.loaded)
				@test result.skipped == ["MissingDemo"]
			end
		end

		@testset "load_plugins! strict=true errors on missing files" begin
			mktempdir() do project
				store = joinpath(project, ".julia_plugins")
				mkpath(store)
				write(
					joinpath(store, "Plugins.toml"),
					"""
					[[plugins]]
					name = "MissingStrict"
					version = "0.1.0"
					namespace = "project"
					path = "project/MissingStrict/MissingStrict.jl"
					""",
				)
				host = Module(Symbol("LoadStrict_" * randstring(8)))
				@test_throws Exception PluginSystem.load_plugins!(host; base_dir = project, strict = true)
			end
		end
	end
end
