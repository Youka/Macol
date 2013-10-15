-- Macro description
script_name = "Audio"
script_description = "Draws audio signals as subtitles."
script_author = "Youka"
script_version = "1.2"
script_modified = "25th February 2013"

-- Bytes to number
local function bton(s)
	local bytes = {s:byte(1,#s)}
	local n = 0
	for i = 0, #bytes-1 do
		n = n + 2^(i*8) * bytes[1+i]
	end
	return n
end

-- Read audio file and store data in memory
local function collect_audio_data(filename)
	-- WAVE data storage
	local wav = {channels = nil, sample_rate = nil, samples = nil, data = nil}
	-- Open file
	local file = io.open(filename, "rb")
	if not file then
		return string.format("Filename %q isn't valid!", filename)
	end
	-- File chunk
	if file:read(4) ~= "RIFF" then
		return "Isn't a 'RIFF' file"
	end
	file:seek("cur", 4)	-- Ignore file size
	if file:read(4) ~= "WAVE" then
		return "Isn't a 'WAVE' file"
	end
	-- Subchunks
	while true do
		-- Chunk id and size
		local id = file:read(4)
		local size = file:read(4)
		-- No more chunks
		if not size then
			break
		-- Chunk to read
		else
			size = bton(size)
			-- Format chunk
			if id == "fmt " then
				local bytes = file:read(2)
				if not bytes or bton(bytes) ~= 1 then
					return "Data format must be PCM!"
				end
				bytes = file:read(2)
				if not bytes then
					return "Channels are missing!"
				end
				wav.channels = bton(bytes)
				bytes = file:read(4)
				if not bytes then
					return "Sample rate is missing!"
				end
				wav.sample_rate = bton(bytes)
				file:seek("cur", 4+2)	-- Ignore byte rate and block align
				bytes = file:read(2)
				if not bytes or bton(bytes) ~= 16 then
					return "Bits per sample must be 16!"
				end
				file:seek("cur", size-16)	-- Ignore extra data
			-- Data chunk
			elseif id == "data" then
				if not wav.channels then
					return "Format must be before data!"
				end
				wav.samples = size / (wav.channels * 2)
				do
					local file_cur_pos = file:seek("cur", 0)
					local file_end_pos = file:seek("end", 0)
					if file_end_pos - file_cur_pos < wav.samples * wav.channels * 2 then
						return "Remaining file bytes aren't enough to collect all samples!"
					end
					file:seek("set", file_cur_pos)
				end
				wav.data = {}
				for c = 1, wav.channels do
					wav.data[c] = {n = 0}
				end
				for s = 1, wav.samples do
					for c = 1, wav.channels do
						local sample = bton(file:read(2))
						wav.data[c].n = wav.data[c].n + 1
						wav.data[c][wav.data[c].n] = sample > 32767 and sample - 65536 or sample
					end
					if aegisub.progress.is_cancelled() then
						return "Samples reading cancelled!"
					end
					aegisub.progress.set(s / wav.samples * 100)
				end
				break	-- Was last needed chunk
			-- Ignorable chunk
			else
				file:seek("cur", size)
			end
		end
	end
	-- All WAVE data collected?
	if not wav.channels then
		return "Format is missing!"
	elseif not wav.data then
		return "Data are missing!"
	end
	-- Return no error and WAVE data
	return nil, wav
end

-- Conversion: amplitudes to magnitudes
function amplitudes_to_magnitudes(amplitudes)
	-- Complex numbers
	local complex_t
	do
		local complex = {}
		local function tocomplex(a, b)
			if type(b) == "number" then return a, {r = b, i = 0}
			elseif type(a) == "number" then return {r = a, i = 0}, b
			else return a, b end
		end
		complex.__add = function(a, b)
			local c1, c2 = tocomplex(a, b)
			return setmetatable({r = c1.r + c2.r, i = c1.i + c2.i}, complex)
		end
		complex.__sub = function(a, b)
			local c1, c2 = tocomplex(a, b)
			return setmetatable({r = c1.r - c2.r, i = c1.i - c2.i}, complex)
		end
		complex.__mul = function(a, b)
			local c1, c2 = tocomplex(a, b)
			return setmetatable({r = c1.r * c2.r - c1.i * c2.i, i = c1.r * c2.i + c1.i * c2.r}, complex)
		end
		complex.__index = complex
		complex_t = function(r, i)
			return setmetatable({r = r, i = i}, complex)
		end
	end
	local function polar(theta)
		return complex_t(math.cos(theta), math.sin(theta))
	end
	local function magnitude(c)
		return math.sqrt(c.r^2 + c.i^2)
	end
	-- Fast Fourier Transform
	local function fft(x)
		-- Check recursion break
		local N = #x
		if N > 1 then
			-- Divide
			local even, even_n, odd, odd_n = {}, 0, {}, 0
			for i=1, N, 2 do
				even_n = even_n + 1
				even[even_n] = x[i]
			end
			for i=2, N, 2 do
				odd_n = odd_n + 1
				odd[odd_n] = x[i]
			end
			-- Conquer
			fft(even)
			fft(odd)
			--Combine
			local t
			for k = 1, N/2 do
				t = polar(-2 * math.pi * (k-1) / N) * odd[k]
				x[k] = even[k] + t
				x[k+N/2] = even[k] - t
			end
		end
	end
	-- Amplitudes to complex numbers
	local data, data_n = {}, 0
	for _, amplitude in ipairs(amplitudes) do
		data_n = data_n + 1
		data[data_n] = complex_t(amplitude, 0)
	end
	-- Process FFT
	fft(data)
	-- Complex numbers to magnitudes
	for i = 1, data_n do
		data[i] = magnitude(data[i])
	end
	return data
end

-- Draw audio data as subtitles
local function draw_audio_data(subs, wav, display, frame_dur, shape_width, shape_height, line_width)
	-- Dialog line template
	local sub = {
		class = "dialogue",
		raw = "",
		section = "[Events]",
		comment = false,
		layer = 0,
		start_time = 0,
		end_time = 0,
		style = "Audio",
		actor = "",
		margin_l = 0,
		margin_r = 0,
		margin_t = 0,
		margin_b = 0,
		effect = "",
		text = ""
	}
	-- Samples per frame
	local frame_samples_max = frame_dur / 1000 * wav.sample_rate
	-- Draw amplitudes
	if display == "Amplitudes" then
		-- Multiplicator for max amplitude offset
		local amplitude_multiplicator = shape_height / 2 / -32768
		-- Through channels
		for c = 1, wav.channels do
			-- Through frames
			local start_sample_i = 1
			while start_sample_i + math.floor(frame_samples_max-1) <= wav.samples do
				-- Set frame time
				sub.start_time = (start_sample_i-1) / frame_samples_max * frame_dur
				sub.end_time = sub.start_time + frame_dur
				-- Collect frame samples from current channel and scale correctly
				local frame_samples, frame_samples_n = {}, 0
				for s = 0, math.floor(frame_samples_max-1) do
					frame_samples_n = frame_samples_n + 1
					frame_samples[frame_samples_n] = wav.data[c][math.floor(start_sample_i) + s] * amplitude_multiplicator
				end
				-- Create amplitudes shape
				local amplitude_shape, amplitude_shape_n = {string.format("m 0 %d l", frame_samples[1])}, 1
				local amplitude
				for x = 1, shape_width do
					amplitude = frame_samples[1 + math.floor(x/shape_width * (frame_samples_n-1))]
					amplitude_shape_n = amplitude_shape_n + 1
					amplitude_shape[amplitude_shape_n] = string.format("%d %d", x, amplitude)
				end
				for x = shape_width, 0, -1 do
					amplitude = frame_samples[1 + math.floor(x/shape_width * (frame_samples_n-1))]
					amplitude_shape_n = amplitude_shape_n + 1
					amplitude_shape[amplitude_shape_n] = string.format("%d %d", x, amplitude - line_width)
				end
				amplitude_shape = table.concat(amplitude_shape, " ")
				-- Output amplitudes dialog line
				sub.text = string.format("{\\pos(0,%d)\\p1}%s", shape_height / 2 + (c-1) * shape_height, amplitude_shape)
				subs.append(sub)
				-- Prepare next frame
				start_sample_i = start_sample_i + frame_samples_max
				if aegisub.progress.is_cancelled() then
					return "Samples drawing cancelled!"
				end
				aegisub.progress.set(start_sample_i / wav.data[1].n * 100)
			end
		end
	-- Draw magnitudes
	else
		-- Multiplicator for magnitude offset
		local magnitude_multiplicator = shape_height / -100
		-- Samples per frame with exponent of 2
		local frame_samples_max_exp2
		do
			local exp = 1
			while 2^exp <= frame_samples_max do
				exp = exp + 1
			end
			frame_samples_max_exp2 = 2^(exp-1)
		end
		-- Through channels
		for c = 1, wav.channels do
			-- Through frames
			local start_sample_i = 1
			while start_sample_i + math.floor(frame_samples_max-1) <= wav.samples do
				-- Set frame time
				sub.start_time = (start_sample_i-1) / frame_samples_max * frame_dur
				sub.end_time = sub.start_time + frame_dur
				-- Collect frame samples from current channel and scale for following conversion
				local frame_samples, frame_samples_n = {}, 0
				for s = 0, math.floor(frame_samples_max_exp2-1) do
					frame_samples_n = frame_samples_n + 1
					frame_samples[frame_samples_n] = wav.data[c][math.floor(start_sample_i) + s] / 32768
				end
				-- Convert amplitudes to magnitudes
				frame_samples = amplitudes_to_magnitudes(frame_samples)
				-- Create magnitudes shape (before: scale magnitude correctly)
				local magnitude_shape, magnitude_shape_n = {string.format("m 0 %d l", frame_samples[1] * magnitude_multiplicator)}, 1
				local magnitude
				for x = 1, shape_width do
					magnitude = frame_samples[1 + math.floor(x/shape_width * (frame_samples_n-1))]
					magnitude_shape_n = magnitude_shape_n + 1
					magnitude_shape[magnitude_shape_n] = string.format("%d %d", x, magnitude * magnitude_multiplicator)
				end
				for x = shape_width, 0, -1 do
					magnitude = frame_samples[1 + math.floor(x/shape_width * (frame_samples_n-1))]
					magnitude_shape_n = magnitude_shape_n + 1
					magnitude_shape[magnitude_shape_n] = string.format("%d %d", x, magnitude * magnitude_multiplicator - line_width)
				end
				magnitude_shape = table.concat(magnitude_shape, " ")
				-- Output magnitudes dialog line
				sub.text = string.format("{\\pos(0,%d)\\p1}%s", c * shape_height, magnitude_shape)
				subs.append(sub)
				-- Prepare next frame
				start_sample_i = start_sample_i + frame_samples_max
				if aegisub.progress.is_cancelled() then
					return "Samples drawing cancelled!"
				end
				aegisub.progress.set(start_sample_i / wav.data[1].n * 100)
			end
		end
	end
end

-- Add missing 'Audio' style
local function add_audio_style(subs)
	-- Find first style line index and search for existing 'Audio' style
	local first_style_i, found_audio_style
	for i = 1, subs.n do
		local sub = subs[i]
		if sub.class == "format" and sub.section == "[V4+ Styles]" then
			first_style_i = i + 1
		end
		if sub.class == "style" and sub.name == "Audio" then
			found_audio_style = true
			break
		end
	end
	-- Add 'Audio' style
	if first_style_i and not found_audio_style then
		subs.insert(first_style_i, {
			class = "style",
			raw = "Style: Audio,Arial,1,&H00FFFFFF,&H00FFFFFF,&H00FFFFFF,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1",
			section = "[V4+ Styles]",
			name = "Audio",
			fontname = "Arial",
			fontsize = 1,
			color1 = "&H00FFFFFF",
			color2 = "&H00FFFFFF",
			color3 = "&H00FFFFFF",
			color4 = "&H00000000",
			bold = false,
			italic = false,
			underline = false,
			strikeout = false,
			scale_x = 100,
			scale_y = 100,
			spacing = 0,
			angle = 0,
			borderstyle = 1,
			outline = 0,
			shadow = 0,
			align = 7,
			margin_l = 0,
			margin_r = 0,
			margin_t = 0,
			margin_b = 0,
			encoding = 1
		})
		return true
	end
end

-- Config results of last generation
local old_config = {
	filename = "",
	display = "Amplitudes",
	frame_dur = 40,
	shape_width = 700,
	shape_height = 200,
	line_width = 2
}

-- Audio GUI
local function audio_gui(subs)
	-- Set task dialog
	aegisub.progress.title(script_name)
	aegisub.progress.set(0)
	aegisub.progress.task("Configuration")
	-- Display config dialog
	local button, config = aegisub.dialog.display(
		-- Config panel
		{
			{class = "label", x = 0, y = 0, width = 1, height = 1, label = "Audio file: "},
			{class = "edit", x = 1, y = 0, width = 1, height = 1, hint = "Audio file to visualize", name = "filename", text = old_config.filename},
			{class = "label", x = 0, y = 1, width = 1, height = 1, label = "Display: "},
			{class = "dropdown", x = 1, y = 1, width = 1, height = 1, hint = "Display audio data as...?", name = "display", value = old_config.display, items = {"Amplitudes", "Magnitudes"}},
			{class = "label", x = 0, y = 2, width = 1, height = 1, label = "Frame duration: "},
			{class = "floatedit", x = 1, y = 2, width = 1, height = 1, hint = "Duration in milliseconds of one frame", name = "frame_dur", value = old_config.frame_dur, min = 10, max = 3600000, step = 0.1},
			{class = "label", x = 0, y = 3, width = 1, height = 1, label = "Drawing width: "},
			{class = "intedit", x = 1, y = 3, width = 1, height = 1, hint = "Width of drawing", name = "shape_width", value = old_config.shape_width, min = 10, max = 2000},
			{class = "label", x = 0, y = 4, width = 1, height = 1, label = "Drawing max height: "},
			{class = "intedit", x = 1, y = 4, width = 1, height = 1, hint = "Maximal height of drawing", name = "shape_height", value = old_config.shape_height, min = 2, max = 200},
			{class = "label", x = 0, y = 5, width = 1, height = 1, label = "Drawing weight: "},
			{class = "intedit", x = 1, y = 5, width = 1, height = 1, hint = "Line width of drawing", name = "line_width", value = old_config.line_width, min = 1, max = 20}
		},
		-- Config buttons
		{"Generate", "Close"}
	)
	-- (Fix floatedit bug)
	if config.frame_dur < 10 then
		config.frame_dur = 10
	elseif config.frame_dur > 3600000 then
		config.frame_dur = 3600000
	end
	-- Save config for next display
	old_config = config
	-- Clicked button was 'Generate'?
	if button == "Generate" then
		-- Collect audio data
		aegisub.progress.task("Read audio data")
		local err, wav = collect_audio_data(config.filename)
		if err then
			aegisub.debug.out(1, err)
		else
			-- Draw audio data
			aegisub.progress.task("Draw audio data")
			err = draw_audio_data(subs, wav, config.display, config.frame_dur, config.shape_width, config.shape_height, config.line_width)
			if err then
				aegisub.debug.out(0, err)
			else
				-- Add style for audio
				if add_audio_style(subs) then
					aegisub.debug.out(3, "'Audio' style added!")
				end
			end
			-- Set undo point
			aegisub.set_undo_point(string.format("%q", script_name))
		end
	end
end

-- Register macro
aegisub.register_macro(script_name, script_description, audio_gui)
