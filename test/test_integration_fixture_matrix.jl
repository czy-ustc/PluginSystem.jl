function _assert_unsat_message(msg::String, plugin::String)
	lower = lowercase(msg)
	@test occursin(lowercase(plugin), lower)
	@test occursin("unsatisf", lower) || occursin("resolve", lower) || occursin("version", lower)
end

@testset "Integration: fixture dependency matrix" begin
	with_fixture_registry(message = "fixture-matrix") do _
		@testset "complex graph resolves to latest compatible set" begin
			with_temp_project() do _
					result = PluginSystem.add("TPluginE")
					got = Dict(p.name => p.version for p in result.installed)
					namespaces = Dict(p.name => p.namespace for p in result.installed)
					expected = Dict(
						"TPluginA" => "1.1.0",
						"TPluginB" => "1.0.0",
						"TPluginC" => "1.1.0",
						"TPluginD" => "1.0.0",
						"TPluginE" => "1.0.0",
						"TPluginG" => "1.0.0",
					)
					@test got == expected
					@test all(v -> v == "fixture", values(namespaces))

					host = Module(Symbol("FixtureMatrixHost"))
					load_result = PluginSystem.load_plugins!(host)
					@test "TPluginE" in load_result.loaded
					tplugin_e = Base.invokelatest(getproperty, host, :TPluginE)
					plan_fn = Base.invokelatest(getproperty, tplugin_e, :plan)
					plan = Base.invokelatest(plan_fn, 1, "matrix")
					@test occursin("A-1.1 says hello to matrix", plan.message)
					@test occursin("[G]", plan.message)
					@test plan.score == 144
			end
		end

		@testset "version-specific dependency branch works" begin
			with_temp_project() do _
					result = PluginSystem.add("TPluginC@1.0")
					@test any(p -> p.name == "TPluginC" && p.version == "1.0.0" && p.namespace == "fixture", result.installed)
					@test any(p -> p.name == "TPluginB" && p.version == "1.0.0" && p.namespace == "fixture", result.installed)
					@test any(p -> p.name == "TPluginA" && p.version == "1.1.0" && p.namespace == "fixture", result.installed)
					@test !any(p -> p.name == "TPluginG", result.installed)
			end
		end

		@testset "major selection propagates to transitive dependencies" begin
			with_temp_project() do _
					result = PluginSystem.add("TPluginD@2")
					@test any(p -> p.name == "TPluginD" && p.version == "2.0.0" && p.namespace == "fixture", result.installed)
					@test any(p -> p.name == "TPluginA" && p.version == "2.0.0" && p.namespace == "fixture", result.installed)
			end
		end

		@testset "cross-chain conflict is unsatisfiable" begin
			with_temp_project() do _
					PluginSystem.add("TPluginB")
					msg = capture_error(() -> PluginSystem.add("TPluginD@2"))
					@test msg !== nothing
					_assert_unsat_message(msg, "TPluginA")
			end
		end

		@testset "plugin with internally conflicting compat is unsatisfiable" begin
			with_temp_project() do _
					msg = capture_error(() -> PluginSystem.add("TPluginF"))
					@test msg !== nothing
					lower = lowercase(msg)
					@test occursin("unsatisf", lower) || occursin("resolve", lower) || occursin("version", lower)
					@test occursin("tpluginf", lower) || occursin("tplugina", lower) || occursin("tplugind", lower)
			end
		end
	end
end
