@testset "App entrypoint" begin
	@test PluginSystem.App.run_command(["help"]) == 0

	io = IOBuffer()
	@test PluginSystem.App.run_command(["help", "add"]; io = io, err = io) == 0
	@test occursin("add <name[@version]>", String(take!(io)))

	io = IOBuffer()
	@test PluginSystem.App.run_command(["help", "publish"]; io = io, err = io) == 0
	@test occursin("merge-request", String(take!(io)))

	io = IOBuffer()
	@test PluginSystem.App.run_command(["registry", "help", "st"]; io = io, err = io) == 0
	@test occursin("registry [status|st]", String(take!(io)))

	io = IOBuffer()
	@test PluginSystem.App.run_command(["help", "registry", "remove"]; io = io, err = io) == 0
	@test occursin("registry [remove|rm]", String(take!(io)))

	io = IOBuffer()
	@test PluginSystem.App.run_command(["help", "cache", "status"]; io = io, err = io) == 0
	@test occursin("cache [status|st]", String(take!(io)))

	io = IOBuffer()
	@test PluginSystem.App.run_command(["help", "cache", "remove"]; io = io, err = io) == 0
	@test occursin("cache [remove|rm]", String(take!(io)))

	io = IOBuffer()
	@test PluginSystem.App.run_command(["help", "generate", "project"]; io = io, err = io) == 0
	@test occursin("generate|gen", String(take!(io)))
end

@testset "App REPL mode" begin
	input = IOBuffer("help\nexit\n")
	out = IOBuffer()
	err = IOBuffer()
	rc = PluginSystem.App.run_command(String[]; io = out, err = err, input = input)
	text = String(take!(out))
	@test rc == 0
	@test occursin("PluginSystem REPL mode", text)
	@test occursin("Usage:", text)
	@test occursin("Leaving PluginSystem REPL.", text)
	@test occursin("plugin> ", text)
	@test isempty(String(take!(err)))

	input = IOBuffer("unknown-command\nquit\n")
	out = IOBuffer()
	err = IOBuffer()
	rc = PluginSystem.App.run_command(String[]; io = out, err = err, input = input)
	@test rc == 0
	@test occursin("Unknown command", String(take!(err)))
	@test occursin("Leaving PluginSystem REPL.", String(take!(out)))
end
