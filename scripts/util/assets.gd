class_name Assets
extends RefCounted

## Images from the project, the same in the editor and in an exported game. Exports don't ship raw source files
## (a PNG becomes Godot's imported texture), so never read res:// files with Image.load_from_file. Load the imported
## texture and take its pixels instead. The sprite sheets are imported lossless (compress/mode=0), so this is
## exact, and the result can get mipmaps or be cut up like any Image.
static func image(path: String) -> Image:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("Assets.image: can't load " + path)
		return Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	if img.has_mipmaps():
		img.clear_mipmaps()
	return img



## In a browser there are no system fonts to fall back on, so emoji (the toolbar, gifts, emotes) would be boxes.
## The web build adds a colour emoji font (Twemoji, assets/fonts/emoji, see docs/CREDITS.md) behind the default
## font. Desktop and phones keep their system emoji (unchanged).
static func web_fonts() -> void:
	if not OS.has_feature("web"):
		return
	var base := ThemeDB.fallback_font
	var emoji := load("res://assets/fonts/emoji/Twemoji.Mozilla.ttf") as Font
	if base == null or emoji == null or base.fallbacks.has(emoji):
		return
	var fb := base.fallbacks
	fb.append(emoji)
	base.fallbacks = fb
