using TOML: parsefile
using Random: randstring

function _write_project_plugin(root::String, name::String, version::String)
	plugin_dir = joinpath(root, "plugins", name)
	mkpath(plugin_dir)
	write(joinpath(plugin_dir, "$name.jl"), """
	\"\"\"
	version = "$version"
	deps = []
	\"\"\"
	module $name
	end
	""")
end

function _manifest_plugins(project::String)
	parsefile(joinpath(project, ".julia_plugins", "Plugins.toml"))["plugins"]
end

@testset "Scenario: end-to-end project workflow" begin
	with_fixture_registry(message = "workflow-fixture") do _
		with_temp_project() do project
				# Step 1: initialize project dependencies from registry.
				add_result = PluginSystem.add("TPluginB")
				@test add_result.action == "add"
				@test any(p -> p.name == "TPluginB" && p.namespace == "fixture", add_result.installed)
				@test any(p -> p.name == "TPluginA" && p.namespace == "fixture", add_result.installed)

				# Step 2: inspect status (API data + human-readable output).
				out = IOBuffer()
				status_rows = PluginSystem.status(io = out)
				status_text = String(take!(out))
				@test occursin("[plugin] STATUS", status_text)
				@test occursin("TPluginB", status_text)
				@test any(r -> r.name == "TPluginB" && r.namespace == "fixture", status_rows)

				# Step 3: application side loads enabled plugins with @load_plugins.
				mod_name = "WorkflowApp_" * randstring(8)
				app_file = joinpath(project, "workflow_app.jl")
				write(app_file, """
				module $mod_name
				using PluginSystem
				@load_plugins
				const HAS_A = isdefined(@__MODULE__, :TPluginA)
				const HAS_B = isdefined(@__MODULE__, :TPluginB)
				const A_VERSION = TPluginA.VERSION
				const B_VERSION = TPluginB.VERSION
				const B_GREETING = TPluginB.greet("workflow")
				const B_SCORE = TPluginB.score(1)
				end
				""")
				Base.include(Main, app_file)
				m = Base.invokelatest(getfield, Main, Symbol(mod_name))
				@test Base.invokelatest(getproperty, m, :HAS_A)
				@test Base.invokelatest(getproperty, m, :HAS_B)
				@test Base.invokelatest(getproperty, m, :A_VERSION) == v"1.1.0"
				@test Base.invokelatest(getproperty, m, :B_VERSION) == v"1.0.0"
				@test occursin("A-1.1 says hello to workflow", Base.invokelatest(getproperty, m, :B_GREETING))
				@test Base.invokelatest(getproperty, m, :B_SCORE) == 112

				# Step 4: add a project-local plugin and verify namespace priority.
				_write_project_plugin(project, "LocalTool", "0.3.0")
				local_result = PluginSystem.add("LocalTool")
				@test any(p -> p.name == "LocalTool" && p.namespace == "project", local_result.installed)
				local_manifest = only(filter(p -> p["name"] == "LocalTool", _manifest_plugins(project)))
				@test local_manifest["path"] == joinpath("project", "LocalTool", "LocalTool.jl")
				@test local_manifest["namespace"] == "project"

				# Step 5: pin/free lifecycle for runtime stability controls.
				PluginSystem.pin("TPluginB")
				b = only(filter(p -> p["name"] == "TPluginB", _manifest_plugins(project)))
				@test get(b, "pinned", false)
				PluginSystem.free("TPluginB")
				b = only(filter(p -> p["name"] == "TPluginB", _manifest_plugins(project)))
				@test !haskey(b, "pinned")

				# Step 6: remove dependencies and return to a clean project state.
				PluginSystem.remove("LocalTool")
				PluginSystem.remove("TPluginB")
				project_cfg = parsefile(joinpath(project, "Plugins.toml"))
				@test isempty(get(project_cfg, "deps", String[]))
		end
	end
end
