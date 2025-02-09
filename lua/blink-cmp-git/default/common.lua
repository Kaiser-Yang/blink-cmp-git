local utils = require('blink-cmp-git.utils')
local log = require('blink-cmp-git.log')
log.setup({ title = 'blink-cmp-git' })

local default_ignored_error = {
    'repository has disabled issues',
    'does not have any commits yet'
}

return {
    score_offset_origin = function(items)
        for i = 1, #items do
            items[i].score_offset = #items - i
        end
    end,
    default_on_error = function(return_value, standard_error)
        if not utils.truthy(standard_error) then
            vim.schedule(function()
                log.error('get_completions failed',
                    '\n',
                    'with error code:', return_value)
            end)
            return true
        end
        for _, ignored_error in pairs(default_ignored_error) do
            if standard_error:find(ignored_error) then
                return true
            end
        end
        vim.schedule(function()
            log.error('get_completions failed',
                '\n',
                'with error code:', return_value,
                '\n',
                'stderr:', standard_error)
        end)
        return true
    end,
    json_array_separator = function(output)
        local items = utils.json_decode(output)
        vim.iter(items):each(function(item)
            item.state = item.state == 'opened' and 'OPEN' or
                item.state == 'closed' and 'CLOSED' or
                item.state == 'merged' and 'MERGED' or
                item.state
        end)
        return items
    end,
}
