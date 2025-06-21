return {
  {
    'nvim-telescope/telescope-file-browser.nvim',
    dependencies = {
      'nvim-telescope/telescope.nvim',
      'nvim-lua/plenary.nvim',
    },
    config = function()
      -- load the extension after telescope is set up
      require('telescope').load_extension 'file_browser'

      -- map <leader>b to open the file_browser
      vim.keymap.set('n', '<leader>b', function()
        require('telescope').extensions.file_browser.file_browser {
          path = vim.fn.expand '%:p:h',
          cwd = vim.fn.expand '%:p:h',
          respect_gitignore = false,
          hidden = true,
        }
      end, { desc = 'Telescope File Browser' })
    end,
  },
}
