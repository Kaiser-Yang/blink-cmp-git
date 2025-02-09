local utils = require('blink-cmp-git.utils')
local common = require('blink-cmp-git.default.common')

local function default_github_enable()
    if vim.fn.executable('git') == 0 or vim.fn.executable('gh') == 0 then return false end
    return utils.remote_url_contain('github.com')
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

local function default_github_pr_or_issue_get_label(item)
    return utils.concat_when_all_true('#', item.number, ' ', item.title, '')
end

local function default_github_pr_get_kind_name(_)
    return 'PR'
end

local function default_github_pr_or_issue_get_insert_text(item)
    return utils.concat_when_all_true('#', item.number, '')
end

local function default_issue_get_kind_name(_)
    return 'Issue'
end

local function default_github_pr_or_issue_get_documentation(item)
    return utils.concat_when_all_true('#', item.number, ' ', item.title, '\n') ..
        utils.concat_when_all_true('State: ', item.state, '\n') ..
        utils.concat_when_all_true('State Reason: ', item.stateReason, '\n') ..
        utils.concat_when_all_true('Author: ', item.author.login, '') ..
        utils.concat_when_all_true(' (', item.author.name, ')') .. '\n' ..
        utils.concat_when_all_true('Created at: ', item.createdAt, '\n') ..
        utils.concat_when_all_true('Updated at: ', item.updatedAt, '\n') ..
        (
            item.state == 'MERGED' and
            utils.concat_when_all_true('Merged  at: ', item.mergedAt, '\n') ..
            utils.concat_when_all_true('Merged  by: ', item.mergedBy.login, '') ..
            utils.concat_when_all_true(' (', item.mergedBy.name, ')') .. '\n'
            or
            utils.concat_when_all_true('Closed  at: ', item.closedAt, '\n')
        ) ..
        utils.concat_when_all_true(item.body, '')
end

local function default_github_mention_get_label(item)
    return utils.concat_when_all_true('@', item.login, '')
end

local function default_github_mention_get_kind_name(_)
    return 'Mention'
end

local function default_github_mention_get_insert_text(item)
    return utils.concat_when_all_true('@', item.login, '')
end

local function default_github_mention_get_documentation(item)
    return {
        get_command = 'gh',
        get_command_args = {
            'api',
            'users/' .. tostring(item.login),
        },
        resolve_documentation = function(output)
            local user_info = utils.json_decode(output)
            return
                utils.concat_when_all_true(user_info.login, '') ..
                utils.concat_when_all_true(' (', user_info.name, ')') .. '\n' ..
                utils.concat_when_all_true('Location: ', user_info.location, '\n') ..
                utils.concat_when_all_true('Email: ', user_info.email, '\n') ..
                utils.concat_when_all_true('Company: ', user_info.company, '\n') ..
                utils.concat_when_all_true('Created at: ', user_info.created_at, '\n')
        end
    }
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
        separate_output = common.json_array_separator,
        get_label = default_github_pr_or_issue_get_label,
        get_kind_name = default_issue_get_kind_name,
        get_insert_text = default_github_pr_or_issue_get_insert_text,
        get_documentation = default_github_pr_or_issue_get_documentation,
        configure_score_offset = default_github_pr_or_issue_configure_score_offset,
        on_error = common.default_on_error,
    },
    pull_request = {
        enable = default_github_enable,
        triggers = { '#' },
        get_command = 'gh',
        get_command_args = {
            'pr',
            'list',
            '--state', 'all',
            '--json', 'number,title,state,body,createdAt,updatedAt,closedAt,mergedAt,mergedBy,author',
        },
        insert_text_trailing = ' ',
        separate_output = common.json_array_separator,
        get_label = default_github_pr_or_issue_get_label,
        get_kind_name = default_github_pr_get_kind_name,
        get_insert_text = default_github_pr_or_issue_get_insert_text,
        get_documentation = default_github_pr_or_issue_get_documentation,
        configure_score_offset = default_github_pr_or_issue_configure_score_offset,
        on_error = common.default_on_error,
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
        separate_output = common.json_array_separator,
        get_label = default_github_mention_get_label,
        get_kind_name = default_github_mention_get_kind_name,
        get_insert_text = default_github_mention_get_insert_text,
        get_documentation = default_github_mention_get_documentation,
        configure_score_offset = common.score_offset_origin,
        on_error = common.default_on_error,
    },
}
