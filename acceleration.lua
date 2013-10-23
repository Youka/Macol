script_name = "Acceleration"
script_description = "Split line into frames and assume tags with accelerated value changes."
script_author = "Youka"
script_version = "1.3"
script_modified = "9th August 2011"

--Frame duration (default: 23.976 fps)
frame_dur = aegisub.video_size() and (aegisub.ms_from_frame(101)-aegisub.ms_from_frame(1)) / 100 or 41.71

--Input config
function create_conf()
	local conf_func = {
		{
			class = "label",
			x = 0, y = 0, width = 1, height = 1,
			label = "Frame steps:"
		},
		{
			class = "intedit", name = "f_step",
			x = 1, y = 0, width = 1, height = 1,
			hint = "How many frames to next picture?",
			value = 1, min = 1, max = 100
		},
		{
			class = "label",
			x = 0, y = 1, width = 1, height = 3,
			label = tag_n..". Tag(s):"
		},
		{
			class = "textbox", name = "tag"..tag_n,
			x = 1, y = 1, width = 15, height = 3,
			hint = "Tags with pattern to insert changing values", text = ""
		},
		{
			class = "label",
			x = 0, y = 4, width = 1, height = 1,
			label = "Acceleration:"
		},
		{
			class = "edit", name = "acc"..tag_n,
			x = 1, y = 4, width = 2, height = 1,
			hint = "Acceleration for input values", text = "1"
		}
	}
	return conf_func
end

--Help window
conf_help = {
	{
		class = "label",
		x = 0, y = 0, width = 1, height = 1,
		label = "Example NUMBER:\nTag(s):  \"\\pos(20.0-50.0,100)\"\nAcceleration:  \"2\""
	},
	{
		class = "label",
		x = 1, y = 0, width = 1, height = 1,
		label = "Example COLOR:\nTag(s):  \"\\1c&&HFF0000&&-&&H0000FF&&\"\nAcceleration:  \"0.7\""
	},
	{
		class = "label",
		x = 2, y = 0, width = 1, height = 1,
		label = "Example ALPHA:\nTag(s):  \"\\alpha&&H00&&-&&HFF&&\"\nAcceleration:  \"10\""
	},
	{
		class = "label",
		x = 0, y = 2, width = 3, height = 1,
		label = "-\"NUMBER-NUMBER\" or \"HEXADECIMAL-HEXADECIMAL\" marks value ranges with chosen acceleration."
	},
	{
		class = "label",
		x = 0, y = 3, width = 3, height = 1,
		label = "-Acceleration values have to be bigger than 0."
	},
	{
		class = "label",
		x = 0, y = 4, width = 3, height = 1,
		label = "-Multiple lines are selectable."
	},
	{
		class = "label",
		x = 0, y = 5, width = 3, height = 1,
		label = "-Remember that \\t tags are senseless!"
	},
	{
		class = "label",
		x = 0, y = 6, width = 3, height = 1,
		label = "-Just integer inputs generates integer changes.\n  Use float number inputs for changes with float numbers."
	},
	{
		class = "label", width = 3, height = 1,
		label = "-Negative numbers are allowed too."
	}
}

