### A Pluto.jl notebook ###
# v0.16.0

using Markdown
using InteractiveUtils

# ╔═╡ a3c6ddb8-2797-11ec-3e15-c1ec8b2dbab9
using HTTP, Gumbo, Cascadia, DataFrames

# ╔═╡ 841489eb-370c-44aa-a2d5-e8cb8c38802b
md"
## Pkg environment
"

# ╔═╡ cce116c5-b462-4dc7-9078-1d0c73f6366c
md"
## List of working URLs 
"

# ╔═╡ 60d35021-5a35-4f10-934c-fe7098ea8821
md"
### AH
"

# ╔═╡ 8b519d18-3c9a-444a-bb5a-2cbee34aef17
url_ah_fruits = "https://www.ah.nl/producten/aardappel-groente-fruit/fruit"

# ╔═╡ c589f745-76da-4c14-9b9a-54e776e660ee
url_ah_veggies = "https://www.ah.nl/producten/aardappel-groente-fruit/groente"

# ╔═╡ 5e3b9d9c-6f6b-4cee-8f93-ecebc96e28d9
url_ah_potatoes = "https://www.ah.nl/producten/aardappel-groente-fruit/aardappelen"

# ╔═╡ a7080d10-8d94-4891-89da-b4e304e8e421
md"
### Jumbo
"

# ╔═╡ 6f86c5d3-5aec-4f4a-9730-735be5c7aa14
url_jum_veggies = "https://www.jumbo.com/producten/groente/"

# ╔═╡ c19c4dfa-9488-42d0-a84a-8b81c313003a
url_jum_fruits = "https://www.jumbo.com/producten/fruit/"

# ╔═╡ ebac1a90-a601-424c-95aa-7d9de0274e4d
md"
### Coop
"

# ╔═╡ 935e725d-ea1c-45b0-9f29-3689d88bade0
url_coop_veggies = "https://www.coop.nl/categorie/boodschappen.groenten?filters=CategoryNameLevel1%3DGroenten%26productFilter%3Dfallback_searchquerydefinition%26category%3Dboodschappen%2Fgroenten&page=1"

# ╔═╡ 7bd04ca0-2cb8-447d-be91-a02077e9d67c
md"
### Parse html data
"

# ╔═╡ af6cfb49-2d39-4093-a3c3-1d8b4585e63f
response = HTTP.get(url_coop_veggies)

# ╔═╡ b54aac32-8de7-4524-b425-13fcba806d54
response_parsed = parsehtml(String(response.body))

# ╔═╡ 15159d7c-d6ac-4d74-bf9c-355eb20e8b9d
md"
## Scrape for relevant data
"

# ╔═╡ 6441dcc9-7a0a-4ff4-b1d6-d4bd1f4aa00f
md"
#### Get product name, quantity and price from AH
"

# ╔═╡ ddf8e963-d545-4344-9876-e5eb54835b94
function parse_and_match(url::String, match::String)
	
	# Get response data	
	response = HTTP.get(url)
	
	# Parse response data using Gumbo.jl	
	response_parsed = parsehtml(String(response.body))
	
	# Match class using Cascadia.jl
	# Look for names and prices of fruits
	class_match = eachmatch(Selector(match), response_parsed.root)
	
	return class_match
	
end	

# ╔═╡ 82cc3715-2d81-47f1-8513-a13e4c27dc85
function get_ah_data(url::String, match::String=".product-card-landscape_root__1tx-c")
	
	class_match = parse_and_match(url, match)
	
	product_names, product_quantity = [String[] for i = 1:2]
	product_price = Float64[]
	
	
	for i = 1:length(class_match)
		
		article = class_match[i]
		
		# Get name of the product
		title = getattr(article[1][1][1][1], "title")
		push!(product_names, title)
		
		# Get price of the product		
		index = length(children(article))
		price = article[index][2][1][1]
		
		price_string = ""
		
		for j = 1:length(children(price))		
			price_string = price_string * text(price[j])
		end
		
	    price_value = parse(Float64, price_string)
		
		push!(product_price, price_value)
		
		# Get quantity of the product
		quantity = text(article[index][2][1][2])
		push!(product_quantity, quantity)		
	end
		
	df_ah_data = DataFrame(Name = product_names, Quantity = product_quantity, 
		                  Price = product_price)
	
	return df_ah_data
	
