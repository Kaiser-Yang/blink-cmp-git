--- @class blink-cmp-git.LogOptions
--- @field title string

local M = {}
local config = {}
local utils = require('blink-cmp-git.utils')

--- @param opts blink-cmp-git.LogOptions
function M.setup(opts) config = vim.tbl_extend('force', config, opts) end

function M.info(...) vim.notify(utils.str(...), vim.log.levels.INFO, { title = config.title }) end

function M.warn(...) vim.notify(utils.str(...), vim.log.levels.WARN, { title = config.title }) end

function M.error(...) vim.notify(utils.str(...), vim.log.levels.ERROR, { title = config.title }) end

function M.debug(...) vim.notify(utils.str(...), vim.log.levels.DEBUG, { title = config.title }) end

function M.trace(...) vim.notify(utils.str(...), vim.log.levels.TRACE, { title = config.title }) end

return M
