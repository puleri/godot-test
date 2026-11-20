extends RefCounted
## Fictional clerk signatures assembled from handwritten pen strokes.

const INK := "302420"
const STROKE_ADVANCE := 80
const STROKES := [
	"M10 50 C23 49 34 46 44 34 C61 13 48 5 38 23 C26 42 30 57 48 53 C61 50 73 45 90 50",
	"M10 50 C22 49 27 31 39 30 C52 27 54 50 65 51 C73 52 79 46 90 50",
	"M10 50 C19 50 25 34 33 36 C42 37 37 52 46 50 C54 50 56 34 65 37 C73 40 75 51 90 50",
	"M10 50 C24 49 36 39 43 43 C52 51 50 77 38 78 C22 79 40 55 58 51 C70 47 79 46 90 50",
	"M10 50 C24 50 30 37 39 34 C46 31 45 47 50 52 C56 59 64 41 72 41 C77 40 81 47 90 50",
	"M10 50 C21 48 37 54 54 55 C76 57 84 36 71 34 C58 32 60 51 90 50",
]
const VARIANTS := [
	[0, 2, 3, 5],
	[1, 4, 0, 3],
	[3, 1, 5, 4],
	[0, 5, 2, 4],
	[4, 0, 3, 2],
	[1, 3, 2, 5],
]


static func make_ink(strokes: PackedInt32Array, slots: int) -> ImageTexture:
	var width := STROKE_ADVANCE * slots + 20
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="88">' % width
	svg += '<g fill="none" stroke="#%s" stroke-width="3.8" stroke-linecap="round" stroke-linejoin="round">' % INK
	for slot in strokes.size():
		svg += '<path transform="translate(%d 0)" d="%s"/>' % [slot * STROKE_ADVANCE, STROKES[strokes[slot]]]
	svg += "</g></svg>"
	var ink := Image.new()
	ink.load_svg_from_string(svg, 2.0)
	ink.generate_mipmaps()
	return ImageTexture.create_from_image(ink)
