@testset "Documentation: structure and runnable guidance" begin
	docs_src = normpath(joinpath(@__DIR__, "..", "docs", "src"))
	_strip_bom(s::String) = startswith(s, '\ufeff') ? replace(s, "\ufeff" => ""; count = 1) : s

	@test isdir(docs_src)

	index_md = _strip_bom(read(joinpath(docs_src, "index.md"), String))
	overview_md = _strip_bom(read(joinpath(docs_src, "overview.md"), String))
	tutorial_md = _strip_bom(read(joinpath(docs_src, "hands-on-tutorial.md"), String))
	getting_started_md = _strip_bom(read(joinpath(docs_src, "getting-started.md"), String))

	@test startswith(strip(index_md), "# ")
	@test startswith(strip(overview_md), "# ")
	@test startswith(strip(tutorial_md), "# ")

	@test occursin("Hands-on Tutorial", index_md)
	@test occursin("Scaffold -> Declare -> Resolve -> Install/Link -> Load Runtime -> Operate", overview_md)
	@test occursin("plugin registry add https://github.com/czy-ustc/fixtures-registry.git", tutorial_md)
	@test occursin("git clone https://github.com/czy-ustc/fixtures-plugins.git fixtures-plugins-dev", tutorial_md)
	@test occursin("plugin dev ../fixtures-plugins-dev/DemoTool", tutorial_md)

	# Getting started should now rely on direct remote registry usage.
	@test occursin("plugin registry add https://github.com/czy-ustc/fixtures-registry.git", getting_started_md)
	@test !occursin("fixtures/registries/FixtureGeneral", getting_started_md)
end



