local cached_itemids = {}

function get_itemid(name)
	local t = type(name)
	if t == "number" then
		return name
	elseif t ~= "string" then
		error("Invalid itemid type: " .. t)
	end
	local id = cached_itemids[name]
	if not id then
		local data = get_item_data_by_name(name)
-- 		local data = kolproxy_log_time_interval("get_item_data_by_name: " .. name, function() return get_item_data_by_name(name) end)
		if not data or not data.id then
			error("No itemid found for item: " .. tostring(name))
		end
		id = tonumber(data.id)
		cached_itemids[name] = id
	end
	return id
end

function intercept_warning(warning)
	if not warning.id then
		error "No warning id!"
	end
	if session["warning-" .. warning.id] then return end
	local head = [[<head><script type="text/javascript" src="http://images.kingdomofloathing.com/scripts/jquery-1.3.1.min.js"></script>
<script>top.charpane.location = "charpane.php"</script></head>]]
	local extratext = ""
	if not warning.norepeat then
		extratext = [[<p><a href="]]..raw_make_href(requestpath, parse_params_raw(input_params))..[[">I fixed it, try again.</a></p>]]
	end
	local msgtext = make_kol_html_frame([[<p>]] ..
		(warning.customwarningprefix or "Warning: ") .. warning.message .. [[</p>]] ..
--		[[<p><a href="http://www.houeland.com/kolproxy/wiki/Adventure_warnings" target="_blank">Help</a> (opens adventure warning documentation in a new tab)</p>]] ..
		extratext ..
		[[<p><small><a href="#" onclick="var link = this; $.post('custom-settings', { pwd: ']] .. session.pwd .. [[', action: 'set state', name: 'warning-]] .. warning.id .. [[', stateset: 'session', value: 'skip', ajax: 1 }, function (res) { link.style.color = 'gray'; link.innerHTML = '(Disabled, trying again...)'; location.href = ']]..raw_make_href(requestpath, parse_params_raw(input_params))..[[' }); return false;" style="color: ]] .. (warning.customdisablecolor or "darkorange") .. [[;">]] .. (warning.customdisablemsg or "I am sure! Do it anyway and disable this warning until I log out.") .. [[</a></small></p>]] ..
		[[]], (warning.customwarningprefix or "Warning: "), (warning.customdisablecolor or "darkorange"))
	text = [[<html>]] .. head .. [[<body>]] .. msgtext .. [[</body></html>]]
	return text, "/kolproxy-warning"
end


local after_pageload_cache = {}

function reset_pageload_cache()
	after_pageload_cache = {}
end

function get_cached_function(f)
-- 	print("get_cached_function", f)
	local v = after_pageload_cache[f]
	if v then
-- 		print("cached f")
		return v
	else
-- 		print("calling raw f")
-- 		v = kolproxy_log_time_interval("get_cached_function: " .. tostring(f), f)
		v = f()
		after_pageload_cache[f] = v
		return v
	end
end

function get_cached_item(name, f)
	local v = after_pageload_cache[name]
	if v then
		return v
	else
		v = f()
		after_pageload_cache[name] = v
		return v
	end
end

raw_submit_page = submit_page

function do_submit_page(t, url, params)
	kolproxy_debug_print("> do_submit_page(" .. tostring(url) .. ")\n" .. debug.traceback(""))
	after_pageload_cache = {}
	local pt, pturl = nil, nil
	if params then
		local tbl = {}
		for a, b in pairs(params) do
			if type(b) == "string" then
				table.insert(tbl, { key = a, value = b })
			elseif type(b) == "number" then
				table.insert(tbl, { key = a, value = tostring(b) })
			else
				error("Unknown submit_page value type: " .. type(b))
			end
		end
		pt, pturl = raw_submit_page(t, url, tbl)
	else
		pt, pturl = raw_submit_page(t, url, nil)
	end
	kolproxy_debug_print("< do_submit_page(" .. tostring(url) .. ")")
	return pt, pturl
end

function get_page(url, params) return do_submit_page("GET", url, params) end

function post_page(url, params) return do_submit_page("POST", url, params) end



raw_async_submit_page = async_submit_page

-- TODO: improve async and after_pageload_cache interaction, after_pageload_cache should be cleared after every completed pageload/statuschange!
function do_async_submit_page(t, url, params)
	kolproxy_debug_print("> do_async_submit_page()\n" .. debug.traceback(""))
	after_pageload_cache = {}
	local pt, pturl, tbl = nil, nil, nil
	if params then
		tbl = {}
		for a, b in pairs(params) do
			if type(b) == "string" then
				table.insert(tbl, { key = a, value = b })
			elseif type(b) == "number" then
				table.insert(tbl, { key = a, value = tostring(b) })
			else
				error("Unknown async_submit_page value type: " .. type(b))
			end
		end
	end
	kolproxy_debug_print("< do_async_submit_page()")
	return raw_async_submit_page(t, url, tbl)
end

function async_get_page(url, params) return do_async_submit_page("GET", url, params) end

function async_post_page(url, params) return do_async_submit_page("POST", url, params) end



raw_make_href = make_href

