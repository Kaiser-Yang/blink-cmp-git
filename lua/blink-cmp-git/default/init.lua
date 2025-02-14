local utils = require('blink-cmp-git.utils')
local log = require('blink-cmp-git.log')
log.setup({ title = 'blink-cmp-git' })

local last_git_repo
local function default_should_reload_cache()
    -- Do not reload cache when the buffer is a prompt buffer
    -- or the source provider is disabled
    if vim.bo.buftype == 'prompt' or
        not utils.source_provider_enabled()
    then
        return false
    end
    if last_git_repo == nil then
        last_git_repo = utils.get_git_repo_absolute_path()
        if not last_git_repo then
            last_git_repo = ''
        end
        return false
    end
    local new_git_repo = utils.get_git_repo_absolute_path() or last_git_repo
    if new_git_repo ~= last_git_repo then
        last_git_repo = new_git_repo
        return true
    end
    return false
end

local function default_before_reload_cache()
    log.info('Start reloading blink-cmp-git cache.')
end

local function default_get_remote_name()
    local possible_remotes = {
        'upstream',
        'origin',
    }
    for _, remote in ipairs(possible_remotes) do
        if utils.truthy(utils.get_repo_remote_url(remote)) then
            return remote
        end
    end
    return ''
end

--- @type blink-cmp-git.Options
return {
    async = true,
    use_items_cache = true,
    -- Whether or not cache the triggers when the source is loaded
    use_items_pre_cache = true,
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
    commit = require('blink-cmp-git.default.commit'),
    git_centers = {
        github = require('blink-cmp-git.default.github'),
        gitlab = require('blink-cmp-git.default.gitlab'),
    }
}
