@testset "API supports explicit workspace base_dir" begin
	with_fixture_registry(message = "workspace-fixture") do _
		mktempdir() do root
			project = joinpath(root, "workspace-project")
			mkpath(project)
			write(joinpath(project, "Plugins.toml"), "deps = []\n")

			# Execute from a different cwd to verify path isolation.
			other_cwd = mktempdir()
			cd(other_cwd) do
				add_result = PluginSystem.add("TPluginB"; base_dir = project)
				@test add_result.action == "add"
				@test any(p -> p.name == "TPluginB", add_result.installed)

				status_rows = PluginSystem.status(base_dir = project)
				@test any(r -> r.name == "TPluginB", status_rows)

				remove_result = PluginSystem.remove("TPluginB"; base_dir = project)
				@test remove_result.action == "remove"
			end
		end
	end
end
