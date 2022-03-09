### A Pluto.jl notebook ###
# v0.18.1

using Markdown
using InteractiveUtils

# ╔═╡ 8e818b32-6823-47b7-aa35-ac4ee9b9afd2
using PlutoTest

# ╔═╡ 8162b1b4-4e61-4f39-9fd7-d16695f138a3
using HypertextLiteral

# ╔═╡ 38e9d7e0-1e3b-4a71-9065-b0e17e39765a
using BenchmarkTools

# ╔═╡ da12a2c8-a631-4da8-be4e-87cc1e1f124c
md"""
# Promises.jl: *JavaScript-inspired async*

"""

# ╔═╡ f0567e34-6fb8-4509-80e7-532e0464f1bd
md"""
You can use Promises.jl to run code in the background:
"""

# ╔═╡ 1cf696fd-6fa4-4e93-8132-63d89d902f95
username = "JuliaLang"

# ╔═╡ 7e24cd7d-6f1c-47e2-b0a3-d8f81a4e7167
md"""
The result is a *pending promise*: it might still running in the background! 
"""

# ╔═╡ 82f259ca-0e35-4278-ac46-aed2fdb87857
md"""
You can use `@await` to wait for it to finish, and get its value:
"""

# ╔═╡ 8a1a621d-b94c-45ee-87b9-6ac2faa3f877
md"""
$(html"<br>")
## Chaining with `then`

One cool feature of promises is **chaining**! Every promise has a `then` function, which can be used to add a new transformation to the chain, returning a new `Promise`.
"""

# ╔═╡ ab37c026-963b-46d2-bc51-56e36eb3b06b
md"""
$(html"<br>")
## Error handling: `reject` and `.catch`

A promise can finish in two ways: it can **resolve** or it can **reject**. This corresponds to the two functions in the constructor, `resolve` and `reject`:

```julia
Promise((resolve, reject) -> begin

	if condition
		# Resolve the promise:
		resolve("Success!")
	else
		# Reject the promise
		reject("Something went wrong...")
	end
end)
```

If you `@await` a promise that has rejected, the rejected value will be rethrown as an error:
"""

# ╔═╡ e7f81212-e7f5-4133-8bfe-a4997c7d1bbb
md"""
In addition, when an exception occurs inside a Promise body, the Promise will reject, with the error message as rejected value:
"""

# ╔═╡ f14c4a43-2f2f-4390-ad4d-940b1926cfb3
md"""
$(html"<br>")
### Chaining errors with `.catch`

There are two special things about rejected values in chains:
1. The `.then` function of a rejected Promise will *immediately reject*, passing the value along. 
"""

# ╔═╡ 038949f4-3f99-496e-a3c7-f980f2fa92d2
md"""
2. The `.catch` is the opposite of `.then`: it is used to handle rejected values.
"""

# ╔═╡ bdb0e349-b043-4a07-9dc8-1f2ea587ac2f
md"""
Here is a little table:

|  | `.then` | `.catch` |
| --- | --- | --- |
| On a **resolved** Promise: | Runs | *Skipped* |
| On a **rejected** Promise: | *Skipped* | Runs |
"""

# ╔═╡ 34d6da04-daa8-484b-bb30-2bf2ee55da9d
md"""
$(html"<br>")
### `Promise{T}` is a parametric type

Like in TypeScript, the `Promise{T}` can specify its **resolve type**. For example, `Promise{String}` is guaranteed to resolve to a `String`.
"""

# ╔═╡ ae4e308e-83be-4e0b-a0a4-96677dcffa22
md"""
Trying to resolve to another type will reject the Promise:
"""

# ╔═╡ 74cdad42-7f54-4da3-befe-a67c969217ae
md"""
This information is available to the Julia compiler, which means that it can do smart stuff!
"""

# ╔═╡ 580d9608-fb50-4845-b3b2-4195cdb41d67


# ╔═╡ 8ab41c7c-b180-473e-bd55-a904f9af6f2c
import Downloads

# ╔═╡ e85d9bc8-9c4e-44eb-8cf6-903cc71d050f
import JSON

# ╔═╡ 530e9bf7-bd09-4978-893a-c945ca15e508
md"""
# Implementation
"""

# ╔═╡ 0a8b61aa-b703-4c8e-baa1-c3bb82d468fe
import AbstractPlutoDingetjes

