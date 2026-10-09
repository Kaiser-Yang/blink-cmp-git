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

--- Get the host of the GitHub repository. Fall back to `github.com` when the
--- host can not be found from the remote URL.
--- @return string
--- @async
function M.github_host()
    local host = utils.get_repo_host()
    return utils.truthy(host) and host or 'github.com'
end

--- Build args for `gh api` or `curl` to request the GitHub REST API.
--- For GitHub Enterprise Server, `gh` is given `--hostname`, and `curl` requests
--- `https://HOST/api/v3`.
--- @param command string
--- @param token string
--- @param endpoint string API endpoint without the leading `/`, e.g. `users/USERNAME`
--- @param paginate? boolean
--- @return string[]
--- @async
function M.github_api_args(command, token, endpoint, paginate)
    local args = M.basic_args_for_github_api(token)
    local host = M.github_host()
    if command == 'curl' then
        local base_url = host == 'github.com' and 'https://api.github.com/'
            or 'https://' .. host .. '/api/v3/'
        table.insert(args, '-s')
        table.insert(args, '-f')
        table.insert(args, base_url .. endpoint)
    else
        table.insert(args, 1, 'api')
        if host ~= 'github.com' then
            table.insert(args, 2, '--hostname')
            table.insert(args, 3, host)
        end
        if paginate then table.insert(args, '--paginate') end
        table.insert(args, endpoint)
    end
    return args
end

function M.github_repo_get_command_args(command, token, type_name)
    return M.github_api_args(
        command,
        token,
        'repos/' .. utils.get_repo_owner_and_repo() .. '/' .. type_name,
        type_name == 'contributors'
    )
end

return M
