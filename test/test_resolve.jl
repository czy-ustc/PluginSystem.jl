@testset "Resolve ordering" begin
	a = PluginSystem.InstalledPluginInfo("A", v"1.0.0", "A", "", String[], "a")
	b = PluginSystem.InstalledPluginInfo("B", v"1.0.0", "B", "", ["A"], "b")
	c = PluginSystem.InstalledPluginInfo("C", v"1.0.0", "C", "", ["B"], "c")

	plugins = Dict{String, PluginSystem.AbstractPluginInfo}("C" => c, "A" => a, "B" => b)
	ordered = PluginSystem.Resolve.topological_sort(plugins)
	@test [p.name for p in ordered] == ["A", "B", "C"]
end
