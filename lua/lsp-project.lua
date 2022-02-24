local plenary = require("plenary.async")

local M = {}

local conf_cache = true
local conf_depth = 1

local cache = {}

-- helper function used in order to
-- recursively merge two tables
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

function read_and_apply(conf_path, client)
    local err, fh = plenary.uv.fs_open(conf_path, "r", 438)
    if not err then
        local err2, stat = plenary.uv.fs_fstat(fh)
        assert(not err2, err)

        local err3, data = plenary.uv.fs_read(fh, stat.size, 0)
        assert(not err3, err)

        -- merge project LSP settings
        local lsp_settings = vim.json.decode(data)
        client.config.settings = merge(client.config.settings, lsp_settings)
        client.notify("workspace/didChangeConfiguration")

        if conf_cache then
            cache[conf_path] = lsp_settings
        end
    end
end

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

function M.invalidate_cache()
    cache = {}
end

function M.wrap(on_init)
    return function(client, init_result)
        local depth = 1

        local dir = vim.fn.getcwd()
        local sep = package.config:sub(1, 1)

        -- begin scanning
        while depth <= conf_depth do
            -- check for .lspconfig.json
            local conf_path = dir .. sep .. ".lspconfig.json"

            if cache[conf_path] then
                -- if cache contains this config, then load it
                client.config.settings = merge(client.config.settings, cache[conf_path])
                client.notify("workspace/didChangeConfiguration")
            else
                -- otherwise, see if it exists and apply it
                plenary.run(function()
                    read_and_apply(conf_path, client)
                end)
            end

            -- go up directory tree
            -- https://stackoverflow.com/questions/14554193/last-index-of-character-in-string
            local last_sep = dir:find(sep .. "[^/]*$")
            if last_sep == nil or last_sep == 0 then
                break
            end

            dir = dir:sub(0, last_sep - 1)
            depth = depth + 1
        end

        -- if the user passed their own on_init, then
        -- call it once we are done
        if on_init ~= nil and type(on_init) == "function" then
            return on_init(client, init_result)
        end
    end
end

return M
