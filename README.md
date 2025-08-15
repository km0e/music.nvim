# music.nvim

A music player inside neovim that uses [mpv](https://github.com/mpv-player/mpv).

### Requirements:

- neovim (latest stable version is recommended)
- mpv
- a [Subsonic](https://subsonic.org/) server (or any compatible server like [Navidrome](https://navidrome.org/), etc.)

### Installation and Configuration

```lua
-- Using lazy.nvim:
{
  "km0e/music.nvim",
  opts = {
    u = "user",
    p = "password",
    url = "subsonic api url",
  }
}
```

### Usage

- The command: `:Music`
- The actual api: `require("music.ui").start()`

- Keymaps:

|     key      | action             |
| :----------: | ------------------ |
| `1, 2, 3...` | play song by index |

### Features

- search by keyword.

### Todo's

- [ ] add playlist support
- [ ] add mode support (e.g. shuffle, repeat)

### Inspiration/Credits

- [mpv.nvim](https://github.com/tamton-aquib/mpv.nvim)