# ╔═╡ 49a8beb7-6a97-4c46-872e-e89822108f39
begin
	Base.@kwdef struct Promise{T}
		resolved_val::Ref{Union{Nothing,Some{T}}}=Ref{Union{Nothing,Some{T}}}(nothing)
		rejected_val::Ref{Union{Nothing,Some}}=Ref{Union{Nothing,Some}}(nothing)
		done::Channel{Nothing}=Channel{Nothing}(1)
	end
	
	function Promise{T}(f::Function) where T
		p = Promise{T}()
		@async begin
			function resolve(val=nothing)
				if !isready(p.done)
					if val isa T
						p.resolved_val[] = Some{T}(val)
					else
						p.rejected_val[] = Some(CapturedException(
							ArgumentError("Can only resolve with values of type $T."),
							stacktrace(backtrace())
						))
					end
					put!(p.done, nothing)
				end
				val
			end
			function reject(val=nothing)
				if !isready(p.done)
					p.rejected_val[] = Some(val)
					put!(p.done, nothing)
				end
				val
			end
			try
				f(resolve, reject)
			catch e
				reject(CapturedException(e, catch_backtrace()))
			end
		end
		p
	end
	function Promise(f::Function)
		Promise{Any}(f)
	end

	Base.eltype(p::Promise{T}) where T = T

	isresolved(p::Promise) = isready(p) && p.resolved_val[] !== nothing
	isrejected(p::Promise) = isready(p) && p.rejected_val[] !== nothing

	Base.isready(p::Promise) = isready(p.done)
	
	function Base.:(==)(a::Promise{T}, b::Promise{T}) where T
		isready(a) == isready(b) &&
		a.resolved_val[] == b.resolved_val[] &&
		a.rejected_val[] == b.rejected_val[]
	end
	
	Base.hash(p::Promise) = hash((
		typeof(p),
		isready(p),
		p.resolved_val[],
		p.rejected_val[],
	))
	
	Base.promote_rule(::Type{Promise{T}}, ::Type{Promise{S}}) where {T,S} = Promise{promote_type(T,S)}
	function Base.convert(PT::Type{Promise{T}}, p::Promise{S}) where {T,S}
		PT() do res, rej
			p.then(val -> res(convert(T, val)))
			p.catch(rej)
		end
	end

	
	function Base.fetch(p::Promise{T})::T where T
		fetch(p.done)
		if p.resolved_val[] !== nothing
			something(p.resolved_val[])
		else
			throw(something(p.rejected_val[]))
		end
	end

	
	function Base.wait(p::Promise)
		fetch(p.done)
		if p.rejected_val[] !== nothing
			throw(something(p.rejected_val[]))
		end
		nothing
	end
	
	function Base.getproperty(p::Promise, name::Symbol)
		if name === :then
			function(f::Function)
				T = Core.Compiler.return_type(f, (eltype(p),))
				Promise{T}() do resolve, reject
					wait(p.done)
					if isresolved(p)
						resolve(f(something(p.resolved_val[])))
					else
						reject(something(p.rejected_val[]))
					end
				end
			end
		elseif name === :catch
			function(f::Function)
				T = Core.Compiler.return_type(f, (Any,))
				
				Promise{Union{T,eltype(p)}}() do resolve, reject
					wait(p.done)
					if isresolved(p)
						resolve(something(p.resolved_val[]))
					else
						resolve(f(something(p.rejected_val[])))
					end
				end
			end
		else
			getfield(p, name)
		end
	end

	
	function Base.show(io::IO, m::MIME"text/plain", p::Promise)
		summary(io, p)
		if isresolved(p)
			write(io, "( <resolved>: ")
			show(io, m, fetch(p))
			write(io, " )")
		elseif isrejected(p)
			write(io, "( <rejected>: ")
			rej_val = something(p.rejected_val[])
			if rej_val isa CapturedException
				println(io)
				showerror(io, rej_val)
				println(io)
			else
				show(io, m, rej_val)
			end
			write(io, " )")
		else
			write(io, "( <pending> )")
		end
	end
	
	function Base.show(io::IO, m::MIME"text/html", p::Promise)
		typestr = sprint(summary, p; context=io)
		state, display = if isresolved(p)
			"resolved", p.resolved_val[]
		elseif isrejected(p)
			"rejected", p.rejected_val[]
		else
			"pending", nothing
		end
		
		show(io, m, @htl(
			"<div style='
				display: flex;
    			flex-direction: row;
    			flex-wrap: wrap;
    			align-items: baseline;
				font-size: 1rem;
				background: $(
					state === "rejected" ? 
					"linear-gradient(90deg, #ff2e2e14, transparent)" :
					"unset"
				);
    			border-radius: 7px;
			'>$(display === nothing ? 
				@htl(
				"""<code style='background: none;'>$(typestr)( $(
					"<$(state)>"
				) )</code>""") : 
				
				@htl("""<code style='background: none;'>$(typestr)( $(
					"<$(state)>: "
				)</code>$(
					(
						AbstractPlutoDingetjes.is_inside_pluto(io) ? 
						Main.PlutoRunner.embed_display : 
						identity
					)(something(display))
				)<code style='background: none;'> )</code>""")
			)</div>"
		))
	end

	@doc """
	```julia
	Promise{T=Any}((resolve, reject) -> begin
		...

		resolve(value)
	end)
	```

	Run code asynchronously, and keep a reference to its future value. 
	
	Based on [`Promise` in JavaScript](https://javascript.info/promise-basics)!
	""" Promise
end

# ╔═╡ 7aef0b5c-dd09-47d3-a08f-81cce84d7ca6
download_result = Promise((resolve, reject) -> begin

	filename = Downloads.download("https://api.github.com/users/$(username)")

	# call `resolve` with the result
	resolve(filename)
	
end)

# ╔═╡ d22278fd-33cb-4dad-ad5f-d6d067c33403
download_result

# ╔═╡ 42c6edee-d43a-40cd-af4f-3d572a6b5e9a
download_result.then(
	filename -> read(filename, String)
).then(
	str -> JSON.parse(str)
)

# ╔═╡ d8aa3fed-78f0-417a-8e47-849ec62fa056
oopsie_result = Promise((res, rej) -> rej("oops!"))

# ╔═╡ 34364f4d-e257-4c22-84ee-d8786a2c377c
Promise((res, rej) -> res(sqrt(-1)))

# ╔═╡ acfae6b5-947a-4648-99ba-bcd2dd3afbca
Promise((res, rej) -> rej("oops!")).then(x -> x + 10).then(x -> x / 100)

# ╔═╡ 66b2b18a-2afe-4607-8982-647681ff9816
Promise((res, rej) -> rej("oops!")).then(x -> x + 10).catch(x -> 123)

# ╔═╡ 959d2e3e-1ef6-4a97-a748-31b0b5ece938
Promise{String}((res,rej) -> res("asdf"))

# ╔═╡ 9d9179de-19b1-4f40-b816-454a8c071c3d
Promise{String}((res,rej) -> res(12341234))

# ╔═╡ f0b73769-dea5-4dfa-8a39-ebf6584abbf5
Core.Compiler.return_type(fetch, (Promise{String},))

# ╔═╡ 8e13e697-e29a-473a-ac11-30e0199be5bb
md"""
### Behaviour
"""

# ╔═╡ b9368cf7-cbcd-4b54-9390-78e8c88f064c


# ╔═╡ a8a07647-2b61-4401-a04d-0921a6bcec76


# ╔═╡ 51ef3992-d6a7-4b46-970c-6b075d14fb71


# ╔═╡ 5d943937-2271-431c-8fc0-4f963aa4dda0


# ╔═╡ 40c9f96a-41e9-496a-b174-490b72927626
let
	c = Channel(1)
	p = Promise((r,_) -> r(take!(c)))
	sleep(.1)
	@assert !isready(p)
	xs = []
	ps = map(1:20) do i
		p.then(v -> push!(xs, i))
	end
	put!(c, 123)
	wait(p)
	wait.(ps)
	@test xs == 1:20