function do_make_href(url, params)
	if params then
		local tbl = {}
		for a, b in pairs(params) do
			if type(b) == "string" then
				table.insert(tbl, { key = a, value = b })
			elseif type(b) == "number" then
				table.insert(tbl, { key = a, value = tostring(b) })
			else
				print("DEBUG make_href error for:", a, b)
				error("Unknown make_href value type: " .. type(b))
			end
		end
		return raw_make_href(url, tbl)
	else
		return raw_make_href(url, nil)
	end
end

make_href = do_make_href


function run_file_with_environment(filename, orgenv, prefillenv, f_notfound)
	local env = {}
	local env_store = {}
	-- HACK: API change
	if not prefillenv.add_printer_raw then
		prefillenv.add_printer_raw = prefillenv.add_printer
	end
	function env.add_printer(file, func)
		prefillenv.add_printer_raw(file, func, filename)
	end
	if not prefillenv.add_processor_raw then
		prefillenv.add_processor_raw = prefillenv.add_processor
	end
	function env.add_processor(file, func)
		prefillenv.add_processor_raw(file, func, filename)
	end
	if not prefillenv.add_automator_raw then
		prefillenv.add_automator_raw = prefillenv.add_automator
	end
	function env.add_automator(file, func)
		prefillenv.add_automator_raw(file, func, filename)
	end
	-- HACK: This is a weird workaround, to get util functions to refer to our environment
	local hack_functions = {
		"add_automation_script",
		"add_itemdrop_counter",
		"__raw_add_warning",
		"__raw_add_extra_warning",
		"add_ascension_zone_check",
		"add_aftercore_zone_check",
		"add_always_zone_check",
		"add_extra_ascension_warning",
		"add_ascension_warning",
		"add_extra_always_warning",
		"add_always_warning",
		"add_ascension_warning",
		"add_aftercore_warning",
		"add_always_adventure_warning",
		"add_extra_always_adventure_warning",
		"add_ascension_adventure_warning",
		"add_extra_ascension_adventure_warning",
		"add_aftercore_adventure_warning",
		"add_chat_redirect",
		"add_chat_command",
		"add_chat_alias",
		"add_raw_chat_script_redirect",
	}
	for x in table.values(hack_functions) do
		env_store[x] = _G[x]
	end
	for x in table.values(hack_functions) do
		setfenv(_G[x], env)
	end

	local __allow_global_writes = true
	local function p_none() end
	setmetatable(env, { __index = function(t, k)
--		local p = p_none
--		if k == "make_cannonsniff_macro" then
--			p = print
--		end
--		p("indexing global", k, filename)
--		p("  check envstore", exported_raw_tostring(env_store))
		local v = rawget(env_store, k)
		if v ~= nil then return v end
--		p("  check prefillenvstore", exported_raw_tostring(prefillenv))
		local v = rawget(prefillenv, k)
		if v ~= nil then return v end
		if f_notfound then
			f_notfound(t, k, filename)
-- 			print("f_notfound", t, k, orgenv[k])
		end
--		p("  check orgenv", exported_raw_tostring(orgenv))
		v = rawget(orgenv, k)
		if v ~= nil then return v end
--		p("  check _G", exported_raw_tostring(_G))
		v = _G[k]
		if v ~= nil then return v end
--		p("  not found")
		return nil
	end, __newindex = function(t, k, v)
		if error_on_writing_text_or_url and (k == "text" or k == "url") then
			error "You can't write to 'text' or 'url' from add_processor, that's just for registering game state changes. You might want add_printer() instead for changing what's displayed?"
		end
--		local p = p_none
--		if error_on_writing_text_or_url then
--			p = print
--		end
--		p("DEBUG: setting global", k, filename)
		if (k == "__allow_global_writes" or not __allow_global_writes) and k ~= "text" and k ~= "url" then
--			p("  in env_store", exported_raw_tostring(env_store))
			rawset(env_store, k, v)
		else
--			p("  orgenv write", k, "from", filename, "to", exported_raw_tostring(orgenv))
			orgenv[k] = v
		end
	end})
-- 	print("runfile", filename)
	local f, e = loadfile("scripts/" .. filename)
	if not f then error(e, 2) end
	setfenv(f, env)

	f()

	__allow_global_writes = rawget(env_store, "__allow_global_writes")
--	print(filename, __allow_global_writes)
end

function load_script_files(env)
	local function add_do_nothing_function(name)
		if not env[name] then
			env[name] = function() end
		end
	end
	add_do_nothing_function("add_processor")
	add_do_nothing_function("add_printer")
	add_do_nothing_function("add_choice_text")
	add_do_nothing_function("add_automator")
	add_do_nothing_function("add_interceptor")
	add_do_nothing_function("add_chat_printer")
	add_do_nothing_function("add_json_chat_printer")
	add_do_nothing_function("add_chat_trigger")

	local global_env = {}
	local function load_file(category, name)
		local warn = true
		run_file_with_environment(name, global_env, env, function (t, k, filename)
			if (warn and k ~= "register_setting") or (k == "character" and not filename:contains("settings-page")) then
				print("Warning: using global variable", k, "in", filename)
-- 				print(debug.traceback())
-- 				error("Warning: invalid __index for name '" .. tostring(k) .. "' in '" .. tostring(filename) .. "'")
			end
		end)
		warn = false
	end

	run_file_with_environment("loaders.lua", { load_file = load_file }, {})
	run_file_with_environment("user-loaders.lua", { load_file = load_file }, {})

	global_env.register_setting = nil
