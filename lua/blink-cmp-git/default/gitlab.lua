local utils = require('blink-cmp-git.utils')

local default_gitlab_enable = function()
    if vim.fn.executable('git') == 0 or vim.fn.executable('glab') == 0 then return false end
    return utils.remote_url_contain('gitlab.com')
end

-- TODO: refactor this function
local default_gitlab_mr_or_issue_separate_output = function(output, is_mr)
    --- @type blink-cmp-git.CompletionItem[]
    local items = {}
    local json_res = utils.json_decode(output)
    for i = 1, #json_res do
        json_res[i].state = json_res[i].state == 'opened' and 'OPEN' or
            json_res[i].state == 'closed' and 'CLOSED' or
            json_res[i].state == 'merged' and 'MERGED' or
            json_res[i].state
        items[i] = {
            label = (is_mr and '!' or '#') .. tostring(json_res[i].iid) ..
                ' ' .. tostring(json_res[i].title),
            insert_text = (is_mr and '!' or '#') .. tostring(json_res[i].iid),
            kind_name = is_mr and 'PR' or 'Issue',
            documentation =
                '#' .. tostring(json_res[i].iid) ..
                ' ' .. tostring(json_res[i].title) .. '\n' ..
                'State: ' .. tostring(json_res[i].state) .. '\n' ..
                'Author: ' .. tostring(json_res[i].author.username) ..
                ' ' .. tostring(json_res[i].author.name) .. '\n' ..
                'Created at: ' .. tostring(json_res[i].created_at) .. '\n' ..
                'Updated at: ' .. tostring(json_res[i].updated_at) .. '\n' ..
                'Closed at: ' .. tostring(json_res[i].closed_at) .. '\n' ..
                tostring(json_res[i].description)
        }
    end
    return items
end

-- TODO: refactor this function
local function default_gitlab_mr_or_issue_configure_score_offset(items)
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

local default_gitlab_mention_separate_output = function(output)
    --- @type blink-cmp-git.CompletionItem[]
    local items = {}
    local json_res = utils.json_decode(output)
    for i = 1, #json_res do
        items[i] = {
            label = '@' .. tostring(json_res[i].username),
            insert_text = '@' .. tostring(json_res[i].username),
            kind_name = 'Mention',
            documentation = {
                get_command = 'glab',
                get_command_args = {
                    'api',
                    'users/' .. tostring(json_res[i].id),
                },
                ---@diagnostic disable-next-line: redefined-local
                resolve_documentation = function(output)
                    local user_info = utils.json_decode(output)
                    return
                        tostring(user_info.username) ..
                        ' (' .. tostring(user_info.name) .. ')\n' ..
                        'Location: ' .. tostring(user_info.location) .. '\n' ..
                        'Email: ' .. tostring(user_info.public_email) .. '\n' ..
                        'Company: ' .. tostring(user_info.work_information) .. '\n' ..
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
        enable = default_gitlab_enable,
        triggers = { '#' },
        get_command = 'glab',
        get_command_args = {
            'issue',
            'list',
            '--all',
            '--output', 'json',
        },
        insert_text_trailing = ' ',
        separate_output = function(output)
            return default_gitlab_mr_or_issue_separate_output(output, false)
        end,
        configure_score_offset = default_gitlab_mr_or_issue_configure_score_offset,
        on_error = require('blink-cmp-git.default.common').default_on_error,
    },
    pull_request = {
        enable = default_gitlab_enable,
        triggers = { '!' },
        get_command = 'glab',
        get_command_args = {
            'mr',
            'list',
            '--all',
            '--output', 'json',
        },
        insert_text_trailing = ' ',
        separate_output = function(output)
            return default_gitlab_mr_or_issue_separate_output(output, true)
        end,
        configure_score_offset = default_gitlab_mr_or_issue_configure_score_offset,
        on_error = require('blink-cmp-git.default.common').default_on_error,
    },
    mention = {
        enable = default_gitlab_enable,
        triggers = { '@' },
        get_command = 'glab',
        get_command_args = {
            'api',
            'projects/:id/users',
        },
        insert_text_trailing = ' ',
        separate_output = default_gitlab_mention_separate_output,
        configure_score_offset = require('blink-cmp-git.default.common').score_offset_origin,
        on_error = require('blink-cmp-git.default.common').default_on_error,
    },
}