end

# ╔═╡ 3f97f5e7-208a-44dc-9726-1923fd8c824b


# ╔═╡ c68ab4c1-6384-4802-a9a6-697a63d3488e
macro testawait(x)
	# fetch = Base.fetch
	fetch = Expr(:., :Base, QuoteNode(:fetch))
	wrap(x::Expr) = Expr(:call, fetch, x)
	wrap(x::Any) = x
	
	e = if Meta.isexpr(x, :call, 3) && (
			x.args[1] === :(==) || x.args[1] === :(===)
		)
		Expr(:call, x.args[1], 
			wrap(x.args[2]),
			wrap(x.args[3]),
		)
	else
		error("Don't know how to await this expression.")
	end
	:(@test $(e))
end

# ╔═╡ 8ac00844-24e5-416d-aa31-28242e4ee6a3
@testawait nothing === Promise() do res, rej
	sleep(1)
	sqrt(-1)
	res(5)
end.then(x -> x* 10).catch(e -> nothing)

# ╔═╡ 9ee2e123-7a24-46b2-becf-2d011abdcb19
md"""
### Types
"""

# ╔═╡ 58533024-ea65-4bce-b32a-727a804d1f4d
@test promote_type(Promise{Int64},Promise{Float64}) === Promise{Float64}

# ╔═╡ 5447d12d-7aa5-47f3-bf04-2516a8974bb9
md"""
### Benchmark

(Could be better 😅)
"""

# ╔═╡ 55fb60c1-b48b-4f0a-a24c-dcc2d7f0af4b
Promise((res,rej) -> res(-50)).then(sqrt)

# ╔═╡ 10bfce78-782d-49a1-9fc8-6b2ac5d16831
Promise((res,rej) -> res(-50)).then(sqrt).catch(e -> 0)

# ╔═╡ 5bb55103-bd26-4f30-bed6-026b003617b7
@benchmark(
	fetch(Promise((res,rej) -> res(-50)).then(sqrt).catch(e -> 0)),
	seconds=3
)

# ╔═╡ 287f91b6-a602-457a-b32b-e0c22f15d514
@benchmark(
	fetch(Promise((res,rej) -> res(50)).then(sqrt).catch(e -> 0).then(sqrt)),
	seconds=3
)

# ╔═╡ 371cede0-6f01-496a-8059-e110dbfc8d05
@benchmark(
	sqrt(sqrt(50)),
	seconds=3
)

# ╔═╡ 06a3eb82-0ffd-4c89-8161-d0f385c2a32e
md"""
# `async`/`await`
"""

# ╔═╡ 939c6e86-ded8-4b15-890b-80207e8d692a
macro await(expr)
	:(Base.fetch($(esc(expr))))
end

# ╔═╡ f9fad7ff-cf6f-43eb-83bd-efc0cb6cde65
@await download_result

# ╔═╡ 80f73d5a-ecd7-414f-b99c-e9ce4ba8bd60
@await oopsie_result

# ╔═╡ a854b9e6-1a82-401e-90d5-f05ffaadae61
macro async_promise(expr)
	# ..... not sure yet!! TODO
end

# ╔═╡ eb4e90d9-0e21-4f06-842d-4260f074f097
md"""
# Wait for settled
"""

# ╔═╡ 8f37aee7-b5e0-44e3-a6d0-fbbb5b88f3ef
md"""
## `Resolved{T}` and `Rejected{T}` types
"""

# ╔═╡ 7c9b31e6-cb90-4734-bf7b-6c7f0337ac62
begin
	abstract type PromiseSettledResult{T} end

	Base.promote_rule(
		::Type{<:PromiseSettledResult{T}}, 
		::Type{<:PromiseSettledResult{S}}
	) where {T,S} = PromiseSettledResult{promote_type(T,S)}

	PromiseSettledResult
end

# ╔═╡ 27876191-a023-49e9-bb3a-d3b3f10090d8
begin
	struct Resolved{T} <: PromiseSettledResult{T}
		value::T
	end

	struct Rejected{T} <: PromiseSettledResult{T}
		value::T
	end
	
	for RT in subtypes(PromiseSettledResult)
		@eval Base.only(a::$RT) = a.value
		
		@eval Base.:(==)(a::$RT, b::$RT) = a.value == b.value
		@eval Base.hash(a::$RT) = hash(a.value, hash($RT))
		
		@eval Base.promote_rule(
			t1::Type{$RT{T}}, 
			t2::Type{$RT{S}}
		) where {T,S} = $RT{promote_type(T,S)}
		
		@eval function Base.convert(
			::Type{<:PromiseSettledResult{T}}, 
			r::$RT{S}
		) where {T,S}
			$RT{T}(convert(T, r.value))
		end
	end

	md"""
	```julia
	struct Resolved{T} <: PromiseSettledResult{T}
		value::T
	end

	struct Rejected{T} <: PromiseSettledResult{T}
		value::T
	end
	```
	"""
end

# ╔═╡ a5b9e007-0282-4eb6-88dd-34855fe42fa4
function await_settled(p::Promise{T})::PromiseSettledResult where T
	wait(p.done)
	isresolved(p) ? 
		Resolved{T}(something(p.resolved_val[])) : 
		Rejected(something(p.rejected_val[]))
end

# ╔═╡ cb47c8c9-2872-4e35-9939-f953319e1acb
@test Promise{Int64}() do res, rej
	res(1)
	res(2)
end |> await_settled === Resolved(1)

# ╔═╡ 6a84cdd0-f57e-4535-bc16-24bc40018033
@test Promise{Int64}() do res, rej
	rej("asdf")
	rej("wow")
end |> await_settled === Rejected("asdf")

# ╔═╡ a0534c86-5cd6-456a-93a6-19292b5879d6
@test Promise{Int64}() do res, rej
	rej("asdf")
	sqrt(-1)
	rej("wow")
end |> await_settled === Rejected("asdf")

