local Job = require('plenary.job')

-- Get the absolute path of current git repo
local function get_git_repo_absolute_path(path)
    if vim.fn.executable('git') == 0 then return nil end
    path = path or vim.fn.getcwd()
    local result
    ---@diagnostic disable-next-line: missing-fields
    Job:new({
        command = 'git',
        args = { 'rev-parse', '--show-toplevel' },
        cwd = path,
        on_exit = function(j, return_value, _)
            if return_value == 0 then
                result = table.concat(j:result(), '\n')
            end
        end
    }):sync()
    return result
end
local last_git_repo = get_git_repo_absolute_path()
local function default_should_reload_cache()
    local new_git_repo = get_git_repo_absolute_path() or last_git_repo
    if new_git_repo ~= last_git_repo then
        last_git_repo = new_git_repo
        return true
    end
    return false
end

--- @type blink-cmp-git.Options
return {
    async = true,
    use_items_cache = true,
    -- Whether or not cache the triggers when the source is loaded
    use_items_pre_cache = true,
    should_reload_cache = default_should_reload_cache,
    kind_icons = {
        Commit = '',
        Mention = '',
        PR = '',
        Issue = '',
    },
    commit = require('blink-cmp-git.default.commit'),
    git_centers = {
        github = require('blink-cmp-git.default.github'),
        -- TODO: this will be implemented in the future
        gitlab = {}
    }
}
