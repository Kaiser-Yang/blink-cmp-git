local utils = require('blink-cmp-git.utils')
local log = require('blink-cmp-git.log')
log.setup({ title = 'blink-cmp-git' })

local M = {}

local default_ignored_error = {
    'repository has disabled issues',
    'does not have any commits yet',
}

function M.score_offset_origin(items)
    for i = 1, #items do
        items[i].score_offset = #items - i
    end
end

function M.default_on_error(return_value, standard_error)
    if not utils.truthy(standard_error) then
        vim.schedule(
            function() log.error('get_completions failed\n', 'with error code:', return_value) end
        )
        return true
    end
    for _, ignored_error in pairs(default_ignored_error) do
        -- always match exact case
        if standard_error:find(ignored_error, 1, true) then return true end
    end
    vim.schedule(
        function()
            log.error(
                'get_completions failed',
                '\n',
                'with error code:',
                return_value,
                '\n',
                'stderr:',
                standard_error
            )
        end
    )
    return true
end

function M.json_array_separator(output)
    return utils.remove_empty_string_value(utils.json_decode(output))
end

function M.basic_args_for_github_api(token)
    local args = {
        '-H',
        'Accept: application/vnd.github+json',
        '-H',
        'X-GitHub-Api-Version: 2022-11-28',
    }
    if utils.truthy(token) then
        table.insert(args, '-H')
        table.insert(args, 'Authorization: Bearer ' .. token)
    end
    return args
end

function M.github_repo_get_command_args(command, token, type_name)
    local args = M.basic_args_for_github_api(token)
    if command == 'curl' then
        table.insert(args, '-s')
        table.insert(args, '-f')
        table.insert(
            args,
            'https://api.github.com/repos/' .. utils.get_repo_owner_and_repo() .. '/' .. type_name
        )
    else
        table.insert(args, 1, 'api')
        table.insert(args, 'repos/' .. utils.get_repo_owner_and_repo() .. '/' .. type_name)
    end
    return args
end

return M
