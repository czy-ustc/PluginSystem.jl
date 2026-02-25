using TOML: parsefile

@testset "Scaffold API" begin
	mktempdir() do root
		project_path = joinpath(root, "my-app")
		project_result = PluginSystem.scaffold_project(project_path)
		@test project_result.action == "generate-project"
		@test project_result.module_name == "MyApp"
		@test isfile(joinpath(project_path, "Plugins.toml"))
		@test isdir(joinpath(project_path, "plugins"))
		project_toml = parsefile(joinpath(project_path, "Plugins.toml"))
		@test isempty(get(project_toml, "deps", Any[]))
	end

	mktempdir() do root
		plugin_path = joinpath(root, "CoolTool")
		result = PluginSystem.scaffold_plugin(plugin_path; version = "1.2.3", deps = ["A", "B", "A"])
		@test result.action == "generate-plugin"
		@test result.layout == "directory"
		def = PluginSystem.Utils.parse_plugin_definition(plugin_path)
		@test def.name == "CoolTool"
		@test def.version == v"1.2.3"
		@test Set(def.deps) == Set(["A", "B"])

		result2 = PluginSystem.scaffold_plugin(plugin_path; version = "1.3.0", force = true)
		@test result2.version == "1.3.0"
		@test PluginSystem.Utils.parse_plugin_definition(plugin_path).version == v"1.3.0"
	end

	mktempdir() do root
		file_path = joinpath(root, "SinglePlugin.jl")
		result = PluginSystem.scaffold_plugin(file_path; as_file = true, deps = ["DepOne"])
		@test result.layout == "file"
		@test isfile(file_path)
		def = PluginSystem.Utils.parse_plugin_definition(file_path)
		@test def.name == "SinglePlugin"
		@test def.deps == ["DepOne"]
	end
end
