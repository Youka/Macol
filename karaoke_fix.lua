script_name = "Karaoke fix"
script_description = "Fixes some faults in karaoke time."
script_author = "Youka"
script_version = "1.0"
script_modified = "9th August 2011"

function karaoke_strip(subs)
	for li=1, #subs do
		local sub = subs[li]
		if sub.class == "dialogue" then
			local start_offset, sum_time = 0, 0
			local i, n = 0, 0
			local function counter()
				n = n + 1
			end
			local function filter(syl)
				i = i + 1
				local t, text = syl:match("{.-\\[kK][of]?(%d+).-}([^{]*)")
				t = tonumber(t) * 10
				text = text:gsub("^%s*(.-)%s*$", "%1")
				if t == 0 or (i == n and text == "") then
					return ""
				elseif i == 1 and text == "" then
					start_offset = t
					return ""
				else
					sum_time = sum_time + t
					return syl
				end
			end
			sub.text:gsub("{.-\\[kK][of]?%d+.-}[^{]*", counter)
			if n > 0 then
				sub.text = sub.text:gsub("{.-\\[kK][of]?%d+.-}[^{]*", filter)
				sub.start_time = sub.start_time + start_offset
				sub.end_time = sub.start_time + sum_time
				subs[li] = sub
			end
		end
	end
	aegisub.set_undo_point("\""..script_name.."\"")
end

aegisub.register_macro(script_name, script_description, karaoke_strip)
