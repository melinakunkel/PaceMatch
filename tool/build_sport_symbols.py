"""Builds assets/fonts/SportSymbols.ttf — the few sport icons Flutter's
Material Icons don't have.

- Badminton (U+F2A8) and Pickleball (U+F2A6, used for Tischtennis) are cut
  out of Google's Material Symbols Outlined font (Apache License 2.0), fixed
  at FILL 0 / wght 400 / GRAD 0 / opsz 24 so they match Material Icons.
- Bouldern (U+E900) is drawn here: a boulder outline with climbing holds, in
  the same 2px (80 unit) stroke.

Usage: pip install fonttools shapely
       python3 tool/build_sport_symbols.py path/to/MaterialSymbolsOutlined.ttf
(the .ttf ships in the material_symbols_icons package on pub.dev)
"""
import sys

from fontTools import subset
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from shapely.geometry import Point, Polygon
from shapely.geometry.polygon import orient
from shapely.ops import unary_union

font = TTFont(sys.argv[1])
font = instancer.instantiateVariableFont(
    font, {'FILL': 0, 'wght': 400, 'GRAD': 0, 'opsz': 24})
options = subset.Options()
options.layout_features = []
options.notdef_outline = True
options.name_IDs = ['*']
subsetter = subset.Subsetter(options)
subsetter.populate(unicodes=[0xF2A8, 0xF2A6])
subsetter.subset(font)

# Boulder: flat bottom, irregular rounded top, plus four holds.
rock = Polygon([(80, 100), (130, 470), (300, 780), (540, 880),
                (760, 760), (880, 450), (880, 100)])
outer = rock.buffer(-40, join_style=1).buffer(40, join_style=1)
ring = outer.difference(outer.buffer(-80, join_style=1))
holds = [Point(360, 330).buffer(58, 16), Point(560, 470).buffer(66, 16),
         Point(420, 620).buffer(48, 16), Point(680, 300).buffer(44, 16)]
shape = unary_union([ring] + holds)

pen = TTGlyphPen(None)


def draw(coords):
    points = [(round(x), round(y)) for x, y in list(coords)[:-1]]
    pen.moveTo(points[0])
    for p in points[1:]:
        pen.lineTo(p)
    pen.closePath()


for poly in (shape.geoms if hasattr(shape, 'geoms') else [shape]):
    poly = orient(poly, sign=-1.0)  # TrueType: outer clockwise, holes ccw
    draw(poly.exterior.coords)
    for hole in poly.interiors:
        draw(hole.coords)

glyph = pen.glyph()
name = 'uniE900'
font['glyf'].glyphs[name] = glyph
glyph.recalcBounds(font['glyf'])
font['hmtx'].metrics[name] = (960, glyph.xMin)
font.setGlyphOrder(font.getGlyphOrder() + [name])
for table in font['cmap'].tables:
    if table.isUnicode():
        table.cmap[0xE900] = name
font['maxp'].numGlyphs = len(font.getGlyphOrder())
font.save('assets/fonts/SportSymbols.ttf')
