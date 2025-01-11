--- @diagnostic disable: unused-local
--- @module 'blink.cmp'

local default = require('blink-cmp-git.default')
local utils = require('blink-cmp-git.utils')
local log = require('blink-cmp-git.log')
local Job = require('plenary.job')
log.setup({ title = 'blink-cmp-git' })

--- @type blink.cmp.Source
--- @diagnostic disable-next-line: missing-fields
local GitSource = {}
--- @type blink-cmp-git.Options
local git_source_config
local items_cache

--- @param documentation_command blink-cmp-git.DocumentationCommand
--- @return Job
local function create_job_from_documentation_command(documentation_command)
    return Job:new({
        command = utils.get_option(documentation_command.get_command),
        args = utils.get_option(documentation_command.get_command_args),
    })
end

local function set_cached_items(trigger, items)
    if not utils.get_option(git_source_config.use_items_cache) or not utils.truthy(trigger) then
        return
    end
    if not items_cache[trigger] then
        items_cache[trigger] = {}
    end
    for _, item in pairs(items) do
        items_cache[trigger][item.label] = item
    end
end

local function get_cached_items(trigger)
    if not utils.get_option(git_source_config.use_items_cache) or not utils.truthy(trigger) then
        return nil
    end
    return items_cache[trigger]
end

local function set_cached_item_documentation(trigger, label, documentation)
    if not utils.get_option(git_source_config.use_items_cache) or
        not utils.truthy(trigger) or not utils.truthy(label) then
        return
    end
    if not items_cache[trigger] then
        items_cache[trigger] = {}
    end
    if not items_cache[trigger][label] then
        items_cache[trigger][label] = {}
    end
    items_cache[trigger][label].documentation = documentation
end

local function get_cached_item_documentation(trigger, label)
    if not utils.get_option(git_source_config.use_items_cache) or
        not utils.truthy(trigger) or not utils.truthy(label) then
        return nil
    end
    return items_cache[trigger] and items_cache[trigger][label] and
        type(items_cache[trigger][label].documentation) == 'string' and
        items_cache[trigger][label].documentation or nil
end

--- @param opts blink-cmp-git.Options
function GitSource.new(opts, _)
    local self = setmetatable({}, { __index = GitSource })
    git_source_config = vim.tbl_deep_extend("force", default, opts or {})
    items_cache = {}
    return self
end

function GitSource:get_trigger_characters()
    local result = {}
    for _, git_center in ipairs(vim.tbl_values(git_source_config.git_centers)) do
        for _, feature in pairs(git_center) do
            local feature_triggers = utils.get_option(feature.triggers)
            if utils.truthy(feature_triggers) then
                for _, trigger in ipairs(feature_triggers) do
                    table.insert(result, trigger)
                end
            end
        end
    end
    for _, trigger in ipairs(utils.get_option(git_source_config.commit.triggers)) do
        table.insert(result, trigger)
    end
    return result
end

--- @return blink-cmp-git.GCSCompletionOptions[]
local function get_enabled_features()
    local result = {}
    for _, git_center in ipairs(vim.tbl_values(git_source_config.git_centers)) do
        for _, feature in pairs(git_center) do
            if utils.get_option(feature.enable) then
                table.insert(result, feature)
            end
        end
    end
    local commit = utils.get_option(git_source_config.commit)
    if commit and utils.get_option(commit.enable) then
        table.insert(result, commit)
    end
    return result
end

