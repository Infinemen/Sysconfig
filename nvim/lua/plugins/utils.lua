return {
    {
        'rhysd/accelerated-jk',
        keys = {
            { 'j', '<Plug>(accelerated_jk_gj)' },
            { 'k', '<Plug>(accelerated_jk_gk)' },
        },
    },
    {
        'windwp/nvim-autopairs',
        event = 'VeryLazy',
        opts = {
            enable_check_bracket_line = false,
        }
    },
    {
        'ethanholz/nvim-lastplace',
        config = true,
    },
    {
        'folke/flash.nvim',
        keys = {
            {
                's',
                mode = { 'n', 'x', 'o' },
                function()
                    require('flash').jump()
                end,
                desc = 'Flash',
            },
            {
                'S',
                mode = { 'n', 'x', 'o' },
                function()
                    require('flash').treesitter()
                end,
                desc = 'Flash Treesitter',
            },
            {
                'r',
                mode = { 'o' },
                function()
                    require('flash').remote()
                end,
                desc = 'Remote Flash',
            },
            {
                'R',
                mode = { 'o', 'x' },
                function()
                    require('flash').treesitter_search()
                end,
                desc = 'Flash Treesitter search',
            },
            {
                '<c-s>',
                mode = { 'c' },
                function()
                    require('flash').toggle()
                end,
                desc = 'Flash Treesitter search',
            },
        },
        config = true
    },
    {
        'echasnovski/mini.comment',
        event = 'VeryLazy',
        config = true,
    },
    {
        'nvim-neo-tree/neo-tree.nvim',
        dependencies = {
            'nvim-lua/plenary.nvim',
            'nvim-tree/nvim-web-devicons',
            'MunifTanjim/nui.nvim',
        },
        keys = {
            { '<leader>e', '<cmd>Neotree toggle<CR>', desc = 'Open the neo-tree', mode = { "n", "v" }}
        },
        config = true,
    },
    {
        's1n7ax/nvim-window-picker',
        opts = {
            filter_rules = {
                include_current_win = true,
                bo = {
                    filetype = { "fidget", "neo-tree" }
                }
            }
        },
        keys = {
            {
                "<c-w>p",
                function()
                    local window_number = require('window-picker').pick_window()
                    if window_number then vim.api.nvim_set_current_win(window_number) end
                end,
            }
        }
    },
}
