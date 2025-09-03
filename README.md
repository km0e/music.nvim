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
          u = "", -- username for subsonic server
          p = "", -- password for subsonic server
          t = "", -- token for subsonic server (optional, if you don't want to use password)
          s = "", -- salt for subsonic server (optional, if you don't want to use password)
          url = "", -- url for subsonic server
          -- see https://www.subsonic.org/pages/api.jsp Authentication section for more details
        },
      },
      -- see https://github.com/folke/snacks.nvim/blob/main/docs/layout.md#-types
      ---@type snacks.layout.Box
      panel = {
        lo = {
          backdrop = false,
          border = "rounded",
          title = "Music Panel",
          title_pos = "center",
          height = 0.8,
          width = 0.6,
          box = "vertical",
          [1] = {
            win = "input",
            height = 1,
          },
          [2] = {
            win = "panel",
            border = "top",
          },
        },
        keys = {
          ["<Esc>"] = "close", -- close the panel
          ["<CR>"] = { "search", mode = "i" }, -- search in insert mode
          ["<Space>"] = "toggle", -- play/pause
          [","] = "append", -- append to current playlist
          ["."] = "replace", -- replace current playlist
          [";"] = "switch", -- switch between panel and lyric window
          ["m"] = "mode", -- switch mode between search, playlist
          ["j"] = "next_search", -- next search result
          ["k"] = "prev_search", -- previous search result
          [">"] = "next", -- next song
          ["<"] = "prev", -- previous song
        },
      },
      -- see https://github.com/folke/snacks.nvim/blob/main/docs/win.md#%EF%B8%8F-config
      ---@type snacks.win.Config
      lyric = {
        backdrop = false,
        border = "none",
        height = 1,
        width = 30,
        keys = {
          [";"] = "leave", -- leave the lyric window
          ["<Left>"] = "mleft", -- move lyric window left
          ["<Right>"] = "mright", -- move lyric window right
          ["<Up>"] = "mup", -- move lyric window up
          ["<Down>"] = "mdown", -- move lyric window down
          ["<C-Up>"] = "inc_h", -- increase height of lyric window
          ["<C-Down>"] = "dec_h", -- decrease height of lyric window
          ["<C-Right>"] = "inc_w", -- increase width of lyric window
          ["<C-Left>"] = "dec_w", -- decrease width of lyric window
        },
      },
    },
}
```

Actions table:

|  ui   | action      | description                                           |
| :---: | :---------- | :---------------------------------------------------- |
| panel | close       | close the music panel                                 |
| panel | search      | search for a song                                     |
| panel | toggle      | play/pause the current song                           |
| panel | append      | append the selected song to playlist                  |
| panel | replace     | replace the current playlist                          |
| panel | switch      | switch between search and playlist                    |
| panel | mode        | change playback mode(normal, repeat, playlist repeat) |
| panel | next_search | go to next search result                              |
| panel | prev_search | go to previous search result                          |
| panel | next        | play next song in the playlist                        |
| panel | prev        | play previous song in the playlist                    |
| lyric | leave       | leave the lyric window                                |
| lyric | mleft       | move lyric window left                                |
| lyric | mright      | move lyric window right                               |
| lyric | mup         | move lyric window up                                  |
| lyric | mdown       | move lyric window down                                |
| lyric | inc_h       | increase height of lyric window                       |
| lyric | dec_h       | decrease height of lyric window                       |
| lyric | inc_w       | increase width of lyric window                        |
| lyric | dec_w       | decrease width of lyric window                        |

### Showcase

https://github.com/user-attachments/assets/7b3fa82e-1ff2-401c-9f0e-a59e0ec92635

### Usage

|    Command    | Api                              | Description           |
| :-----------: | :------------------------------- | :-------------------- |
|   `:Music`    | `require("music.panel").start()` | open the music panel  |
| `:MusicLyric` | `require("music.lyric").start()` | open the lyric window |

- Keymaps:

Except for the keys defined in the configuration, the following keymaps are available in the music panel:

|  key  | action                                                                 |
| :---: | ---------------------------------------------------------------------- |
| `N ,` | append to playlist (N is the number of the song)                       |
| `N .` | replace current whole playlist with song (N is the number of the song) |

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
- display lyrics if available (which need server support [OpenSubsonic](https://opensubsonic.netlify.app/))

### Todo's

- [ ] subsonic playlist
- [ ] random play
- [ ] multi source support (multiple subsonic servers, etc.)
- [ ] modify playlist(low priority)

### Inspiration/Credits

- [mpv.nvim](https://github.com/tamton-aquib/mpv.nvim)
