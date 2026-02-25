using TOML: parsefile
_ns_norm_relpath(path::String) = replace(normpath(path), '\\' => '/')

@testset "Integration: multiple and nested namespaces" begin
	mktempdir() do root
		plugin_a_repo = joinpath(root, "ns-alpha-repo")
		plugin_a_sub = joinpath(plugin_a_repo, "NsAlpha")
		mkpath(plugin_a_sub)
		write_plugin_module(joinpath(plugin_a_sub, "NsAlpha.jl"), "NsAlpha", "0.1.0")
		git_init_repo!(plugin_a_repo)
		git_commit_all!(plugin_a_repo; message = "init-ns-alpha")

		plugin_b_repo = joinpath(root, "ns-beta-repo")
		plugin_b_sub = joinpath(plugin_b_repo, "NsBeta")
		mkpath(plugin_b_sub)
		write_plugin_module(joinpath(plugin_b_sub, "NsBeta.jl"), "NsBeta", "0.2.0")
		git_init_repo!(plugin_b_repo)
		git_commit_all!(plugin_b_repo; message = "init-ns-beta")

		registry_repo = joinpath(root, "ns-registry")
		mkpath(registry_repo)
		write(joinpath(registry_repo, "Registry.toml"), """
		name = "NamespaceRegistry"
		version = "1.0"
		repo = "file:///local/NamespaceRegistry"

		[packages]
		""")
		git_init_repo!(registry_repo)
		git_commit_all!(registry_repo; message = "init-ns-registry")

		try
			PluginSystem.publish(
				plugin_a_repo,
				registry_repo;
				subdir = "NsAlpha",
				rev = git_head(plugin_a_repo),
				namespace = "acme/tools",
			)
			PluginSystem.publish(
				plugin_b_repo,
				registry_repo;
				subdir = "NsBeta",
				rev = git_head(plugin_b_repo),
				namespace = "org/team/data",
			)

			reg = parsefile(joinpath(registry_repo, "Registry.toml"))
			meta_a = parsefile(joinpath(registry_repo, reg["packages"]["NsAlpha"] * ".toml"))
			meta_b = parsefile(joinpath(registry_repo, reg["packages"]["NsBeta"] * ".toml"))
			@test meta_a["namespace"] == "acme/tools"
			@test meta_b["namespace"] == "org/team/data"

			with_registry("NamespaceRegistry", registry_repo) do
				mktempdir() do project
					cd(project) do
						result = PluginSystem.add("NsAlpha", "NsBeta")
						@test any(p -> p.name == "NsAlpha" && p.namespace == "acme/tools", result.installed)
						@test any(p -> p.name == "NsBeta" && p.namespace == "org/team/data", result.installed)

						manifest = parsefile(joinpath(project, ".julia_plugins", "Plugins.toml"))
						a = only(filter(p -> p["name"] == "NsAlpha", manifest["plugins"]))
						b = only(filter(p -> p["name"] == "NsBeta", manifest["plugins"]))
						@test a["namespace"] == "acme/tools"
						@test b["namespace"] == "org/team/data"
						@test _ns_norm_relpath(a["path"]) == "acme/tools/NsAlpha/NsAlpha.jl"
						@test _ns_norm_relpath(b["path"]) == "org/team/data/NsBeta/NsBeta.jl"

						@test isfile(joinpath(project, ".julia_plugins", "acme", "tools", "NsAlpha", "NsAlpha.jl"))
						@test isfile(joinpath(project, ".julia_plugins", "org", "team", "data", "NsBeta", "NsBeta.jl"))

						out = IOBuffer()
						PluginSystem.status(io = out)
						text = String(take!(out))
						@test occursin("acme/tools", text)
						@test occursin("org/team/data", text)
					end
				end
			end
		finally
			PluginSystem.Cache.remove(url = plugin_a_repo)
			PluginSystem.Cache.remove(url = plugin_b_repo)
		end
	end
end