# ╔═╡ be56fd49-7898-4171-8837-8c1b251cdeba
@test Promise{Int64}() do res, rej
	sqrt(-1)
	rej("asdf")
	rej("wow")
end |> await_settled isa Rejected{CapturedException}

# ╔═╡ 6bb08e1c-bfe9-40c7-92b5-5c71aba040dd
@test Promise{Int64}() do res, rej
	res(1)
	sqrt(-1)
	rej("asdf")
end |> await_settled === Resolved(1)

# ╔═╡ 9aa052ef-5f60-4935-94d1-a4cbc5096d46
let
	p1 = Promise{Int64}() do res, rej
		res(1)
	end

	p2 = Promise{Int64}() do res, rej
		p1.then(res)
		await_settled(p1)
		yield()
		res(-100)
	end

	@test await_settled(p2) === Resolved(1)
end

# ╔═╡ 2b6e41af-c9e9-4774-a6f5-51c301705a10
let
	p1 = Promise{Int64}() do res, rej
		rej(-1)
	end

	p2 = Promise{Int64}() do res, rej
		p1.catch(res)
		await_settled(p1)
		yield()
		res(-100)
	end

	@test await_settled(p2) === Resolved(-1)
end

# ╔═╡ 1ef3378e-62ac-463b-b8c0-dfb6f46f956b
let
	p1 = Promise{Int64}() do res, rej
		sqrt(-1)
	end

	p2 = Promise{Any}() do res, rej
		p1.catch(res)
		await_settled(p1)
		yield()
		res(2)
	end

	@test fetch(p2) isa CapturedException
end

# ╔═╡ 5869262c-40fe-4752-856d-1da536e3e11a
let
	p1 = Promise{Int64}() do res, rej
		sqrt(-1)
	end

	p2 = Promise{Any}() do res, rej
		p1.catch(res)
		await_settled(p1)
		yield()
		res(-100)
	end

	@test fetch(p2) isa CapturedException
end

# ╔═╡ 3cb7964a-45bb-471e-9fca-c390e06b0fee
@test Promise{Int64}() do res, rej
	res("asdf")
end |> await_settled isa Rejected{CapturedException}

# ╔═╡ 9e27473e-91b3-4261-8033-5295d4a94426
@test Promise{Int64}() do res, rej
	@async res("asdf")
end |> await_settled isa Rejected{CapturedException}

# ╔═╡ 4d661d30-6522-4e7d-895a-786d2d776809
@test await_settled(Promise{String}((r,_) -> (sleep(.1); r("asdf")))) ===
	Resolved{String}("asdf")

# ╔═╡ fa4d6805-8b15-4c24-991c-6762d2701932
@test await_settled(Promise{Int64}((res,rej) -> rej("asdf"))) ===
	Rejected{String}("asdf")

# ╔═╡ 56e274e8-7523-45f1-bd44-5ef71d2feaf2
md"""
### Promotion, conversion
"""

# ╔═╡ 75de613a-3eb8-49e8-9f71-fc55b76cef00
@test promote_rule(Resolved{Int64}, Rejected{Float64}) ==
	PromiseSettledResult{Float64}

# ╔═╡ 497a01eb-7cf9-47b9-95bf-75f59829be36
@test promote_rule(PromiseSettledResult{Int64}, Resolved{Float64}) ==
	PromiseSettledResult{Float64}

# ╔═╡ c7ec7091-a9b3-46c8-8eaf-222b5eb7ebc2
@test promote_rule(Resolved{Int64}, Resolved{Float64}) == Resolved{Float64}

# ╔═╡ 44769580-1983-45ac-b1d5-d5ddb252f7bf
@test convert(PromiseSettledResult{Float64}, Resolved(1)) === Resolved(1.0)

# ╔═╡ 3b11ace6-cdf7-4c90-a96c-f804c3cb4e2f
md"""
### Equality, hash
"""

# ╔═╡ c9bc257b-b204-4019-ab65-9d9489cee16d
@test Resolved(1) == Resolved(1.0)

# ╔═╡ ee4c0c55-bf1d-42c8-8de1-350dd17dff7d
@test Rejected(1) == Rejected(1.0)

# ╔═╡ cc244956-78e0-4804-bc14-91c629bdf28f
@test hash(Resolved(1)) == hash(Resolved(1.0))

# ╔═╡ aa22fed7-bb22-4d52-9e64-3f4a27597f93
@test hash(Rejected(1)) == hash(Rejected(1.0))

# ╔═╡ 02edf8aa-10b3-4da9-a097-3b9dc9a7302d
@test hash(Resolved(1)) != hash(Rejected(1.0))

# ╔═╡ a0c7275b-8fcb-4c0b-b724-aa29f0b878e8
md"""
# Combining promises

We also have ports of the JavaScript functions: `Promise.all`, `Promise.any` and `Promise.reject`.
"""

# ╔═╡ 0dcba3ea-1884-4136-b9a6-42b4cbdf0c50
fetch_all(ps) = fetch.(ps)

# ╔═╡ e36ae108-ab09-4e9c-a6a1-9e596408fda0
fetch_all(ps::AbstractSet) = Set(fetch(p) for p in ps)

# ╔═╡ a0a5f687-56a6-4bc0-9e0a-6d22d0d2de47
"""
```julia
all(promises::AbstractVector{Promise})::Promise
all(promises::AbstractSet{Promise, ...})::Promise
all(promises::Tuple{Promise, Promise, ...})::Promise
```

Create a new Promise that waits for all given `promises` to resolved, and then resolves to a single vector, tuple or set with all the values.

If any of the `promises` rejects, the new Promise will also reject.


See also: 
- [`any`](@ref), which only rejects if every one of the `promises` rejects.
- [`race`](@ref), which rejects immediately if one of the `promises` rejects.

"""
function promise_all(ps)
	T = Core.Compiler.return_type(fetch_all, (typeof(ps),))
	
	Promise{T}() do res, rej
		# Attach early exit hooks to all promises:
		for p in ps
			if !isresolved(p) # (optimization)
				p.catch(rej)
			end
		end
		
		# Wait for all promises to finish
		for p in ps
			wait(p.done)
		end
		
		yield() # to allow the early exit catch hooks to fire first
		
		res(fetch_all(ps))
	end