end

# ╔═╡ 91ab065f-0e81-42c4-9fc7-352f77559f08
get_ah_data(url_ah_fruits)

# ╔═╡ 52bfc6a7-9c28-41f2-b7a7-a7af86e31ae2
get_ah_data(url_ah_veggies)

# ╔═╡ 6a579e1c-b60a-4598-8a3b-658918bfaa6e
get_ah_data(url_ah_potatoes);

# ╔═╡ 7c1e8de6-a10e-43b4-939a-b1544eb0f9de
md"
#### Get product name, quantity and price from Jumbo
"

# ╔═╡ 727e6fe0-8477-4933-a228-d0172a01cff8
function get_jumbo_data(url::String, match::String=".product-container")
	
	class_match = parse_and_match(url, match)
	
	product_names, product_quantity = [String[] for i = 1:2]
	product_price = Float64[]
	
	for i = 1:length(class_match)
		
		article = class_match[i]
		
		# Get product names		
		try
			alt = getattr(article[2][1][1], "alt")
			push!(product_names, alt)
		catch e
			if isa(e, KeyError)
				continue
			else
				@info "This is a new error: $(e)"
			end
		end
		
		# Get price data
		price = text(article[3][3][1][1])
		push!(product_price, parse(Float64, price))		
	end
	
	# Get quantity data from product names
	for i = 1:length(product_names)
		if occursin(r"[0-9]+g", product_names[i]) || 
		   occursin(r"[0-9]+kg", product_names[i])

			quantity = split(product_names[i], " ")[end]
			push!(product_quantity, quantity)
		else
			push!(product_quantity, "per stuk")
		end
	end		
	
	df_jum_data = DataFrame(Name = product_names, Quantity = product_quantity, 
		                  Price = product_price)
	
	return df_jum_data
end

# ╔═╡ d4dd1f81-e7a7-4bce-84fc-e24148fa9206
get_jumbo_data(url_jum_veggies)

# ╔═╡ 44343331-3f39-4c71-9e81-f94ab589c06c
get_jumbo_data(url_jum_fruits)

# ╔═╡ 073d5b53-4e8f-41fe-97bc-3c527f9242f7
md"
#### Get product name, quantity and price from Coop
"

# ╔═╡ 7eb3fb16-8bcf-483b-a7de-d49f9e58a8dd
response_parsed.root

# ╔═╡ cfc7981e-c7f8-4a0e-bdd9-3671af9ec02a
class_match = eachmatch(Selector(".product-card__info"), response_parsed.root)

# ╔═╡ 9318419e-a64e-44e9-acfa-03aa88d85600
card = class_match[5]

# ╔═╡ de1909a3-1c3c-4c51-8279-4794940b404d
function get_coop_data(url::String, match::String=".product-card__info")
	
	class_match = parse_and_match(url, match)
	
	product_names, product_quantity = [String[] for i = 1:2]
	product_price = Float64[]
	
	for i = 1:length(class_match)
		
		card = class_match[i]
		
		# Get product names		
		try
			name = text(card[1][1][1])
			push!(product_names, name)
		catch e
			@info "This is a new error: $(e)"			
		end
		
		# Get price data
		part1 = replace(text(card[3][1][1][1][1]), "," => ".")
		part2 = text(card[3][1][1][1][2][1])
		
		price = part1 * part2
		push!(product_price, parse(Float64, price))	
		
		# Get quantity data
		quantity = text(card[2][1])
		push!(product_quantity, quantity)
	
	end
	
	df_coop_data = DataFrame(Name = product_names, Quantity = product_quantity, 
		                  Price = product_price)
	
	return df_coop_data
end

# ╔═╡ 61f28512-56b0-4728-85c4-1d7654ab55c2
get_coop_data(url_coop_veggies)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Cascadia = "54eefc05-d75b-58de-a785-1a3403f0919f"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Gumbo = "708ec375-b3d6-5a57-a7ce-8257bf98657a"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"

