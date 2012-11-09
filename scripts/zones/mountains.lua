--add_interceptor("/trapper.php", function()
--	if not setting_enabled("automate simple tasks") then return end
--	if input_params == "[]" then
--		-- TODO: revisit, handle familiar equipment locking
--		local famid = familiarid()
--		get_page("/familiar.php", { action = "newfam", ajax = 1, newfam = 72 }) -- parrot
--		text, url = get_page(requestpath)
--		get_page("/familiar.php", { action = "newfam", ajax = 1, newfam = famid })
--		return text, url
--	end
--end)


-- itznotyerzitz mine

add_choice_text("A Flat Miner", { -- choice adventure number: 18
	["Loot the dwarf's belongings"] = { getitem = "miner's pants" },
	["Hijack the Meat vein"] = { getitem = "7-Foot Dwarven mattock" },
	["Help the dwarf"] = { getmeat = 100 },
})

add_choice_text("100% Legal", { -- choice adventure number: 19
	["Demand loot"] = { getitem = "miner's helmet" },
	["Ask for ore"] = { getitem = "miner's pants" },
	["Say you'll keep quiet for free"] = { getmeat = 100 },
})

add_choice_text("See You Next Fall", { -- choice adventure number: 20
	["Give 'im the stick"] = { getitem = "miner's helmet" },
	["DOOOOON'T GIVE 'IM THE STICK!"] = { getitem = "7-Foot Dwarven mattock" },
	["Negotiate for a reward"] = { getmeat = 100 },
})

add_choice_text("More Locker Than Morlock", { -- choice adventure number: 556
	["Open the locka'"] = { text = "Get a piece of mining gear" },
	["Get to the choppa' (which is outside)"] = { leave_noturn = true },
})

