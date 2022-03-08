local plenary = require("plenary.async")

local M = {}

local conf_depth = -1

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

    while depth <= conf_depth or conf_depth == -1 do
        -- check for .lspconfig.json
        local conf_path = dir .. sep .. ".lspconfig.json"

        -- otherwise, see if it exists and apply it
        local err, fh = plenary.uv.fs_open(conf_path, "r", 438)
        if not err then
            local err, stat = plenary.uv.fs_fstat(fh)
            assert(not err, err)

            local err, data = plenary.uv.fs_read(fh, stat.size, 0)
            assert(not err, err)

            -- merge project LSP settings
            local lsp_settings = vim.json.decode(data)
            client.config.settings = merge(client.config.settings, lsp_settings)
            changed = true
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

    if config.scan_depth ~= nil and type(config.scan_depth) == "number" then
        conf_depth = config.scan_depth
    end
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
