local utils = require('blink-cmp-git.utils')
local common = require('blink-cmp-git.default.common')

--- @async
local function default_github_enable()
    if
        not utils.command_found('git')
        or not utils.command_found('gh') and not utils.command_found('curl')
    then
        return false
    end
    if utils.truthy(utils.get_repo_owner_and_repo_from_octo()) then return true end
    return utils.get_repo_remote_url():find('github%.com')
end

local function default_github_pr_or_issue_get_label(item)
    return utils.concat_when_all_true('#', item.number, ' ', item.title)
end

local function default_github_pr_get_kind_name(_) return 'PR' end

local function default_github_pr_or_issue_get_insert_text(item)
    return utils.concat_when_all_true('#', item.number)
end

local function default_issue_get_kind_name(_) return 'Issue' end

local function default_github_pr_or_issue_get_documentation(item)
    return utils.concat_when_all_true('#', item.number, ' ', item.title, '\n')
        .. utils.concat_when_all_true(
            'State: ',
            item.locked and 'locked'
                or item.draft and 'draft'
                or item.merged_at and 'merged'
                or item.state,
            '\n'
        )
        .. utils.concat_when_all_true(
            'State Reason: ',
            item.active_lock_reason or item.state_reason,
            '\n'
        )
        .. utils.concat_when_all_true('Author: ', item.user.login, '\n')
        .. utils.concat_when_all_true('Created at: ', item.created_at, '\n')
        .. utils.concat_when_all_true('Updated at: ', item.updated_at, '\n')
        .. (utils.concat_when_all_true('Merged  at: ', item.merged_at, '\n') or utils.concat_when_all_true(
            'Closed  at: ',
            item.closed_at,
            '\n'
        ) .. utils.concat_when_all_true('Closed by: ', item.closed_by.login, '\n'))
        .. utils.concat_when_all_true(item.body)
end

local function default_github_mention_get_label(item) return utils.concat_when_all_true(item.login) end

local function default_github_mention_get_kind_name(_) return 'Mention' end

local function default_github_mention_get_insert_text(item)
    return utils.concat_when_all_true('@', item.login)
end

local function default_github_get_command() return utils.command_found('gh') and 'gh' or 'curl' end

local function default_github_mention_get_documentation(item)
    return {
        get_token = '',
        get_command = default_github_get_command,
        get_command_args = function(command, token)
            local args = common.basic_args_for_github_api(token)
            if command == 'curl' then
                table.insert(args, '-s')
                table.insert(args, '-f')
                table.insert(args, 'https://api.github.com/users/' .. item.login)
            else
                table.insert(args, 1, 'api')
                table.insert(args, 'users/' .. item.login)
            end
            return args
        end,
        resolve_documentation = function(output)
            local user_info = utils.json_decode(output)
            return utils.concat_when_all_true(user_info.login, '')
                .. utils.concat_when_all_true(' (', user_info.name, ')')
                .. '\n'
                .. utils.concat_when_all_true('Location: ', user_info.location, '\n')
                .. utils.concat_when_all_true('Email: ', user_info.email, '\n')
                .. utils.concat_when_all_true('Company: ', user_info.company, '\n')
                .. utils.concat_when_all_true('Created at: ', user_info.created_at, '\n')
        end,
        on_error = common.default_on_error,
    }
end

local function default_github_issue_separate_output(output)
    local issues_and_prs = common.json_array_separator(output)
    -- `github` api return prs for issues, so we need to filter out prs
    local issues = {}
    vim.iter(issues_and_prs):each(function(issue)
        if issue.pull_request == nil then table.insert(issues, issue) end
    end)
    return issues
end

--- @type blink-cmp-git.GCSOptions
return {
    issue = {
        enable = default_github_enable,
        triggers = { '#' },
        get_token = '',
        get_command = default_github_get_command,
        get_command_args = function(command, token)
            return common.github_repo_get_command_args(command, token, 'issues')
        end,
        insert_text_trailing = ' ',
        separate_output = default_github_issue_separate_output,
        get_label = default_github_pr_or_issue_get_label,
        get_kind_name = default_issue_get_kind_name,
        get_insert_text = default_github_pr_or_issue_get_insert_text,
        get_documentation = default_github_pr_or_issue_get_documentation,
        configure_score_offset = common.score_offset_origin,
        on_error = common.default_on_error,
    },
    pull_request = {
        enable = default_github_enable,
        triggers = { '#' },
        get_token = '',
        get_command = default_github_get_command,
        get_command_args = function(command, token)
            return common.github_repo_get_command_args(command, token, 'pulls')
        end,
        insert_text_trailing = ' ',
        separate_output = common.json_array_separator,
        get_label = default_github_pr_or_issue_get_label,
        get_kind_name = default_github_pr_get_kind_name,
        get_insert_text = default_github_pr_or_issue_get_insert_text,
        get_documentation = default_github_pr_or_issue_get_documentation,
        configure_score_offset = common.score_offset_origin,
        on_error = common.default_on_error,
    },
    mention = {
        enable = default_github_enable,
        triggers = { '@' },
        get_token = '',
        get_command = default_github_get_command,
        get_command_args = function(command, token)
            return common.github_repo_get_command_args(command, token, 'contributors')
        end,
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
