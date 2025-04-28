# 🎨 FlickGame

An implementation of [Increpare's](https://www.increpare.com) [FlickGame](https://flickgame.org) in my micro framework [Lena](https://github.com/lichendust/lena) that I wrote in an afternoon for fun. No, really, it's not a serious implementation. Don't try and ship on it.

## Controls

- Left click to paint/interact.
- Middle click to pick colours.
- Right click to flood fill.
- `[` and `]` to change brush size.
- `SPACE` to start the game.
- `ESCAPE` to return to the editor.
- `RETURN` to save the game.
- `F11` to toggle fullscreen.

You can re-open and play a saved `.json` file like so, which will launch in play mode by default:

```sh
flickgame save.json
```

You can switch colours, frames and what frame a colour maps to by left-clicking on the UI at the bottom of the editor.

## Compile

```sh
odin build flickgame.odin -file -collection:shared="path/to/lenarepo" -define:LENA_PALETTE=16
```

## License

The code in `flickgame.odin` is committed to the public domain. No warranty is implied; use at your own risk.
