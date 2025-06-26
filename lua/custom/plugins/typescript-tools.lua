return {
  {
    'pmizio/typescript-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
    opts = {
      settings = {
        inlay_hints = {
          parameter_names = { enabled = true },
        },
      },
    },
  },
}
