-- Script informations
script_name = "SSB xport"
script_description = "Ex-/imports editor content (ASS) to/from a SSB file."
script_author = "Youka"
script_version = "1.0 (2st February 2014)"

-- Check cancel state and terminate process if set
local function check_cancel()
	if aegisub.progress.is_cancelled() then
		aegisub.cancel()
	end
end

-- Output error message and terminate process
local function error(s, ...)
	aegisub.log(0, s, ...)
	aegisub.cancel()
end

-- Is Aegisub version 3+?
local function is_aegi3()
	if aegisub.decode_path then
		return true
	else
		return false, "Aegisub 3+ required"
	end
end

-- Register export macro
aegisub.register_macro("SSB export", "Exports editor content to SSB", function(subs)
		-- Set progress title
		aegisub.progress.title("SSB export")
		-- Convert ASS to SSB
		aegisub.progress.task("Convert editor content to SSB")
		local ssb = {
			meta = {
				title = "",
				author = "",
				description = "",
				version = ""
			},
			frame = {
				width = nil,
				height = nil
			},
			styles = {},
			events = {}
		}
		aegisub.progress.set(0)
		for i=1, subs.n do
			local line = subs[i].raw
			-- Save meta
			if line:find("^Title: ") then
				ssb.meta.title = line:sub(8)
			elseif line:find("^Original Script: ") then
				ssb.meta.author = line:sub(18)
			elseif line:find("^Update Details: ") then
				ssb.meta.description = line:sub(17)
			elseif line:find("^Version: ") then
				ssb.meta.version = line:sub(10)
			-- Save frame
			elseif line:find("^PlayResX: ") then
				ssb.frame.width = line:sub(11)
			elseif line:find("^PlayResY: ") then
				ssb.frame.height = line:sub(11)
			-- Save style
			elseif line:find("^SSBStyle: ") then
				local name, content = line:match("^SSBStyle: (.-),(.*)$")
				if content then
					ssb.styles[name] = content
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
					ssb.styles[name] = string.format("{font-family=%s;font-size=%s;color=%s%s%s;alpha=%s;kcolor=%s%s%s;line-color=%s%s%s;line-alpha=%s;font-style=%s;scale-x=%s;scale-y=%s;font-space-h=%s;rotate-z=%s;mode=%s;line-width=%s;align=%s;margin-h=%s;margin-v=%s}",
											fontname, fontsize,
											color1:sub(9,10), color1:sub(7,8), color1:sub(5,6), color1:sub(3,4),
											color2:sub(9,10), color2:sub(7,8), color2:sub(5,6),
											color3:sub(9,10), color3:sub(7,8), color3:sub(5,6), color3:sub(3,4),
											(bold == "-1" and "b" or "") .. (italic == "-1" and "i" or "") .. (underline == "-1" and "u" or "") .. (strikeout == "-1" and "s" or ""),
											scale_x, scale_y, spacing, angle,
											borderstyle == "3" and "boxed" or "fill", outline, alignment, margin_l, margin_v)
				end
			-- Save event
			elseif line:find("^Comment: ") or line:find("^Dialogue: ") then
				local layer, start_time, end_time, style, name, margin_l, margin_r, margin_v, effect, text = line:match((line:find("^C") and "^Comment: " or "^Dialogue: ") .. string.rep("(.-),", 9) .. "(.*)$")
				if text then
					local function ass_to_ssb_time(t)
						local h, m, s, ms = t:match("^0*(%d+):0*(%d+):0*(%d+).0*(%d*)$")
						if ms then
							if h ~= "0" then
								return string.format("%s:%s:%s.%s0", h, m, s, ms)
							elseif m ~= "0" then
								return string.format("%s:%s.%s0", m, s, ms)
							elseif s ~= "0" then
								return string.format("%s.%s0", s, ms)
							else
								return string.format("%s0", ms)
							end
						else
							return t .. "0"
						end
					end
					if line:find("^C") then
						table.insert(ssb.events, string.format("// %s-%s|%s|%s|%s", ass_to_ssb_time(start_time), ass_to_ssb_time(end_time), style, name, text))
					else
						table.insert(ssb.events, string.format("%s-%s|%s|%s|%s", ass_to_ssb_time(start_time), ass_to_ssb_time(end_time), style, name, text))
					end
				end
			end
			-- Update progress bar
			aegisub.progress.set(i / subs.n * 100)
			-- Check process cancelling
			check_cancel()
		end
		-- Get output filename by dialog
		aegisub.progress.task("Save file")
		local filename = aegisub.dialog.save("Save SSB file", "", "", "SSB files (.ssb)|*.ssb")
		if filename then
			-- Create output file
			local file = io.open(filename, "w")
			if file then
				-- Inserts empty line between sections
				local function insert_space()
					if file:seek() > 0 then
						file:write("\n")
					end
				end
				-- Write meta to file
				if ssb.meta.title ~= "" or ssb.meta.author ~= "" or ssb.meta.description ~= "" or ssb.meta.version ~= "" then
					file:write("#META\n")
					if ssb.meta.title ~= "" then
						file:write(string.format("Title: %s\n", ssb.meta.title))
					end
					if ssb.meta.author ~= "" then
						file:write(string.format("Author: %s\n", ssb.meta.author))
					end
					if ssb.meta.description ~= "" then
						file:write(string.format("Description: %s\n", ssb.meta.description))
					end
					if ssb.meta.version ~= "" then
						file:write(string.format("Version: %s\n", ssb.meta.version))
					end
				end
				-- Write frame to file
				if ssb.frame.width and ssb.frame.height then
					insert_space()
					file:write(string.format("#FRAME\nWidth: %s\nHeight: %s\n", ssb.frame.width, ssb.frame.height))
				end
				-- Write styles to file
				if next(ssb.styles) then
					insert_space()
					file:write("#STYLES\n")
					for name, content in pairs(ssb.styles) do
						file:write(string.format("%s: %s\n", name, content))
					end
				end
				-- Write events to file
				if ssb.events[1] then
					insert_space()
					file:write("#EVENTS\n")
					for _, content in ipairs(ssb.events) do
						file:write(content .. "\n")
					end
				end
				file:close()
			else
				error("Couldn't write in file %q!", filename)
			end
		end
	end,
	-- Validate macro by Aegisub version
	is_aegi3
)

