--- @diagnostic disable: unused-local
--- @module 'blink.cmp'

local default = require('blink-cmp-git.default')
local utils = require('blink-cmp-git.utils')
local log = require('blink-cmp-git.log')
local Job = require('plenary.job')
log.setup({ title = 'blink-cmp-git' })

--- @class blink.cmp.Source
--- @field git_source_config blink-cmp-git.Options
--- @field cache blink-cmp-git.Cache
local GitSource = {}

--- @param documentation_command blink-cmp-git.DocumentationCommand
--- @return Job
local function create_job_from_documentation_command(documentation_command)
    return Job:new({
        command = utils.get_option(documentation_command.get_command),
        args = utils.get_option(documentation_command.get_command_args),
    })
end

--- @param git_source_config blink-cmp-git.Options
--- @return blink-cmp-git.GCSCompletionOptions[]
local function get_enabled_features(git_source_config)
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

--- @param context blink.cmp.Context
--- @return lsp.TextEdit
local function get_text_edit_range(context)
    return {
        -- This range make it possible to remove the trigger character
        start = {
            line = context.cursor[1] - 1,
            character = context.cursor[2] - 1
        },
        ['end'] = {
            line = context.cursor[1] - 1,
            character = context.cursor[2]
        }
    }
end

--- @param opts blink-cmp-git.Options
--- @return blink-cmp-git.GCSCompletionOptions[]
function GitSource.new(opts, _)
    local self = setmetatable({}, { __index = GitSource })
    self.git_source_config = vim.tbl_deep_extend("force", default, opts or {})
    self.cache = require('blink-cmp-git.cache').new()
    return self
end

function GitSource:get_trigger_characters()
    local result = {}
    for _, git_center in ipairs(vim.tbl_values(self.git_source_config.git_centers)) do
        for _, feature in pairs(git_center) do
            local feature_triggers = utils.get_option(feature.triggers)
            if utils.truthy(feature_triggers) then
                for _, trigger in ipairs(feature_triggers) do
                    table.insert(result, trigger)
                end
            end
        end
    end
    for _, trigger in ipairs(utils.get_option(self.git_source_config.commit.triggers)) do
        table.insert(result, trigger)
    end
    return result
end

--- @param context blink.cmp.Context
--- @param callback fun(response?: blink.cmp.CompletionResponse)
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
    ---@diagnostic disable-next-line: param-type-mismatch
    if not self:should_show_completions(context, nil) then
        transformed_callback()
        return cancel_fun
    end
    local async = utils.get_option(self.git_source_config.async)
    local use_items_cache = utils.get_option(self.git_source_config.use_items_cache)
    local should_reload_items_cache = utils.get_option(self.git_source_config.should_reload_items_cache)
    if should_reload_items_cache then
        self.cache:clear()
    end
    local trigger = context.trigger.initial_character
    local cached_items
    if use_items_cache then
---@diagnostic disable-next-line: param-type-mismatch
        cached_items = self.cache:get(trigger)
    end
    if cached_items then
        items = cached_items
        for key, item in pairs(items) do
            -- Only need to update the range
            items[key].textEdit.range = get_text_edit_range(context)
        end
        transformed_callback()
        return cancel_fun
    end
    --- @type Job
    local job
    local trigger_pos = context.cursor[2] - 1
    local enabled_features = get_enabled_features(self.git_source_config)
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
                                    range = get_text_edit_range(context)
                                },
                                documentation = match.documentation,
                                gitSourceTrigger = trigger,
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
        if use_items_cache then
            for key, item in pairs(items) do
                self.cache:set({ trigger, item.label }, item)
            end
        end
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
--- @param context blink.cmp.Context
function GitSource:should_show_completions(context, _)
    return context.trigger.initial_kind == 'trigger_character' and context.mode ~= 'cmdline'
        and vim.tbl_contains(self:get_trigger_characters(), context.trigger.initial_character)
end

--- @param item blink.cmp.CompletionItem
--- @param callback fun(item: blink.cmp.CompletionItem)
function GitSource:resolve(item, callback)
    ---@diagnostic disable-next-line: undefined-field
    local trigger = item.gitSourceTrigger
    local transformed_callback = function()
        vim.schedule(function()
            callback(item)
        end)
    end
    local use_items_cache = utils.get_option(self.git_source_config.use_items_cache)
    local cached_item_documentation
    if use_items_cache then
        cached_item_documentation = self.cache:get({ trigger, item.label, 'documentation' })
    end
    if cached_item_documentation then
        item.documentation = cached_item_documentation
        if item.documentation == '' then
            item.documentation = nil
        end
        transformed_callback()
        return
    end
    if type(item.documentation) == 'string' or not item.documentation then
        if use_items_cache then
            self.cache:set({ trigger, item.label, 'documentation' }, item.documentation)
        end
        if item.documentation == '' then
            item.documentation = nil
        end
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
            if use_items_cache then
                self.cache:set({ trigger, item.label, 'documentation' }, item.documentation)
            end
        else
            item.documentation = nil
        end
        transformed_callback()
    end)
    if utils.get_option(self.git_source_config.async) then
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
