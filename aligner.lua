obs = obslua
enabled = false
prefix = '^[vh]c_'
padding = 40

function ticker()
    if not enabled then
        return
    end
    local sources = obs.obs_enum_sources()
	if sources ~= nil then
        --local source = obs.obs_get_source_by_name(current_scene_name())
		for _, source in ipairs(sources) do
            local sourceName = obs.obs_source_get_name(source)
            local sourceKind = obs.obs_source_get_unversioned_id(source)
            if string.match(sourceName, prefix) ~= nil and sourceKind == "group" then
                -- The scene matches the name
                local isVerticalAlign = string.match(sourceName,"^v", 1) ~= nil 

                local group = obs.obs_group_from_source(source)
                local group_items = obs.obs_scene_enum_items(group)
                
                local firstIteration = true
                local newScale = obs.vec2()
                local i = 0
                local height = 0
                local width = 0
                for _, group_item in ipairs(group_items) do
                    if not obs.obs_sceneitem_visible(group_item) then
                        goto continue_gil
                    end

                    local group_item_source = obs.obs_sceneitem_get_source(group_item)
                    if firstIteration then
                        obs.obs_sceneitem_get_scale(group_item, newScale)
                        height = round(obs.obs_source_get_height(group_item_source) * newScale.x)
                        width = round(obs.obs_source_get_width(group_item_source) * newScale.y)
                    else
                        obs.obs_sceneitem_set_scale(group_item, newScale)
                    end
                    local pos = obs.vec2()
                    if isVerticalAlign then
                        obs.vec2_set(pos, 0, i*padding + i*height )
                    else
                        obs.vec2_set(pos, i*padding + i*width ,0)
                    end
                    obs.obs_sceneitem_set_pos(group_item, pos)
                    
                    firstIteration = false
                    i = i+1
                    ::continue_gil::
                end
                --obs.obs_scene_release(group) - no need for obs_group_from_source
                obs.sceneitem_list_release(group_items)
            end
            ::continue::
		end
	end
	obs.source_list_release(sources)
end

function script_properties()
	local props = obs.obs_properties_create()
	obs.obs_properties_add_bool(props, "enabled", "Enabled")
    obs.obs_properties_add_text(props, "prefix", "Prefix of the group", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_int(props, "padding", "Padding", 0, 1000, 1)

	return props
end


-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Centers the elements on group \nMade by Pandry"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
    enabled = obs.obs_data_get_bool(settings, "enabled")
    prefix  = obs.obs_data_get_string(settings, "prefix")
    padding  = obs.obs_data_get_int(settings, "padding")
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	--obs.obs_data_set_default_int(settings, "duration", 5)
	obs.obs_data_set_default_string(settings, "prefix", prefix)
	obs.obs_data_set_default_bool(settings, "enabled", enabled)
	obs.obs_data_set_default_int(settings, "padding", padding)
end

-- a function named script_load will be called on startup
function script_load(settings)
    -- Adds an timer callback which triggers every millseconds.
    obs.timer_add(ticker, 100)

    -- Removes a timer callback. (Note: You can also use remove_current_callback() to terminate the timer from the timer callback)
    -- timer_remove(callback)
end

function round(n)
    return math.floor(n + 0.5)
 end