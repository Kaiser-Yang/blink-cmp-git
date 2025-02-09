local Job = require('plenary.job')
local utils = require('blink-cmp-git.utils')

local function default_github_enable()
    if vim.fn.executable('git') == 0 or vim.fn.executable('gh') == 0 then return false end
    return utils.remote_url_contain('github.com')
end

-- TODO: refactor this function
local function default_github_pr_or_issue_separate_output(output, is_pr)
    --- @type blink-cmp-git.CompletionItem[]
    local items = {}
    local json_res = utils.json_decode(output)
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
                'Author: ' .. tostring(json_res[i].author.login) ..
                ' ' .. tostring(json_res[i].author.name) .. '\n' ..
                'Created at: ' .. tostring(json_res[i].createdAt) .. '\n' ..
                'Updated at: ' .. tostring(json_res[i].updatedAt) .. '\n' ..
                'Closed at: ' .. tostring(json_res[i].closedAt) .. '\n' ..
                tostring(json_res[i].body)
        }
    end
    return items
end

-- TODO: refactor this function
local function default_github_pr_or_issue_configure_score_offset(items)
    -- Bonus to make sure items sorted as below:
    -- open issue, open pr, closed issue, merged pr, closed pr
    local keys = {
        'OPENIssue',
        'OPENPR',
        'CLOSEDIssue',
        'MERGEDPR',
        'CLOSEDPR'
    }
    local bonus = 999999
    local bonus_score = {}
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

local function default_github_mention_separate_output(output)
    local json_res = utils.json_decode(output)
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
                    local user_info = utils.json_decode(output)
                    return
                        tostring(user_info.login) ..
                        ' (' .. tostring(user_info.name) .. ')\n' ..
                        'Location: ' .. tostring(user_info.location) .. '\n' ..
                        'Email: ' .. tostring(user_info.email) .. '\n' ..
                        'Company: ' .. tostring(user_info.company) .. '\n' ..
                        'Created at: ' .. tostring(user_info.created_at) .. '\n'
                end
            }
        }
    end
    return items
end

--- @type blink-cmp-git.GCSOptions
return {
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
        on_error = require('blink-cmp-git.default.common').default_on_error,
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
        on_error = require('blink-cmp-git.default.common').default_on_error,
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
        separate_output = default_github_mention_separate_output,
        configure_score_offset = require('blink-cmp-git.default.common').score_offset_origin,
        on_error = require('blink-cmp-git.default.common').default_on_error,
    },
}
