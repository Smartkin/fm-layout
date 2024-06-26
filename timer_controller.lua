-- Controller source to get time from timer source and split it if needed

local obs = obslua
local bit = require("bit")
local table_to_string = require("table_to_string")

timer_controller = {}
timer_controller.id = "fm_timer_controller"
timer_controller.output_flags = obs.OBS_SOURCE_CAP_DISABLED

timer_controller.get_name = function()
    return "FM multiplayer layout timer controller"
end

timer_controller.create = function(settings, source)
    local data = {}
    data.uuid = obs.obs_source_get_uuid(source)

    local ctx = util.create_item_ctx(timer_controller.get_id(data))
    ctx.id = timer_controller.get_id(data)
    ctx.scene = obs.obs_data_get_string(settings, util.setting_names.scene)

    -- obs.script_log(obs.LOG_INFO, "Created timer controller " .. obs.obs_data_get_json(settings))

    ctx.props_settings = settings

    return data
end

timer_controller.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, util.setting_names.runner_amt, 1)
end

timer_controller.get_id = function(data)
    return timer_controller.id .. data.uuid
end

-- Binds the function call to the object and one additional parameter
local function bind(t, k, p)
    return function(...) return t[k](t, p, ...) end
end

timer_controller.timer_start_finish = function(self, data, props, prop)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))
    local state = ctx.state
    if state == nil then
        state = util.timer_states.stopped
    end
    local timer = obs.obs_get_source_by_uuid(obs.obs_data_get_string(ctx.props_settings, util.setting_names.timer_source))
    if state == util.timer_states.stopped or state == util.timer_states.paused then
        ctx.state = util.timer_states.running
        obs.obs_source_media_play_pause(timer, false)
        obs.obs_property_set_description(prop, util.timer_controller_names.timer_finish)
        obs.obs_property_set_visible(data.pause_continue_btn, true)
    elseif state == util.timer_states.running then
        ctx.state = util.timer_states.finished
        obs.obs_source_media_next(timer)
        obs.obs_property_set_description(prop, util.timer_controller_names.timer_reset)
        obs.obs_property_set_visible(data.pause_continue_btn, false)
        obs.obs_property_set_visible(data.continue_after_finish_btn, true)
    elseif state == util.timer_states.finished then
        ctx.state = util.timer_states.stopped
        obs.obs_source_media_stop(timer)
        obs.obs_property_set_description(prop, util.timer_controller_names.timer_start)
        obs.obs_property_set_visible(data.pause_continue_btn, false)
        obs.obs_property_set_visible(data.continue_after_finish_btn, false)
    end
    return true
end

timer_controller.timer_continue_after_finish = function(self, data, props, prop)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))
    local state = ctx.state
    if state == nil then
        return false
    end
    if state ~= util.timer_states.finished then
        return false
    end

    local timer = obs.obs_get_source_by_uuid(obs.obs_data_get_string(ctx.props_settings, util.setting_names.timer_source))
    ctx.state = util.timer_states.running
    obs.obs_source_media_previous(timer)
    obs.obs_property_set_description(data.start_finish_btn, util.timer_controller_names.timer_finish)
    obs.obs_property_set_visible(data.pause_continue_btn, true)
    obs.obs_property_set_visible(prop, false)
    return true
end

timer_controller.timer_pause_continue = function(self, data, props, prop)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))
    local state = ctx.state
    if state == nil then
        return false
    end
    local timer = obs.obs_get_source_by_uuid(obs.obs_data_get_string(ctx.props_settings, util.setting_names.timer_source))
    if state == util.timer_states.running then
        ctx.state = util.timer_states.paused
        obs.obs_source_media_play_pause(timer, true)
        obs.obs_property_set_description(prop, util.timer_controller_names.timer_continue)
    elseif state == util.timer_states.paused then
        ctx.state = util.timer_states.running
        obs.obs_source_media_play_pause(timer, false)
        obs.obs_property_set_description(prop, util.timer_controller_names.timer_pause)
    end
    return true
end

local function update_runner_time(timer, state, ctx, setting_name)
    if state ~= util.timer_states.running and state ~= util.timer_states.finished then
        return false
    end
    local current_time_ms = obs.obs_source_media_get_time(timer)
    local seconds = math.floor(current_time_ms / 1000)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    local time_string = string.format("%d:%02d:%02d", hours, minutes % 60, seconds % 60)
    util.set_item_visible(ctx, setting_name, true)
    util.set_obs_text_source_text(ctx, obs.obs_data_get_string(ctx.props_settings, setting_name),
        time_string)
end

timer_controller.update_left_runner = function(self, data, props, prop)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))
    local state = ctx.state
    if state == nil then
        return false
    end
    local timer = obs.obs_get_source_by_uuid(obs.obs_data_get_string(ctx.props_settings, util.setting_names.timer_source))
    update_runner_time(timer, state, ctx, util.setting_names.left_runner)
    return false
end

timer_controller.update_right_runner = function(self, data, props, prop)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))
    local state = ctx.state
    if state == nil then
        return false
    end
    local timer = obs.obs_get_source_by_uuid(obs.obs_data_get_string(ctx.props_settings, util.setting_names.timer_source))
    update_runner_time(timer, state, ctx, util.setting_names.right_runner)
    return false
end

timer_controller.update_top_left_runner = function(self, data, props, prop)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))
    local state = ctx.state
    if state == nil then
        return false
    end
    local timer = obs.obs_get_source_by_uuid(obs.obs_data_get_string(ctx.props_settings, util.setting_names.timer_source))
    update_runner_time(timer, state, ctx, util.setting_names.top_left_runner)
    return false
end

