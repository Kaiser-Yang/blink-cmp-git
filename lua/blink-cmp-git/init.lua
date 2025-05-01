--- @diagnostic disable: unused-local
--- @module 'blink.cmp'

local default = require('blink-cmp-git.default')
local utils = require('blink-cmp-git.utils')
local log = require('blink-cmp-git.log')
local blink_cmp_git_reload_cache_command = 'BlinkCmpGitReloadCache'
local blink_cmp_git_autocmd_group = 'blink-cmp-git-autocmd'
log.setup({ title = 'blink-cmp-git' })

--- @class blink.cmp.Source
--- @field git_source_config blink-cmp-git.Options
--- @field cache blink-cmp-git.Cache
--- @field pre_cache_items table<string, {items: table}>
local GitSource = {}

--- @param context blink.cmp.Context
--- @return lsp.Range
local function get_text_edit_range(context)
    return {
        -- This range make it possible to remove the trigger character
        start = {
            line = context.cursor[1] - 1,
            character = context.cursor[2] - 1,
        },
        ['end'] = {
            line = context.cursor[1] - 1,
            character = context.cursor[2],
        },
    }
end

--- @param feature blink-cmp-git.GCSCompletionOptions
--- @param result string
--- @return blink-cmp-git.CompletionItem[]
local function assemble_completion_items_from_output(feature, result)
    local items = {} ---@type blink-cmp-git.CompletionItem[]
    for _, v in pairs(feature.separate_output(result)) do
        table.insert(items, {
            label = feature.get_label(v),
            kind_name = feature.get_kind_name(v),
            insert_text = feature.get_insert_text(v),
            documentation = feature.get_documentation(v),
        })
    end
    feature.configure_score_offset(items)
    return items
end

--- @param feature blink-cmp-git.GCSCompletionOptions
--- @return blink.cmp.CompletionItem[]
--- @return blink.cmp.CompletionItem[]
--- @async
local function items_for_feature(feature)
    local co = coroutine.running()
    assert(co, 'This function should run inside a coroutine')

    local command = utils.get_option(feature.get_command) ---@type string
    local token = utils.get_option(feature.get_token) ---@type string
    local args = utils.get_option(feature.get_command_args, command, token) ---@type string[]

    vim.system(
        vim.list_extend({ command }, args),
        {
            text = true,
            cwd = utils.get_cwd(),
            env = utils.get_job_default_env(),
        },
        vim.schedule_wrap(function(out)
            local ok, err = coroutine.resume(co, out)
            if not ok then vim.notify(debug.traceback(co, err), vim.log.levels.ERROR) end
        end)
    )
    local out = coroutine.yield() --[[@as vim.SystemCompleted]]

    local signal = out.signal
    local return_value = out.code
    if signal == 9 then return {} end
    if return_value ~= 0 or utils.truthy(out.stderr) then
        if feature.on_error(return_value, out.stderr) then return {} end
    end
    if out.stdout == '' then
        log.trace('search command return empty result')
        return {}
    end

    local match_list = assemble_completion_items_from_output(feature, out.stdout)
    return vim.iter(match_list)
        :map(
            function(match)
                return {
                    label = match.label,
                    kind = require('blink.cmp.types').CompletionItemKind[match.kind_name] or 0,
                    textEdit = {
                        newText = match.insert_text
                            .. (utils.get_option(feature.insert_text_trailing) or ''),
                    },
                    score_offset = match.score_offset,
                    documentation = match.documentation,
                }
            end
        )
        :totable()
end

--- @async
function GitSource:create_pre_cache_jobs()
    self.pre_cache_items = {}
    for _, feature in pairs(self:get_enabled_features()) do
        local triggers = utils.get_option(feature.triggers) ---@type string[]
        for _, trigger in pairs(triggers) do
            if not self.pre_cache_items[trigger] then
                self.pre_cache_items[trigger] = {
                    items = {},
                }
            end
            local all_items = self.pre_cache_items[trigger]
            local new_items = items_for_feature(feature)
            vim.list_extend(all_items.items, new_items)
        end
    end
    for trigger, job_and_items in pairs(self.pre_cache_items) do
        for _, item in pairs(job_and_items.items) do
            self.cache:set({ trigger, item.label }, item)
        end
    end