function GitSource:get_completions(context, callback)
    local cancel_fun = function() end
    local items = {}
    local transformed_callback = function()
        vim.schedule(function()
            callback({
                is_incomplete_backward = false,
                is_incomplete_forward = false,
                items = vim.tbl_values(items)
            })
        end)
    end
    local async = utils.get_option(git_source_config.async)
    ---@diagnostic disable-next-line: param-type-mismatch
    if not self:should_show_completions(context, nil) then
        transformed_callback()
        return cancel_fun
    end
    if utils.get_option(git_source_config.should_reload_items_cache) then
        items_cache = {}
    end
    local trigger = context.trigger.initial_character
    local cached_items = get_cached_items(trigger)
    if cached_items then
        items = cached_items
        transformed_callback()
        return cancel_fun
    end
    --- @type Job
    local job
    local trigger_pos = context.cursor[2] - 1
    local enabled_features = get_enabled_features()
    for _, feature in ipairs(enabled_features) do
        local feature_triggers = utils.get_option(feature.triggers)
        if utils.truthy(feature_triggers) and vim.tbl_contains(feature_triggers, trigger) then
            local cmd = utils.get_option(feature.get_command)
            local cmd_args = utils.get_option(feature.get_command_args)
            local next_job = Job:new({
                command = cmd,
                args = cmd_args,
                on_exit = function(j, return_value, _)
                    if return_value ~= 0 and utils.truthy(j:stderr_result()) then
                        log.error('command failed:', cmd,
                            '\n',
                            'cmd_args:', cmd_args,
                            '\n',
                            'with error code:', return_value,
                            '\n',
                            'stderr:', j:stderr_result())
                        return
                    end
                    if utils.truthy(j:result()) then
                        local match_list = utils.get_option(feature.separate_output,
                            table.concat(j:result(), '\n'))
                        vim.iter(match_list):each(function(match)
                            items[match] = {
                                label = match.label,
                                kind = require('blink.cmp.types').CompletionItemKind.Text,
                                textEdit = {
                                    newText = match.insert_text,
                                    range = {
                                        start = {
                                            line = context.cursor[1] - 1,
                                            character = context.cursor[2] - 1
                                        },
                                        ['end'] = {
                                            line = context.cursor[1] - 1,
                                            -- TODO: check this
                                            character = context.cursor[2] - 1
                                                + #match.insert_text
                                        }
                                    }
                                },
                                documentation = match.documentation,
                                gitSouceTrigger = trigger,
                            }
                        end)
                    else
                        log.trace('search command return empty result')
                    end
                end
            })
            if not job then
                job = next_job
            else
                job:and_then(next_job)
            end
        end
    end
    -- the feature for the trigger may not be enabled
    if job == nil then
        transformed_callback()
        return cancel_fun
    end
    job:after(function()
        set_cached_items(trigger, items)
        transformed_callback()
    end)
    if async then
        cancel_fun = function() job:shutdown(0, nil) end
    end
    if async then
        job:start()
    else
        job:sync()
    end
    return cancel_fun
end

-- HACK: the blink.cmp does not call this function
function GitSource:should_show_completions(context, _)
    return context.trigger.initial_kind == 'trigger_character' and context.mode ~= 'cmdline'
        and vim.tbl_contains(self:get_trigger_characters(), context.trigger.initial_character)
end

function GitSource:resolve(item, callback)
    ---@diagnostic disable-next-line: undefined-field
    local trigger = item.gitSourceTrigger
    local transformed_callback = function()
        callback(item)
    end
    local cached_item_documentation = get_cached_item_documentation(trigger, item.label)
    if cached_item_documentation then
        item.documentation = cached_item_documentation
        transformed_callback()
        return
    end
    if type(item.documentation) == 'string' then
        set_cached_item_documentation(trigger, item.label, item.documentation)
        transformed_callback()
        return
    end
    ---@diagnostic disable-next-line: param-type-mismatch
    local job = create_job_from_documentation_command(item.documentation)
    job:after(function()
        if utils.truthy(job:result()) then
            item.documentation =
            ---@diagnostic disable-next-line: undefined-field
                item.documentation.resolve_documentation(table.concat(job:result(), '\n'))
            set_cached_item_documentation(trigger, item.label, item.documentation)
        else
            item.documentation = nil
        end
        transformed_callback()
    end)
    if utils.get_option(git_source_config.async) then
        job:start()
    else
        job:sync()
    end
end

-- TODO: add highlight
-- vim.api.nvim_set_hl(0, 'BlinkCmpGit', { link = 'Search', default = true })
-- local highlight_ns_id = 0
-- pcall(function()
--     highlight_ns_id = require('blink.cmp.config').appearance.highlight_ns
-- end)
return GitSource
