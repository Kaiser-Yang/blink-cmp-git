local utils = require('blink-cmp-git.utils')
local common = require('blink-cmp-git.default.common')

local default_gitlab_enable = function()
    if not utils.command_found('git') or
        not utils.command_found('glab') and not utils.command_found('curl') then
        return false
    end
    return utils.get_repo_remote_url():find('gitlab%.com')
end

local function default_gitlab_issue_get_label(item)
    return utils.concat_when_all_true('#', item.iid, ' ', item.title, '')
end

local function default_gitlab_issue_get_kind_name(_)
    return 'Issue'
end

local function default_gitlab_issue_get_insert_text(item)
    return utils.concat_when_all_true('#', item.iid, '')
end

local function default_gitlab_mr_get_label(item)
    return utils.concat_when_all_true('!', item.iid, ' ', item.title)
end

local function default_gitlab_mr_get_kind_name(_)
    return 'MR'
end

local function default_gitlab_mr_get_insert_text(item)
    return utils.concat_when_all_true('!', item.iid)
end

local function default_gitlab_mr_or_issue_get_documentation(item, is_mr)
    return
        utils.concat_when_all_true(is_mr and '!' or '#', item.iid, ' ', item.title, '\n') ..
        utils.concat_when_all_true('State: ',
            item.discussion_locked and 'locked' or
            item.draft and 'draft' or
            item.state, '\n') ..
        utils.concat_when_all_true('Author: ', item.author.username, '') ..
        utils.concat_when_all_true(' (', item.author.name, ')') .. '\n' ..
        utils.concat_when_all_true('Created at: ', item.created_at, '\n') ..
        utils.concat_when_all_true('Updated at: ', item.updated_at, '\n') ..
        (
            item.state == 'merged' and
            utils.concat_when_all_true('Merged  at: ', item.merged_at, '\n') ..
            utils.concat_when_all_true('Merged  by: ', item.merged_by.username, '') ..
            utils.concat_when_all_true(' (', item.merged_by.name, ')') .. '\n'
            or
            item.state == 'closed' and
            utils.concat_when_all_true('Closed  at: ', item.closed_at, '\n') ..
            utils.concat_when_all_true('Closed  by: ', item.closed_by.username, '') ..
            utils.concat_when_all_true(' (', item.closed_by.name, ')') .. '\n'
            or ''
        ) ..
        utils.concat_when_all_true(item.description)
end

local function default_gitlab_mention_get_label(item)
    return utils.concat_when_all_true(item.username, '')
end

local function default_gitlab_mention_get_kind_name(_)
    return 'Mention'
end

local function default_gitlab_mention_get_insert_text(item)
    return utils.concat_when_all_true('@', item.username, '')
end

local function default_gitlab_get_command()
    return utils.command_found('glab') and 'glab' or 'curl'
end

local function basic_args_for_gitlab_api(token)
    if utils.truthy(token) then
        return {
            '-H', 'PRIVATE-TOKEN: ' .. token,
        }
    end
    return {}
end

local function default_gitlab_mention_get_documentation(item)
    return {
        get_token = '',
        get_command = default_gitlab_get_command,
        get_command_args = function(command, token)
            local args = basic_args_for_gitlab_api(token)
            if command == 'curl' then
                table.insert(args, '-s')
                table.insert(args, '-f')
                table.insert(args, 'https://gitlab.com/api/v4/users/' .. tostring(item.id))
            else
                table.insert(args, 1, 'api')
                table.insert(args, 'users/' .. tostring(item.id))
            end
            return args
        end,
        ---@diagnostic disable-next-line: redefined-local
        resolve_documentation = function(output)
            local user_info = utils.json_decode(output)
            utils.remove_empty_string_value(user_info)
            return
                utils.concat_when_all_true(user_info.username, '') ..
                utils.concat_when_all_true(' (', user_info.name, ')') .. '\n' ..
                utils.concat_when_all_true('Location: ', user_info.location, '\n') ..
                utils.concat_when_all_true('Email: ', user_info.public_email, '\n') ..
                utils.concat_when_all_true('Company: ', user_info.work_information, '\n') ..
                utils.concat_when_all_true('Created at: ', user_info.created_at, '\n')
        end,
        on_error = common.default_on_error,
    }
end

local function default_gitlab_mr_issue_mention_get_command_args(command, token, type_name)
    local args = basic_args_for_gitlab_api(token)
    if command == 'curl' then
        table.insert(args, '-s')
        table.insert(args, '-f')
        table.insert(args,
            'https://gitlab.com/api/v4/projects/' ..
            utils.get_repo_owner_and_repo(true) .. '/' ..
            type_name
        )
    else
        table.insert(args, 1, 'api')
        table.insert(args,
            'projects/' ..
            utils.get_repo_owner_and_repo(true) .. '/' ..
            type_name
        )
    end
    return args
end

--- @type blink-cmp-git.GCSOptions
return {
    issue = {
        enable = default_gitlab_enable,
        triggers = { '#' },
        get_token = '',
        get_command = default_gitlab_get_command,
        get_command_args = function(command, token)
            return default_gitlab_mr_issue_mention_get_command_args(command, token, 'issues')
        end,
        insert_text_trailing = ' ',
        separate_output = common.json_array_separator,
        get_label = default_gitlab_issue_get_label,
        get_kind_name = default_gitlab_issue_get_kind_name,
        get_insert_text = default_gitlab_issue_get_insert_text,
        get_documentation = function(item)
            return default_gitlab_mr_or_issue_get_documentation(item, false)
        end,
        configure_score_offset = common.score_offset_origin,
        on_error = common.default_on_error,
    },
    pull_request = {
        enable = default_gitlab_enable,
        triggers = { '!' },
        get_token = '',
        get_command = default_gitlab_get_command,
        get_command_args = function(command, token)
            return default_gitlab_mr_issue_mention_get_command_args(command, token, 'merge_requests')
        end,
        insert_text_trailing = ' ',
        separate_output = common.json_array_separator,
        get_label = default_gitlab_mr_get_label,
        get_kind_name = default_gitlab_mr_get_kind_name,
        get_insert_text = default_gitlab_mr_get_insert_text,
        get_documentation = function(item)
            return default_gitlab_mr_or_issue_get_documentation(item, true)
        end,
        configure_score_offset = common.score_offset_origin,
        on_error = common.default_on_error,
    },
    mention = {
        enable = default_gitlab_enable,
        triggers = { '@' },
        get_token = '',
        get_command = default_gitlab_get_command,
        get_command_args = function(command, token)
            return default_gitlab_mr_issue_mention_get_command_args(command, token, 'users')
        end,
        insert_text_trailing = ' ',
        separate_output = common.json_array_separator,
        get_label = default_gitlab_mention_get_label,
        get_kind_name = default_gitlab_mention_get_kind_name,
        get_insert_text = default_gitlab_mention_get_insert_text,
        get_documentation = default_gitlab_mention_get_documentation,
        configure_score_offset = common.score_offset_origin,
        on_error = common.default_on_error,
    },
}
