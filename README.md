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
          {
            id = "default", -- id of the source, must be unique
            url = "", -- url for subsonic server
            q = {
              u = "", -- username for subsonic server
              p = "", -- password for subsonic server
              t = "", -- token for subsonic server (optional, if you don't want to use password)
              s = "", -- salt for subsonic server (optional, if you don't want to use password)
            },
            -- see https://www.subsonic.org/pages/api.jsp Authentication section for more details
          },
        },
      },
      -- see https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-config
      ---@type snacks.picker.Config
      panel = {

        title = "Search Music",
        label = "Enter search query:",
        win = {
          input = {
            keys = {
              ["<CR>"] = { "search", mode = "i" }, -- search in insert mode
              ["<Space>"] = "toggle", -- play/pause
              [","] = "append", -- append to current playlist
              ["."] = "replace", -- replace current playlist
              ["m"] = "mode", -- switch mode between search, playlist
              [">"] = "next", -- next song
              ["<"] = "prev", -- previous song
            },
          },
          preview = {
            wo = { number = false, relativenumber = false, signcolumn = "no", foldcolumn = "0" },
          },
        },
      },
      -- see https://github.com/folke/snacks.nvim/blob/main/docs/win.md#%EF%B8%8F-config
      ---@type snacks.win.Config
      lyric = {
        backdrop = false,
        border = "none",
        row = 1,
        col = 0.7,
        height = 1,
        width = 50,
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
  },
}
```

Actions table:

|  ui   | action  | description                                           |
| :---: | :------ | :---------------------------------------------------- |
| panel | search  | search for a song                                     |
| panel | toggle  | play/pause the current song                           |
| panel | append  | append the selected song to playlist                  |
| panel | replace | replace the current playlist                          |
| panel | mode    | change playback mode(normal, repeat, playlist repeat) |
| panel | next    | play next song in the playlist                        |
| panel | prev    | play previous song in the playlist                    |
| lyric | leave   | leave the lyric window                                |
| lyric | mleft   | move lyric window left                                |
| lyric | mright  | move lyric window right                               |
| lyric | mup     | move lyric window up                                  |
| lyric | mdown   | move lyric window down                                |
| lyric | inc_h   | increase height of lyric window                       |
| lyric | dec_h   | decrease height of lyric window                       |
| lyric | inc_w   | increase width of lyric window                        |
| lyric | dec_w   | decrease width of lyric window                        |

### Showcase

https://github.com/user-attachments/assets/7b3fa82e-1ff2-401c-9f0e-a59e0ec92635

### Usage

|    Command    | Api                              | Description           |
| :-----------: | :------------------------------- | :-------------------- |
|   `:Music`    | `require("music.panel").start()` | open the music panel  |
| `:MusicLyric` | `require("music.lyric").start()` | open the lyric window |

- Keymaps:

Except for the keys defined in the configuration, the following keymaps are available in the music panel:

|     key     | action                                                                 |
| :---------: | ---------------------------------------------------------------------- |
| `N append`  | append to playlist (N is the number of the song)                       |
| `N replace` | replace current whole playlist with song (N is the number of the song) |

### Features

- play/pause music
- change playback mode(normal, repeat, playlist repeat)
- search by keyword.
- navigate through search results
- append or replace current playlist with a song
- display current playlist and switch between songs
- display lyrics if available (which need server support [OpenSubsonic](https://opensubsonic.netlify.app/))

### Todo's

- [ ] MPD support
- [ ] subsonic playlist
- [ ] random play
- [ ] multi source support (multiple subsonic servers, etc.)
- [ ] modify playlist(low priority)

### Inspiration/Credits

- [mpv.nvim](https://github.com/tamton-aquib/mpv.nvim)
