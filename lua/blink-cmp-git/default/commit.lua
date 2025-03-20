local common = require('blink-cmp-git.default.common')
local utils = require('blink-cmp-git.utils')

local function default_commit_separate_output(output)
    local success, result = pcall(common.json_array_separator, output)
    if success then return result end
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
    return commits
end

local function default_commit_get_label(item)
    -- There may be some commits that have no message, we just use the hash to represent them
    if type(item) == 'table' then
        return item.sha:sub(1, 7) .. ' ' .. ((item.commit.message or ''):match('([^\n]*)') or '')
    end
    return item:match('commit ([^\n]*)'):sub(1, 7) .. ' ' .. (item:match('\n\n%s*([^\n]*)') or '')
end

local function default_commit_get_kind_name(_) return 'Commit' end

local function default_commit_get_insert_text(item)
    if type(item) == 'table' then return item.sha:sub(1, 7) end
    return item:match('commit ([^\n]*)'):sub(1, 7)
end

local function default_commit_get_documentation(item)
    if type(item) == 'table' then
        return 'commit '
            .. item.sha
            .. '\n'
            .. 'Author:     '
            .. item.commit.author.name
            .. ' <'
            .. item.commit.author.email
            .. '>\n'
            .. 'AuthorDate: '
            .. item.commit.author.date
            .. '\n'
            .. 'Commit:     '
            .. item.commit.committer.name
            .. ' <'
            .. item.commit.committer.email
            .. '>\n'
            .. 'CommitDate: '
            .. item.commit.committer.date
            .. '\n'
            .. item.commit.message
    end
    return item
end

local function default_commit_enable()
    return utils.truthy(utils.get_repo_owner_and_repo_from_octo()) or utils.is_inside_git_repo()
end

local function default_commit_get_command()
    if utils.truthy(utils.get_repo_owner_and_repo_from_octo()) then
        return utils.command_found('gh') and 'gh' or 'curl'
    end
    return 'git'
end

local function default_commit_get_command_args(command, token)
    if command == 'git' then
        return {
            '--no-pager',
            'log',
            '--pretty=fuller',
            '--decorate=no',
        }
    else
        return common.github_repo_get_command_args(command, token, 'commits')
    end
end

--- @type blink-cmp-git.GCSCompletionOptions
return {
    enable = default_commit_enable,
    triggers = { ':' },
    get_token = '',
    get_command = default_commit_get_command,
    get_command_args = default_commit_get_command_args,
    insert_text_trailing = ' ',
    separate_output = default_commit_separate_output,
    get_label = default_commit_get_label,
    get_kind_name = default_commit_get_kind_name,
    get_insert_text = default_commit_get_insert_text,
    get_documentation = default_commit_get_documentation,
    configure_score_offset = common.score_offset_origin,
    on_error = common.default_on_error,
}
