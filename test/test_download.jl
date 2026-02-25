@testset "Download helpers" begin
	@test PluginSystem.Download._normalize_git_subpath(nothing) == ""
	@test PluginSystem.Download._normalize_git_subpath(" a/b ") == "a/b"
	@test_throws Exception PluginSystem.Download._normalize_git_subpath("../x")

	mktempdir() do src
		mktempdir() do dst
			mkpath(joinpath(src, ".git"))
			write(joinpath(src, ".gitignore"), "ignored.txt\nsub/tmp/\n")
			write(joinpath(src, "kept.txt"), "ok")
			write(joinpath(src, "ignored.txt"), "no")
			mkpath(joinpath(src, "sub", "tmp"))
			write(joinpath(src, "sub", "tmp", "x.txt"), "no")
			mkpath(joinpath(src, "sub"))
			write(joinpath(src, "sub", "keep.txt"), "ok")

			PluginSystem.Download._copy_tree(src, dst)
			@test isfile(joinpath(dst, "kept.txt"))
			@test isfile(joinpath(dst, "sub", "keep.txt"))
			@test !ispath(joinpath(dst, "ignored.txt"))
			@test !ispath(joinpath(dst, ".git"))
			@test !ispath(joinpath(dst, "sub", "tmp"))
		end
	end
end