end

# ╔═╡ 940d2947-d18c-4e1e-bc6f-0fcfd6bba63d
@test Core.Compiler.return_type(fetch_all, (Tuple{Promise{Int64},Promise{String}},)) === Tuple{Int64,String}

# ╔═╡ 860132cd-86ea-4a1d-b435-a4f8ff7672ac
@test Core.Compiler.return_type(fetch_all, (Vector{Promise{String}},)) === Vector{String}

# ╔═╡ 8c7599b5-7dd3-4a14-ae1d-e24ba6c7a0d3
@test Core.Compiler.return_type(fetch_all, (Set{Promise{String}},)) === Set{String}

# ╔═╡ ef4bf6e9-06c4-4568-b765-25107c9b994b
md"""
### Examples
"""

# ╔═╡ 6b6caae2-2aa1-424b-83df-70cb6256eef3
md"""
#### Behaviour
"""

# ╔═╡ 47ceb1bc-c95d-472b-9f08-313937ffe14b
md"""
#### Types
"""

# ╔═╡ 4383a75f-cd86-487f-a2a1-6817b5e5bdaa
md"""
## `any` & `race`
"""

# ╔═╡ fec7b7b4-d483-4f92-ac60-3a61edba1075
union_type(ps::AbstractVector{Promise{T}}) where T = T

# ╔═╡ 5da62d01-75af-487c-9727-8c924fbfe26b
union_type(ps::AbstractSet{Promise{T}}) where T = T

# ╔═╡ 8d57a295-0bd3-4a68-acbc-4069b61eb8ed
union_type(ps::Tuple) = Core.Compiler.typejoin((eltype(p) for p in ps)...)

# ╔═╡ 495ebb66-1632-4015-81db-aa7911bcbe14
union_type(ps) = Any

# ╔═╡ a881d3ee-8e26-4aba-b694-5a4a429a941c
"""
```julia
any(promises::AbstractVector{Promise})::Promise
any(promises::AbstractSet{Promise, ...})::Promise
any(promises::Tuple{Promise, Promise, ...})::Promise
```

Create a new Promise that waits for any of the given `promises` to resolve, and then resolves to that value.

If every one of the `promises` rejects, the new Promise will also reject.

See also: 
- [`race`](@ref), which rejects immediately if one of the `promises` rejects.
- [`all`](@ref), which waits for all `promises` to resolve.
"""
function promise_any(ps)
	T = union_type(ps)
	Promise{T}() do res, rej
		for p in ps
			p.then(res)
		end
		
		for p in ps
			wait(p.done)
		end
		yield()
		rej(ErrorException("All promises rejected"))
	end
end

# ╔═╡ 09fc563e-3339-4e63-89e6-4f523d201d99
"""
```julia
race(promises::AbstractVector{Promise})::Promise
race(promises::AbstractSet{Promise, ...})::Promise
race(promises::Tuple{Promise, Promise, ...})::Promise
```

Create a new Promise that waits for any of the given `promises` to **resolve or reject**, and then resolves or rejects to that value.

See also: 
- [`any`](@ref), which only rejects if every one of the `promises` rejects.
- [`all`](@ref), which waits for all `promises` to resolve.
"""
function promise_race(ps)
	T = union_type(ps)
	Promise{T}() do res, rej
		for p in ps
			p.then(res)
			p.catch(rej)
			
			# (optimization)
			if isready(p.done)
				break
			end
		end
	end
end

# ╔═╡ 627b5eac-9cd9-42f4-a7bf-6b7e5b09fd33
const Promises = (;
	resolve = function(val::T) where T
		Promise{T}((res,rej) -> res(val))
	end,
	reject = function(val::T) where T
		Promise{T}((res,rej) -> rej(val))
	end,
	all = promise_all,
	any = promise_any,
	race = promise_race,
	delay = function(delay::Real, val::T=nothing) where T
		Promise{T}() do res,rej
			sleep(delay)
			res(val)
		end
	end,
)

