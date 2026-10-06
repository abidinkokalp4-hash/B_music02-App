"""Render the app's code-defined purple play mark at launcher resolution."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math
root=Path(__file__).resolve().parents[1]
n=1024
im=Image.new('RGBA',(n,n),(0,0,0,0))
# Rounded triangle from a superellipse-like sampled cubic outline.
def curve(p0,p1,p2,p3):
 return [tuple((1-t)**3*p0[k]+3*(1-t)**2*t*p1[k]+3*(1-t)*t*t*p2[k]+t**3*p3[k] for k in [0,1]) for t in [i/60 for i in range(61)]]
pts=curve((250,135),(180,100),(110,155),(110,235))+curve((110,235),(110,380),(110,630),(110,790))+curve((110,790),(110,870),(180,918),(250,882))+curve((250,882),(440,785),(675,665),(849,572))+curve((849,572),(929,530),(929,476),(849,435))+curve((849,435),(670,341),(437,230),(250,135))
mask=Image.new('L',(n,n));ImageDraw.Draw(mask).polygon(pts,fill=255)
glow=mask.filter(ImageFilter.GaussianBlur(25));im.paste((134,36,255,150),(0,0,n,n),glow)
grad=Image.new('RGBA',(n,n));px=grad.load()
for y in range(n):
 for x in range(n):
  light=max(0,1-math.hypot(x-210,y-180)/880);px[x,y]=(int(60+145*light),int(8+55*light),int(130+125*light),255)
im.paste(grad,(0,0),mask)
d=ImageDraw.Draw(im);d.line(pts+[pts[0]],fill=(196,96,255,255),width=13,joint='curve')
p2=[(x*.43+290,y*.43+284) for x,y in pts];d.polygon(p2,fill=(252,231,255,255));d.line(p2+[p2[0]],fill=(255,248,255,255),width=7,joint='curve')
im.save(root/'assets/images/b_music02_logo.png')
