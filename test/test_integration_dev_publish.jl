using TOML: parsefile

@testset "Integration: dev" begin
	mktempdir() do src
		plugin_dir = joinpath(src, "DevPlugin")
		mkpath(plugin_dir)
		write_plugin_module(joinpath(plugin_dir, "DevPlugin.jl"), "DevPlugin", "0.1.0")

		result = PluginSystem.dev(plugin_dir; force = true)
		@test isdir(result.path)
		@test isfile(joinpath(result.path, "DevPlugin.jl"))

		mktempdir() do project
			cd(project) do
				PluginSystem.add("DevPlugin")
				manifest = parsefile(joinpath(project, ".julia_plugins", "Plugins.toml"))
				p = only(filter(x -> x["name"] == "DevPlugin", manifest["plugins"]))
				@test p["version"] == "0.1.0"
			end
		end
	end
end

@testset "Integration: publish" begin
	mktempdir() do root
		# plugin git repo
		plugin_repo = joinpath(root, "plugin")
		mkpath(joinpath(plugin_repo, "PubPlugin"))
		write_plugin_module(joinpath(plugin_repo, "PubPlugin", "PubPlugin.jl"), "PubPlugin", "1.2.0"; deps = ["DepA"])
		git_init_repo!(plugin_repo)
		git_commit_all!(plugin_repo; message = "init")

		try
			# registry git repo
			registry_repo = joinpath(root, "registry")
			mkpath(registry_repo)
			write(joinpath(registry_repo, "Registry.toml"), """
			name = "DevRegistry"
			version = "1.0"
			repo = "file:///local/DevRegistry"

			[packages]
			""")
			git_init_repo!(registry_repo)
			git_commit_all!(registry_repo; message = "init")

			PluginSystem.dev(plugin_repo; subdir = "PubPlugin", force = true)
			dev_path = joinpath(PluginSystem.GLOBAL_DEV_PLUGINS_DIR, "PubPlugin")
			@test isdir(dev_path)

			pub = PluginSystem.publish(plugin_repo, registry_repo; subdir = "PubPlugin")
			@test pub.released_dev == true
			@test !isdir(dev_path)

			reg = parsefile(joinpath(registry_repo, "Registry.toml"))
			@test haskey(reg["packages"], "PubPlugin")
			meta_path = joinpath(registry_repo, reg["packages"]["PubPlugin"] * ".toml")
			@test isfile(meta_path)
			meta = parsefile(meta_path)
			@test haskey(meta["versions"], "1.2.0")
		finally
			PluginSystem.Cache.remove(url = plugin_repo)
			rm(joinpath(PluginSystem.GLOBAL_DEV_PLUGINS_DIR, "PubPlugin"); recursive = true, force = true)
		end
	end
end
