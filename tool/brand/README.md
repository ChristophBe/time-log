# The mark

`mark.svg` is the icon: the app's own block — a span of the day, carrying the
live edge that identifies it — on ink. It is the product's visual language at
icon size, which is why it is this and not a clock: the app has no clock face in
it anywhere.

`mark-foreground.svg` is the same mark without its ground, held inside the 66 %
safe zone that an Android launcher may crop to.

Both are hand-written SVG, so the mark is editable text rather than a binary
nobody can change.

## Regenerating

There is no SVG rasteriser on a stock macOS box, so the PNGs are rendered by
headless Chrome and the platform sets by `flutter_launcher_icons`:

```sh
# 1. SVG -> 1024px PNG (repeat for mark-foreground)
printf '<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:transparent}svg{display:block}</style>\n' > /tmp/mark.html
cat tool/brand/mark.svg >> /tmp/mark.html
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
  --disable-gpu --default-background-color=00000000 --virtual-time-budget=2000 \
  --window-size=1024,1024 --screenshot=tool/brand/mark-1024.png file:///tmp/mark.html

# 2. every platform's icons, from the config in pubspec.yaml
dart run flutter_launcher_icons
```

Check the result at 16 px before committing — that is the size that kills marks,
and it is why this one is two shapes and not three.
