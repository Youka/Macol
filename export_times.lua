-- Script information
script_name = "Export times"
script_description = "Exports times to given text file."
script_author = "Youka"
script_version = "1.0 (20.01.2014)"

-- Register macro to aegisub
aegisub.register_macro(script_name, script_description, function(subs, sel, act)
	-- Show configuration dialog
	local button, config = aegisub.dialog.display({
			{
				class = "label",
				x = 0, y = 0, width = 1, height = 1,
				label = "Format: "
			},
			{
				class = "edit", name = "format",
				x = 1, y = 0, width = 16, height = 1,
				text = "<H>:<MM>:<SS>.<ZZ*>,<H>:<MM>:<SS>.<ZZ*>", hint = "Time format (H = hours, M = minutes, S = seconds, Z = milliseconds, * = ignored milliseconds)"
			}
		},{"All", "Selected","Cancel"})
	-- Pressed process button
	if button == "All" or button == "Selected" then
		-- Show file save dialog
		local filename = aegisub.dialog.save("Save times", "", "", "Text files (.txt)|.txt", false)
		if filename then
			-- Try to open output file
			local file = io.open(filename, "w")
			if file then
				-- Write line time in wished format to output file
				local function write_time(sub)
					-- Convert milliseconds to hours, minutes, seconds and milliseconds
					local function parse_time(t)
						local h = math.floor(t / 3600000)
						t = t % 3600000
						local m = math.floor(t / 60000)
						t = t % 60000
						return h, m, math.floor(t / 1000), t % 1000
					end
					-- Collect time units of start and end time
					local start_h, start_m, start_s, start_ms = parse_time(sub.start_time)
					local end_h, end_m, end_s, end_ms = parse_time(sub.end_time)
					-- Insert times in format description
					local timestamp = config.format:gsub("<[HMSZ%*]+>", function(capture)
						-- Insert hours
						if capture == "<HH>" or capture == "<H>" then
							local sformat = "%0" .. capture:len()-2 .. "d"
							if start_h then
								local out = string.format(sformat, start_h)
								start_h = nil
								return out
							else
								return string.format(sformat, end_h)
							end
						-- Insert minutes
						elseif capture == "<MM>" or capture == "<M>" then
							local sformat = "%0" .. capture:len()-2 .. "d"
							if start_m then
								local out = string.format(sformat, start_m)
								start_m = nil
								return out
							else
								return string.format(sformat, end_m)
							end
						-- Insert seconds
						elseif capture == "<SS>" or capture == "<S>" then
							local sformat = "%0" .. capture:len()-2 .. "d"
							if start_s then
								local out = string.format(sformat, start_s)
								start_s = nil
								return out
							else
								return string.format(sformat, end_s)
							end
						-- Insert milliseconds
						elseif capture == "ZZZ" or capture == "ZZ" or capture == "<Z>" or
							    capture == "<ZZ*>" or capture == "Z*" then
							local sformat, ten_precision
							if capture:find("%*") then
								sformat, ten_precision = "%0" .. capture:len()-3 .. "d", true
							else
								sformat, ten_precision = "%0" .. capture:len()-2 .. "d", false
							end
							if start_ms then
								local out = string.format(sformat, ten_precision and start_ms / 10 or start_ms)
								start_ms = nil
								return out
							else
								return string.format(sformat, ten_precision and end_ms / 10 or end_ms)
							end
						-- Re-insert invalid capture
						else
							return capture
						end
					end)
					-- Write formatted time to output file
					file:write(timestamp)
					file:write("\n")
				end
				-- Iterate through wished lines for time output
				if button == "All" then
					for i = 1, subs.n do
						local sub = subs[i]
						if sub.class == "dialogue" then
							write_time(sub)
						end
					end
				else -- button == "Selected"
					for _, i in ipairs(sel) do
						write_time(subs[i])
					end
				end
			else
				-- Couldn't open output file
				aegisub.log("Couldn't write to file %q", filename)
				aegisub.cancel()
			end
		end
	end
end)
