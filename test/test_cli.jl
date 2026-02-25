using TOML: parsefile

@testset "CLI scaffold generation" begin
	mktempdir() do root
		project_path = joinpath(root, "my-sample-project")
		plugin_path = joinpath(project_path, "plugins", "SamplePlugin")
		file_plugin = joinpath(root, "OneFilePlugin.jl")

		out = IOBuffer()
		rc = PluginSystem.App.run_command(["generate", "project", project_path]; io = out, err = out)
		text = String(take!(out))
		@test rc == 0
		@test occursin("[scaffold] PROJECT", text)
		@test isfile(joinpath(project_path, "Plugins.toml"))
		@test isfile(joinpath(project_path, "src", "MySampleProject.jl"))

		out = IOBuffer()
		rc = PluginSystem.App.run_command(["generate", "plugin", plugin_path, "--version", "0.2.0", "--deps", "Alpha,Beta"]; io = out, err = out)
		text = String(take!(out))
		@test rc == 0
		@test occursin("[scaffold] PLUGIN", text)
		def = PluginSystem.Utils.parse_plugin_definition(plugin_path)
		@test def.version == v"0.2.0"
		@test Set(def.deps) == Set(["Alpha", "Beta"])

		out = IOBuffer()
		rc = PluginSystem.App.run_command(["gen", "plugin", file_plugin, "--file", "true", "--force", "true"]; io = out, err = out)
		@test rc == 0
		@test isfile(file_plugin)
		def_file = PluginSystem.Utils.parse_plugin_definition(file_plugin)
		@test def_file.name == "OneFilePlugin"
	end
end

function _setup_cache_repo_for_cli()
	repo = mktempdir()
	git_init_repo!(repo)
	write(joinpath(repo, "Demo.jl"), "module Demo\nend\n")
	git_commit_all!(repo; message = "fixture")
	repo
end

@testset "API silent return and CLI output" begin
	cache_repo = nothing

	try
		with_fixture_registry(message = "cli-fixture") do _registry_repo
			with_temp_project() do _
				# Direct API call: returns structured info.
				result = PluginSystem.add("TPluginB")
				@test result.action == "add"
				@test any(p -> p.name == "TPluginB" && p.namespace == "fixture", result.installed)

				# CLI add call: prints meaningful completion message.
				out = IOBuffer()
				rc = PluginSystem.App.run_command(["add", "TPluginB"]; io = out, err = out)
				text = String(take!(out))
				@test rc == 0
				@test occursin("[plugin] ADD", text)
				@test occursin("plugin delta", text)
				@test occursin("no plugin version changes", text)
				@test occursin("installed", text)

				# CLI call: prints required output.
				out = IOBuffer()
				rc = PluginSystem.App.run_command(["status"]; io = out, err = out)
				text = String(take!(out))
				@test rc == 0
				@test occursin("[plugin] STATUS", text)
				@test occursin("fixture", text)

				out = IOBuffer()
				rc = PluginSystem.App.run_command(["pin", "TPluginB"]; io = out, err = out)
				text = String(take!(out))
				@test rc == 0
				@test occursin("[plugin] PIN", text)
				@test occursin("pinned 1 plugin(s)", lowercase(text))

				out = IOBuffer()
				rc = PluginSystem.App.run_command(["free", "TPluginB"]; io = out, err = out)
				text = String(take!(out))
				@test rc == 0
				@test occursin("[plugin] FREE", text)
				@test occursin("freed 1 plugin(s)", lowercase(text))

				out = IOBuffer()
				rc = PluginSystem.App.run_command(["registry", "st"]; io = out, err = out)
				text = String(take!(out))
				@test rc == 0
				@test occursin("[registry] STATUS", text)

				cache_repo = _setup_cache_repo_for_cli()
				PluginSystem.Cache.remove(url = cache_repo)
				mktempdir() do tmp
					PluginSystem.Download.download(cache_repo, nothing, nothing, joinpath(tmp, "cache"); force = true)
				end

				out = IOBuffer()
				rc = PluginSystem.App.run_command(["cache", "st"]; io = out, err = out)
				text = String(take!(out))
				@test rc == 0
				@test occursin("[cache] STATUS", text)
				@test occursin(cache_repo, text)

				entries = filter(e -> get(e, :url, nothing) == cache_repo, PluginSystem.Cache.status())
				@test !isempty(entries)
				key = entries[1].key

				out = IOBuffer()
				rc = PluginSystem.App.run_command(["cache", "rm", "--key", key]; io = out, err = out)
				text = String(take!(out))
				@test rc == 0
				@test occursin("[cache] REMOVE", text)
				@test occursin("deleting selected cache entries", text)
				@test occursin("removed", lowercase(text))
				@test isempty(filter(e -> get(e, :url, nothing) == cache_repo && get(e, :key, nothing) == key, PluginSystem.Cache.status()))
			end
		end
	finally
		cache_repo !== nothing && PluginSystem.Cache.remove(url = cache_repo)
		cache_repo !== nothing && rm(cache_repo; recursive = true, force = true)
	end
end
