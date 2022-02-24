local plenary = require("plenary.async")

local M = {}

local conf_cache = true
local conf_depth = 1

local cache = {}

-- Helper function used for recursively
-- merging two tables.
local function merge(lhs, rhs)
    for k, v in pairs(rhs) do
        if lhs[k] ~= nil and type(lhs[k]) == "table" then
            merge(lhs[k], v)
        else
            lhs[k] = v
        end
    end

    return lhs
end

-- Used by M.wrap. Asynchronous function which traverses
-- parent directories and reads available ".lspconfig.json"
-- files.
local function read_and_apply(client)
    local depth = 1
    local changed = false

    local dir = vim.fn.getcwd()
    local sep = package.config:sub(1, 1)

    while depth <= conf_depth do
        -- check for .lspconfig.json
        local conf_path = dir .. sep .. ".lspconfig.json"

        if cache[conf_path] then
            -- if cache contains this config, then load it
            client.config.settings = merge(client.config.settings, cache[conf_path])
            changed = true
        else
            -- otherwise, see if it exists and apply it
            local err, fh = plenary.uv.fs_open(conf_path, "r", 438)
            if not err then
                local err2, stat = plenary.uv.fs_fstat(fh)
                assert(not err2, err)

                local err3, data = plenary.uv.fs_read(fh, stat.size, 0)
                assert(not err3, err)

                -- merge project LSP settings
                local lsp_settings = vim.json.decode(data)
                client.config.settings = merge(client.config.settings, lsp_settings)
                changed = true

                if conf_cache then
                    cache[conf_path] = lsp_settings
                end
            end
        end

        -- go up directory tree
        -- https://stackoverflow.com/questions/14554193/last-index-of-character-in-string
        local last_sep = dir:find(sep .. "[^/]*$")
        if last_sep == nil then
            break
        end

        dir = dir:sub(0, last_sep - 1)
        depth = depth + 1
    end

    if changed then
        client.notify("workspace/didChangeConfiguration", {
            settings = client.config.settings
        })
    end
end

-- Sets up lsp-project with the given configuration.
function M.setup(config)
    -- apply configuration changes
    if config ~= nil and type(config) ~= "table" then
        error("lsp-project: config was not a table")
    end

    if config.depth ~= nil and type(config.cache) == "boolean" then
        conf_cache = config.cache
    end

    if config.depth ~= nil and type(config.depth) == "number" then
        conf_depth = config.depth
    end

    -- setup cache invalidation command
    vim.cmd [[
        command LsprojInvalCache lua require('lsp-project').invalidate_cache()
    ]]
end

-- Invalidates the per-directory config cache.
function M.invalidate_cache()
    cache = {}
end

-- Wraps a user-specified "on_init" handler to allow for
-- lsp-project to load per-directory settings.
function M.wrap(on_init)
    return function(client, init_result)
        -- begin scanning
        plenary.run(function()
            read_and_apply(client)
        end)

        -- if the user passed their own on_init,
        -- then call it
        if on_init ~= nil and type(on_init) == "function" then
            return on_init(client, init_result)
        end
    end
end

return M
