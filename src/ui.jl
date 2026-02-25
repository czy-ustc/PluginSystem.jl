module UI

public change, header, note, step, summary

function _emit(io::Union{Nothing, IO}, text::AbstractString; color::Symbol = :normal, bold::Bool = false)
	io === nothing && return
	printstyled(io, text, color = color, bold = bold)
end

function _line(io::Union{Nothing, IO}, text::AbstractString; color::Symbol = :normal, bold::Bool = false)
	io === nothing && return
	_emit(io, text; color = color, bold = bold)
	println(io)
end

function header(io::Union{Nothing, IO}, scope::AbstractString, action::AbstractString)
	io === nothing && return
	_emit(io, "[", color = :light_black, bold = true)
	_emit(io, scope, color = :cyan, bold = true)
	_emit(io, "] ", color = :light_black, bold = true)
	_emit(io, uppercase(action), color = :magenta, bold = true)
	println(io)
end

function step(io::Union{Nothing, IO}, msg::AbstractString)
	_line(io, "  -> $msg"; color = :light_black, bold = true)
end

function note(io::Union{Nothing, IO}, msg::AbstractString)
	_line(io, "  .. $msg"; color = :light_black)
end

function change(io::Union{Nothing, IO}, kind::Symbol, msg::AbstractString)
	io === nothing && return
	prefix, color = if kind == :add
		("+", :green)
	elseif kind == :remove
		("-", :light_red)
	elseif kind == :update
		("~", :yellow)
	else
		("=", :light_black)
	end
	_emit(io, "  $prefix "; color = color, bold = true)
	_emit(io, msg; color = :normal, bold = kind != :none)
	println(io)
end

function summary(io::Union{Nothing, IO}, msg::AbstractString; level::Symbol = :ok)
	label, color = if level == :ok
		("ok", :green)
	elseif level == :warn
		("warn", :yellow)
	elseif level == :error
		("err", :light_red)
	else
		("info", :cyan)
	end
	io === nothing && return
	_emit(io, "  [", color = :light_black, bold = true)
	_emit(io, label, color = color, bold = true)
	_emit(io, "] ", color = :light_black, bold = true)
	_emit(io, msg; color = color, bold = true)
	println(io)
end

end#= module UI =#
