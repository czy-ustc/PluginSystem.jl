using TOML: parsefile

@testset "Integration: full publish workflow" begin
	mktempdir() do root
		plugin_repo = joinpath(root, "flow-plugin-repo")
		plugin_subdir = joinpath(plugin_repo, "FlowPlugin")
		mkpath(plugin_subdir)
		plugin_file = joinpath(plugin_subdir, "FlowPlugin.jl")
		write_plugin_module(plugin_file, "FlowPlugin", "0.1.0")
		git_init_repo!(plugin_repo)
		git_commit_all!(plugin_repo; message = "init-flow-plugin")

		registry_repo = joinpath(root, "flow-registry")
		mkpath(registry_repo)
		write(joinpath(registry_repo, "Registry.toml"), """
		name = "FlowRegistry"
		version = "1.0"
		repo = "file:///local/FlowRegistry"

		[packages]
		""")
		git_init_repo!(registry_repo)
		git_commit_all!(registry_repo; message = "init-flow-registry")

		try
			# Step 1: publish initial version.
			rev_v010 = git_head(plugin_repo)
			out = IOBuffer()
			pub = PluginSystem.publish(plugin_repo, registry_repo; subdir = "FlowPlugin", rev = rev_v010, io = out)
			pub_text = String(take!(out))
			@test pub.action == "publish"
			@test pub.name == "FlowPlugin"
			@test pub.version == "0.1.0"
			@test occursin("[plugin] PUBLISH", pub_text)
			@test occursin("published FlowPlugin v0.1.0", pub_text)

			reg = parsefile(joinpath(registry_repo, "Registry.toml"))
			@test haskey(reg["packages"], "FlowPlugin")
			meta_path = joinpath(registry_repo, reg["packages"]["FlowPlugin"] * ".toml")
			@test isfile(meta_path)
			meta = parsefile(meta_path)
			@test meta["namespace"] == "published"
			@test haskey(meta["versions"], "0.1.0")
			@test get(meta["versions"]["0.1.0"], "rev", nothing) == rev_v010

			with_registry("FlowRegistry", registry_repo) do
				# Step 2: install from registry in a clean project and verify namespace.
				with_temp_project() do project
					add_out = IOBuffer()
					add_res = PluginSystem.add("FlowPlugin"; io = add_out)
					add_text = String(take!(add_out))
					@test any(p -> p.name == "FlowPlugin" && p.version == "0.1.0" && p.namespace == "published", add_res.installed)
					@test occursin("+ FlowPlugin v0.1.0 [published]", add_text)

					manifest = parsefile(joinpath(project, ".julia_plugins", "Plugins.toml"))
					p = only(filter(x -> x["name"] == "FlowPlugin", manifest["plugins"]))
					@test p["version"] == "0.1.0"
					@test p["namespace"] == "published"
					@test p["path"] == joinpath("published", "FlowPlugin", "FlowPlugin.jl")

					# Step 3: publish a new version and update project.
					write_plugin_module(plugin_file, "FlowPlugin", "0.2.0")
					git_commit_all!(plugin_repo; message = "release-0.2.0")
					rev_v020 = git_head(plugin_repo)

					pub2 = PluginSystem.publish(plugin_repo, registry_repo; subdir = "FlowPlugin", rev = rev_v020)
					@test pub2.version == "0.2.0"

					meta2 = parsefile(meta_path)
					@test haskey(meta2["versions"], "0.2.0")
					PluginSystem.Registry.update("FlowRegistry")

					up_out = IOBuffer()
					up_res = PluginSystem.update("FlowPlugin"; io = up_out)
					up_text = String(take!(up_out))
					@test any(p -> p.name == "FlowPlugin" && p.version == "0.2.0" && p.namespace == "published", up_res.installed)
					@test occursin("~ FlowPlugin v0.1.0 => v0.2.0 [published]", up_text)
				end
			end
		finally
			PluginSystem.Cache.remove(url = plugin_repo)
		end
	end
end

@testset "Integration: publish pushes branch to remote" begin
	mktempdir() do root
		plugin_repo = joinpath(root, "push-plugin-repo")
		plugin_subdir = joinpath(plugin_repo, "PushPlugin")
		mkpath(plugin_subdir)
		write_plugin_module(joinpath(plugin_subdir, "PushPlugin.jl"), "PushPlugin", "0.1.0")
		git_init_repo!(plugin_repo)
		git_commit_all!(plugin_repo; message = "init-push-plugin")

		registry_repo = joinpath(root, "push-registry")
		mkpath(registry_repo)
		write(joinpath(registry_repo, "Registry.toml"), """
		name = "PushRegistry"
		version = "1.0"
		repo = "file:///local/PushRegistry"

		[packages]
		""")
		git_init_repo!(registry_repo)
		git_commit_all!(registry_repo; message = "init-push-registry")

		registry_remote = joinpath(root, "push-registry-remote.git")
		run(pipeline(`git init --quiet --bare $registry_remote`, stdout = devnull, stderr = devnull))
		git_run_quiet(registry_repo, "remote", "add", "origin", registry_remote)

		try
			branch = "pluginsystem/pushplugin-v0.1.0"
			rev = git_head(plugin_repo)
			pub = PluginSystem.publish(
				plugin_repo,
				registry_repo;
				subdir = "PushPlugin",
				rev = rev,
				remote = "origin",
				branch = branch,
				push = true,
			)

			@test pub.branch == branch
			@test pub.committed == true
			@test pub.pushed == true
			@test pub.base === nothing
			@test pub.merge_request_url === nothing

			pushed_sha = strip(readchomp(`git --git-dir $registry_remote rev-parse --verify refs/heads/$branch`))
			@test !isempty(pushed_sha)
		finally
			PluginSystem.Cache.remove(url = plugin_repo)
		end
	end
end

@testset "Integration: publish returns merge request URL" begin
	mktempdir() do root
		plugin_repo = joinpath(root, "mr-plugin-repo")
		plugin_subdir = joinpath(plugin_repo, "MRPlugin")
		mkpath(plugin_subdir)
		write_plugin_module(joinpath(plugin_subdir, "MRPlugin.jl"), "MRPlugin", "0.1.0")
		git_init_repo!(plugin_repo)
		git_commit_all!(plugin_repo; message = "init-mr-plugin")

		registry_repo = joinpath(root, "mr-registry")
		mkpath(registry_repo)
		write(joinpath(registry_repo, "Registry.toml"), """
		name = "MRRegistry"
		version = "1.0"
		repo = "https://github.com/example/mr-registry.git"

		[packages]
		""")
		git_init_repo!(registry_repo)
		git_commit_all!(registry_repo; message = "init-mr-registry")
		git_run_quiet(registry_repo, "remote", "add", "origin", "https://github.com/example/mr-registry.git")

		try
			branch = "pluginsystem/mrplugin-v0.1.0"
			rev = git_head(plugin_repo)
			pub = PluginSystem.publish(
				plugin_repo,
				registry_repo;
				subdir = "MRPlugin",
				rev = rev,
				remote = "origin",
				branch = branch,
				base = "main",
				create_merge_request = true,
			)

			@test pub.branch == branch
			@test pub.base == "main"
			@test pub.pushed == false
			@test pub.merge_request_url !== nothing
			@test occursin("https://github.com/example/mr-registry/compare/main...pluginsystem%2Fmrplugin-v0.1.0?expand=1", pub.merge_request_url)
		finally
			PluginSystem.Cache.remove(url = plugin_repo)
		end
	end
end
