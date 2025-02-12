local common = require('blink-cmp-git.default.common')
local utils = require('blink-cmp-git.utils')

local function default_commit_separate_output(output)
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
    return item:match('commit ([^\n]*)'):sub(1, 7) .. ' ' .. item:match('\n\n%s*([^\n]*)')
end

local function default_commit_get_kind_name()
    return 'Commit'
end

local function default_commit_get_insert_text(item)
    return item:match('commit ([^\n]*)'):sub(1, 7)
end

local function default_commit_get_documentation(item)
    return item
end

--- @type blink-cmp-git.GCSCompletionOptions
return {
    enable = utils.is_inside_git_repo,
    triggers = { ':' },
    get_token = '',
    get_command = 'git',
    get_command_args = {
        '--no-pager',
        'log',
        '--pretty=fuller',
        '--decorate=no',
    },
    insert_text_trailing = ' ',
    separate_output = default_commit_separate_output,
    get_label = default_commit_get_label,
    get_kind_name = default_commit_get_kind_name,
    get_insert_text = default_commit_get_insert_text,
    get_documentation = default_commit_get_documentation,
    configure_score_offset = common.score_offset_origin,
    on_error = common.default_on_error,
}