# ╔═╡ 649be363-e5dd-4c76-ae82-83e28e62b4f9
@testawait Promises.resolve(5).then(x -> x // 5) == 1

# ╔═╡ c4158166-b5ed-46aa-93c5-e95c77c57c6c
@testawait 50 == Promises.resolve(5.0).then(x -> x*10).catch(e -> "oops")

# ╔═╡ 4beec0e9-4c1e-4b25-9651-e00c798ed823
@testawait Promises.resolve(4) == 4

# ╔═╡ 1657bdf9-870c-4b7b-a5c4-57b53a3e1b13
let
	a, b = promote(
		Promises.resolve(1),
		Promises.resolve(3.0),
	)
	@test fetch.((a,b)) === (1.0, 3.0)
end

# ╔═╡ f0c68f85-a55d-4823-a699-ce064af29ff4
@testawait Promises.resolve(0.1).
				then(sleep).
				then(n -> n isa Nothing ? 0.2 : "what") == 0.2

# ╔═╡ 17c7f0ab-169c-4798-8f6d-afe950d10715
@test !isready(Promises.resolve(.1).then(sleep))

# ╔═╡ f0b70a1f-48d1-4593-8e36-092aebb4c92f
@test nothing === @await Promises.resolve(.1).then(sleep)

# ╔═╡ bcbb5f22-02b6-4ff6-a690-46112e25be87
@test typeof([
	Promises.resolve(1),
	Promises.resolve(3.0),
]) === Vector{Promise{Float64}}

# ╔═╡ 2efae81f-78fb-4d9f-ada6-f22beebf0f1e
@test Promises.resolve(4.0) isa Promise{Float64}

# ╔═╡ f0d96abb-16d5-45b1-a3bf-2d6e7ab96549
@test eltype(Promises.resolve(4.0)) === Float64

# ╔═╡ 3388a6bf-7718-485f-83eb-5c2bab93d283
@test await_settled(Promises.reject(1)) === Rejected{Int64}(1)

# ╔═╡ d349e559-8ad2-48a6-b949-b514399553dc
@test await_settled(Promises.resolve(1)) === Resolved{Int64}(1)

# ╔═╡ 03006230-3654-4372-9f49-367d1689c551
let
	p = Promises.all((
		Promises.resolve(1),
		Promises.reject(2),
	))
	@test await_settled(p) === Rejected(2)
end

# ╔═╡ 120e3b56-c5db-43d4-b165-de77299582e0
let
	p = Promises.all((
		Promises.delay(0.01, 1),
		Promises.delay(0.05, 2),
	))
	@test await_settled(p) === Resolved((1,2))
end

# ╔═╡ 54b64da2-bce4-4b7d-bfae-394a93996cf2
let
	p = Promises.all((
		Promises.delay(0.01, 1),
		Promise((res,rej) -> Promises.delay(0.05, 2).then(rej)),
	))
	@test await_settled(p) isa Rejected
end

# ╔═╡ cddeb7fe-4132-4663-bfe0-8fb529278490
pall1 = Promises.all((
	Promises.resolve(1),
	Promises.resolve(2),
	Promises.resolve(3.0),
))

# ╔═╡ b47b7e63-d640-459e-bb72-d51ac9eb71a9
@test pall1 isa Promise{Tuple{Int64,Int64,Float64}}

# ╔═╡ 7f2b582f-2ce9-4240-bf6b-cd2e5a139d03
@test fetch(pall1) === (1,2,3.0)

# ╔═╡ cc54d67d-ab0e-4ef8-afe9-d830ef5cc3ff
pall2 = Promises.all([
	Promises.resolve(1),
	Promises.resolve(2),
	Promises.resolve(3.0),
])

# ╔═╡ 648975e1-0791-407a-881a-c60cce7b69b0
@test pall2 isa Promise{Vector{Float64}}

# ╔═╡ 77ec04ca-c691-4ef5-9661-a9bd37b452a3
pall3 = Promises.all(Set([
	Promises.resolve(1),
	Promises.resolve(2),
	Promises.resolve(3.0),
]))

# ╔═╡ a5c33dca-d24d-41fe-9cf8-b0435fc5cf3f
@test pall3 isa Promise{Set{Float64}}

# ╔═╡ a07a14c9-13dc-43f5-9300-5358356ce1a4


# ╔═╡ aad170a6-c7e3-43c2-bac5-3cd0ff4bf770
md"""
### Examples
"""

# ╔═╡ 0e7fa174-8865-4d75-9c8c-e939165bcd66
md"""
#### Behaviour
"""

# ╔═╡ 81238018-e5dc-491d-8a8f-0964c9a76845
@testawait Promises.any((
	Promises.reject(1),
	Promises.resolve(2),
)) === 2

# ╔═╡ d1e0d545-f5d8-4fb3-866b-810e021f4a45
@test Promises.race((
	Promises.reject(1),
	Promises.resolve(2),
)) |> await_settled == Rejected(1)

# ╔═╡ 08f280ed-e949-4491-8ccc-473c519291dc
@testawait Promises.race((
	Promises.resolve(2),
	Promises.reject(1),
)) === 2

# ╔═╡ 5bafaea8-4b70-4ad6-98df-e2ea6f6e078e
@testawait Promises.any((
	Promises.delay(0.01, 1),
	Promises.delay(0.05, 2),
)) === 1

# ╔═╡ 0a61ae15-f011-49c9-8f3c-aaa01369490f
@testawait Promises.any((
	Promises.delay(0.05, 1),
	Promises.delay(0.01, 2),
)) === 2

# ╔═╡ 298da21f-1719-4635-b10a-7a879cd7fd62
@testawait Promises.any((
	Promises.delay(0.01, 1),
	Promises.delay(0.05, -2).then(sqrt),
)) === 1

# ╔═╡ 93a6be91-31af-43a7-a7b3-1e509acac2e9
@testawait Promises.any((
	Promises.delay(0.05, 1),
	Promises.delay(0.01, -2).then(sqrt),
)) === 1

# ╔═╡ 5bb6467c-8116-4c8b-8182-e246d7b96ea1
let
	p = Promises.race((
		Promises.delay(0.15, 1),
		Promises.delay(0.01, -2).then(sqrt),
	))

	@test await_settled(p) isa Rejected{CapturedException}
end

# ╔═╡ 53c28e9b-d80e-4c58-ad97-16f28fee80f9
md"""
#### Types
"""

# ╔═╡ f9bde599-294b-48fc-b9fc-acd32dfcdf2a
pany1 = Promises.any((
	Promises.resolve(1),
	Promises.resolve(2),
	Promises.resolve(3.0),
))

# ╔═╡ 8c12ef4b-b5e0-4931-8717-821705567e52
pany2 = Promises.any([
	Promises.resolve(1),
	Promises.resolve(2),
	Promises.resolve(3.0),
])

# ╔═╡ 602b0ca7-f658-417f-aecf-df976122acac
pany3 = Promises.any(Set([
	Promises.resolve(1),
	Promises.resolve(2),
	Promises.resolve(3.0),
]))

# ╔═╡ 1eba6534-f9fb-49b4-bba6-bb6ff6edb616
@test pany1 isa Promise{Real}

# ╔═╡ f73c6b96-de7e-4b9e-945f-4882615b34a3
@test pany2 isa Promise{Float64}

# ╔═╡ 2403cff6-1aa7-47a6-a030-693dd0b89921
@test pany3 isa Promise{Float64}

# ╔═╡ 490ff94f-07e5-435e-8269-bdc2c917bce0
@test fetch(pany1) === 1

# ╔═╡ faca7d88-bcb8-43e3-9cce-20a65061b8d6
@test fetch(pany2) === 1.0

# ╔═╡ b0e0fdf9-7535-45b0-ac85-2c9fdaa28677
@test fetch(pany3) ∈ 1:3

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AbstractPlutoDingetjes = "6e696c72-6542-2067-7265-42206c756150"
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
Downloads = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
PlutoTest = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"

[compat]
AbstractPlutoDingetjes = "~1.1.4"
BenchmarkTools = "~1.3.1"
HypertextLiteral = "~0.9.3"
JSON = "~0.21.3"
PlutoTest = "~0.2.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0"
manifest_format = "2.0"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "4c10eee4af024676200bc7752e536f858c6b8f93"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.1"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "85b5da0fa43588c75bb1ff986493443f821c70b7"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.2.3"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PlutoTest]]
deps = ["HypertextLiteral", "InteractiveUtils", "Markdown", "Test"]
git-tree-sha1 = "cd214d5c737563369887ac465a6d3c0fd7c1f854"
uuid = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
version = "0.2.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─da12a2c8-a631-4da8-be4e-87cc1e1f124c
# ╟─f0567e34-6fb8-4509-80e7-532e0464f1bd
# ╟─1cf696fd-6fa4-4e93-8132-63d89d902f95
# ╠═7aef0b5c-dd09-47d3-a08f-81cce84d7ca6
# ╟─7e24cd7d-6f1c-47e2-b0a3-d8f81a4e7167
# ╠═d22278fd-33cb-4dad-ad5f-d6d067c33403
# ╟─82f259ca-0e35-4278-ac46-aed2fdb87857
# ╠═f9fad7ff-cf6f-43eb-83bd-efc0cb6cde65
# ╟─8a1a621d-b94c-45ee-87b9-6ac2faa3f877
# ╠═42c6edee-d43a-40cd-af4f-3d572a6b5e9a
# ╟─ab37c026-963b-46d2-bc51-56e36eb3b06b
# ╠═d8aa3fed-78f0-417a-8e47-849ec62fa056
# ╠═80f73d5a-ecd7-414f-b99c-e9ce4ba8bd60
# ╟─e7f81212-e7f5-4133-8bfe-a4997c7d1bbb
# ╠═34364f4d-e257-4c22-84ee-d8786a2c377c
# ╟─f14c4a43-2f2f-4390-ad4d-940b1926cfb3
# ╠═acfae6b5-947a-4648-99ba-bcd2dd3afbca
# ╟─038949f4-3f99-496e-a3c7-f980f2fa92d2
# ╠═66b2b18a-2afe-4607-8982-647681ff9816
# ╟─bdb0e349-b043-4a07-9dc8-1f2ea587ac2f
# ╟─34d6da04-daa8-484b-bb30-2bf2ee55da9d
# ╠═959d2e3e-1ef6-4a97-a748-31b0b5ece938
# ╟─ae4e308e-83be-4e0b-a0a4-96677dcffa22
# ╠═9d9179de-19b1-4f40-b816-454a8c071c3d
# ╟─74cdad42-7f54-4da3-befe-a67c969217ae
# ╠═f0b73769-dea5-4dfa-8a39-ebf6584abbf5
# ╟─580d9608-fb50-4845-b3b2-4195cdb41d67
# ╠═8ab41c7c-b180-473e-bd55-a904f9af6f2c
# ╠═e85d9bc8-9c4e-44eb-8cf6-903cc71d050f
# ╟─530e9bf7-bd09-4978-893a-c945ca15e508
# ╠═8e818b32-6823-47b7-aa35-ac4ee9b9afd2
# ╠═8162b1b4-4e61-4f39-9fd7-d16695f138a3
# ╠═0a8b61aa-b703-4c8e-baa1-c3bb82d468fe
# ╟─49a8beb7-6a97-4c46-872e-e89822108f39
# ╟─627b5eac-9cd9-42f4-a7bf-6b7e5b09fd33
# ╟─8e13e697-e29a-473a-ac11-30e0199be5bb
# ╟─649be363-e5dd-4c76-ae82-83e28e62b4f9
# ╟─c4158166-b5ed-46aa-93c5-e95c77c57c6c
# ╟─4beec0e9-4c1e-4b25-9651-e00c798ed823
# ╟─1657bdf9-870c-4b7b-a5c4-57b53a3e1b13
# ╟─f0c68f85-a55d-4823-a699-ce064af29ff4
# ╟─8ac00844-24e5-416d-aa31-28242e4ee6a3
# ╟─b9368cf7-cbcd-4b54-9390-78e8c88f064c
# ╟─cb47c8c9-2872-4e35-9939-f953319e1acb
# ╟─6a84cdd0-f57e-4535-bc16-24bc40018033
# ╟─a0534c86-5cd6-456a-93a6-19292b5879d6
# ╟─be56fd49-7898-4171-8837-8c1b251cdeba
# ╟─6bb08e1c-bfe9-40c7-92b5-5c71aba040dd
# ╟─a8a07647-2b61-4401-a04d-0921a6bcec76
# ╟─9aa052ef-5f60-4935-94d1-a4cbc5096d46
# ╟─2b6e41af-c9e9-4774-a6f5-51c301705a10
# ╟─1ef3378e-62ac-463b-b8c0-dfb6f46f956b
# ╟─5869262c-40fe-4752-856d-1da536e3e11a
# ╟─51ef3992-d6a7-4b46-970c-6b075d14fb71
# ╟─3cb7964a-45bb-471e-9fca-c390e06b0fee
# ╟─9e27473e-91b3-4261-8033-5295d4a94426
# ╟─5d943937-2271-431c-8fc0-4f963aa4dda0
# ╟─40c9f96a-41e9-496a-b174-490b72927626
# ╟─3f97f5e7-208a-44dc-9726-1923fd8c824b
# ╟─17c7f0ab-169c-4798-8f6d-afe950d10715
# ╟─f0b70a1f-48d1-4593-8e36-092aebb4c92f
# ╟─c68ab4c1-6384-4802-a9a6-697a63d3488e
# ╟─9ee2e123-7a24-46b2-becf-2d011abdcb19
# ╟─58533024-ea65-4bce-b32a-727a804d1f4d
# ╟─bcbb5f22-02b6-4ff6-a690-46112e25be87
# ╟─2efae81f-78fb-4d9f-ada6-f22beebf0f1e
# ╟─f0d96abb-16d5-45b1-a3bf-2d6e7ab96549
# ╟─5447d12d-7aa5-47f3-bf04-2516a8974bb9
# ╠═38e9d7e0-1e3b-4a71-9065-b0e17e39765a
# ╠═55fb60c1-b48b-4f0a-a24c-dcc2d7f0af4b
# ╠═10bfce78-782d-49a1-9fc8-6b2ac5d16831
# ╠═5bb55103-bd26-4f30-bed6-026b003617b7
# ╠═287f91b6-a602-457a-b32b-e0c22f15d514
# ╠═371cede0-6f01-496a-8059-e110dbfc8d05
# ╟─06a3eb82-0ffd-4c89-8161-d0f385c2a32e
# ╠═939c6e86-ded8-4b15-890b-80207e8d692a
# ╠═a854b9e6-1a82-401e-90d5-f05ffaadae61
# ╟─eb4e90d9-0e21-4f06-842d-4260f074f097
# ╟─a5b9e007-0282-4eb6-88dd-34855fe42fa4
# ╟─3388a6bf-7718-485f-83eb-5c2bab93d283
# ╟─d349e559-8ad2-48a6-b949-b514399553dc
# ╟─4d661d30-6522-4e7d-895a-786d2d776809
# ╟─fa4d6805-8b15-4c24-991c-6762d2701932
# ╟─8f37aee7-b5e0-44e3-a6d0-fbbb5b88f3ef
# ╟─7c9b31e6-cb90-4734-bf7b-6c7f0337ac62
# ╟─27876191-a023-49e9-bb3a-d3b3f10090d8
# ╟─56e274e8-7523-45f1-bd44-5ef71d2feaf2
# ╟─75de613a-3eb8-49e8-9f71-fc55b76cef00
# ╟─497a01eb-7cf9-47b9-95bf-75f59829be36
# ╟─c7ec7091-a9b3-46c8-8eaf-222b5eb7ebc2
# ╟─44769580-1983-45ac-b1d5-d5ddb252f7bf
# ╟─3b11ace6-cdf7-4c90-a96c-f804c3cb4e2f
# ╟─c9bc257b-b204-4019-ab65-9d9489cee16d
# ╟─ee4c0c55-bf1d-42c8-8de1-350dd17dff7d
# ╟─cc244956-78e0-4804-bc14-91c629bdf28f
# ╟─aa22fed7-bb22-4d52-9e64-3f4a27597f93
# ╟─02edf8aa-10b3-4da9-a097-3b9dc9a7302d
# ╟─a0c7275b-8fcb-4c0b-b724-aa29f0b878e8
# ╟─a0a5f687-56a6-4bc0-9e0a-6d22d0d2de47
# ╟─0dcba3ea-1884-4136-b9a6-42b4cbdf0c50
# ╟─e36ae108-ab09-4e9c-a6a1-9e596408fda0
# ╟─940d2947-d18c-4e1e-bc6f-0fcfd6bba63d
# ╟─860132cd-86ea-4a1d-b435-a4f8ff7672ac
# ╟─8c7599b5-7dd3-4a14-ae1d-e24ba6c7a0d3
# ╟─ef4bf6e9-06c4-4568-b765-25107c9b994b
# ╟─6b6caae2-2aa1-424b-83df-70cb6256eef3
# ╟─03006230-3654-4372-9f49-367d1689c551
# ╟─120e3b56-c5db-43d4-b165-de77299582e0
# ╟─54b64da2-bce4-4b7d-bfae-394a93996cf2
# ╟─47ceb1bc-c95d-472b-9f08-313937ffe14b
# ╠═cddeb7fe-4132-4663-bfe0-8fb529278490
# ╠═cc54d67d-ab0e-4ef8-afe9-d830ef5cc3ff
# ╠═77ec04ca-c691-4ef5-9661-a9bd37b452a3
# ╟─b47b7e63-d640-459e-bb72-d51ac9eb71a9
# ╟─648975e1-0791-407a-881a-c60cce7b69b0
# ╟─a5c33dca-d24d-41fe-9cf8-b0435fc5cf3f
# ╟─7f2b582f-2ce9-4240-bf6b-cd2e5a139d03
# ╟─4383a75f-cd86-487f-a2a1-6817b5e5bdaa
# ╟─a881d3ee-8e26-4aba-b694-5a4a429a941c
# ╟─09fc563e-3339-4e63-89e6-4f523d201d99
# ╟─fec7b7b4-d483-4f92-ac60-3a61edba1075
# ╟─5da62d01-75af-487c-9727-8c924fbfe26b
# ╟─8d57a295-0bd3-4a68-acbc-4069b61eb8ed
# ╟─495ebb66-1632-4015-81db-aa7911bcbe14
# ╟─a07a14c9-13dc-43f5-9300-5358356ce1a4
# ╟─aad170a6-c7e3-43c2-bac5-3cd0ff4bf770
# ╟─0e7fa174-8865-4d75-9c8c-e939165bcd66
# ╟─81238018-e5dc-491d-8a8f-0964c9a76845
# ╟─d1e0d545-f5d8-4fb3-866b-810e021f4a45
# ╟─08f280ed-e949-4491-8ccc-473c519291dc
# ╟─5bafaea8-4b70-4ad6-98df-e2ea6f6e078e
# ╟─0a61ae15-f011-49c9-8f3c-aaa01369490f
# ╟─298da21f-1719-4635-b10a-7a879cd7fd62
# ╟─93a6be91-31af-43a7-a7b3-1e509acac2e9
# ╟─5bb6467c-8116-4c8b-8182-e246d7b96ea1
# ╟─53c28e9b-d80e-4c58-ad97-16f28fee80f9
# ╠═f9bde599-294b-48fc-b9fc-acd32dfcdf2a
# ╠═8c12ef4b-b5e0-4931-8717-821705567e52
# ╠═602b0ca7-f658-417f-aecf-df976122acac
# ╟─1eba6534-f9fb-49b4-bba6-bb6ff6edb616
# ╟─f73c6b96-de7e-4b9e-945f-4882615b34a3
# ╟─2403cff6-1aa7-47a6-a030-693dd0b89921
# ╟─490ff94f-07e5-435e-8269-bdc2c917bce0
# ╟─faca7d88-bcb8-43e3-9cce-20a65061b8d6
# ╟─b0e0fdf9-7535-45b0-ac85-2c9fdaa28677
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
