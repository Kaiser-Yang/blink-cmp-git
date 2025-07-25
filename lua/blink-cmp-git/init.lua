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
--- @field running_pre_cache_jobs vim.SystemObj[]
--- @field _after_cache? fun()
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
--- @async
local function items_for_feature(feature, running_jobs)
    local co = coroutine.running()
    assert(co, 'This function should run inside a coroutine')

    local command = utils.get_option(feature.get_command) ---@type string
    local token = utils.get_option(feature.get_token) ---@type string
    local args = utils.get_option(feature.get_command_args, command, token) ---@type string[]

    local job = vim.system(
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
    table.insert(running_jobs, job)
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
    local co = coroutine.running()
    assert(co, 'This function should run inside a coroutine')

    local all_items = {} ---@type table<string, lsp.CompletionItem[]>
    local n_coroutines = 0

    for _, feature in pairs(self:get_enabled_features()) do
        local triggers = utils.get_option(feature.triggers) ---@type string[]
        for _, trigger in pairs(triggers) do
            if not all_items[trigger] then all_items[trigger] = {} end
            local items = all_items[trigger]

            coroutine.wrap(function()
                n_coroutines = n_coroutines + 1
                local new_items = items_for_feature(feature, self.running_pre_cache_jobs)
                vim.list_extend(items, new_items)

                local ok, err = coroutine.resume(co)
                if not ok then vim.notify(debug.traceback(co, err), vim.log.levels.ERROR) end
            end)()
        end
    end
    for _ = 1, n_coroutines do
        coroutine.yield()
    end

    for trigger, items in pairs(all_items) do
        for _, item in ipairs(items) do
            self.cache:set({ trigger, item.label }, item)
        end
    end

    if self._after_cache then self._after_cache() end
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
    self.running_pre_cache_jobs = {}
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

    self.cache = require('blink-cmp-git.cache').new()
    coroutine.wrap(function() self:create_pre_cache_jobs() end)()

    -- reload cache command and autocmd
    vim.api.nvim_create_user_command(blink_cmp_git_reload_cache_command, function()
        self.git_source_config.before_reload_cache()

        self.cache:clear()

        vim.iter(self.running_pre_cache_jobs):each(function(job) job:kill('TERM') end)
        self.running_pre_cache_jobs = {}
        self._after_cache = nil
        coroutine.wrap(function() self:create_pre_cache_jobs() end)()
    end, { nargs = 0 })
    vim.api.nvim_create_augroup(blink_cmp_git_autocmd_group, { clear = true })
    vim.api.nvim_create_autocmd({ 'InsertEnter' }, {
        group = blink_cmp_git_autocmd_group,
        callback = function()
            coroutine.wrap(function()
                if not self.git_source_config.should_reload_cache() then return end
                vim.cmd(blink_cmp_git_reload_cache_command)
            end)()
        end,
    })

    -- call `should_reload_cache` so the default `last_git_repo` is set
    coroutine.wrap(function()
        local co = coroutine.running()
        -- defer the call to avoid getting empty `last_git_repo` even in a git repo
        vim.schedule(function()
            local ok, err = coroutine.resume(co)
            if not ok then vim.notify(debug.traceback(co, err), vim.log.levels.ERROR) end
        end)
        coroutine.yield()
        self.git_source_config.should_reload_cache()
    end)()

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

---@param context blink.cmp.Context
---@param callback function
function GitSource:handle_items_pre_cache(context, callback) end

function GitSource:get_completions(context, callback)
    coroutine.wrap(function()
        local co = coroutine.running()

        local trigger = context.trigger.initial_character ---@type string
        if
            ---@diagnostic disable-next-line: missing-parameter
            not self:should_show_items(context)
            or not context.line
                :sub(1, context.cursor[2])
                :match(context.trigger.initial_character .. '$')
        then
            callback()
            return
        end

        local items = self.cache:get(trigger) ---@type table<string, lsp.CompletionItem>
        if not items then
            self._after_cache = function()
                self._after_cache = nil
                local ok, err = coroutine.resume(co)
                if not ok then vim.notify(debug.traceback(co, err), vim.log.levels.ERROR) end
            end
            coroutine.yield()
            items = self.cache:get(trigger) ---@type table<string, lsp.CompletionItem>
        end

        items = vim.iter(items)
            :map(function(key, item)
                item.textEdit.range = get_text_edit_range(context)
                item.gitSourceTrigger = trigger
                return key, item
            end)
            :fold({}, function(acc, key, item)
                acc[key] = item
                return acc
            end)
        callback({
            is_incomplete_backward = false,
            is_incomplete_forward = false,
            -- vim.deepcopy is required, because blink will modify the items
            items = vim.tbl_values(vim.deepcopy(items)),
        })
    end)()

    return function() end
end

--- @param context blink.cmp.Context
function GitSource:should_show_items(context, _)
    return context.trigger.initial_kind == 'trigger_character'
        and context.mode ~= 'cmdline'
        and vim.tbl_contains(self:get_trigger_characters(), context.trigger.initial_character)
end

function GitSource:resolve(item, callback)
    local job ---@type vim.SystemObj | nil
    coroutine.wrap(function()
        local documentation = item.documentation
        ---@cast documentation +blink-cmp-git.DocumentationCommand

        ---@diagnostic disable-next-line: undefined-field
        local trigger = item.gitSourceTrigger ---@type string
        local cached_item_documentation = self.cache:get({ trigger, item.label, 'documentation' })
        if cached_item_documentation then
            documentation = cached_item_documentation
            if documentation == '' then documentation = nil end
            item.documentation = documentation
            callback(item)
            return
        end
        if type(documentation) == 'string' or not documentation then
            if documentation and documentation:match('^%s*$') then documentation = '' end
            -- cache empty string
            self.cache:set({ trigger, item.label, 'documentation' }, documentation or '')
            if documentation == '' then documentation = nil end
            item.documentation = documentation
            callback(item)
            return
        end

        local co = coroutine.running()

        local command = utils.get_option(documentation.get_command) ---@type string
        local token = utils.get_option(documentation.get_token) ---@type string
        local args = utils.get_option(documentation.get_command_args, command, token) ---@type string[]

        job = vim.system(
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
        -- cache empty string
        self.cache:set({ trigger, item.label, 'documentation' }, documentation or '')
        if documentation == '' then documentation = nil end
        item.documentation = documentation
        callback(item)
    end)()

    return function()
        if not job then return end
        job:kill('TERM')
        job = nil
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
