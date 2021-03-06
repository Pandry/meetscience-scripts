obs           = obslua
source_name   = ""
total_seconds = 0

cur_seconds   = 0
last_text     = ""
stop_text     = ""
activated     = false
start_rec_on_end = false
set_vol_on_end = false
audio_track    = ""
volume_target = -40

transition_name = ""
transition_at_end = false
transition_destination_scene = ""
transition_time = 300
triggered = false

hotkey_id     = obs.OBS_INVALID_HOTKEY_ID

-- Function to set the time text
function set_time_text()
	local seconds       = math.floor(cur_seconds % 60)
	local total_minutes = math.floor(cur_seconds / 60)
	local minutes       = math.floor(total_minutes % 60)
	local hours         = math.floor(total_minutes / 60)
	local text          = string.format("%02d:%02d", minutes, seconds)

	if cur_seconds < 1 then
		triggered = true
		text = stop_text

		-- Start recording if requested and not already recording
		if start_rec_on_end and not obs.obs_frontend_recording_active() then
			obs.obs_frontend_recording_start()
		end

		-- Lower volume on end
		if set_vol_on_end then
			local source = obs.obs_get_source_by_name(audio_track)
			obs.obs_source_set_volume(source, math.pow(2,(volume_target/6)) )
		end

		-- Transition
		if transition_at_end then
			local old_transition = obs.obs_frontend_get_current_transition()
			-- https://github.com/obsproject/obs-studio/issues/5313
			--local old_transition_duration = obs.obs_frontend_get_transition_duration()

			local transition = get_transition_by_name(transition_name)
			--print(obs.obs_source_get_name(transition) .. transition_time)
			--obs.obs_frontend_set_current_transition(transition)
			obs.obs_frontend_set_current_transition(transition)
			obs.os_sleep_ms(100) 
			--obs.obs_frontend_set_current_transition(transition)
			--obs.obs_frontend_set_transition_duration(transition_time)
			local destination_scene = obs.obs_get_source_by_name(transition_destination_scene)
			obs.obs_transition_start(transition, obs.OBS_TRANSITION_MODE_AUTO, transition_time, destination_scene)
			--obs.os_sleep_ms(transition_time+500) 
			--obs.obs_frontend_set_current_transition(old_transition)
			--obs.obs_frontend_set_transition_duration(old_transition_duration)
		end
	end

	if text ~= last_text then
		local source = obs.obs_get_source_by_name(source_name)
		if source ~= nil then
			local settings = obs.obs_data_create()
			obs.obs_data_set_string(settings, "text", text)
			obs.obs_source_update(source, settings)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)
		end
	end

	last_text = text
end

function get_transition_by_name(name) 
	local obs_list = obs.obs_frontend_get_transitions()
	for _, transition in pairs(obs_list) do
		local transition_name = obs.obs_source_get_name(transition)
		if transition_name == name then
			obs.source_list_release(obs_list)
			return transition
		end
	end
	obs.source_list_release(obs_list)
	return nil
end

function timer_callback()
	cur_seconds = cur_seconds - 1
	if cur_seconds < 0 then
		obs.remove_current_callback()
		cur_seconds = 0
	end

	set_time_text()
end

function activate(activating)
	if activated == activating then
		return
	end

	activated = activating

	if activating then
		triggered = false
		cur_seconds = total_seconds
		set_time_text()
		obs.timer_add(timer_callback, 1000)
	else
		obs.timer_remove(timer_callback)
	end
end

-- Called when a source is activated/deactivated
function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
end

function source_activated(cd)
	activate_signal(cd, true)
end

function source_deactivated(cd)
	activate_signal(cd, false)
end

function reset(pressed)
	if not pressed then
		return
	end

	triggered = false
	activate(false)
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local active = obs.obs_source_active(source)
		obs.obs_source_release(source)
		activate(active)
	end
end

function reset_button_clicked(props, p)
	reset(true)
	return false
end