--Manipulate chosen lines with every tags+acceleration input
function accelerate(subs, sel, config)
	--Count config element number (minus 1 for f_step value)
	local n = 0
	for _, _ in pairs(config) do
		n = n + 1
	end
	n = n - 1
	--Added lines
	local add_n = 0
	--Through all selected lines
	for si, li in ipairs(sel) do
		--Create line copy
		local sub = subs[li+add_n]
		--Frame number
		local frame_n = math.ceil((sub.end_time - sub.start_time) / (frame_dur * config.f_step))
		--Through every frame
		for f = 1, frame_n do
			--Advance status
			local pct = f / frame_n
			--Line copy
			local line = table.copy(sub)
			--Through all tags+acceleration inputs
			for i=1, n/2 do
				--Tags
				local text = config["tag"..i]
				--Acceleration
				local acc = tonumber(config["acc"..i])
				if not acc then
					return "Acceleration input is not a number in "..i..". Tag(s)!"
				elseif acc <= 0 then
					return "Acceleration input smaller than 0 in "..i..". Tag(s)!"
				end
				acc = math.pow(pct, acc)
				--Replace function - numbers
				local function calc_val(v1, v2)
					local str1 = v1
					local str2 = v2
					--String to number
					v1 = tonumber(v1)
					v2 = tonumber(v2)
					--Distances
					local dist = v2 - v1
					--Return
					if str1:find("%.") or str2:find("%.") then
						return string.format("%.3f", v1 + dist * acc)
					else
						return string.format("%d", v1 + dist * acc)
					end
				end
				--Replace function - alphas
				local function calc_alp(a1, a2)
					--Hexadecimal to number
					a1 = tonumber(a1, 16)
					a2 = tonumber(a2, 16)
					--Distances
					local dist = a2 - a1
					--Return
					return string.format("&H%02x&", a1 + dist * acc)
				end
				--Replace function - colors
				local function calc_col(b1, g1, r1, b2, g2, r2)
					--Hexadecimal to number
					r1 = tonumber(r1, 16)
					g1 = tonumber(g1, 16)
					b1 = tonumber(b1, 16)
					r2 = tonumber(r2, 16)
					g2 = tonumber(g2, 16)
					b2 = tonumber(b2, 16)
					--Distances
					local dist_r = r2 - r1
					local dist_g = g2 - g1
					local dist_b = b2 - b1
					--Return
					return string.format("&H%02x%02x%02x&", b1 + dist_b * acc, g1 + dist_g * acc, r1 + dist_r * acc)
				end
				--Insert accelerated values
				text = text:gsub("(%-?[%d%.]+)%-(%-?[%d%.]+)", calc_val)
				text = text:gsub("&H(%x%x)&%-&H(%x%x)&", calc_alp)
				text = text:gsub("&H(%x%x)(%x%x)(%x%x)&%-&H(%x%x)(%x%x)(%x%x)&", calc_col)
				add_vals(line, text)
			end
			--Abort process
			if (aegisub.progress.is_cancelled()) then return "Progress canceled!" end
			--Finalize frame
			line.start_time = line.start_time + (f-1) * (frame_dur * config.f_step)
			line.end_time = line.start_time + (frame_dur * config.f_step) < line.end_time and line.start_time + (frame_dur * config.f_step) or line.end_time
			subs.insert(li+add_n, line)
			add_n = add_n + 1
		end
		--Delete old line
		subs.delete(li+add_n)
		add_n = add_n - 1
		aegisub.progress.set(si / #sel * 100)
	end
end

--Add calculated values + tag definition to subtitle text
function add_vals(s, t)
	if s.text:find("{") then
		s.text = s.text:gsub("{", "{"..t, 1)
	else
		s.text = "{"..t.."}"..s.text
	end
end

--Copy table
function table.copy(t)
	local new_t = {}
	for key, val in pairs(t) do
		new_t[key] = val
	end
	return new_t
end

--Add one tags+acceleration task
function add_tags(conf_func)
	if tag_n<6 then
		tag_n = tag_n + 1

		local new_tag = {
			class = "label",
			x = 0, y = 1 + (tag_n-1)*4, width = 1, height = 3,
			label = tag_n..". Tag(s):"
		}

		local new_tag_value = {
			class = "textbox", name = "tag"..tag_n,
			x = 1, y = 1 + (tag_n-1)*4, width = 15, height = 3,
			hint = "Tags with pattern to insert changing values", text = ""
		}

		local new_acc =	 {
			class = "label",
			x = 0, y = 1 + (tag_n-1)*4+3, width = 1, height = 1,
			label = "Acceleration:"
		}

		local new_acc_value = {
			class = "edit", name = "acc"..tag_n,
			x = 1, y = 1 + (tag_n-1)*4+3, width = 1, height = 1,
			hint = "Acceleration for input values", text = "1"
		}

		table.insert(conf_func, new_tag)
		table.insert(conf_func, new_tag_value)
		table.insert(conf_func, new_acc)
		table.insert(conf_func, new_acc_value)
	end
end

--Remove one tags+acceleration task
function remove_tags(conf_func)
	if tag_n > 1 then
		for i=1, 4 do
			table.remove(conf_func, 2 + (tag_n-1) * 4 + 1)
		end
		tag_n = tag_n - 1
	end
end

--Initialisation + GUI
function run(subs, sel)
	--Prepare status and values
	tag_n = 1
	local button, config
	local conf = create_conf()
	aegisub.progress.title (script_name)
	aegisub.progress.set(0)
	--Create dialog box
	repeat
		button, config = aegisub.dialog.display(conf,{"Execute","Add tag(s)","Remove tag(s)","Help","Cancel"})
		--Save input values
		for key, val in pairs(config) do
			for _, element in ipairs(conf) do
				if element.name and key == element.name then
					if element.value then
						element.value = val
					else
						element.text = val
					end
				end
			end
		end
		--Alternative button clicked
		if button == "Add tag(s)" then add_tags(conf) end
		if button == "Remove tag(s)" then remove_tags(conf) end
		if button == "Help" then
			aegisub.progress.title (script_name.." - Help")
			aegisub.dialog.display(conf_help, {"OK"})
			aegisub.progress.title (script_name)
		end
	until button == "Execute" or button == "Cancel" or button == false
	--Execute function
	if button == "Execute" then
		local err = accelerate(subs, sel, config)
		--Error handling
		if err then
			if err == "Progress canceled!" then
				aegisub.set_undo_point("\""..script_name.."\"")
				err = err.."\n\nUndo last action to avoid errors."
			end
			aegisub.debug.out(2,"Couldn't finish function:\n"..err)
		else
			aegisub.set_undo_point("\""..script_name.."\"")
		end
	end
end

--Test for lines with 0 frames
function test_null_frames(subs, sel)
	for i, si in ipairs(sel) do
		local sub = subs[si]
		if (math.ceil((sub.end_time - sub.start_time) / frame_dur) < 1) then
			return false
		end
	end
	return true
end

--Register macro in aegisub
aegisub.register_macro(script_name,script_description,run,test_null_frames)
