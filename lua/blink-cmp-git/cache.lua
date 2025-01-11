--- @class blink-cmp-git.Cache
--- @field new fun(): blink-cmp-git.Cache
--- @field get fun(self: blink-cmp-git.Cache, keys: string|string[]): any
--- @field set fun(self: blink-cmp-git.Cache, keys: string|string[], value: any)
--- @field clear fun(self: blink-cmp-git.Cache)
local Cache = {}

function Cache.new()
    local self = setmetatable({}, { __index = Cache })
    self.cache = {}
    return self
end

function Cache:clear()
    self.cache = {}
end

--- @param keys string|string[]
function Cache:get(keys)
    keys = type(keys) == 'table' and keys or { keys }
    local res = nil
    for _, key in ipairs(keys) do
        if self.cache[key] then
            res = self.cache[key]
        else
            res = nil
            break
        end
    end
    return res
end

--- @param keys string|string[]
--- @param value? any
function Cache:set(keys, value)
    keys = type(keys) == 'table' and keys or { keys }
    local pre = nil
    local last_key = nil
    local now = self.cache
    for _, key in ipairs(keys) do
        if not now[key] then
            now[key] = {}
        end
        pre = now
        last_key = key
        now = now[key]
    end
    pre[last_key] = value
end

return Cache
