-- Script informations
script_name = "SSB xport"
script_description = "Ex-/imports editor content (ASS) to/from a SSB file."
script_author = "Youka"
script_version = "1.0 (1st February 2014)"

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
					ssb.styles[name] = string.format("{font-family=%s;font-size=%s;color=%s%s%s;alpha=%s;kcolor=%s%s%s;line-color=%s%s%s;line-alpha=%s;font-style=%s;scale-x=%s;scale-y=%s;font-space-h=%s;rotate-z=%s;line-width=%s;align=%s;margin-h=%s;margin-v=%s}",
											fontname, fontsize,
											color1:sub(9,10), color1:sub(7,8), color1:sub(5,6), color1:sub(3,4),
											color2:sub(9,10), color2:sub(7,8), color2:sub(5,6),
											color3:sub(9,10), color3:sub(7,8), color3:sub(5,6), color3:sub(3,4),
											(bold == "-1" and "b" or "") .. (italic == "-1" and "i" or "") .. (underline == "-1" and "u" or "") .. (strikeout == "-1" and "s" or ""),
											scale_x, scale_y, spacing, angle,
											outline, alignment, margin_l, margin_v)
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
		local filename = aegisub.dialog.save("Save SSB file", "", "", "SSB files (.ssb)|.ssb")
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
		
		-- TODO
		
	end,
	-- Validate macro by Aegisub version
	is_aegi3
)
