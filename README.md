# neoguh.nvim
A neogit ui for guh.nvim


## Install
```lua
vim.pack.add({
  -- dependencies
  "https://github.com/NeogitOrg/neogit",
  "https://github.com/justinmk/guh.nvim",

  "https://github.com/edisj/neoguh.nvim",
})
```

Requirements:
  - [guh.nvim](https://github.com/justinmk/guh.nvim)
  - [neogit](https://github.com/neogitorg/neogit)
  - neovim 0.13+

## Usage
This plugin exports a single command `:Neoguh`, which is nothing but shallow `:Guh` wrapper that instead opens the ui in a custom Neogit view.
Everything you can do with `:Guh`, you can do with `Neoguh`.
```vim
" Repo view for the current repo
:Neoguh
" Repo view for any repo (or anything :Guh accepts as an arg)
:Neoguh neovim/neovim
:Neoguh https://github.com/neovim/neovim
```

## Credit
Everything here is built on top of `guh.nvim` and `neogit`. Guh provides all of the GitHub plumbing, state management, api calls, etc. and Neogit provides the UI component-based library for building the ui. I just wired things together :). 
  - [justinmk/guh.nvim](https://github.com/justinmk/guh.nvim)
  - [NeogitOrg/neogit](https://github.com/neogitorg/neogit)
  - [emrearmagan/atlas.nvim](https://github.com/emrearmagan/atlas.nvim) - The original inspiration for this project. I used Atlas and thought it was amazing, but I wanted something more integrated with my current git workflow.
