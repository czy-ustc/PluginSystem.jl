using Documenter
using PluginSystem

const DOC_PAGES = [
	"Home" => "index.md",
	"Guided Path" => [
		"Overview" => "overview.md",
		"Getting Started" => "getting-started.md",
		"CLI Guide" => "cli.md",
		"Scaffolding" => "scaffolding.md",
		"Managing Plugins" => "managing-plugins.md",
		"Registries" => "registries.md",
		"Namespaces" => "namespaces.md",
		"Version Resolution" => "version-resolution.md",
		"Hands-on Tutorial" => "hands-on-tutorial.md",
		"Creating and Publishing Plugins" => "creating-and-publishing-plugins.md",
	],
	"Reference" => [
		"Cache and Artifacts" => "cache-and-artifacts.md",
		"Testing and Fixtures" => "testing-and-fixtures.md",
		"Use Cases and Benefits" => "use-cases-and-benefits.md",
		"Configuration Files" => "configuration-files.md",
		"API" => "api.md",
		"Architecture" => "architecture.md",
	],
]

function _collect_markdown_pages(entry)
	if entry isa Pair
		value = last(entry)
		if value isa String
			return String[value]
		elseif value isa AbstractVector
			files = String[]
			for child in value
				append!(files, _collect_markdown_pages(child))
			end
			return files
		end
		error("Unsupported pages entry value type: $(typeof(value))")
	elseif entry isa String
		return String[entry]
	end
	error("Unsupported pages entry type: $(typeof(entry))")
end

function _validate_level1_headings!(pages)
	doc_src = joinpath(@__DIR__, "src")
	files = unique(vcat([_collect_markdown_pages(entry) for entry in pages]...))
	issues = String[]

	for rel in files
		path = joinpath(doc_src, rel)
		if !isfile(path)
			push!(issues, "$rel: file not found")
			continue
		end

		text = replace(read(path, String), "\r\n" => "\n", "\ufeff" => "")
		lines = split(text, '\n')
		first_idx = findfirst(line -> !isempty(strip(line)), lines)
		if first_idx === nothing
			push!(issues, "$rel: empty file")
			continue
		end

		first_line = strip(lines[first_idx])
		startswith(first_line, "# ") || push!(issues, "$rel: first non-empty line must be a level-1 heading")

		h1_count = count(line -> startswith(strip(line), "# "), lines)
		h1_count == 1 || push!(issues, "$rel: expected exactly one level-1 heading, found $h1_count")
	end

	isempty(issues) || error("Documentation heading check failed:\n" * join(issues, "\n"))
	nothing
end

_validate_level1_headings!(DOC_PAGES)

makedocs(
	sitename = "PluginSystem.jl",
	modules = [PluginSystem],
	doctest = true,
	repo = Documenter.Remotes.GitHub("czy-ustc", "PluginSystem.jl"),
	format = Documenter.HTML(
		prettyurls = false,
		repolink = "https://github.com/czy-ustc/PluginSystem.jl",
		edit_link = "main",
	),
	pages = DOC_PAGES,
)