end

--- @type blink-cmp-git.Options
local latest_git_source_config = default
--- @type blink.cmp.SourceProviderConfig
local latest_source_provider_config

--- @return blink-cmp-git.Options
function GitSource.get_latest_git_source_config() return latest_git_source_config end

--- @return blink.cmp.SourceProviderConfig
function GitSource.get_latest_source_provider_config() return latest_source_provider_config end

local function configure_highlight_group(kind_name)
    local default_hl = {
        Issue = { default = true, fg = '#a6e3a1' },
        Commit = { default = true, fg = '#a6e3a1' },
        Mention = { default = true, fg = '#a6e3a1' },
        PR = { default = true, fg = '#a6e3a1' },
        MR = { default = true, fg = '#a6e3a1' },
    }
    vim.api.nvim_set_hl(
        0,
        'BlinkCmpGitKind' .. kind_name,
        default_hl[kind_name] or { link = 'BlinkCmpKind', default = true }
    )
    vim.api.nvim_set_hl(
        0,
        'BlinkCmpGitKindIcon' .. kind_name,
        default_hl[kind_name] or { link = 'BlinkCmpKind', default = true }
    )
    vim.api.nvim_set_hl(
        0,
        'BlinkCmpGitLabel' .. kind_name .. 'Id',
        default_hl[kind_name] or { link = 'BlinkCmpLabel', default = true }
    )
    vim.api.nvim_set_hl(
        0,
        'BlinkCmpGitLabel' .. kind_name .. 'Rest',
        { link = 'BlinkCmpLabel', default = true }
    )
end

local function highlight_override_on_condition(condition, context, text, override, fallback)
    local result
    if condition then result = utils.get_option(override, context, text) end
    if not result then result = utils.get_option(fallback, context, text) end
    return result
end

