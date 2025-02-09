local Job = require('plenary.job')

-- enable when current directory is inside a git repo
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
end

--- @type blink-cmp-git.GCSCompletionOptions
return {
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
    separate_output = default_commit_separate_output,
    configure_score_offset = require('blink-cmp-git.default.common').score_offset_origin,
    on_error = require('blink-cmp-git.default.common').default_on_error,
}
