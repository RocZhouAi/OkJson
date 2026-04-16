#!/usr/bin/env python3
"""生成 OkJson 现代风格应用图标 - macOS 风格"""

from PIL import Image, ImageDraw, ImageFont
import math
import os

# 设计色板（开发工具风格）
COLORS = {
    'bg_top': (22, 33, 62),        # 深蓝顶部
    'bg_bottom': (15, 23, 42),     # 更深蓝底部
    'brace': (241, 245, 249),      # 近白色花括号
    'brace_shadow': (59, 130, 246, 60),  # 蓝色辉光
    'accent': (59, 130, 246),      # 蓝色 #3B82F6
    'accent_light': (96, 165, 250), # 亮蓝色
    'ok_color': (52, 211, 153),    # 翡翠绿 #34D399
}


def lerp_color(c1, c2, t):
    """线性插值两个颜色"""
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_rounded_rect(draw, xy, radius, fill):
    """绘制圆角矩形"""
    x0, y0, x1, y1 = xy
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.pieslice([x0, y0, x0 + 2*radius, y0 + 2*radius], 180, 270, fill=fill)
    draw.pieslice([x1 - 2*radius, y0, x1, y0 + 2*radius], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - 2*radius, x0 + 2*radius, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - 2*radius, y1 - 2*radius, x1, y1], 0, 90, fill=fill)


def create_icon(size=1024):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    corner_radius = int(size * 0.22)

    # === 1. 渐变背景 ===
    gradient = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    grad_draw = ImageDraw.Draw(gradient)
    for y in range(size):
        t = y / size
        # 从深蓝到更深蓝的垂直渐变
        color = lerp_color(COLORS['bg_top'], COLORS['bg_bottom'], t)
        grad_draw.line([(0, y), (size, y)], fill=(*color, 255))

    # 用圆角矩形蒙版裁剪
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    draw_rounded_rect(mask_draw, (0, 0, size, size), corner_radius, 255)
    img = Image.composite(gradient, img, mask)

    # === 2. 微妙的顶部高光 ===
    highlight = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    hl_draw = ImageDraw.Draw(highlight)
    for y in range(size // 3):
        alpha = int(25 * (1 - y / (size // 3)) ** 2)
        hl_draw.line([(corner_radius, y), (size - corner_radius, y)],
                     fill=(255, 255, 255, alpha))
    # 蒙版裁剪高光
    img = Image.alpha_composite(img, Image.composite(highlight, Image.new('RGBA', (size, size), (0,0,0,0)), mask))

    # === 3. 底部蓝色微光（非常微妙） ===
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    center_x = size // 2
    glow_radius = int(size * 0.35)
    for r in range(glow_radius, 0, -1):
        alpha = int(8 * (r / glow_radius) ** 2)
        glow_draw.ellipse(
            [center_x - r, size - int(size * 0.05) - r,
             center_x + r, size - int(size * 0.05) + r],
            fill=(59, 130, 246, alpha)
        )
    img = Image.alpha_composite(img, Image.composite(glow, Image.new('RGBA', (size, size), (0,0,0,0)), mask))

    draw = ImageDraw.Draw(img)

    # === 4. 绘制花括号 { } ===
    brace_size = int(size * 0.48)
    font_paths = [
        '/Library/Fonts/SF-Mono-Bold.otf',
        '/System/Library/Fonts/SFCompact.ttf',
        '/System/Library/Fonts/Menlo.ttc',
        '/System/Library/Fonts/Courier.dfont',
    ]
    brace_font = None
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                brace_font = ImageFont.truetype(fp, brace_size)
                break
            except Exception:
                continue
    if not brace_font:
        brace_font = ImageFont.load_default()

    text = "{ }"
    bbox = draw.textbbox((0, 0), text, font=brace_font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (size - tw) // 2 - bbox[0]
    ty = (size - th) // 2 - bbox[1] - int(size * 0.06)

    # 蓝色辉光（多层模糊效果）
    glow_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw_text = ImageDraw.Draw(glow_layer)
    for offset in range(6, 0, -1):
        alpha = int(15 * (7 - offset))
        for dx in range(-offset, offset + 1):
            for dy in range(-offset, offset + 1):
                if dx*dx + dy*dy <= offset*offset:
                    glow_draw_text.text(
                        (tx + dx, ty + dy), text,
                        fill=(59, 130, 246, alpha),
                        font=brace_font
                    )
    img = Image.alpha_composite(img, glow_layer)
    draw = ImageDraw.Draw(img)

    # 白色花括号主体
    # 先画一层薄阴影
    draw.text((tx + 1, ty + 2), text,
              fill=(0, 0, 0, 50), font=brace_font)
    # 主体
    draw.text((tx, ty), text,
              fill=(241, 245, 249, 245), font=brace_font)

    # === 5. 绘制 "Ok" 标签 ===
    ok_size = int(size * 0.13)
    try:
        ok_font = ImageFont.truetype('/System/Library/Fonts/SFCompact.ttf', ok_size)
    except Exception:
        ok_font = ImageFont.load_default()

    ok_text = "Ok"
    ok_bbox = draw.textbbox((0, 0), ok_text, font=ok_font)
    ok_tw = ok_bbox[2] - ok_bbox[0]
    ok_th = ok_bbox[3] - ok_bbox[1]
    ok_x = (size - ok_tw) // 2 - ok_bbox[0]
    ok_y = ty + th + int(size * 0.01)

    # "Ok" 用翡翠绿色
    draw.text((ok_x, ok_y), ok_text,
              fill=(*COLORS['ok_color'], 230), font=ok_font)

    # === 6. 边框微光 ===
    border_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border_layer)
    # 顶部边缘高光线
    for x in range(corner_radius, size - corner_radius):
        border_draw.point((x, 1), fill=(255, 255, 255, 20))
        border_draw.point((x, 2), fill=(255, 255, 255, 10))
    img = Image.alpha_composite(img, Image.composite(border_layer, Image.new('RGBA', (size, size), (0,0,0,0)), mask))

    return img


def main():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    icon_dir = os.path.join(project_root, 'OkJson', 'Resources', 'Assets.xcassets',
                            'AppIcon.appiconset')

    print("正在生成图标...")
    icon = create_icon(1024)

    # 收集需要的尺寸
    sizes = set()
    for f in os.listdir(icon_dir):
        if f.endswith('.png'):
            name = os.path.splitext(f)[0]
            try:
                sizes.add(int(name))
            except ValueError:
                pass

    sizes.update([16, 20, 29, 32, 40, 48, 50, 55, 57, 58, 60, 64, 66, 72, 76, 80, 87,
                  88, 92, 100, 102, 108, 114, 120, 128, 144, 152, 167, 172, 180, 196,
                  216, 234, 256, 258, 512, 1024])

    print(f"导出 {len(sizes)} 个尺寸...")

    for s in sorted(sizes):
        resized = icon.resize((s, s), Image.LANCZOS)
        path = os.path.join(icon_dir, f'{s}.png')
        resized.save(path, 'PNG')

    print("✅ 图标生成完成！")


if __name__ == '__main__':
    main()
