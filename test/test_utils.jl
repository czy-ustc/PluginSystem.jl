@testset "Utils" begin
	@test PluginSystem.Utils.project_plugins_toml("C:/tmp") == joinpath("C:/tmp", "Plugins.toml")
	@test PluginSystem.Utils.manifest_plugins_toml("C:/tmp") == joinpath("C:/tmp", ".julia_plugins", "Plugins.toml")
	@test PluginSystem.Utils.plugins_dir("C:/tmp") == joinpath("C:/tmp", "plugins")

	mktempdir() do dir
		path = joinpath(dir, "x.toml")
		@test PluginSystem.Utils.read_toml_if_exists(path) == Dict{String, Any}()

		write(path, "name = \"demo\"\n")
		cfg = PluginSystem.Utils.read_toml_required(path)
		@test cfg["name"] == "demo"
	end

	mktempdir() do dir
		file_plugin = joinpath(dir, "FilePlugin.jl")
		write(file_plugin, """
		\"\"\"
		version = "1.2.3"
		deps = ["DepA"]
		\"\"\"
		module FilePlugin
		end
		""")
		def = PluginSystem.Utils.parse_plugin_definition(file_plugin)
		@test def.name == "FilePlugin"
		@test def.version == v"1.2.3"
		@test def.deps == ["DepA"]
	end

	mktempdir() do dir
		pdir = joinpath(dir, "DirPlugin")
		mkpath(pdir)
		write(joinpath(pdir, "DirPlugin.jl"), """
		\"\"\"
		version = "0.1.0"
		deps = ["A", "B"]
		\"\"\"
		module DirPlugin
		end
		""")
		def = PluginSystem.Utils.parse_plugin_definition(pdir)
		@test def.name == "DirPlugin"
		@test def.is_dir
	end

	mktempdir() do dir
		root = joinpath(dir, "workspace-root")
		nested = joinpath(root, "a", "b", "c")
		mkpath(nested)
		write(joinpath(root, "Plugins.toml"), "deps = []\n")

		ws = PluginSystem.Utils.workspace(nested)
		@test ws.root == root
		@test PluginSystem.Utils.find_workspace_root(nested) == root
		@test PluginSystem.Utils.project_plugins_toml(ws) == joinpath(root, "Plugins.toml")
		@test PluginSystem.Utils.manifest_plugins_toml(ws) == joinpath(root, ".julia_plugins", "Plugins.toml")
		@test PluginSystem.Utils.plugin_store_dir(ws) == joinpath(root, ".julia_plugins")
	end

	mktempdir() do dir
		no_marker = joinpath(dir, "no-marker")
		mkpath(no_marker)
		@test PluginSystem.Utils.find_workspace_root(no_marker) == no_marker
	end
end