[compat]
Cascadia = "~1.0.1"
DataFrames = "~1.2.2"
Gumbo = "~0.8.0"
HTTP = "~0.9.14"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractTrees]]
git-tree-sha1 = "03e0550477d86222521d254b741d470ba17ea0b5"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.3.4"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Cascadia]]
deps = ["AbstractTrees", "Gumbo"]
git-tree-sha1 = "95629728197821d21a41778d0e0a49bc2d58ab9b"
uuid = "54eefc05-d75b-58de-a785-1a3403f0919f"
version = "1.0.1"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "4866e381721b30fac8dda4c8cb1d9db45c8d2994"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.37.0"

[[Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[DataAPI]]
git-tree-sha1 = "bec2532f8adb82005476c141ec23e921fc20971b"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.8.0"

[[DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "d785f42445b63fc86caa08bb9a9351008be9b765"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.2.2"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[Gumbo]]
deps = ["AbstractTrees", "Gumbo_jll", "Libdl"]
git-tree-sha1 = "e711d08d896018037d6ff0ad4ebe675ca67119d4"
uuid = "708ec375-b3d6-5a57-a7ce-8257bf98657a"
version = "0.8.0"

[[Gumbo_jll]]
deps = ["Libdl", "Pkg"]
git-tree-sha1 = "86111f5523d7c42da0edd85ef7999c663881ac1e"
uuid = "528830af-5a63-567c-a44a-034ed33b8444"
version = "0.10.1+1"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "60ed5f1643927479f845b0135bb369b031b541fa"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.14"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a193d6ad9c45ada72c14b731a318bedd3c2f00cf"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.3.0"

[[PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "0d1245a357cc61c8cd61934c07447aa569ff22e6"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.1.0"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "1162ce4a6c4b7e31e0e6b14486a6986951c73be9"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.5.2"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─841489eb-370c-44aa-a2d5-e8cb8c38802b
# ╠═a3c6ddb8-2797-11ec-3e15-c1ec8b2dbab9
# ╟─cce116c5-b462-4dc7-9078-1d0c73f6366c
# ╟─60d35021-5a35-4f10-934c-fe7098ea8821
# ╠═8b519d18-3c9a-444a-bb5a-2cbee34aef17
# ╠═c589f745-76da-4c14-9b9a-54e776e660ee
# ╠═5e3b9d9c-6f6b-4cee-8f93-ecebc96e28d9
# ╟─a7080d10-8d94-4891-89da-b4e304e8e421
# ╠═6f86c5d3-5aec-4f4a-9730-735be5c7aa14
# ╠═c19c4dfa-9488-42d0-a84a-8b81c313003a
# ╟─ebac1a90-a601-424c-95aa-7d9de0274e4d
# ╠═935e725d-ea1c-45b0-9f29-3689d88bade0
# ╟─7bd04ca0-2cb8-447d-be91-a02077e9d67c
# ╠═af6cfb49-2d39-4093-a3c3-1d8b4585e63f
# ╠═b54aac32-8de7-4524-b425-13fcba806d54
# ╟─15159d7c-d6ac-4d74-bf9c-355eb20e8b9d
# ╟─6441dcc9-7a0a-4ff4-b1d6-d4bd1f4aa00f
# ╟─ddf8e963-d545-4344-9876-e5eb54835b94
# ╟─82cc3715-2d81-47f1-8513-a13e4c27dc85
# ╠═91ab065f-0e81-42c4-9fc7-352f77559f08
# ╠═52bfc6a7-9c28-41f2-b7a7-a7af86e31ae2
# ╠═6a579e1c-b60a-4598-8a3b-658918bfaa6e
# ╟─7c1e8de6-a10e-43b4-939a-b1544eb0f9de
# ╟─727e6fe0-8477-4933-a228-d0172a01cff8
# ╠═d4dd1f81-e7a7-4bce-84fc-e24148fa9206
# ╠═44343331-3f39-4c71-9e81-f94ab589c06c
# ╟─073d5b53-4e8f-41fe-97bc-3c527f9242f7
# ╠═7eb3fb16-8bcf-483b-a7de-d49f9e58a8dd
# ╠═cfc7981e-c7f8-4a0e-bdd9-3671af9ec02a
# ╠═9318419e-a64e-44e9-acfa-03aa88d85600
# ╟─de1909a3-1c3c-4c51-8279-4794940b404d
# ╠═61f28512-56b0-4728-85c4-1d7654ab55c2
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
