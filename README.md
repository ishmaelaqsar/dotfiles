# dotfiles

The `dotfiles` directory contains all configurations

The `bin` directory contains scripts that will be symlinked to the provided directory when running the `install` script - defaults to `$HOME/.local/bin`

## Bootstrap

```
git clone https://github.com/ishmaelaqsar/dotfiles.git && ./dotfiles/install
```

## scripts

`sync-dotfiles` script creates a symlink for all files in the `dotfiles` directory (maintaining the structure) to the provided directory - defaults to `$HOME`
