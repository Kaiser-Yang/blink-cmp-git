local utils = require('blink-cmp-git.utils')
local log = require('blink-cmp-git.log')
log.setup({ title = 'blink-cmp-git' })

local last_git_repo ---@type string?

--- @async
local function default_should_reload_cache()
    local co = coroutine.running()
    assert(co, 'This function should run inside a coroutine')

    -- Do not reload cache when the buffer is a prompt buffer
    -- or the source provider is disabled
    if vim.bo.buftype == 'prompt' or not utils.source_provider_enabled() then return false end
    if last_git_repo == nil then
        last_git_repo = utils.get_git_repo_absolute_path()
        if not last_git_repo then last_git_repo = '' end
        return false
    end
    local new_git_repo = utils.get_git_repo_absolute_path() or last_git_repo
    if new_git_repo ~= last_git_repo then
        last_git_repo = new_git_repo
        return true
    end
    return false
end

local function default_before_reload_cache() log.info('Start reloading blink-cmp-git cache.') end

local function default_get_remote_name()
    local possible_remotes = {
        'upstream',
        'origin',
    }
    for _, remote in ipairs(possible_remotes) do
        if utils.truthy(utils.get_repo_remote_url(remote)) then return remote end
    end
    return ''
end

local function default_kind_highlight(context, _) return 'BlinkCmpGitKind' .. context.kind end

local function default_kind_icon_highlight(context, _) return 'BlinkCmpGitKindIcon' .. context.kind end

local function default_label_highlight(context, _)
    local id_len = #(context.label:match('^[^%s]+'))
    -- Find id like #123, !123 or hash,
    -- but not for mention
    if id_len > 0 and id_len ~= #context.label then
        local highlights = {
            {
                0,
                id_len,
                group = 'BlinkCmpGitLabel' .. context.kind .. 'Id',
            },
            {
                id_len,
                #context.label - id_len,
                group = 'BlinkCmpGitLabel' .. context.kind .. 'Rest',
            },
        }
        -- characters matched on the label by the fuzzy matcher
        for _, idx in ipairs(context.label_matched_indices) do
            table.insert(highlights, { idx, idx + 1, group = 'BlinkCmpLabelMatch' })
        end
        return highlights
    end
    -- return nil to use the default highlight
    return nil
end

--- @type blink-cmp-git.Options
return {
    should_reload_cache = default_should_reload_cache,
    before_reload_cache = default_before_reload_cache,
    kind_icons = {
        Commit = '',
        Mention = '',
        PR = '',
        MR = '',
        Issue = '',
    },
    get_cwd = vim.fn.getcwd,
    get_remote_name = default_get_remote_name,
    kind_highlight = default_kind_highlight,
    kind_icon_highlight = default_kind_icon_highlight,
    label_highlight = default_label_highlight,
    commit = require('blink-cmp-git.default.commit'),
    git_centers = {
        github = require('blink-cmp-git.default.github'),
        gitlab = require('blink-cmp-git.default.gitlab'),
    },
}
