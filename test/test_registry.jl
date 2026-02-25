@testset "Registry helpers" begin
	u1 = PluginSystem.Registry._stable_plugin_uuid("registry:General", "PluginA", "P/PluginA")
	u2 = PluginSystem.Registry._stable_plugin_uuid("registry:General", "PluginA", "P/PluginA")
	u3 = PluginSystem.Registry._stable_plugin_uuid("registry:General", "PluginB", "P/PluginB")

	@test u1 == u2
	@test u1 != u3
end

@testset "Registry add/status/remove" begin
	mktempdir() do root
		registry_repo = joinpath(root, "sample_registry_repo")
		mkpath(registry_repo)
		write(joinpath(registry_repo, "Registry.toml"), """
		name = "SampleRegistry"
		uuid = "11111111-1111-1111-1111-111111111111"
		repo = "https://example.com/sample-registry.git"

		[packages]
		""")
		git_init_repo!(registry_repo)
		git_commit_all!(registry_repo; message = "init-sample-registry")

		PluginSystem.Registry.remove("SampleRegistry")
		out = IOBuffer()
		res = PluginSystem.Registry.add(registry_repo; io = out)
		text = String(take!(out))
		@test res.action == "registry-add"
		@test "SampleRegistry" in res.added
		@test occursin("[registry] ADD", text)

		rows = PluginSystem.Registry.status()
		@test any(r -> r.name == "SampleRegistry", rows)

		out = IOBuffer()
		rmres = PluginSystem.Registry.remove("SampleRegistry"; io = out)
		rmtext = String(take!(out))
		@test rmres.action == "registry-remove"
		@test "SampleRegistry" in rmres.removed
		@test occursin("[registry] REMOVE", rmtext)
	end
end