----------------------------------------------------------

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	local props = obs.obs_properties_create()
	obs.obs_properties_add_int(props, "duration", "Duration (minutes)", 1, 100000, 1)

	local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_unversioned_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)

	obs.obs_properties_add_text(props, "stop_text", "Final Text", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_button(props, "reset_button", "Reset Timer", reset_button_clicked)
	-- Recordings
	obs.obs_properties_add_bool(props, "start_rec_on_end", "Start recording on end")
	-- Volume
		-- Checkbox
	obs.obs_properties_add_bool(props, "set_vol_on_end", "Lower volume on end")
		-- Mixers
	local a = obs.obs_properties_add_list(props, "audio_track", "Audio track", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_channels = (bit.band(obs.obs_source_get_audio_mixers(source), bit.bor(1,bit.bor(2,bit.bor(3,bit.bor(4,bit.bor(5,6))))) ))
			if source_channels > 0 then
				source_id = obs.obs_source_get_unversioned_id(source)
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(a, name, name)
			end
		end
	end
	obs.source_list_release(sources)
		-- Target volume
	obs.obs_properties_add_int(props, "volume_target", "Target volume", -90, 0, 0.1)

	-- Transition
	obs.obs_properties_add_bool(props, "transition_at_end", "Enable transition on end")
	obs.obs_properties_add_int(props, "transition_time", "Transition time", 0, 5000, 100)

	local transitions_list = obs.obs_properties_add_list(props, "transition", "Transition", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local obs_list = obs.obs_frontend_get_transitions()
	for _, transition in pairs(obs_list) do
		local transition_name = obs.obs_source_get_name(transition)
		obs.obs_property_list_add_string(transitions_list, transition_name, transition_name)
	end
	obs.source_list_release(obs_list)


	local transition_destination_scene_list = obs.obs_properties_add_list(props, "transition_destination_scene", "Scene to transition to", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	obs_list = obs.obs_frontend_get_scenes()
	for _, scene in pairs(obs_list) do
		local scene_name = obs.obs_source_get_name(scene)
		obs.obs_property_list_add_string(transition_destination_scene_list, scene_name, scene_name)
	end
	obs.source_list_release(obs_list)


	return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Sets a text source to act as a countdown timer when the source is active.\n\nMade by Jim\nEdited by Pandry"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	activate(false)

	total_seconds = obs.obs_data_get_int(settings, "duration") * 60
	source_name = obs.obs_data_get_string(settings, "source")
	stop_text = obs.obs_data_get_string(settings, "stop_text")
	start_rec_on_end = obs.obs_data_get_bool(settings, "start_rec_on_end")
	set_vol_on_end = obs.obs_data_get_bool(settings, "set_vol_on_end")
	audio_track = obs.obs_data_get_string(settings, "audio_track")
	volume_target = obs.obs_data_get_int(settings, "volume_target")
	transition_time = obs.obs_data_get_int(settings, "transition_time")
	transition_at_end = obs.obs_data_get_bool(settings, "transition_at_end")
	transition_name = obs.obs_data_get_string(settings, "transition")
	transition_destination_scene = obs.obs_data_get_string(settings, "transition_destination_scene")

	reset(true)
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "duration", 5)
	obs.obs_data_set_default_string(settings, "stop_text", "Starting soon (tm)")
	obs.obs_data_set_default_bool(settings, "start_rec_on_end", false)
	-- Audio
		--	Checkbox 
	obs.obs_data_set_default_bool(settings, "set_vol_on_end", false)
	-- Target volume
	obs.obs_data_set_default_int(settings, "volume_target", -40)
	-- Transition
	obs.obs_data_set_default_int(settings, "transition_time", 300)
	obs.obs_data_set_default_bool(settings, "transition_at_end", false)
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
	local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
	obs.obs_data_set_array(settings, "reset_hotkey", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

-- a function named script_load will be called on startup
function script_load(settings)
	-- Connect hotkey and activation/deactivation signal callbacks
	--
	-- NOTE: These particular script callbacks do not necessarily have to
	-- be disconnected, as callbacks will automatically destroy themselves
	-- if the script is unloaded.  So there's no real need to manually
	-- disconnect callbacks that are intended to last until the script is
	-- unloaded.
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)

	hotkey_id = obs.obs_hotkey_register_frontend("reset_timer_thingy", "Reset Timer", reset)
	local hotkey_save_array = obs.obs_data_get_array(settings, "reset_hotkey")
	obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end