end


function make_kol_html_frame(contents, title, bgcolor)
	return [[<center><table  width=95%  cellspacing=0 cellpadding=0><tr><td style="color: white;" align=center bgcolor=]] .. (bgcolor or "green") .. [[><b>]] .. (title or "Results:") .. [[</b></td></tr><tr><td style="padding: 5px; border: 1px solid ]]..(bgcolor or "green")..[[;"><center><table><tr><td>]] .. contents .. [[</td></tr></table></center></td></tr><tr><td height=4></td></tr></table></center>]]
end

function add_raw_message_to_page(pagetext, msg)
	local pre_, dv_, mid_, end_, post_ = pagetext:match("^(.+)(<div style='overflow: auto'><center><table)(.+)(</body></html>)(.*)$")
	if pre_ and dv_ and mid_ and end_ and post_ then
		local wrappedmsg = [[<center><table width=95%><tr><td>]] .. msg .. [[</td></tr></table></center>]]
		return pre_ .. wrappedmsg .. "<br>" .. dv_ .. mid_ .. end_ .. post_
	elseif pagetext:match("<body>") then
		return pagetext:gsub("<body>", function(a) return a .. msg end)
	else
		return msg .. pagetext
	end
end

function add_message_to_page(pagetext, msg, title, color)
	return add_raw_message_to_page(pagetext, make_kol_html_frame(msg, title, color))
end

function add_colored_message_to_page(pagetext, msg, color) -- TODO: Deprecated!
	return add_message_to_page(pagetext, "<pre>" .. msg .. "</pre>", "Result:", color)
end

function add_formatted_colored_message_to_page(pagetext, msg, color) -- TODO: Deprecated!
	return add_message_to_page(pagetext, msg, "Result:", color)
end

function run_functions(p, pagetext, run)
	original_page_text = pagetext
	pagetext = run(p, pagetext)

	if p == "/fight.php" then
		pagetext = pagetext:gsub([[(<td[^>]-><img src="http://images.kingdomofloathing.com/itemimages/)([^"]+.gif)(" width=30 height=30 alt="[^"]+" title=")([^"]+)("></td><td[^>]->)(.-)(</td></tr>)]], function (pre, itemimage, mid, title, td, msg, post)
	--~ 		print("item use", msg)
			item_image = itemimage
			item_name = title
			msg = run("used combat item", msg)
			item_image = nil
			item_name = nil
			return pre .. itemimage .. mid .. title .. td .. msg .. post
		end)
	end

	pagetext = pagetext:gsub([[<center><table class="item" style="float: none" rel="[^"]*"><tr><td><img src="http://images.kingdomofloathing.com/itemimages/[^"]+.gif" alt="[^"]*" title="[^"]*" class=hand onClick='descitem%([0-9]+%)'></td><td valign=center class=effect>You acquire .-</td></tr></table></center>]], function (droptext)
-- 			print("item drop gsub", droptext)
		item_image = droptext:match([[src="http://images.kingdomofloathing.com/itemimages/([^"]+).gif"]])
		item_name = droptext:match([[title="([^"]*)"]])
		msg = droptext
		if item_name then
			msg = run("item drop: " .. item_name, msg)
		end
		msg = run("item drop", msg)
-- 		print("item capture", pre, rel, mid, dropinfo, post)
-- 		local msg = pre .. rel .. mid .. "<span style=\"color: darkgreen\">" .. dropinfo .. "</span>" .. post
-- 		if string.match(rel, "u=u") then
-- 			msg = pre .. rel .. mid .. "<span style=\"color: darkgreen\">" .. dropinfo .. "</span> [use]" .. post
-- 			http://localhost:18481/inv_use.php?pwd=xxx&which=3&whichitem=3236
-- 		elseif string.match(rel, "u=q") then
-- 			msg = pre .. rel .. mid .. "<span style=\"color: darkgreen\">" .. dropinfo .. "</span> [equip]" .. post
-- 			http://localhost:18481/inv_equip.php?pwd=xxx&which=2&action=equip&whichitem=2813
-- 		end
		return msg
	end)

	if p == "/fight.php" then
		pagetext = pagetext:gsub([[(<!%-%-familiarmessage%-%-><center><table>.-</table></center>)]], function (msg)
			familiarmessage_picture = msg:match([[<!%-%-familiarmessage%-%-><center><table><tr><td align=center valign=center><img src="http://images.kingdomofloathing.com/itemimages/([^"]+).gif" width=30 height=30></td>]])
			if familiarmessage_picture then
				msg = run("familiar message: " .. familiarmessage_picture, msg)
			end
			msg = run("familiar message", msg)
			return msg
		end)
	end

	pagetext = run("all pages", pagetext)

	return pagetext
end
