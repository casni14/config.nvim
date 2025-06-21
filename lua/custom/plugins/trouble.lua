return {
  {
    'folke/trouble.nvim',
    config = function()
      require('trouble').setup {
        auto_preview = true,
      }

      vim.keymap.set('n', '<leader>tt', function()
        vim.cmd 'Trouble diagnostics toggle'
      end, { desc = 'Toggle Trouble Diagnostics' })
      vim.keymap.set('n', '[t', function()
        require('trouble').next { skip_groups = true, jump = true }
      end)

      vim.keymap.set('n', ']t', function()
        require('trouble').prev { skip_groups = true, jump = true }
      end)
    end,
  },
}
