import sys
from PIL import Image, ImageDraw, ImageFilter

SS = 4
D  = 1024 * SS

VERDE       = (45, 158, 107)
VERDE_FUNDO = (38, 140, 95)
TELHADO     = (216, 78, 62)
TELHADO_ESC = (181, 58, 48)
CREME       = (253, 250, 244)
CREME_SOMBRA= (232, 226, 214)
PORTA       = (32, 120, 82)
CARNE       = (203, 79, 76)
CARNE_ESC   = (166, 54, 56)
OSSO        = (247, 233, 220)
FOLHA       = (124, 192, 96)
FOLHA_ESC   = (92, 160, 70)
FOLHA_CLARO = (163, 214, 128)
QUEIJO      = (248, 198, 66)
QUEIJO_ESC  = (216, 162, 38)

def u(v): return v * D

img = Image.new('RGBA', (D, D), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Sombra difusa das comidas, pintada antes de tudo
sombras = Image.new('RGBA', (D, D), (0, 0, 0, 0))
ds = ImageDraw.Draw(sombras)

def sombra(caixa):
    ds.ellipse(caixa, fill=(0, 0, 0, 55))

# ── Casa ──────────────────────────────────────────────────────────────
# Corpo mais baixo, deixando espaço para as comidas saírem por cima.
d.rounded_rectangle(
    [u(0.270), u(0.540), u(0.730), u(0.840)], radius=u(0.030), fill=CREME)
d.rounded_rectangle(
    [u(0.270), u(0.786), u(0.730), u(0.840)], radius=u(0.030),
    fill=CREME_SOMBRA)
d.rectangle([u(0.270), u(0.786), u(0.730), u(0.812)], fill=CREME_SOMBRA)

# Telhado
pico_y = 0.400
d.polygon([(u(0.500), u(pico_y)),
           (u(0.790), u(0.560)),
           (u(0.210), u(0.560))], fill=TELHADO)
# Faixa do beiral, separando telhado e parede
d.rounded_rectangle(
    [u(0.210), u(0.545), u(0.790), u(0.585)], radius=u(0.018),
    fill=TELHADO_ESC)

# Porta
d.rounded_rectangle(
    [u(0.437), u(0.660), u(0.563), u(0.840)], radius=u(0.026), fill=PORTA)
d.ellipse([u(0.533), u(0.752), u(0.556), u(0.775)], fill=CREME)

# ── Comidas saindo por cima do telhado ────────────────────────────────
# Ficam baixas de propósito, encostando no telhado: assim leem como
# "saindo da casa" em vez de flutuarem soltas.

# BIFE — oval com osso redondo na ponta (o osso em T virava uma letra)
bx, by = 0.262, 0.392
sombra([u(bx - 0.118), u(by - 0.086), u(bx + 0.108), u(by + 0.104)])
d.ellipse([u(bx - 0.118), u(by - 0.084), u(bx + 0.108), u(by + 0.092)],
          fill=CARNE)
d.ellipse([u(bx - 0.082), u(by - 0.050), u(bx + 0.018), u(by + 0.058)],
          fill=CARNE_ESC)
d.ellipse([u(bx + 0.030), u(by - 0.030), u(bx + 0.098), u(by + 0.042)],
          fill=OSSO)
d.ellipse([u(bx + 0.050), u(by - 0.010), u(bx + 0.078), u(by + 0.022)],
          fill=(233, 214, 198))

# QUEIJO — cunha compacta no centro, sem invadir os vizinhos
qx, qy = 0.500, 0.300
sombra([u(qx - 0.098), u(qy - 0.036), u(qx + 0.098), u(qy + 0.108)])
d.polygon([(u(qx - 0.092), u(qy + 0.076)),
           (u(qx + 0.092), u(qy + 0.076)),
           (u(qx + 0.092), u(qy - 0.016))], fill=QUEIJO)
d.polygon([(u(qx + 0.092), u(qy - 0.016)),
           (u(qx + 0.092), u(qy - 0.052)),
           (u(qx - 0.104), u(qy + 0.046)),
           (u(qx - 0.092), u(qy + 0.076))], fill=QUEIJO_ESC)
for hx, hy, hr in [(0.034, 0.034, 0.016), (0.004, 0.058, 0.011),
                   (0.062, 0.056, 0.011)]:
    d.ellipse([u(qx + hx - hr), u(qy + hy - hr),
               u(qx + hx + hr), u(qy + hy + hr)], fill=QUEIJO_ESC)

# REPOLHO — folhas que ESTOURAM o contorno do círculo, senão vira uma bola
rx, ry = 0.740, 0.392
sombra([u(rx - 0.112), u(ry - 0.096), u(rx + 0.108), u(ry + 0.108)])
# Folhas externas rompendo a silhueta
for fx, fy, fw, fh in [(-0.070, -0.062, 0.070, 0.058),
                       ( 0.006, -0.082, 0.062, 0.052),
                       ( 0.062, -0.040, 0.056, 0.058),
                       (-0.084,  0.014, 0.058, 0.056)]:
    d.ellipse([u(rx + fx - fw), u(ry + fy - fh),
               u(rx + fx + fw), u(ry + fy + fh)], fill=FOLHA_ESC)
# Miolo
d.ellipse([u(rx - 0.092), u(ry - 0.076), u(rx + 0.092), u(ry + 0.098)],
          fill=FOLHA)
d.ellipse([u(rx - 0.054), u(ry - 0.042), u(rx + 0.058), u(ry + 0.064)],
          fill=FOLHA_CLARO)
# Nervuras: duas curvas curtas saindo do centro
for dx in (-0.030, 0.026):
    d.line([(u(rx + dx * 0.3), u(ry - 0.030)),
            (u(rx + dx), u(ry + 0.014)),
            (u(rx + dx * 0.7), u(ry + 0.058))],
           fill=FOLHA_ESC, width=int(u(0.011)), joint='curve')

# Compõe as sombras borradas por baixo do desenho
sombras = sombras.filter(ImageFilter.GaussianBlur(u(0.012)))
base = Image.new('RGBA', (D, D), (0, 0, 0, 0))
d2 = ImageDraw.Draw(base)
d2.rounded_rectangle([0, 0, D, D], radius=u(0.235), fill=VERDE)
composto = Image.alpha_composite(base, sombras)
composto = Image.alpha_composite(composto, img)

# Recorta ao formato arredondado
mascara = Image.new('L', (D, D), 0)
ImageDraw.Draw(mascara).rounded_rectangle([0, 0, D, D], radius=u(0.235), fill=255)
composto.putalpha(mascara)

saida = sys.argv[1]
composto.resize((1024, 1024), Image.LANCZOS).save(f'{saida}/icone_1024.png')

# Foreground adaptativo: conteúdo dentro do círculo seguro do Android.
sem_fundo = Image.alpha_composite(sombras, img)
fg = Image.new('RGBA', (D, D), (0, 0, 0, 0))
corte = sem_fundo.crop((int(u(0.14)), int(u(0.16)), int(u(0.86)), int(u(0.88))))
lado = int(D * 0.60)
corte = corte.resize((lado, lado), Image.LANCZOS)
fg.paste(corte, ((D - lado) // 2, (D - lado) // 2), corte)
fg.resize((1024, 1024), Image.LANCZOS).save(f'{saida}/icone_foreground.png')
print('gerado')