timer_controller.update_top_right_runner = function(self, data, props, prop)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))
    local state = ctx.state
    if state == nil then
        return false
    end
    local timer = obs.obs_get_source_by_uuid(obs.obs_data_get_string(ctx.props_settings, util.setting_names.timer_source))
    update_runner_time(timer, state, ctx, util.setting_names.top_right_runner)
    return false
end

timer_controller.update_bottom_left_runner = function(self, data, props, prop)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))
    local state = ctx.state
    if state == nil then
        return false
    end
    local timer = obs.obs_get_source_by_uuid(obs.obs_data_get_string(ctx.props_settings, util.setting_names.timer_source))
    update_runner_time(timer, state, ctx, util.setting_names.bottom_left_runner)
    return false
end

timer_controller.update_bottom_right_runner = function(self, data, props, prop)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))
    local state = ctx.state
    if state == nil then
        return false
    end
    local timer = obs.obs_get_source_by_uuid(obs.obs_data_get_string(ctx.props_settings, util.setting_names.timer_source))
    update_runner_time(timer, state, ctx, util.setting_names.bottom_right_runner)
    return false
end

timer_controller.reset_player_times = function(self, data, props, prop)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))
    local runner_amt = obs.obs_data_get_int(ctx.props_settings, util.setting_names.runner_amt)
    if runner_amt == 2 then
        util.set_item_visible(ctx, util.setting_names.left_runner, false)
        util.set_item_visible(ctx, util.setting_names.right_runner, false)
    elseif runner_amt == 3 then
        util.set_item_visible(ctx, util.setting_names.top_left_runner, false)
        util.set_item_visible(ctx, util.setting_names.top_right_runner, false)
        util.set_item_visible(ctx, util.setting_names.bottom_left_runner, false)
    elseif runner_amt == 4 then
        util.set_item_visible(ctx, util.setting_names.top_left_runner, false)
        util.set_item_visible(ctx, util.setting_names.top_right_runner, false)
        util.set_item_visible(ctx, util.setting_names.bottom_left_runner, false)
        util.set_item_visible(ctx, util.setting_names.bottom_right_runner, false)
    end
end

timer_controller.get_properties = function(data)
    local ctx = util.get_item_ctx(timer_controller.get_id(data))

    local btn_names = {
        timer_start = util.timer_controller_names.timer_start,
        timer_pause = util.timer_controller_names.timer_pause
    }

    if ctx.state == util.timer_states.finished then
        btn_names.timer_start = util.timer_controller_names.timer_reset
    elseif ctx.state == util.timer_states.running then
        btn_names.timer_start = util.timer_controller_names.timer_finish
    elseif ctx.state == util.timer_states.paused then
        btn_names.timer_pause = util.timer_controller_names.timer_continue
    end

    ctx.props_def = obs.obs_properties_create()

    local runner_amt = obs.obs_data_get_int(ctx.props_settings, util.setting_names.runner_amt)
    -- obs.script_log(obs.LOG_INFO, "Runner amount in timer controller " .. tostring(runner_amt))
    if runner_amt > 1 then
        obs.obs_properties_add_button(ctx.props_def, "reset_runner_times",
            util.timer_controller_names.reset_runner_times, bind(timer_controller, "reset_player_times", data))
    end
    if runner_amt == 2 then
        obs.obs_properties_add_button(ctx.props_def, "left_runner", util.timer_controller_names.left_runner,
            bind(timer_controller, "update_left_runner", data))
        obs.obs_properties_add_button(ctx.props_def, "right_runner", util.timer_controller_names.right_runner,
            bind(timer_controller, "update_right_runner", data))
    elseif runner_amt == 3 then
        obs.obs_properties_add_button(ctx.props_def, "top_left_runner", util.timer_controller_names.top_left_runner,
            bind(timer_controller, "update_top_left_runner", data))
        obs.obs_properties_add_button(ctx.props_def, "top_right_runner", util.timer_controller_names.top_right_runner,
            bind(timer_controller, "update_top_right_runner", data))
        obs.obs_properties_add_button(ctx.props_def, "bottom_left_runner",
            util.timer_controller_names.bottom_left_runner, bind(timer_controller, "update_bottom_left_runner", data))
    elseif runner_amt == 4 then
        obs.obs_properties_add_button(ctx.props_def, "top_left_runner", util.timer_controller_names.top_left_runner,
            bind(timer_controller, "update_top_left_runner", data))
        obs.obs_properties_add_button(ctx.props_def, "top_right_runner", util.timer_controller_names.top_right_runner,
            bind(timer_controller, "update_top_right_runner", data))
        obs.obs_properties_add_button(ctx.props_def, "bottom_left_runner",
            util.timer_controller_names.bottom_left_runner, bind(timer_controller, "update_bottom_left_runner", data))
        obs.obs_properties_add_button(ctx.props_def, "bottom_right_runner",
            util.timer_controller_names.bottom_right_runner, bind(timer_controller, "update_bottom_right_runner", data))
    end

    data.continue_after_finish_btn = obs.obs_properties_add_button(ctx.props_def, "continue_after_finish",
        util.timer_controller_names.timer_continue, bind(timer_controller, "timer_continue_after_finish", data))
    data.start_finish_btn = obs.obs_properties_add_button(ctx.props_def, "start_finish_timer", btn_names.timer_start,
        bind(timer_controller, "timer_start_finish", data))
    data.pause_continue_btn = obs.obs_properties_add_button(ctx.props_def, "pause_continue_timer", btn_names.timer_pause,
        bind(timer_controller, "timer_pause_continue", data))

    obs.obs_property_set_visible(data.continue_after_finish_btn, false)
    obs.obs_property_set_visible(data.pause_continue_btn, false)

    return ctx.props_def
end

timer_controller.get_width = function(data)
    return 0
end

timer_controller.get_height = function(data)
    return 0
end


obs.obs_register_source(timer_controller)
