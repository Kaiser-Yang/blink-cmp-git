local Job = require('plenary.job')
local log = require('blink-cmp-git.log')
local utils = require('blink-cmp-git.utils')
log.setup({ title = 'blink-cmp-git' })

--- @param items blink-cmp-git.CompletionItem[]
local score_offset_origin = function(items)
    for i = 1, #items do
        items[i].score_offset = #items - i
    end
end

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

local function default_commit_enable()
    if vim.fn.executable('git') == 0 then return false end
    local res = false
    ---@diagnostic disable-next-line: missing-fields
    Job:new({
        command = 'git',
        args = { 'rev-parse', '--is-inside-work-tree' },
        cwd = vim.fn.getcwd(),
        on_exit = function(_, return_value, _)
            res = return_value == 0
        end
    }):sync()
    return res
end

local default_ignored_error = {
    'repository has disabled issues',
    'does not have any commits yet'
}
local default_on_error = function(return_value, standard_error)
    for _, ignored_error in pairs(default_ignored_error) do
        if standard_error:find(ignored_error) then
            return true
        end
    end
    vim.schedule(function()
        log.error('get_completions failed',
            '\n',
            'with error code:', return_value,
            '\n',
            'stderr:', standard_error)
    end)
    return true
end

--- @type blink-cmp-git.GCSCompletionOptions
local default_commit = {
    -- enable when current directory is inside a git repo
    enable = default_commit_enable,
    triggers = { ':' },
    get_command = 'git',
    get_command_args = {
        '--no-pager',
        'log',
        '--pretty=fuller',
        '--decorate=no',
    },
    insert_text_trailing = ' ',
    separate_output = function(output)
        local lines = vim.split(output, '\n')
        local i = 1
        local commits = {}
        -- I've tried use regex to match the commit, but there always were some commits missing
        while i < #lines do
            local j = i + 1
            while j < #lines do
                if lines[j]:match('^commit ') then
                    j = j - 1
                    break
                end
                j = j + 1
            end
            commits[#commits + 1] = table.concat(lines, '\n', i, j)
            i = j + 1
        end
        --- @type blink-cmp-git.CompletionItem[]
        local items = {}
        ---@diagnostic disable-next-line: redefined-local
        for i = 1, #commits do
            --- @type string
            local commit = commits[i]
            items[i] = {
                -- the fist 7 characters of the hash and the subject of the commit
                label =
                    commit:match('commit ([^\n]*)'):sub(1, 7)
                    ..
                    ' '
                    ..
                    commit:match('\n\n%s*([^\n]*)'),
                kind_name = 'Commit',
                insert_text = commit:match('^commit ([^\n]*)'):sub(1, 7),
                documentation = commit
            }
        end
        return items
    end,
    configure_score_offset = score_offset_origin,
    on_error = default_on_error,
}

local function default_github_enable()
    if vim.fn.executable('git') == 0 or vim.fn.executable('gh') == 0 then return false end
    local output = ''
    ---@diagnostic disable-next-line: missing-fields
    Job:new({
        command = 'git',
        args = { 'remote', '-v' },
        cwd = vim.fn.getcwd(),
        on_exit = function(job, return_value, _)
            if return_value ~= 0 then
                return
            end
            output = table.concat(job:result(), '\n')
        end
    }):sync()
    return output:find('github.com') ~= nil
end

local function default_github_pr_or_issue_separate_output(output, is_pr)
    --- @type blink-cmp-git.CompletionItem[]
    local items = {}
    local json_res = vim.json.decode(output)
    for i = 1, #json_res do
        items[i] = {
            label = '#' .. tostring(json_res[i].number) ..
                ' ' .. tostring(json_res[i].title),
            insert_text = '#' .. tostring(json_res[i].number),
            kind_name = is_pr and 'PR' or 'Issue',
            documentation =
                '#' .. tostring(json_res[i].number) ..
                ' ' .. tostring(json_res[i].title) .. '\n' ..
                'State: ' .. tostring(json_res[i].state) .. '\n' ..
                ((is_pr or not utils.truthy(tostring(json_res[i].stateReason))) and '' or
                    'State Reason: ' .. tostring(json_res[i].stateReason) .. '\n') ..
                'Author: ' .. tostring(json_res[i].author.login) .. '\n' ..
                'Created at: ' .. tostring(json_res[i].createdAt) .. '\n' ..
                'Updated at: ' .. tostring(json_res[i].updatedAt) .. '\n' ..
                'Closed at: ' .. tostring(json_res[i].closedAt) .. '\n' ..
                tostring(json_res[i].body)
        }
    end
    return items
end

local function default_github_pr_or_issue_configure_score_offset(items)
    -- Bonus to make sure items sorted as below:
    -- open issue
    -- open pr
    -- closed issue
    -- merged pr
    -- closed pr
    local keys = {
        'OPENIssue',
        'OPENPR',
        'CLOSEDIssue',
        'MERGEDPR',
        'CLOSEDPR'
    }
    local bonus = 999999
    local bonus_score = {
    }
    for i = 1, #keys do
        bonus_score[keys[i]] = bonus * (#keys - i)
    end
    for i = 1, #items do
        local state = ''
        if type(items[i].documentation) == 'string' then
            state = items[i].documentation:match('State: (%w*)')
        end
        local bonus_key = state .. items[i].kind_name
        if bonus_score[bonus_key] then
            items[i].score_offset = bonus_score[bonus_key]
        end
        -- sort by number when having the same bonus score
        local number = items[i].label:match('#(%d+)')
        if number then
            if items[i].score_offset == nil then
                items[i].score_offset = 0
            end
            items[i].score_offset = items[i].score_offset + tonumber(number)
        end
    end
end

--- @type blink-cmp-git.Options
local default = {
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
    commit = default_commit,
    git_centers = {
        github = {
            issue = {
                enable = default_github_enable,
                triggers = { '#' },
                get_command = 'gh',
                get_command_args = {
                    'issue',
                    'list',
                    '--state', 'all',
                    '--json', 'number,title,state,stateReason,body,createdAt,updatedAt,closedAt,author',
                },
                insert_text_trailing = ' ',
                separate_output = function(output)
                    return default_github_pr_or_issue_separate_output(output, false)
                end,
                configure_score_offset = default_github_pr_or_issue_configure_score_offset,
                on_error = default_on_error,
            },
            pull_request = {
                enable = default_github_enable,
                triggers = { '#' },
                get_command = 'gh',
                get_command_args = {
                    'pr',
                    'list',
                    '--state', 'all',
                    '--json', 'number,title,state,body,createdAt,updatedAt,closedAt,author',
                },
                insert_text_trailing = ' ',
                separate_output = function(output)
                    return default_github_pr_or_issue_separate_output(output, true)
                end,
                configure_score_offset = default_github_pr_or_issue_configure_score_offset,
                on_error = default_on_error,
            },
            mention = {
                enable = default_github_enable,
                triggers = { '@' },
                get_command = 'gh',
                get_command_args = {
                    'api',
                    'repos/:owner/:repo/contributors',
                },
                insert_text_trailing = ' ',
                separate_output = function(output)
                    local json_res = vim.json.decode(output)
                    --- @type blink-cmp-git.CompletionItem[]
                    local items = {}
                    for i = 1, #json_res do
                        items[i] = {
                            label = '@' .. tostring(json_res[i].login),
                            insert_text = '@' .. tostring(json_res[i].login),
                            kind_name = 'Mention',
                            documentation = {
                                get_command = 'gh',
                                get_command_args = {
                                    'api',
                                    'users/' .. tostring(json_res[i].login),
                                },
                                ---@diagnostic disable-next-line: redefined-local
                                resolve_documentation = function(output)
                                    local user_info = vim.json.decode(output)
                                    return
                                        tostring(user_info.login) ..
                                        ' ' .. tostring(user_info.name) .. '\n' ..
                                        'Location: ' .. tostring(user_info.location) .. '\n' ..
                                        'Email: ' .. tostring(user_info.email) .. '\n' ..
                                        'Company: ' .. tostring(user_info.company) .. '\n' ..
                                        'Created at: ' .. tostring(user_info.created_at) .. '\n' ..
                                        'Updated at: ' .. tostring(user_info.updated_at) .. '\n'
                                end
                            }
                        }
                    end
                    return items
                end,
                configure_score_offset = score_offset_origin,
                on_error = default_on_error,
            },
        },
        -- TODO: this will be implemented in the future
        gitlab = {}
    }
}
return default