--- @param opts blink-cmp-git.Options
--- @param config blink.cmp.SourceProviderConfig
--- @return blink-cmp-git.GCSCompletionOptions[]
function GitSource.new(opts, config)
    local self = setmetatable({}, { __index = GitSource })
    self.git_source_config = vim.tbl_deep_extend('force', default, opts or {})
    latest_git_source_config = self.git_source_config
    latest_source_provider_config = config

    -- configure hl, set this before creating jobs
    -- so that the hl can be used in the jobs correctly
    local completion_item_kind = require('blink.cmp.types').CompletionItemKind
    local blink_kind_icons = require('blink.cmp.config').appearance.kind_icons
    for kind_name, icon in pairs(utils.get_option(self.git_source_config.kind_icons)) do
        completion_item_kind[#completion_item_kind + 1] = kind_name
        completion_item_kind[kind_name] = #completion_item_kind
        blink_kind_icons[kind_name] = icon
        configure_highlight_group(kind_name)
    end
    local components = require('blink.cmp.config').completion.menu.draw.components
    -- components will never be nil
    if components then
        local user_kind_hl = components.kind.highlight
        local user_kind_icon_hl = components.kind_icon.highlight
        local user_label_hl = components.label.highlight
        components.kind.highlight = function(context, text)
            return highlight_override_on_condition(
                context.source_name == config.name,
                context,
                text,
                self.git_source_config.kind_highlight,
                user_kind_hl
            )
        end
        components.kind_icon.highlight = function(context, text)
            return highlight_override_on_condition(
                context.source_name == config.name,
                context,
                text,
                self.git_source_config.kind_icon_highlight,
                user_kind_icon_hl
            )
        end
        components.label.highlight = function(context, text)
            return highlight_override_on_condition(
                context.source_name == config.name,
                context,
                text,
                self.git_source_config.label_highlight,
                user_label_hl
            )
        end
    end

    -- cache and pre-cache jobs
    self.cache = require('blink-cmp-git.cache').new()
    self.pre_cache_items = {}
    local use_items_cache = utils.get_option(self.git_source_config.use_items_cache) ---@type boolean
    local use_items_pre_cache = utils.get_option(self.git_source_config.use_items_pre_cache) ---@type boolean
    if use_items_cache and use_items_pre_cache then
        coroutine.wrap(function() self:create_pre_cache_jobs() end)()
    end

    -- reload cache command and autocmd
    vim.api.nvim_create_user_command(blink_cmp_git_reload_cache_command, function()
        self.git_source_config.before_reload_cache()

        if not utils.get_option(self.git_source_config.use_items_cache) then return end
        self.cache:clear()

        if not utils.get_option(self.git_source_config.use_items_pre_cache) then return end
        -- TODO: cancel previous pre cache jobs
        coroutine.wrap(function() self:create_pre_cache_jobs() end)()
    end, { nargs = 0 })
    vim.api.nvim_create_augroup(blink_cmp_git_autocmd_group, { clear = true })
    vim.api.nvim_create_autocmd({ 'InsertEnter' }, {
        group = blink_cmp_git_autocmd_group,
        callback = function()
            if not self.git_source_config.should_reload_cache() then return end
            vim.cmd(blink_cmp_git_reload_cache_command)
        end,
    })
    -- call the function so the default last_git_repo is set
    -- defer the call to avoid getting empty last_git_repo even in a git repo
    vim.schedule_wrap(self.git_source_config.should_reload_cache)()

    return self
end

function GitSource:get_trigger_characters()
    local result = {}
    for _, git_center in pairs(vim.tbl_values(self.git_source_config.git_centers)) do
        for _, feature in pairs(git_center) do
            local feature_triggers = utils.get_option(feature.triggers)
            if utils.truthy(feature_triggers) then
                for _, trigger in pairs(feature_triggers) do
                    table.insert(result, trigger)
                end
            end
        end
    end
    for _, trigger in pairs(utils.get_option(self.git_source_config.commit.triggers)) do
        table.insert(result, trigger)
    end
    return result
end

function GitSource:handle_items_pre_cache(context, callback)
    if
        not utils.get_option(self.git_source_config.use_items_pre_cache)
        or not utils.get_option(self.git_source_config.use_items_cache)
    then
        return
    end

    local items = {} ---@type lsp.CompletionItem[]
    local trigger = context.trigger.initial_character

    items = self.cache:get(trigger) or {}
    for _, item in pairs(items) do
        item.textEdit.range = get_text_edit_range(context)
        item.gitSourceTrigger = trigger
    end
    callback({
        is_incomplete_backward = false,
        is_incomplete_forward = false,
        items = vim.tbl_values(items),
    })
end

function GitSource:get_completions(context, callback)
    coroutine.wrap(function()
        local items = {} ---@type table<string, lsp.CompletionItem>
        local trigger = context.trigger.initial_character ---@type string
        local transformed_callback = function()
            for _, item in pairs(items) do
                item.textEdit.range = get_text_edit_range(context)
                item.gitSourceTrigger = trigger
            end
            callback({
                is_incomplete_backward = false,
                is_incomplete_forward = false,
                items = items,
            })
        end
        if
            ---@diagnostic disable-next-line: missing-parameter
            not self:should_show_items(context)
            or not context.line
                :sub(1, context.cursor[2])
                :match(context.trigger.initial_character .. '$')
        then
            transformed_callback()
            return
        end

        self:handle_items_pre_cache(context, callback)

        local use_items_cache = utils.get_option(self.git_source_config.use_items_cache) ---@type boolean
        local cached_items ---@type table<string, lsp.CompletionItem>|nil
        if use_items_cache then cached_items = self.cache:get(trigger) end
        if cached_items then
            items = cached_items
            transformed_callback()
            return
        end

        local trigger_pos = context.cursor[2] - 1
        local enabled_features = self:get_enabled_features()
        for _, feature in pairs(enabled_features) do
            local feature_triggers = utils.get_option(feature.triggers) ---@type string[]
            if utils.truthy(feature_triggers) and vim.tbl_contains(feature_triggers, trigger) then
                local feature_items = items_for_feature(feature)
                vim.tbl_extend('force', items, feature_items)
            end
        end
        if not utils.truthy(enabled_features) then
            transformed_callback()
            return
        end

        if use_items_cache then
            for _, item in pairs(items) do
                self.cache:set({ trigger, item.label }, item)
            end
        end
        transformed_callback()
    end)()

    return function()
        -- TODO(TheLeoP): cancel function
    end
end

--- @param context blink.cmp.Context
function GitSource:should_show_items(context, _)
    return context.trigger.initial_kind == 'trigger_character'
        and context.mode ~= 'cmdline'
        and vim.tbl_contains(self:get_trigger_characters(), context.trigger.initial_character)
end

function GitSource:resolve(item, callback)
    coroutine.wrap(function()
        local documentation = item.documentation
        ---@cast documentation +blink-cmp-git.DocumentationCommand

        ---@diagnostic disable-next-line: undefined-field
        local trigger = item.gitSourceTrigger
        local use_items_cache = utils.get_option(self.git_source_config.use_items_cache) ---@type boolean
        local cached_item_documentation
        if use_items_cache then
            cached_item_documentation = self.cache:get({ trigger, item.label, 'documentation' })
        end
        if cached_item_documentation then
            documentation = cached_item_documentation
            if documentation == '' then documentation = nil end
            callback(item)
            return
        end
        if type(documentation) == 'string' or not documentation then
            if documentation and documentation:match('^%s*$') then documentation = '' end
            if use_items_cache then
                -- cache empty string
                self.cache:set({ trigger, item.label, 'documentation' }, documentation or '')
            end
            if documentation == '' then documentation = nil end
            callback(item)
            return
        end

        -- TODO(TheLeoP): put this insise of a coroutine. Theres a callback in here
        local co = coroutine.running()

        local command = utils.get_option(documentation.get_command) ---@type string
        local token = utils.get_option(documentation.get_token) ---@type string
        local args = utils.get_option(documentation.get_command_args, command, token) ---@type string[]

        vim.system(
            vim.list_extend({ command }, args),
            {
                text = true,
                cwd = utils.get_cwd(),
                env = utils.get_job_default_env(),
            },
            vim.schedule_wrap(function(out)
                local ok, err = coroutine.resume(co, out)
                if not ok then vim.notify(debug.traceback(co, err), vim.log.levels.ERROR) end
            end)
        )
        local out = coroutine.yield() --[[@as vim.SystemCompleted]]

        local return_value = out.code
        if return_value ~= 0 or utils.truthy(out.stderr) then
            if documentation.on_error(return_value, out.stderr) then
                documentation = nil
                goto cache_handler
            end
        end
        if utils.truthy(out.stdout) then
            documentation = documentation.resolve_documentation(out.stdout)
            if documentation and documentation:match('^%s*$') then documentation = '' end
        else
            documentation = nil
        end
        ::cache_handler::
        if use_items_cache then
            -- cache empty string
            self.cache:set({ trigger, item.label, 'documentation' }, documentation or '')
        end
        if documentation == '' then documentation = nil end
        callback(item)
    end)()

    return function()
        -- TODO(TheLeoP): cancel function?
    end
end

--- @return blink-cmp-git.GCSCompletionOptions[]
--- @async
function GitSource:get_enabled_features()
    local result = {}
    for _, git_center in pairs(vim.tbl_values(self.git_source_config.git_centers)) do
        for _, feature in pairs(git_center) do
            if utils.get_option(feature.enable) then table.insert(result, feature) end
        end
    end
    local commit = self.git_source_config.commit
    if commit and utils.get_option(commit.enable) then table.insert(result, commit) end
    return result
end

return GitSource
