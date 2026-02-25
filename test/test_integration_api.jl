using TOML: parsefile

@testset "Integration: API with deps list and project plugins" begin
	with_fixture_registry(message = "api-fixture") do _
		with_temp_project() do project
				out = IOBuffer()
				result = PluginSystem.add("TPluginB"; io = out)
				add_text = String(take!(out))
				project_cfg = parsefile(joinpath(project, "Plugins.toml"))
				@test get(project_cfg, "deps", String[]) == ["TPluginB"]
				@test any(p -> p.name == "TPluginB" && p.namespace == "fixture", result.installed)
				@test any(p -> p.name == "TPluginA" && p.namespace == "fixture", result.installed)
				@test occursin("[plugin] ADD", add_text)
				@test occursin("plugin delta", add_text)
				@test occursin("+ TPluginA v1.1.0 [fixture]", add_text)
				@test occursin("+ TPluginB v1.0.0 [fixture]", add_text)

				manifest_path = joinpath(project, ".julia_plugins", "Plugins.toml")
				manifest = parsefile(manifest_path)
				names = Set(p["name"] for p in get(manifest, "plugins", []))
				@test names == Set(["TPluginA", "TPluginB"])
				a = only(filter(p -> p["name"] == "TPluginA", manifest["plugins"]))
				b = only(filter(p -> p["name"] == "TPluginB", manifest["plugins"]))
				@test a["path"] == joinpath("fixture", "TPluginA", "TPluginA.jl")
				@test b["path"] == joinpath("fixture", "TPluginB", "TPluginB.jl")
				@test a["namespace"] == "fixture"
				@test b["namespace"] == "fixture"

				status_data = PluginSystem.status()
				st_b = only(filter(x -> x.name == "TPluginB", status_data))
				@test st_b.namespace == "fixture"

				PluginSystem.pin("TPluginB")
				manifest = parsefile(manifest_path)
				b = only(filter(p -> p["name"] == "TPluginB", manifest["plugins"]))
				@test get(b, "pinned", false) == true

				PluginSystem.free("TPluginB")
				manifest = parsefile(manifest_path)
				b = only(filter(p -> p["name"] == "TPluginB", manifest["plugins"]))
				@test !haskey(b, "pinned")

				out = IOBuffer()
				PluginSystem.remove("TPluginB"; io = out)
				remove_text = String(take!(out))
				@test occursin("[plugin] REMOVE", remove_text)
				@test occursin("plugin delta", remove_text)
				@test occursin("- TPluginA v1.1.0", remove_text)
				@test occursin("- TPluginB v1.0.0", remove_text)
				project_cfg = parsefile(joinpath(project, "Plugins.toml"))
				@test isempty(get(project_cfg, "deps", String[]))
		end
	end
end

@testset "Integration: free releases dev source and falls back to registry" begin
	with_fixture_registry(message = "api-free-dev") do _
		with_temp_project() do project
			dev_root = mktempdir()
			dev_plugin = joinpath(dev_root, "TPluginB")
			try
				write_plugin_module(joinpath(dev_plugin, "TPluginB.jl"), "TPluginB", "9.9.0")
				PluginSystem.dev(dev_plugin; force = true)
				global_dev_path = joinpath(PluginSystem.GLOBAL_DEV_PLUGINS_DIR, "TPluginB")
				@test isdir(global_dev_path)

				add_res = PluginSystem.add("TPluginB")
				@test any(p -> p.name == "TPluginB" && p.namespace == "global" && p.version == "9.9.0", add_res.installed)

				manifest_path = joinpath(project, ".julia_plugins", "Plugins.toml")
				manifest = parsefile(manifest_path)
				dev_entry = only(filter(p -> p["name"] == "TPluginB", manifest["plugins"]))
				@test dev_entry["namespace"] == "global"
				@test dev_entry["version"] == "9.9.0"

				out = IOBuffer()
				free_res = PluginSystem.free("TPluginB"; io = out)
				free_text = String(take!(out))
				@test free_res.action == "free"
				@test "TPluginB" in free_res.undeveloped
				@test occursin("[plugin] FREE", free_text)
				@test occursin("released dev source: TPluginB", free_text)
				@test !isdir(global_dev_path)

				manifest = parsefile(manifest_path)
				reg_entry = only(filter(p -> p["name"] == "TPluginB", manifest["plugins"]))
				@test reg_entry["namespace"] == "fixture"
				@test reg_entry["version"] == "1.0.0"
			finally
				rm(dev_root; recursive = true, force = true)
				rm(joinpath(PluginSystem.GLOBAL_DEV_PLUGINS_DIR, "TPluginB"); recursive = true, force = true)
			end
		end
	end
end

@testset "Integration: project plugin overrides global plugin" begin
	with_temp_project() do project
		write_plugin_module(joinpath(project, "plugins", "LocalOnly", "LocalOnly.jl"), "LocalOnly", "0.2.0")

		result = PluginSystem.add("LocalOnly")
		manifest = parsefile(joinpath(project, ".julia_plugins", "Plugins.toml"))
		p = only(filter(x -> x["name"] == "LocalOnly", manifest["plugins"]))
		@test p["version"] == "0.2.0"
		@test p["namespace"] == "project"
		@test p["path"] == joinpath("project", "LocalOnly", "LocalOnly.jl")
		@test any(x -> x.name == "LocalOnly" && x.namespace == "project", result.installed)
	end
end
