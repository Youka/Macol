-- Script informations
script_name = "SSB export"
script_description = "Exports editor content (ASS) to a SSB file."
script_author = "Youka"
script_version = "1.0 (31th December 2013)"

-- Check cancel state and terminate process if set
local function check_cancel()
	if aegisub.progress.is_cancelled() then
		aegisub.cancel()
	end
end

-- Output error message and terminate process
local function error(s, ...)
	if type(s) == "string" then
		aegisub.log(0, s, ...)
		aegisub.cancel()
	end
end

-- Macro memory
local last_filename = ""
-- Register macro
aegisub.register_macro(script_name, script_description, function(subs)
		-- Set progress title
		aegisub.progress.title(script_name)
		-- Convert ASS to SSB (rewrite of converter used in SSBRenderer's Aegisub interface)
		aegisub.progress.task("Convert editor content to SSB")
		local ssb, current_section = "", 0	-- Sections: 0 = NONE, 1 = META, 2 = FRAME, 3 = STYLES, 4 = EVENTS
		local function set_section(section)
			if current_section ~= section then
				ssb = ssb .. (
						ssb:len() == 0 and
						(section == 1 and "#META\n" or section == 2 and "#FRAME\n" or section == 3 and "#STYLES\n" or section == 4 and "#EVENTS\n") or
						(section == 1 and "\n#META\n" or section == 2 and "\n#FRAME\n" or section == 3 and "\n#STYLES\n" or section == 4 and "\n#EVENTS\n")
					)
				current_section = section
			end
		end
		aegisub.progress.set(0)
		for i=1, subs.n do
			local line = subs[i].raw
			-- Save meta
			if line:find("^Title: ") then
				set_section(1)
				ssb = string.format("%s%s\n", ssb, line)
			elseif line:find("^Original Script: ") then
				set_section(1)
				ssb = string.format("%sAuthor: %s\n", ssb, line:sub(18))
			elseif line:find("^Update Details: ") then
				set_section(1)
				ssb = string.format("%sDescription: %s\n", ssb, line:sub(17))
			-- Save frame
			elseif line:find("^PlayResX: ") then
				set_section(2)
				ssb = string.format("%sWidth: %s\n", ssb, line:sub(11))
			elseif line:find("^PlayResY: ") then
				set_section(2)
				ssb = string.format("%sHeight: %s\n", ssb, line:sub(11))
			-- Save style
			elseif line:find("^SSBStyle: ") then
				local name, content = line:match("^SSBStyle: (.-),(.*)$")
				if content then
					set_section(3)
					ssb = string.format("%s%s: %s\n", ssb, name, content)
				end
			elseif line:find("^Style: ") then
				local name, fontname, fontsize,
						color1, color2, color3, color4,
						bold, italic, underline, strikeout,
						scale_x, scale_y, spacing, angle,
						borderstyle, outline, shadow,
						alignment, margin_l, margin_r, margin_v,
						encoding = line:match("^Style: " .. string.rep("(.-),", 22) .. "(.*)$")
				if encoding then
					set_section(3)
					ssb = string.format("%s%s: {font-family=%s;font-size=%s;color=%s%s%s;alpha=%s;kcolor=%s%s%s;line-color=%s%s%s;line-alpha=%s;font-style=%s;scale-x=%s;scale-y=%s;font-space-h=%s;rotate-z=%s;line-width=%s;align=%s;margin-h=%s;margin-v=%s}\n",
												ssb, name, fontname, fontsize,
												color1:sub(9,10), color1:sub(7,8), color1:sub(5,6), color1:sub(3,4),
												color2:sub(9,10), color2:sub(7,8), color2:sub(5,6),
												color3:sub(9,10), color3:sub(7,8), color3:sub(5,6), color3:sub(3,4),
												(bold == "-1" and "b" or "") .. (italic == "-1" and "i" or "") .. (underline == "-1" and "u" or "") .. (strikeout == "-1" and "s" or ""),
												scale_x, scale_y, spacing, angle,
												outline, alignment, margin_l, margin_v)
				end
			-- Save event
			elseif line:find("^Comment: ") or line:find("^Dialogue: ") then
				local layer, start_time, end_time, style, name, margin_l, margin_r, margin_v, effect, text
						= line:match((line:find("^C") and "^Comment: " or "^Dialogue: ") .. string.rep("(.-),", 9) .. "(.*)$")
				if text then
					set_section(4)
					if line:find("^C") then
						ssb = ssb .. "// "
					end
					ssb = string.format("%s%s0-%s0|%s|%s|%s\n", ssb, start_time, end_time, style, name, text)
				end
			end
			-- Update progress bar
			aegisub.progress.set(i / subs.n * 100)
			-- Check process cancelling
			check_cancel()
		end
		-- Get output filename by dialog
		aegisub.progress.task("Save file")
		local button, config = aegisub.dialog.display({
				{
					class = "label",
					x = 0, y = 0, width = 1, height = 1,
					label = "Filename:"
				},
				{
					class = "edit", name = "filename",
					x = 1, y = 0, width = 5, height = 1,
					text = last_filename == "" and aegisub.decode_path("?script") or last_filename, hint = "Output SSB filename"
				}
			}, {"Export", "Cancel"})
		-- Export button pressed?
		if button == "Export" then
			-- Save filename for next execution (with SSB file extension)
			last_filename = (config.filename:len() > 4 and config.filename:sub(-4) ~= ".ssb") and
								config.filename .. ".ssb" or
								config.filename
			-- Create output file
			local file = io.open(last_filename, "w")
			if file then
				-- Fill file with generated SSB content
				file:write(ssb)
				file:close()
			else
				error("Couldn't write in file %q!", last_filename)
			end
		end
	end,
	-- Validate macro by Aegisub version 3+
	function()
		if aegisub.decode_path then
			return true
		else
			return false, "Aegisub 3+ required"
		end
	end
)
