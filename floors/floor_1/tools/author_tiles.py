"""Author original native 16px SVG tiles. No resized high-detail source artwork.
Run from the repository root: python3 floors/floor_1/tools/author_tiles.py
"""
from pathlib import Path
import random
root=Path(__file__).resolve().parents[1]
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="256" height="64" viewBox="0 0 256 64" shape-rendering="crispEdges">']
def rect(x,y,w,h,c):
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#{c}"/>')
def poly(points,c):
    parts.append(f'<polygon points="{points}" fill="#{c}"/>')
for tile in range(64):
    rng=random.Random(945+tile)
    parts.append(f'<g transform="translate({tile%16*16},{tile//16*16})">')
    if tile<8 or 40<=tile<44 or 48<=tile<52:
        grass=4<=tile<8
        base='59665e' if tile>=48 else ('456331' if grass else ('87734d' if tile>=40 else '6c6146'))
        rect(0,0,16,16,base)
        shades=['6c7b6d','434f49','869080'] if tile>=48 else (['64843c','344e2b','8fa74d'] if grass else ['7c7050','5c563e','91805b'])
        for j in range(18):
            x,y=rng.randrange(15),rng.randrange(15)
            rect(x,y,rng.choice([1,2,3]),1,rng.choice(shades))
        for j in range(3):
            x,y=rng.randrange(13),rng.randrange(13)
            rect(x,y,3,2,'4f5138' if grass else '56513d')
            rect(x,y,2,1,'9b9564' if grass else 'a4936a')
        if grass:
            for j in range(5):
                x,y=rng.randrange(1,15),rng.randrange(2,14)
                rect(x,y,1,2,'a0aa58'); rect(x-1,y-1,1,1,'788c43')
    elif 8<=tile<16:
        rect(0,0,16,16,'242c29')
        poly('1,2 5,0 13,1 16,5 15,12 11,16 3,15 0,10','40483d')
        poly('2,3 6,1 13,2 15,5 13,10 6,12 1,9','777760')
        poly('2,4 7,2 13,3 13,5 7,4 3,6','a09b75')
        poly('1,10 6,12 13,10 15,8 14,13 10,15 4,14','535a48')
        rect(6,5,1,5,'555d4a');rect(7,8,5,1,'555d4a')
        rect(3,13,2,2,'323e35');rect(11,12,1,3,'323e35')
        if tile%3!=0:
            for x,y in [(2,2),(3,1),(4,2),(5,1),(10,3),(12,2)]:
                rect(x,y,2,1,'6e833d');rect(x,y+1,1,1,'435a30')
        if tile>=12:
            rect(0,10,16,6,'323b32');rect(1,10,14,1,'6e7155')
            for x in [2,6,11]:
                rect(x,12,1,4,'242e29');rect(x+1,12,2,2,'46513e')
    elif 16<=tile<20:
        rect(0,0,16,16,'326c68')
        for j in range(10):
            x,y=rng.randrange(14),rng.randrange(16)
            rect(x,y,rng.choice([1,2,3]),1,rng.choice(['3b8079','55988a','295954']))
        rect(2+(tile%3),4,5,1,'80b2a0');rect(8,12,4,1,'69a190')
    elif 20<=tile<24 or 36<=tile<40:
        # Transparent leafy fern clusters, drawn at their actual native pixels.
        rect(7,6,2,9,'283e26')
        for x,y,w in [(3,3,4),(8,1,3),(9,5,5),(1,7,6),(8,9,6),(3,11,4)]:
            rect(x,y,w,3,'263f28');rect(x,y,w-1,2,'4c7335')
            rect(x+1,y,1,1,'93a34c')
        rect(7,3,1,11,'769344')
        if tile>=36:
            for x,y in [(3,4),(11,6),(5,11)]:
                rect(x,y,3,1,'d2c98a');rect(x+1,y-1,1,3,'e9dfac');rect(x+1,y,1,1,'b68c43')
    elif 24<=tile<28:
        poly('3,3 11,1 15,5 15,12 11,15 3,14 0,10 0,6','29342d')
        poly('3,4 10,2 13,5 13,10 10,12 3,11 1,8','7e8168')
        poly('3,4 10,2 11,4 7,5 3,7 2,6','b2ac82')
        poly('2,10 6,12 12,10 13,8 14,12 10,14 4,13','4c5b44')
        rect(7,6,1,4,'4b5845');rect(8,8,3,1,'4b5845')
        rect(3,3,3,1,'82944a');rect(2,4,3,2,'546f36')
    elif 28<=tile<32:
        poly('0,3 4,4 9,7 16,7 16,11 8,10 3,7 0,7','313d29')
        poly('0,3 5,5 9,7 16,7 16,9 8,9 3,6 0,5','89663e')
        rect(8,6,1,5,'a88a50');rect(9,10,2,3,'5c4c30')
        rect(1,2,3,2,'567137');rect(4,3,2,2,'88a34b')
    elif 32<=tile<36:
        rect(0,0,16,16,'293431')
        for y in [1,5,9,13]:
            rect(1,y,14,3,'657466');rect(1,y,14,1,'a1a98a');rect(2,y+2,12,1,'414e44')
        rect(0,0,1,16,'8d947b');rect(15,0,1,16,'414e44')
    else:
        rect(0,0,16,16,'11231f')
        for j in range(8):
            rect(rng.randrange(14),rng.randrange(14),2,1,'182b24')
    parts.append('</g>')
parts.append('</svg>')
(root/'art'/'cave_tiles.svg').write_text('\n'.join(parts))
print('Authored cave_tiles.svg: 64 native 16x16 cells')
