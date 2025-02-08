local M = {}
local health = vim.health

local function check_command_executable(command)
    if vim.fn.executable(command) == 0 then
        health.warn('"' .. command .. '"' .. ' not found.')
    else
        health.ok('"' .. command .. '" found.')
    end
end

function M.check()
    health.start('blink-cmp-git')
    check_command_executable('git')
    check_command_executable('gh')
end

return M
