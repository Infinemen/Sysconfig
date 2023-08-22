return {
    'neovim/nvim-lspconfig',
    cmd = { 'Mason', 'Neoconf' },
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = {
        'williamboman/mason.nvim',
        'williamboman/mason-lspconfig',
        'folke/neodev.nvim',
        {
            'j-hui/fidget.nvim',
            tag = 'legacy'
        },
    },
    config = function()
        local servers = {
            lua_ls = {
                Lua = {
                    workspace = { checkThirdParty = false },
                    telemetry = { enable = false },
                },
            },
            pyright = {},
            clangd = {},
            ltex = {},
        }
        local on_attach = function(_, bufnr)
            local nmap = function(keys, func, desc)
                if desc then
                    desc = 'LSP: ' .. desc
                end
                vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
            end

            nmap( 'gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
            nmap( 'gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
            nmap( 'gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
            nmap( 'gi', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
            nmap( 'K', vim.lsp.buf.hover, 'Hover Documentation')
            nmap( '<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')
            nmap( '<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
            nmap( '<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
            nmap( '<leader>da', require('telescope.builtin').lsp_diagnostics, '[D]iagnostics')
            nmap( '<leader>wl', function()
                                    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                                end,
                '[W]orkspace [L]ist Folders')
            nmap( '<leader>D', vim.lsp.buf.type_definition, 'Type [D]efinition')
            nmap( '<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
            nmap( '<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
            nmap( '<leader>f',  function()
                                    vim.lsp.buf.format { async = true }
                                end,
                '[F]ormat code')
        end
        local capabilities = require('cmp_nvim_lsp').default_capabilities()
        require('neodev').setup()
        require('fidget').setup()
        require('mason').setup({
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗"
                }
            }
        })
        require('mason-lspconfig').setup({
            ensure_installed = vim.tbl_keys(servers),
            handlers = {
                function(server_name)
                    require('lspconfig')[server_name].setup {
                        settings = servers[server_name],
                        on_attach = on_attach,
                        capabilities = capabilities,
                    }
                end,
            }
        })
    end
}
