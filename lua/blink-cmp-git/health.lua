local M = {}
local health = vim.health
local utils = require('blink-cmp-git.utils')

--- @param command string
--- @param message? string
--- @return boolean
local function check_command_executable(command, message)
    message = message or ('"' .. command .. '" not found.')
    if not utils.command_found(command) then
        health.warn(message)
        return false
    end
    health.ok('"' .. command .. '" found.')
    return true
end

function M.check()
    health.start('blink-cmp-git')
    check_command_executable('git')
    local should_check_curl = false
    should_check_curl = should_check_curl
        or not check_command_executable('gh', '"gh" not found, will use curl instead.')
    should_check_curl = should_check_curl
        or not check_command_executable('glab', '"glab" not found, will use curl instead.')
    if should_check_curl then check_command_executable('curl') end
end

return M
