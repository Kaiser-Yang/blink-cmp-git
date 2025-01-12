local Job = require('plenary.job')

local function is_inside_git_repo()
    local res = false
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

--- @type blink-cmp-git.GCSCompletionOptions
local default_commit = {
    -- enable when current directory is inside a git repo
    enable = is_inside_git_repo,
    triggers = { ':' },
    get_command = 'git',
    get_command_args = {
        '--no-pager',
        'log',
        '--pretty=fuller',
        '--decorate=no',
    },
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
                insert_text = commit:match('^commit ([^\n]*)'):sub(1, 7) .. ' ',
                documentation = commit
            }
        end
        return items
    end,
}

-- check if the git repo is hosted on GitHub
local function remote_contains_github()
    local output = ''
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

local default_github_pr_and_issue_separate_output = function(output)
    --- @type blink-cmp-git.CompletionItem[]
    local items = {}
    local json_res = vim.json.decode(output)
    for i = 1, #json_res do
        items[i] = {
            label = '#' .. tostring(json_res[i].number) ..
                ' ' .. tostring(json_res[i].title),
            insert_text = '#' .. tostring(json_res[i].number) .. ' ',
            documentation =
                '#' .. tostring(json_res[i].number) ..
                ' ' .. tostring(json_res[i].title) .. '\n' ..
                'State: ' .. tostring(json_res[i].state) .. '\n' ..
                'Author: ' .. tostring(json_res[i].author.login) .. '\n' ..
                'Created at: ' .. tostring(json_res[i].createdAt) .. '\n' ..
                'Updated at: ' .. tostring(json_res[i].updatedAt) .. '\n' ..
                'Closed at: ' .. tostring(json_res[i].closedAt) .. '\n' ..
                tostring(json_res[i].body)
        }
    end
    return items
end

--- @type blink-cmp-git.Options
local default = {
    async = true,
    use_items_cache = true,
    -- Whether or not cache the triggers when the source is loaded
    use_items_pre_cache = true,
    commit = default_commit,
    git_centers = {
        github = {
            issue = {
                enable = remote_contains_github,
                triggers = { '#' },
                get_command = 'gh',
                get_command_args = {
                    'issue',
                    'list',
                    '--json', 'number,title,state,body,createdAt,updatedAt,closedAt,author',
                },
                separate_output = default_github_pr_and_issue_separate_output,
            },
            pull_request = {
                enable = remote_contains_github,
                triggers = { '#' },
                get_command = 'gh',
                get_command_args = {
                    'pr',
                    'list',
                    '--json', 'number,title,state,body,createdAt,updatedAt,closedAt,author',
                },
                separate_output = default_github_pr_and_issue_separate_output,
            },
            mention = {
                enable = remote_contains_github,
                triggers = { '@' },
                get_command = 'gh',
                get_command_args = {
                    'api',
                    'repos/:owner/:repo/contributors',
                },
                separate_output = function(output)
                    local json_res = vim.json.decode(output)
                    local items = {}
                    for i = 1, #json_res do
                        items[i] = {
                            label = '@' .. tostring(json_res[i].login),
                            insert_text = '@' .. tostring(json_res[i].login) .. ' ',
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
            },
        },
        -- TODO: this will be implemented in the future
        git_lab = {}
    }
}
return default
