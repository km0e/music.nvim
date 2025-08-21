# music.nvim

A music player inside neovim that uses [mpv](https://github.com/mpv-player/mpv).

### Requirements:

- neovim (latest stable version is recommended)
- mpv
- a [Subsonic](https://subsonic.org/) server (or any compatible server like [Navidrome](https://navidrome.org/), etc.)

### Installation and Configuration

Default configuration looks like this:

```lua
-- Using lazy.nvim:
{
  "km0e/music.nvim",
  opts = {
    source = {
      subsonic = {
        u = nil, -- username for subsonic server
        url = nil, -- url for subsonic server
        p = nil, -- password for subsonic server
        t = nil, -- token for subsonic server (optional, if you don't want to use password)
        s = nil, -- salt for subsonic server (optional, if you don't want to use password)
        -- see https://www.subsonic.org/pages/api.jsp Authentication section for more details
      }
    }
    win = {
      -- see https://github.com/folke/snacks.nvim/blob/main/docs/win.md#%EF%B8%8F-config
      backdrop = false,
			height = 0.8,
			width = 0.6,
			border = "rounded",
			title = "Music Panel",
			title_pos = "center",
    }
    keys = {
      close = "<Esc>", -- key to close the panel
      search = { "<CR>", "s" }, -- key to search by keyword
      toggle = "<Space>", -- key to toggle play/pause
      append = "a", -- key to append song to playlist
      replace = "r", -- key to replace current playlist with song
      switch = ";", -- key to open the panel
      mode = "m", -- key to toggle playback mode
      next_search = "j", -- key to go to next search result
      prev_search = "k", -- key to go to previous search result
      next = ">", -- key to go to next song in playlist
      prev = "<", -- key to go to previous song in playlist
    },
  }
}
```

### Showcase

https://github.com/user-attachments/assets/7b3fa82e-1ff2-401c-9f0e-a59e0ec92635

### Usage

- The command: `:Music`
- The actual api: `require("music.ui").start()`

- Keymaps:

Except for the keys defined in the configuration, the following keymaps are available in the music panel:

|  key  | action                                                                 |
| :---: | ---------------------------------------------------------------------- |
| `N a` | append to playlist (N is the number of the song)                       |
| `N r` | replace current whole playlist with song (N is the number of the song) |

- Auto commands:

|      event      | action                                                              |
| :-------------: | ------------------------------------------------------------------- |
|  `InsertEnter`  | close the panel if it is open (to avoid conflicts with insert mode) |
| `InsertCharPre` | always search for the input character with about 500ms delay        |

### Features

- play/pause music
- change playback mode(normal, repeat, playlist repeat)
- search by keyword.
- navigate through search results
- append or replace current playlist with a song
- display current playlist and switch between songs

### Todo's

- [ ] subsonic playlist
- [ ] random play
- [ ] multi source support (multiple subsonic servers, etc.)
- [ ] switch song in playlist
- [ ] modify playlist(low priority)

### Inspiration/Credits

- [mpv.nvim](https://github.com/tamton-aquib/mpv.nvim)
