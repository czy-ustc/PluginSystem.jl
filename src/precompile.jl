using PrecompileTools: @compile_workload, @setup_workload

function _write_precompile_local_plugin(root::String)
	mkpath(joinpath(root, "plugins", "PrecompileLocal"))
	write(
		joinpath(root, "plugins", "PrecompileLocal", "PrecompileLocal.jl"),
		"""
		\"\"\"
		version = "0.1.0"
		deps = []
		\"\"\"
		module PrecompileLocal
		end
		""",
	)
end

function _exercise_precompile_load_plugins(project::String)
	# Precompile the macro expansion path with a concrete source file context.
	script = joinpath(project, "precompile_load_case.jl")
	write(script, "# precompile load_plugins workload\n")
	ex = Expr(:macrocall, Symbol("@load_plugins"), LineNumberNode(1, script))
	macroexpand(PluginSystem, ex)
	Base.precompile(Tuple{typeof(load_plugins!), Module})
end

@setup_workload begin
	@compile_workload begin
		mktempdir() do project
			cd(project) do
				write("Plugins.toml", "deps = []\n")
				_write_precompile_local_plugin(project)

				add("PrecompileLocal")
				status()
				pin("PrecompileLocal")
				free("PrecompileLocal")
				_exercise_precompile_load_plugins(project)
				remove("PrecompileLocal")

				Registry.status()
				Cache.status()
				scaffold_project(joinpath(project, "GeneratedProject"); force = true)
				scaffold_plugin(joinpath(project, "GeneratedPlugin"); force = true)

				io = IOBuffer()
				App.run_command(["help"]; io = io, err = io)
				App.run_command(["status"]; io = io, err = io)
				App.run_command(["cache", "st"]; io = io, err = io)
				App.run_command(["generate", "project", joinpath(project, "GeneratedFromCLI"), "--force", "true"]; io = io, err = io)
			end
		end
	end
end
