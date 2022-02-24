# lsp-project.nvim
`lsp-project` allows for per-project language server settings when using the
native LSP client, a la Visual Studio Code.

When setup, `lsp-project` will apply settings located in files named
`.lspconfig.json` in the current working directory and its parent directories.
[Here](.lspconfig.json) is an example.

## Installation
Install as you usually would with your plugin manager of choice. `lsp-project`
requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

[packer.nvim](https://github.com/wbthomason/packer.nvim):
```lua
use {
    "woofdoggo/lsp-project.nvim",
    requires = "nvim-lua/plenary.nvim"
}
```

## Quickstart
Install `lsp-project` with your plugin manager of choice, and include a call to
setup in your Neovim configuration. You can check the 
[Configuration](#configuration) section for more detailed information.

```lua
local lsp_project = require("lsp-project")

lsp_project.setup({
    cache = true,
    scan_depth = 10
})
```

When setting up your language servers, you must wrap your `on_init` function
with `lsp-project`. Here is a short example you can follow if you are using
`nvim-lspconfig`:

```lua
local lsp_project = require("lsp-project")
local lsp = require("lspconfig")

lsp.rust_analyzer.setup({
    on_init = lsp_project.wrap(),

    -- provide your default global language server settings
    settings = {
        ...
    },

    -- add any other LSP settings as usual
})
```

## Configuration
Here is an example configuration for `lsp-project` with explanations of what
the options do:

```lua
local lsp_project = require("lsp-project")

lsp_project.setup({
    -- Whether or not to cache per-project LSP settings.
    -- Enabling this may result in issues if you are
    -- frequently changing per-project settings.
    cache = true,

    -- How many folders to scan backwards for per-project
    -- settings.
    -- If set to 1, it will only scan the current directory.
    -- If set to n >= 2, it will scan n directories up the tree.
    scan_depth = 1,
})
```

> **Note:** If enabled, the cache will not refresh until you either restart
Neovim or run the `LsprojInvalCache` command. The new project settings will
take effect when you open new files.

When setting up your language servers, you must wrap your `on_init` function
with `lsp-project`. Here is a short example you can follow if you are using
`nvim-lspconfig`:

```lua
local lsp_project = require("lsp-project")
local lsp = require("lspconfig")

lsp.rust_analyzer.setup({
    -- wrap your on_init function with lsp-project
    on_init = lsp_project.wrap(),

    -- add any global language server settings you usually use
    settings = {

    },

    -- add any other LSP settings you use
})
```

If you use your own custom `on_init` function, you can pass it to the `wrap`
call, like so:

```lua
-- ...

local function my_on_init(client, init_result)
    -- do something
end

lsp.rust_analyzer.setup({
    on_init = lsp_project.wrap(my_on_init),

    -- ... other LSP settings
})
```

If you use something other than `nvim-lspconfig` (such as interfacing with
Neovim's LSP functionality directly), you should follow the above example
passing a wrapped `on_init` function to whatever starts your LSP client.
