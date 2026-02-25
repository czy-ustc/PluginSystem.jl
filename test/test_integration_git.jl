function _write_file(path::String, content::String)
	mkpath(dirname(path))
	write(path, content)
end

@testset "Integration: local git repository download" begin
	mktempdir() do repo
		repo_url = abspath(repo)
		PluginSystem.Cache.remove(url = repo_url)

		git_init_repo!(repo)

		_write_file(joinpath(repo, ".gitignore"), "ignored.log\nbuild/\n")
		_write_file(joinpath(repo, "README.md"), "# Demo\n")
		_write_file(joinpath(repo, "ignored.log"), "ignore me")
		_write_file(joinpath(repo, "build", "tmp.txt"), "ignore me")
		_write_file(joinpath(repo, "src", "DemoPlugin.jl"), "module DemoPlugin\nend\n")
		git_commit_all!(repo; message = "initial")

		mktempdir() do workspace
			dest_all = joinpath(workspace, "all")
			PluginSystem.Download.download(repo_url, nothing, nothing, dest_all; force = true)
			@test isfile(joinpath(dest_all, "README.md"))
			@test isfile(joinpath(dest_all, "src", "DemoPlugin.jl"))
			@test !ispath(joinpath(dest_all, "ignored.log"))
			@test !ispath(joinpath(dest_all, "build"))
			@test !ispath(joinpath(dest_all, ".git"))

			dest_src = joinpath(workspace, "src_only")
			PluginSystem.Download.download(repo_url, nothing, "src", dest_src; force = true)
			@test isfile(joinpath(dest_src, "DemoPlugin.jl"))

			# With force=false stale files are preserved.
			_write_file(joinpath(dest_src, "stale.txt"), "stale")
			PluginSystem.Download.download(repo_url, nothing, "src", dest_src; force = false)
			@test isfile(joinpath(dest_src, "stale.txt"))

			# With force=true destination is replaced.
			PluginSystem.Download.download(repo_url, nothing, "src", dest_src; force = true)
			@test !isfile(joinpath(dest_src, "stale.txt"))
		end

		_write_file(joinpath(repo, "src", "DemoPlugin.jl"), "module DemoPlugin\nconst V = 2\nend\n")
		git_commit_paths!(repo, "src/DemoPlugin.jl"; message = "update")

		mktempdir() do workspace
			PluginSystem.Download.download(repo_url, nothing, "src", joinpath(workspace, "src"); force = true)
		end

		entries = filter(e -> get(e, :url, nothing) == repo_url, PluginSystem.Cache.status())
		@test !isempty(entries)
		@test length(Set(getfield.(entries, :key))) >= 2

		count = PluginSystem.Cache.remove(key = entries[1].key).removed
		@test count >= 1
		PluginSystem.Cache.remove(url = repo_url)
	end
end

@testset "Integration: cache delete by url after repo removed" begin
	mktempdir() do root
		repo = joinpath(root, "RepoUPPER")
		mkpath(repo)
		repo_url = abspath(repo)
		PluginSystem.Cache.remove(url = repo_url)

		git_init_repo!(repo)
		_write_file(joinpath(repo, "Only.jl"), "module Only\nend\n")
		git_commit_all!(repo; message = "initial")

		mktempdir() do workspace
			PluginSystem.Download.download(repo_url, nothing, nothing, joinpath(workspace, "all"); force = true)
		end
		@test !isempty(filter(e -> get(e, :url, nothing) == repo_url, PluginSystem.Cache.status()))

		# Remove source repository first to ensure cache-key matching does not depend on `ispath(url)`.
		rm(repo; recursive = true, force = true)
		removed = PluginSystem.Cache.remove(url = repo_url).removed
		@test removed >= 1
		@test isempty(filter(e -> get(e, :url, nothing) == repo_url, PluginSystem.Cache.status()))
	end
end