-- Register import macro
aegisub.register_macro("SSB import", "Imports editor content from SSB", function(subs)
		-- Set progress title
		aegisub.progress.title("SSB import")
		-- Get input filename by dialog
		aegisub.progress.task("Load file")
		local filename = aegisub.dialog.open("Load SSB file", "", "", "SSB files (.ssb)|*.ssb")
		if filename then
			-- Open input file
			local file = io.open(filename, "r")
			if file then
				-- Clear editor content
				while subs.n > 0 do
					subs.delete(1)
				end
				-- Convert SSB to ASS
				aegisub.progress.task("Convert SSB to editor content")
				local section = "NONE"
				aegisub.progress.set(0)
				for line in file:lines() do
					-- Update section
					if line:find("^#%u+") then
						section = line:match("^#(%u+)")
					-- Save meta
					elseif section == "META" then
						if line:find("^Title: ") then
							subs.append({class = "info", key = "Title", value = line:sub(8)})
						elseif line:find("^Author: ") then
							subs.append({class = "info", key = "Original Script", value = line:sub(9)})
						elseif line:find("^Description: ") then
							subs.append({class = "info", key = "Update Details", value = line:sub(14)})
						elseif line:find("^Version: ") then
							subs.append({class = "info", key = "Version", value = line:sub(10)})
						end
					-- Save frame
					elseif section == "FRAME" then
						if line:find("^Width: ") then
							subs.append({class = "info", key = "PlayResX", value = line:sub(8)})
						elseif line:find("^Height: ") then
							subs.append({class = "info", key = "PlayResY", value = line:sub(9)})
						end
					-- Save style
					elseif section == "STYLES" then
						local name, fontname, fontsize,
							color, alpha, kcolor, line_color, line_alpha,
							fontstyle, scale_x, scale_y, spacing, angle,
							mode, line_width, alignment, margin_h, margin_v =
							line:match("^(.-): {font%-family=(.-);font%-size=(.-);color=(.-);alpha=(.-);kcolor=(.-);line%-color=(.-);line%-alpha=(.-);font%-style=(.-);scale%-x=(.-);scale%-y=(.-);font%-space%-h=(.-);rotate%-z=(.-);mode=(.-);line%-width=(.-);align=(.-);margin%-h=(.-);margin%-v=(.-)}")
						if margin_v then
							subs.append({
								class = "style",
								name = name,
								fontname = fontname,
								fontsize = tonumber(fontsize),
								color1 = string.format("&H%02s%02s%02s%02s", alpha, color:sub(5,6), color:sub(3,4), color:sub(1,2)),
								color2 = string.format("&HFF%02s%02s%02s", kcolor:sub(5,6), kcolor:sub(3,4), kcolor:sub(1,2)),
								color3 = string.format("&H%02s%02s%02s%02s", line_alpha, line_color:sub(5,6), line_color:sub(3,4), line_color:sub(1,2)),
								color4 = "&HFF000000",
								bold = fontstyle:find("b") ~= nil,
								italic = fontstyle:find("i") ~= nil,
								underline = fontstyle:find("u") ~= nil,
								strikeout = fontstyle:find("s") ~= nil,
								scale_x = tonumber(scale_x),
								scale_y = tonumber(scale_y),
								spacing = tonumber(spacing),
								angle = tonumber(angle),
								borderstyle = mode == "boxed" and 3 or 1,
								outline = tonumber(line_width),
								shadow = 0,
								align = tonumber(alignment),
								margin_l = tonumber(margin_h),
								margin_r = tonumber(margin_h),
								margin_t = tonumber(margin_v),
								encoding = 1
							})
						end
					-- Save event
					elseif section == "EVENTS" then
						local comment, start_time, end_time, style, note, text = line:match("^([/%s]*)(.-)-(.-)|(.-)|(.-)|(.*)")
						if text then
							local function ssb_to_ass_time(t)
								local h, m, s, ms = t:match("(%d+):(%d+):(%d+)%.(%d+)")
								if ms then
									return ms + s * 1000 + m * 60000 + h * 3600000
								else
									m, s, ms = t:match("(%d+):(%d+)%.(%d+)")
									if ms then
										return ms + s * 1000 + m * 60000
									else
										s, ms = t:match("(%d+)%.(%d+)")
										if ms then
											return ms + s * 1000
										else
											ms = tonumber(t)
											if ms then
												return ms
											else
												return 0
											end
										end
									end
								end
							end
							subs.append({
								class = "dialogue",
								comment = comment:find("^//") ~= nil,
								layer = 0,
								start_time = ssb_to_ass_time(start_time),
								end_time = ssb_to_ass_time(end_time),
								style = style,
								actor = note,
								margin_l = 0,
								margin_r = 0,
								margin_t = 0,
								effect = "",
								text = text
							})
						end
					end
					-- Update progress bar
					local file_pos = file:seek()
					aegisub.progress.set(file_pos / file:seek("end") * 100)
					file:seek("set", file_pos)
					-- Check process cancelling
					check_cancel()
				end
				file:close()
				-- Set undo point
				aegisub.set_undo_point("SSB import")
			else
				error("Couldn't read file %q!", filename)
			end
		end
	end,
	-- Validate macro by Aegisub version
	is_aegi3
)