add_processor("/mining.php", function()
	if not params.mine then return end
	if not text:contains("mining.php") then return end
	mine = params.mine:match("([0-9]+)")
	if mine then
		stateid = "mining.results." .. mine
		tbl = ascension[stateid] or {}
		tabletext = text:match([[<table cellpadding=0 cellspacing=0 border=0 background='http://images.kingdomofloathing.com/otherimages/mine/mine_background.gif'>(.-)</table>]])
		if not tabletext then return end
		local id = -1
		for celltext in tabletext:gmatch([[<td[^>]*>(.-)</td>]]) do
			id = id + 1
			image, title, height, width = celltext:match([[<img src='(http://images.kingdomofloathing.com/otherimages/mine/[a-z0-9]+.gif)' alt='[^']+' title='([^']+)' border=0 height=(50) width=(50)>]])
			if image then
				if image:match("wall1111.gif") or image:match("wallsparkle") then
					tbl[id] = nil
				end
			end
		end
		ascension[stateid] = tbl
	end
	which = query:match("which=([0-9]+)")
	resulttext = text:match([[<table *width=95%% *cellspacing=0 cellpadding=0><tr><td style="color: white;" align=center bgcolor=blue.-><b>Results:</b>(.-)<table *width=95%% *cellspacing=0 cellpadding=0><tr><td style="color: white;" align=center bgcolor=blue.-><b>]])
	if resulttext then
		img = resulttext:match([[<img src="http://images.kingdomofloathing.com/itemimages/([^"]+).gif"]])
		if mine and img then
			stateid = "mining.results." .. mine
			tbl = ascension[stateid] or {}
			tbl[tonumber(which)] = img
			ascension[stateid] = tbl
		end
	end
end)

add_processor("/place.php", function ()
	if params.action == "trappercabin" then
		local wantore = text:match([[some dagburned ([a-z]-) ore]]) or text:match([[bring me that cheese and ([a-z]-) ore]])
		if wantore then
			ascension["trapper.ore"] = wantore
		end
	end
end)

local function get_mine_curtbl(minetext)
	local orechars = { aore = "2", core = "3", lore = "1", baconstone = "8" }
	local remap_id = {}
	local remap_id_inverse = {}
	for y = 0, 5 do
		for x = 1, 6 do
			remap_id[8 + y * 8 + x] = y * 6 + x
			remap_id_inverse[y * 6 + x] = 8 + y * 8 + x
		end
	end
	local x = minetext:match([[<table cellpadding=0 cellspacing=0 border=0 background='http://images.kingdomofloathing.com/otherimages/mine/mine_background.gif'>(.-)</table>]])
	local id = -1
	local curtbl = {}
	local can_mine_next = {}
	local already_mined = {}
	for celltext in x:gmatch([[<td[^>]*>(.-)</td>]]) do
		id = id + 1
		image, title, height, width = celltext:match([[<img src='(http://images.kingdomofloathing.com/otherimages/mine/[a-z0-9]+.gif)' alt='[^']+' title='([^']+)' border=0 height=(50) width=(50)>]])
		linkdata = celltext:match([[<a href='mining.php%?mine=[0-9]+&which=[0-9]+&pwd=[0-9a-f]+'>]])
		if image then
			if linkdata then
-- 				print("link", id, remap_id[id])
				can_mine_next[id] = true
				if title:contains("Promising") or image:contains("spark") then
					curtbl[id] = "!"
				else
					curtbl[id] = "0"
				end
			else
				if tbl[id] then -- and alt == "Open Cavern" 
					curtbl[id] = orechars[tbl[id]] or "0"
				elseif not image:match("wall1111.gif") and not image:match("wallsparkle") then
					already_mined[id] = true
					curtbl[id] = "0"
				else
					curtbl[id] = "?"
				end
			end
		end
	end
	return curtbl
end

local mine_data = nil

local function compute_mine_spoiler(minetext)
	local what_do_we_want = nil
	if ascension["trapper.ore"] then
		local trapper_wants = { asbestos = "a", chrome = "c", linoleum = "l" }
		what_did_we_want = trapper_wants[ascension["trapper.ore"]]
		if count(ascension["trapper.ore"] .. " ore") < 3 then
			what_do_we_want = trapper_wants[ascension["trapper.ore"]]
		end
	end
	if not what_do_we_want then
		return nil
	end
	local curtbl = get_mine_curtbl(minetext)
-- 	print("DEBUG curtbl:", curtbl)
	local curmine = ""
	for _, i in ipairs {
			 9, 10, 11, 12, 13, 14,
			17, 18, 19, 20, 21, 22,
			25, 26, 27, 28, 29, 30,
			33, 34, 35, 36, 37, 38 } do
		curmine = curmine .. curtbl[i]
	end
	if curmine:len() ~= 24 then
		error "Error parsing mine, did not find the 24 expected tiles"
	end
-- 	print("curmine", curmine)
	-- TODO: count number of non-ore sparkles found for probability calculations
	local function is_compatible(mine)
		for i = 1, 24 do
			local wehave = curmine:sub(i, i)
			local minehas = mine:sub(i, i)
			if wehave == "?" then
			elseif wehave == "!" then
			elseif wehave ~= minehas then
-- 				print("check", i, "|", wehave, minehas)
				return false
			end
		end
		return true
	end
	mine_data = nil -- DEBUG HACK, TODO: REMOVE
	if not mine_data then
		mine_data = {}
		for l in io.lines("mine-output-sample") do
			local a, b = l:match("^(.*): (.*)$")
			mine_data[a] = tonumber(b)
		end
	end
	local p_sum = 0
	local ps = {}
	local filledness = 0
	local totalness = 0
	for a, b in pairs(mine_data) do
		totalness = totalness + 1
		if is_compatible(a) then
			filledness = filledness + 1
			for i = 1, 24 do
				if a:sub(i, i) == "1" then
					ps[i] = (ps[i] or 0) + b
				end
			end
			p_sum = p_sum + b
		else
			mine_data[a] = nil
		end
	end
	print("DEBUG filled total", filledness, totalness, filledness / totalness)
-- 	print("p_sum", p_sum)
-- 	for y = 0, 3 do
-- 		local tbl = {}
-- 		for x = 1, 6 do
-- 			local i = y * 6 + x
-- 			table.insert(tbl, (ps[i] or 0) / p_sum)
-- 		end
-- 		print(table.concat(tbl, ", "))
-- 	end

	local retps = {}
	if p_sum > 0 then
		for i_idx, i in ipairs {
			 9, 10, 11, 12, 13, 14,
			17, 18, 19, 20, 21, 22,
			25, 26, 27, 28, 29, 30,
			33, 34, 35, 36, 37, 38 } do
				retps[i] = (ps[i_idx] or 0) / p_sum
		end
	end
	if true then return retps end -- DEBUG
	local num_matches = 0
	local ores = {}
	for i = 1, 24 do
		ores[i] = { a = 0, c = 0, l = 0, d = 0, ["."] = 0 }
	end
	local function check(layout)
		for x = 1, curmine:len() do
			local want = curmine:sub(x, x)
			if want == "?" then
			elseif want == layout:sub(x, x) then
			else
				return false
			end
		end
-- 		print("..", layout)
		for x = 1, layout:len() do
			local y = layout:sub(x, x)
			ores[x][y] = ores[x][y] + 1
		end
		num_matches = num_matches + 1
		return true
	end
	local approx_distances = {}
	for xr, _ in pairs(can_mine_next) do
		local x = remap_id[xr]
		if x then
			approx_distances[x] = 0
		end
	end
	local function approx_min_distance(l, tile)
		local found = {}
		for x, _ in pairs(already_mined) do
			local c = remap_id[x]
			if c then
				if l:sub(c,c) == what_do_we_want then
					found[c] = true
				end
			end
		end
		local function get_xy(i)
			i = i - 1
			local y = math.floor(i / 6)
			local x = i - y * 6
			return x, y
		end
		local function mine_distance(a, b)
			x1, y1 = get_xy(a)
			x2, y2 = get_xy(b)
			return math.abs(x1 - x2) + math.abs(y1 - y2)
		end
		local nearest = 1000
		for x = 1, l:len() do
			local y = l:sub(x, x)
			if y == what_do_we_want and not found[x] then
				local dist = mine_distance(tile, x)
-- 				print("dist", x, table_to_str(found))
				nearest = math.min(nearest, dist)
			end
		end
-- 		print("nearest", nearest)
		return nearest
	end
	for l in io.lines("mine-layouts.txt") do
		for _, mapping in ipairs(remappings) do
			local l_remapped = ""
			for x = 1, l:len() do
				l_remapped = l_remapped .. mapping[l:sub(x,x)]
			end
			if check(l_remapped) then
				for xr, _ in pairs(can_mine_next) do
					local x = remap_id[xr]
-- 					print("xr", xr, remap_id[xr])
					if x then
-- 						print("approx", x, approx_min_distance(l_remapped, x))
						approx_distances[x] = approx_distances[x] + approx_min_distance(l_remapped, x)
					end
				end
			end
		end
	end
	for y = 0, 3 do
		local line = ""
		for x = 1, 6 do
			local c = y * 6 + x
			line = line .. string.format("%10.2f%%", ores[c][what_do_we_want] * 100.0 / num_matches)
		end
		print(line)
	end
	local best_dist = -1
	for y = 0, 5 do
-- 		local line = ""
		for x = 1, 6 do
			local c = y * 6 + x
			if approx_distances[c] then
				if (best_dist == -1 or approx_distances[c] < best_dist) and (approx_distances[c] >= 0 and approx_distances[c] < 1000000000) and (num_matches >= 20) then
					best_dist = approx_distances[c]
					best_which = remap_id_inverse[c]
				end
			end
-- 			line = line .. string.format("[%2d|%10d]", c, approx_distances[c] or -1)
		end
-- 		print(line)
	end
	print("best", best_which, best_dist)
	return best_which, what_did_we_want
end

local mining_ids = {
	 [9] = 0, [10] = 1, [11] = 0, [12] = 1, [13] = 0, [14] = 1,
	[17] = 1, [18] = 0, [19] = 1, [20] = 0, [21] = 1, [22] = 0,
	[25] = 0, [26] = 1, [27] = 0, [28] = 1, [29] = 0, [30] = 1,
	[33] = 1, [34] = 0, [35] = 1, [36] = 0, [37] = 1, [38] = 0,
	[41] = 0, [42] = 1, [43] = 0, [44] = 1, [45] = 0, [46] = 1,
	[49] = 1, [50] = 0, [51] = 1, [52] = 0, [53] = 1, [54] = 0,
}

add_printer("/mining.php", function ()
	if not params.mine then return end
	if not text:contains("mining.php") then return end
	mine = params.mine:match("([0-9]+)")
	if mine then
		stateid = "mining.results." .. mine
		tbl = ascension[stateid] or {}
	else
		tbl = {}
	end
	local orechars = { aore = "a", core = "c", lore = "l", baconstone = "d" }
	if tonumber(mine) == 1 and setting_enabled("enable experimental implementations") then
		text = text:gsub("</body>", [[<center style="color: darkorange">{ Experimental implementation note: The mine explorer is currently only considering part of the possible mines, and therefore has inexact percentages. In particular, it might incorrectly report 100%% or 0%% when there are very few possibilities left. }</center>%0]])
		ps = compute_mine_spoiler(text)
	end
	text = text:gsub("</head>", [[
<style>
	table { border-collapse: collapse; }
	td.linkminecell:hover { background-color: rgba(150, 150, 150, 0.5); }
	.validcell { background-color: rgba(0, 0, 0, 0.67); border: solid thin gray; }
</style>
%0]])
	text = text:gsub([[(<table cellpadding=0 cellspacing=0 border=0 background='http://images.kingdomofloathing.com/otherimages/mine/mine_background.gif'>)(.-)(</table>)]], function(pre, tabletext, post)
		id = -1
		tabletext = tabletext:gsub([[<td[^>]*>(.-)</td>]], function(celltext)
			id = id + 1
			mineclass = ""
			if mining_ids[id] then
				mineclass = " validcell"
			end
			chance = nil
			if ps and ps[id] then
				chance = string.format("%2.0f%%", ps[id] * 100)
			end
			image, title, height, width = celltext:match([[<img src='(http://images.kingdomofloathing.com/otherimages/mine/[a-z0-9]+.gif)' alt='[^']+' title='([^']+)' border=0 height=(50) width=(50)>]])
			linkdata = celltext:match([[<a href='mining.php%?mine=[0-9]+&which=[0-9]+&pwd=[0-9a-f]+'>]])
			if image then
				if linkdata then
					local linkcolor = ""
					local linktext = ""
					local bgstyle = ""
					if title:contains("Promising") or image:contains("spark") then
						linkcolor = "lightgreen"
						linktext = chance or "?"
					else
						linkcolor = "yellow"
						linktext = chance or "x"
					end
					bgstyle = [[background-image: url(']] .. image .. [['); background-repeat: no-repeat;]]
					return [[<td class="linkminecell]]..mineclass..[[" style="height: ]] .. height .. [[px; width: ]] .. width .. [[px; ]] .. bgstyle .. [[">]] .. linkdata .. [[<center style="line-height: 50px;"><span style="color: ]] .. linkcolor .. [[;">]] .. linktext .. [[</span></center></a></td>]]
				else
					local background = [[background-image: url(']] .. image .. [['); background-repeat: no-repeat;]]
					if tbl[id] then -- and alt == "Open Cavern" 
						celldata = [[<center><img src="http://images.kingdomofloathing.com/itemimages/]] .. tbl[id] .. [[.gif"></center>]]
						local trapper_wants = { asbestos = "a", chrome = "c", linoleum = "l" }
						local what_did_we_want = trapper_wants[ascension["trapper.ore"]]
						print("DEBUG", what_did_we_want, orechars[tbl[id]])
						if what_did_we_want and orechars[tbl[id]] == what_did_we_want then
							background = "background-color: green;";
						end
					else
						if title:contains("Promising") or image:contains("spark") then
							celldata = [[<center><span style="color: lightblue;">]] .. (chance or "?") .. [[</span></center>]]
						else
							celldata = [[<center><span style="color: lightblue;">]] .. (chance or "") .. [[</span></center>]]
						end
					end
					return [[<td class="minecell]]..mineclass..[[" style="height: ]] .. height .. [[px; width: ]] .. width .. [[px; ]] .. background .. [[">]] .. celldata .. [[</td>]]
				end
			else
				return false
			end
		end)
		return pre .. tabletext .. post
	end)
end)

-- goatlet

-- add_choice_text("Between a Rock and Some Other Rocks", { -- choice adventure number: 162
-- 	["Help the miners clear the rocks away"] = "Unlock the goatlet",
-- 	["Screw these rocks, I'm gonna roll out"] = { leave_noturn = true },
-- })

add_ascension_zone_check(271, function()
	if buff("On the Trail") then
		local trailed = retrieve_trailed_monster()
		if trailed ~= "dairy goat" then
			return "You are trailing '" .. tostring(trailed) .. "' when you might want to sniff a dairy goat."
		end
	end
end)

-- extreme slope

-- TODO: Mark good choices

add_choice_text("Generic Teen Comedy Snowboarding Adventure", { -- choice adventure number: 17
	["Give him a pep-talk"] = { getitem = "eXtreme mittens" },
	["Give him some boarding tips"] = { getitem = "snowboarder pants" },
	["Offer to help him cheat"] = { getmeat = 200 },
})

add_choice_text("Saint Beernard", {
	["Help the heroic dog"] = { getitem = "snowboarder pants" },
	["Flee in terror"] = { getitem = "eXtreme scarf" },
	["Ask for some beer, first"] = { getmeat = 200 },
})

add_choice_text("Yeti Nother Hippy", {
	["Help the hippy"] = { getitem = "eXtreme mittens" },
	["Let irony take its course"] = { getitem = "eXtreme scarf" },
	["Negotiate his release"] = { getmeat = 200 },
})

add_choice_text("Duffel on the Double", {
	["Open the bag"] = { "Get a piece of eXtreme Cold-Weather Gear", },
	["Scram"] = { leave_noturn = true },
})

-- orc chasm

add_automator("/mountains.php", function()
	if not setting_enabled("automate simple tasks") then return end
	if tonumber(params.orcs) == 1 then
		if text:contains("you are unable to get past them") then
			async_post_page("/forestvillage.php", { pwd = params.pwd, action = "untinker", whichitem = get_itemid("abridged dictionary") })
			text, url = get_page("/mountains.php", params)
		end
	end
end)

-- mt. noob

add_automator("/tutorial.php", function()
	if not setting_enabled("automate simple tasks") then return end
	if params.action == "toot" then
		if text:contains("letter from King Ralph XI") then
			text, url = use_item_noajax("letter from King Ralph XI")()
		end
	end
end)
