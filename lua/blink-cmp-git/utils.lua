local M = {}
local Job = require('plenary.job')

function M.get_option(opt, ...)
    if type(opt) == 'function' then
        return opt(...)
    else
        return opt
    end
end

function M.truthy(value)
    if type(value) == 'boolean' then
        return value
    elseif type(value) == 'function' then
        return M.truthy(value())
    elseif type(value) == 'table' then
        return not vim.tbl_isempty(value)
    elseif type(value) == 'string' then
        return value ~= ''
    elseif type(value) == 'number' then
        return value ~= 0
    elseif type(value) == 'nil' then
        return false
    else
        return true
    end
end

--- Transform arguments to string, and concatenate them with a space.
function M.str(...)
    local args = { ... }
    for i, v in ipairs(args) do
        args[i] = type(args[i]) == 'string' and args[i] or vim.inspect(v)
    end
    return table.concat(args, ' ')
end

function M.remote_url_contain(content)
    if vim.fn.executable('git') == 0 then return false end
    local output = ''
    ---@diagnostic disable-next-line: missing-fields
    Job:new({
        command = 'git',
        args = { 'remote', '-v' },
        cwd = vim.fn.getcwd(),
        on_exit = function(job, return_value, _)
            if return_value ~= 0 then
                return
            end
            output = table.concat(job:result(), '\n')
        end
    }):sync()
    return output:find(content) ~= nil
end

function M.json_decode(str, opts)
    opts = vim.tbl_extend('force', { luanil = { object = true, array = true } }, opts or {})
    return vim.json.decode(str, opts)
end

function M.concat_when_all_true(...)
    local args = {}
    for i = 1, select('#', ...) do
        local arg = select(i, ...)
        if not arg then
            return ''
        end
        table.insert(args, tostring(arg))
    end
    return table.concat(args, '')
end

return M
