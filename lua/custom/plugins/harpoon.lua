return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require 'harpoon'
    local extensions = require 'harpoon.extensions'

    harpoon:extend(extensions.builtins.highlight_current_file())
    -- First setup harpoon with basic configuration
    harpoon:setup {
      settings = {
        save_on_toggle = true,
      },
    }

    vim.keymap.set('n', '<leader>a', function()
      harpoon:list():add()
    end, { desc = '[A]dd file to Harpoon list' })
    vim.keymap.set('n', '<C-e>', function()
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end, { desc = 'Toggl[e] Harpoon Quick Menu' })

    vim.keymap.set('n', '<C-h>', function()
      harpoon:list():select(1)
    end, { desc = 'Jump to first file in Harpoon list' })
    vim.keymap.set('n', '<C-j>', function()
      harpoon:list():select(2)
    end, { desc = 'Jump to second file in Harpoon list' })
    vim.keymap.set('n', '<C-k>', function()
      harpoon:list():select(3)
    end, { desc = 'Jump to third file in Harpoon list' })
    vim.keymap.set('n', '<C-l>', function()
      harpoon:list():select(4)
    end, { desc = 'Jump to fourth file in Harpoon list' })
    -- Toggle previous & next buffers stored within Harpoon list
    vim.keymap.set('n', '<C-P>', function()
      harpoon:list():prev()
    end, { desc = 'Jump to [P]revious file in Harpoon list' })
    vim.keymap.set('n', '<C-N>', function()
      harpoon:list():next()
    end, { desc = 'Jump to [N]ext file in Harpoon list' })
  end,
}
