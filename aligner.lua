obs = obslua
enabled = false
prefix = '^%d+x%d+_'
padding = 300


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
                -- Get info about the rows and columns in the name
                local rows = tonumber(string.match(sourceName,"%d+", 1))
                local cols = tonumber(string.match(sourceName,"%d+", 2))

                if rows < 2 and cols < 2 then
                    goto continue
                end

                --obs.obs_sceneitem_group_enum_items()
                local group = obs.obs_group_from_source(source)
                --if not obs.obs_sceneitem_is_group(source) then
                --    print("Somehow we encountered a non-group")
                --    goto continue
                --end
                local group_items = obs.obs_scene_enum_items(group)
                
                for _, group_item in ipairs(group_items) do
                    if not obs.obs_sceneitem_visible(group_item) then
                        goto continue_gil
                    end

                    local group_item_source = obs.obs_sceneitem_get_source(group_item)
                    local group_item_name = obs.obs_source_get_name(group_item_source)

                    
                    print('found: ' .. group_item_name)
                    local pos = obs.vec2() -- x,y
                    obs.obs_sceneitem_get_pos(group_item, pos)
                    local scale = obs.vec2() -- x,y
                    obs.obs_sceneitem_get_scale(group_item, scale)
                    print(scale.x ..','..scale.y)
                    
                    local swidth = obs.obs_source_get_width(group_item_source)
                    local sheight = obs.obs_source_get_height(group_item_source)

                    local width = swidth * scale.x
                    local height = sheight * scale.y
                    --print(width .. ','..height..','..scale)

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
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	--obs.obs_data_set_default_int(settings, "duration", 5)
	obs.obs_data_set_default_string(settings, "prefix", prefix)
	obs.obs_data_set_default_bool(settings, "enabled", enabled)
end

-- a function named script_load will be called on startup
function script_load(settings)
    -- Adds an timer callback which triggers every millseconds.
    obs.timer_add(ticker, 4000)

    -- Removes a timer callback. (Note: You can also use remove_current_callback() to terminate the timer from the timer callback)
    -- timer_remove(callback)
end