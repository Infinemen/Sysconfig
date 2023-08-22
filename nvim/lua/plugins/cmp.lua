return {
    'hrsh7th/nvim-cmp',
    event = {'BufReadPost', 'BufNewFile' },
    dependencies = {
        'hrsh7th/cmp-path',
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-cmdline',
        {
            'saadparwaiz1/cmp_luasnip',
            dependencies = {
                {
                    'L3MON4D3/LuaSnip',
                    dependencies = {
                        'rafamadriz/friendly-snippets',
                    }
                }
            }
        },
    },
    config = function()
        require('luasnip.loaders.from_vscode').lazy_load()
        local has_words_before = function()
            unpack = unpack or table.unpack
            local line, col = unpack(vim.api.nvim_win_get_cursor(0))
            return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
        end
        local cmp = require 'cmp'
        local luasnip = require('luasnip')

        local cmp_mapping = {
            ["<Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                    cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then
                    luasnip.expand_or_jump()
                elseif has_words_before() then
                    cmp.complete()
                else
                    fallback()
                end
             end, { "i", "s" }),

            ["<S-Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                    cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                    luasnip.jump(-1)
                else
                    fallback()
                end
            end, { "i", "s" }),
            ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }

        cmp.setup {
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body)
                end,
            },
            sources = cmp.config.sources {
                {name = 'nvim-lsp'},
                {name = 'path'},
                {name = 'luasnip'},
                {name = 'buffer'},
            },
            mapping = cmp.mapping.preset.insert( cmp_mapping ),
            experimental = {
                ghost_text = true,
            }
        }

        cmp.setup.cmdline('/', {
            mapping = cmp.mapping.preset.insert( cmp_mapping ),
            sources = {
                {name = 'buffer'},
            }
        })

        cmp.setup.cmdline(':', {
            mapping = cmp.mapping.preset.insert( cmp_mapping ),
            sources = cmp.config.sources({
                {name = 'path'},
                {name = 'cmpdline'},
            })
        })
    end,
}
