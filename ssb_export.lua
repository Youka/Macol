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
		local function set_meta_section()
			if current_section ~= 1 then
				ssb = ssb:len() == 0 and ssb .. "#META\n" or ssb .. "\n#META\n"
				current_section = 1
			end
		end
		local function set_frame_section()
			if current_section ~= 2 then
				ssb = ssb:len() == 0 and ssb .. "#FRAME\n" or ssb .. "\n#FRAME\n"
				current_section = 2
			end
		end
		aegisub.progress.set(0)
		for i=1, subs.n do
			local line = subs[i].raw
			-- Save meta
			if line:find("^Title: ") then
				set_meta_section()
				ssb = string.format("%s%s\n", ssb, line)
			elseif line:find("^Original Script: ") then
				set_meta_section()
				ssb = string.format("%sAuthor: %s\n", ssb, line:sub(18))
			elseif line:find("^Update Details: ") then
				set_meta_section()
				ssb = string.format("%sDescription: %s\n", ssb, line:sub(17))
			-- Save frame
			elseif line:find("^PlayResX: ") then
				set_frame_section()
				ssb = string.format("%sWidth: %s\n", ssb, line:sub(11))
			elseif line:find("^PlayResY: ") then
				set_frame_section()
				ssb = string.format("%sHeight: %s\n", ssb, line:sub(11))
			-- Save style
			elseif line:find("^Style: ") then
				if current_section ~= 3 then
					ssb = ssb:len() == 0 and ssb .. "#STYLES\n" or ssb .. "\n#STYLES\n"
					current_section = 3
				end
				
				-- TODO
				
			-- Save event
			elseif line:find("^Comment: ") or line:find("^Dialogue: ") then
				if current_section ~= 4 then
					ssb = ssb:len() == 0 and ssb .. "#EVENTS\n" or ssb .. "\n#EVENTS\n"
					current_section = 4
				end
				
				-- TODO
				
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
				error("Couldn't write in file %q!", config.filename)
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
