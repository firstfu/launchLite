#!/usr/bin/env python3
"""
LaunchLite App Icon Generator — Refined Edition
Design Philosophy: Luminous Ascent
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import random


SIZE = 1024
CENTER = SIZE // 2


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(len(c1)))


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def create_superellipse_mask(size, n=5):
    """True superellipse (squircle) mask for macOS icon shape."""
    mask = Image.new("L", (size, size), 0)
    pixels = mask.load()
    half = size / 2.0
    r = half * 0.92

    for y in range(size):
        for x in range(size):
            nx = abs((x - half) / r)
            ny = abs((y - half) / r)
            if nx == 0 and ny == 0:
                pixels[x, y] = 255
                continue
            try:
                val = nx**n + ny**n
                if val <= 1.0:
                    edge_dist = 1.0 - val
                    if edge_dist < 0.04:
                        pixels[x, y] = int(255 * (edge_dist / 0.04))
                    else:
                        pixels[x, y] = 255
            except (OverflowError, ValueError):
                pass
    return mask


def draw_radial_gradient(img, center, radius, color_inner, color_outer):
    """Efficient radial gradient on RGBA image."""
    px = img.load()
    cx, cy = center
    r_sq = radius * radius
    # Only iterate within bounding box
    x0 = max(0, int(cx - radius))
    x1 = min(img.width, int(cx + radius) + 1)
    y0 = max(0, int(cy - radius))
    y1 = min(img.height, int(cy + radius) + 1)

    for y in range(y0, y1):
        dy_sq = (y - cy) ** 2
        for x in range(x0, x1):
            dist_sq = (x - cx) ** 2 + dy_sq
            if dist_sq > r_sq:
                continue
            t = smoothstep(math.sqrt(dist_sq) / radius)
            color = lerp_color(color_inner, color_outer, t)
            # Alpha composite manually
            existing = px[x, y]
            new_a = color[3]
            if new_a == 0:
                continue
            if existing[3] == 0:
                px[x, y] = color
            else:
                # Simple over compositing
                a_out = new_a + existing[3] * (255 - new_a) // 255
                if a_out == 0:
                    continue
                r = (color[0] * new_a + existing[0] * existing[3] * (255 - new_a) // 255) // a_out
                g = (color[1] * new_a + existing[1] * existing[3] * (255 - new_a) // 255) // a_out
                b = (color[2] * new_a + existing[2] * existing[3] * (255 - new_a) // 255) // a_out
                px[x, y] = (min(255, r), min(255, g), min(255, b), min(255, a_out))


def generate_icon():
    # === COLOR PALETTE ===
    bg_top = hex_to_rgb("#080F1E")
    bg_mid = hex_to_rgb("#0C1D3A")
    bg_bottom = hex_to_rgb("#102A50")

    teal_bright = hex_to_rgb("#5EEADF")
    teal_main = hex_to_rgb("#3DC8C0")
    teal_deep = hex_to_rgb("#1A7E8C")
    sapphire = hex_to_rgb("#145A80")
    navy_deep = hex_to_rgb("#0A2844")

    amber = hex_to_rgb("#F5A623")
    amber_hot = hex_to_rgb("#FFCC44")
    warm_orange = hex_to_rgb("#E8853D")

    # === BASE CANVAS WITH GRADIENT ===
    base = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    base_px = base.load()
    for y in range(SIZE):
        t = y / SIZE
        if t < 0.5:
            t2 = t / 0.5
            color = lerp_color(bg_top, bg_mid, smoothstep(t2))
        else:
            t2 = (t - 0.5) / 0.5
            color = lerp_color(bg_mid, bg_bottom, smoothstep(t2))
        for x in range(SIZE):
            base_px[x, y] = (*color, 255)

    # === STAR FIELD ===
    random.seed(42)
    stars_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    stars_draw = ImageDraw.Draw(stars_layer)
    for _ in range(120):
        sx = random.randint(50, SIZE - 50)
        sy = random.randint(30, int(SIZE * 0.55))
        brightness = random.randint(30, 140)
        sz = random.choice([1, 1, 1, 1, 2])
        stars_draw.ellipse(
            [sx - sz, sy - sz, sx + sz, sy + sz],
            fill=(210, 225, 255, brightness),
        )
    # A few brighter stars
    for _ in range(12):
        sx = random.randint(80, SIZE - 80)
        sy = random.randint(50, int(SIZE * 0.45))
        stars_draw.ellipse([sx - 2, sy - 2, sx + 2, sy + 2], fill=(240, 248, 255, 100))
        # Tiny cross flare
        stars_draw.line([(sx - 4, sy), (sx + 4, sy)], fill=(240, 248, 255, 50), width=1)
        stars_draw.line([(sx, sy - 4), (sx, sy + 4)], fill=(240, 248, 255, 50), width=1)

    base = Image.alpha_composite(base, stars_layer)

    # === AMBIENT ATMOSPHERE GLOW ===
    atmo = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_radial_gradient(
        atmo, (CENTER, int(SIZE * 0.78)), int(SIZE * 0.55),
        (40, 140, 160, 20), (0, 0, 0, 0)
    )
    base = Image.alpha_composite(base, atmo)

    # === CONCENTRIC ORBIT RINGS ===
    rings = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rings_draw = ImageDraw.Draw(rings)
    rcx, rcy = CENTER, int(SIZE * 0.53)
    for i in range(5):
        rx = 140 + i * 65
        ry = 35 + i * 16
        alpha = max(6, 28 - i * 5)
        c = lerp_color(teal_main, sapphire, i / 4.0)
        for t_offset in range(2):
            rings_draw.ellipse(
                [rcx - rx, rcy - ry - t_offset, rcx + rx, rcy + ry - t_offset],
                outline=(*c, alpha), width=1
            )
    base = Image.alpha_composite(base, rings)

    # === MAIN CHEVRON FORM ===
    apex_x = CENTER
    apex_y = int(SIZE * 0.12)
    wing_y = int(SIZE * 0.60)
    notch_y = int(SIZE * 0.37)

    chevron_outer = [
        (apex_x, apex_y),
        (apex_x + 235, wing_y),
        (apex_x + 140, wing_y),
        (apex_x, notch_y),
        (apex_x - 140, wing_y),
        (apex_x - 235, wing_y),
    ]

    # Draw gradient-filled chevron using mask technique
    chev_mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(chev_mask).polygon(chevron_outer, fill=255)

    # Create a gradient image for the chevron
    chev_grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    chev_px = chev_grad.load()
    for y in range(apex_y, wing_y + 1):
        t = (y - apex_y) / (wing_y - apex_y)
        # Top: bright teal -> Mid: rich teal -> Bottom: deep sapphire
        if t < 0.3:
            c = lerp_color(teal_bright, teal_main, t / 0.3)
            a = 240
        elif t < 0.7:
            c = lerp_color(teal_main, teal_deep, (t - 0.3) / 0.4)
            a = 230
        else:
            c = lerp_color(teal_deep, sapphire, (t - 0.7) / 0.3)
            a = 220
        for x in range(SIZE):
            chev_px[x, y] = (*c, a)

    # Apply chevron mask
    chev_grad.putalpha(Image.composite(
        chev_grad.split()[3], Image.new("L", (SIZE, SIZE), 0), chev_mask
    ))
    base = Image.alpha_composite(base, chev_grad)

    # === CHEVRON EDGE HIGHLIGHTS ===
    edge_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    edge_draw = ImageDraw.Draw(edge_layer)

    # Left edge highlight
    left_edge = [
        (apex_x, apex_y),
        (apex_x - 235, wing_y),
        (apex_x - 230, wing_y),
        (apex_x + 3, apex_y + 8),
    ]
    edge_draw.polygon(left_edge, fill=(*teal_bright, 40))

    # Right subtle shadow
    right_shadow = [
        (apex_x + 3, apex_y + 8),
        (apex_x + 235, wing_y),
        (apex_x + 230, wing_y),
        (apex_x, apex_y),
    ]
    edge_draw.polygon(right_shadow, fill=(0, 20, 40, 30))

    base = Image.alpha_composite(base, edge_layer)

    # === INNER CHEVRON DIVIDER LINE ===
    div = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    div_draw = ImageDraw.Draw(div)
    # Thin bright line from apex down center
    for y in range(apex_y + 15, notch_y - 5):
        t = (y - apex_y - 15) / (notch_y - 5 - apex_y - 15)
        alpha = int(100 * (1 - t * 0.5))
        w = max(1, int(2 * (1 - t * 0.3)))
        div_draw.line([(CENTER - w, y), (CENTER + w, y)], fill=(220, 255, 252, alpha))
    base = Image.alpha_composite(base, div)

    # === APEX GLOW ===
    apex_g = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_radial_gradient(
        apex_g, (apex_x, apex_y + 25), 90,
        (220, 255, 250, 90), (0, 0, 0, 0)
    )
    base = Image.alpha_composite(base, apex_g)

    # === LAUNCH TRAIL ===
    trail = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    trail_draw = ImageDraw.Draw(trail)

    trail_top = notch_y
    trail_bottom = int(SIZE * 0.90)

    # Central bright core trail
    for y in range(trail_top, trail_bottom):
        t = (y - trail_top) / (trail_bottom - trail_top)
        # Core: hot amber -> fading orange
        core_alpha = int(220 * (1 - t) ** 1.8)
        core_width = max(1, int(10 * (1 - t) ** 0.8))
        c = lerp_color((*amber_hot,), (*warm_orange,), min(1, t * 1.5))
        trail_draw.line(
            [(CENTER - core_width, y), (CENTER + core_width, y)],
            fill=(*c, core_alpha)
        )

    # Outer glow trails (wider, softer)
    for y in range(trail_top, trail_bottom):
        t = (y - trail_top) / (trail_bottom - trail_top)
        glow_alpha = int(60 * (1 - t) ** 2)
        glow_width = int(25 * (1 - t * 0.5))
        c = lerp_color((*amber,), (*warm_orange,), t)
        if glow_alpha > 2:
            trail_draw.line(
                [(CENTER - glow_width, y), (CENTER + glow_width, y)],
                fill=(*c, glow_alpha)
            )

    # Side diverging streaks
    random.seed(77)
    for streak_i in range(7):
        angle = (streak_i - 3) * 0.08
        for y in range(trail_top + 10, trail_bottom - 40):
            t = (y - trail_top - 10) / (trail_bottom - 40 - trail_top - 10)
            x_off = int(angle * (y - trail_top) * 1.5)
            alpha = int(50 * (1 - t) ** 2 * (1 - abs(streak_i - 3) / 3.5))
            x = CENTER + x_off
            if 0 <= x < SIZE and alpha > 1:
                trail_draw.point((x, y), fill=(*amber, alpha))
                if alpha > 10:
                    trail_draw.point((x + 1, y), fill=(*amber, alpha // 2))

    base = Image.alpha_composite(base, trail)

    # === IGNITION POINT GLOW ===
    ign = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_radial_gradient(
        ign, (CENTER, trail_top + 5), 80,
        (255, 200, 80, 130), (0, 0, 0, 0)
    )
    draw_radial_gradient(
        ign, (CENTER, trail_top + 5), 40,
        (255, 240, 200, 80), (0, 0, 0, 0)
    )
    base = Image.alpha_composite(base, ign)

    # === LUMINOUS PARTICLES ===
    particles = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    particles_draw = ImageDraw.Draw(particles)
    random.seed(123)
    for _ in range(40):
        px = CENTER + random.randint(-200, 200)
        py = random.randint(int(SIZE * 0.13), int(SIZE * 0.78))
        ps = random.choice([1, 2, 2, 3])
        dist = abs(px - CENTER) / 200.0
        alpha = int(max(20, 100 * (1 - dist)))
        ct = random.random()
        pc = lerp_color((*teal_bright,), (*amber,), ct)
        particles_draw.ellipse(
            [px - ps, py - ps, px + ps, py + ps], fill=(*pc, alpha)
        )
    base = Image.alpha_composite(base, particles)

    # === VIGNETTE ===
    vig = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    vig_px = vig.load()
    for y in range(SIZE):
        dy = (y - CENTER) / CENTER
        for x in range(SIZE):
            dx = (x - CENTER) / CENTER
            d = math.sqrt(dx * dx + dy * dy)
            if d > 0.65:
                a = int(min(90, (d - 0.65) / 0.35 * 90))
                vig_px[x, y] = (0, 0, 8, a)
    base = Image.alpha_composite(base, vig)

    # === APPLY MACOS SQUIRCLE MASK ===
    mask = create_superellipse_mask(SIZE, n=5)
    final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    final.paste(base, (0, 0), mask)

    # === SUBTLE INNER GLOW BORDER ===
    # Create a slightly smaller mask to find the edge
    inner_mask = create_superellipse_mask(SIZE, n=5)
    # Erode by 2px
    eroded = inner_mask.copy()
    eroded_px = eroded.load()
    mask_px = inner_mask.load()
    border = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    border_px = border.load()

    for y in range(2, SIZE - 2):
        for x in range(2, SIZE - 2):
            val = mask_px[x, y]
            if val > 128:
                is_near_edge = False
                for dy in [-3, -2, -1, 0, 1, 2, 3]:
                    for dx in [-3, -2, -1, 0, 1, 2, 3]:
                        ny, nx = y + dy, x + dx
                        if 0 <= nx < SIZE and 0 <= ny < SIZE:
                            if mask_px[nx, ny] < 100:
                                is_near_edge = True
                                break
                    if is_near_edge:
                        break
                if is_near_edge:
                    t_y = y / SIZE
                    if t_y < 0.4:
                        border_px[x, y] = (200, 230, 255, 25)
                    else:
                        border_px[x, y] = (0, 0, 0, 20)

    final = Image.alpha_composite(final, border)

    return final


def main():
    print("Generating LaunchLite icon (refined)...")
    icon = generate_icon()

    output = "/Users/firstfu/Desktop/launchlite/LaunchLite_Icon_1024.png"
    icon.save(output, "PNG", optimize=True)
    print(f"1024x1024 saved: {output}")

    for s in [512, 256, 128]:
        resized = icon.resize((s, s), Image.LANCZOS)
        p = f"/Users/firstfu/Desktop/launchlite/LaunchLite_Icon_{s}.png"
        resized.save(p, "PNG", optimize=True)
        print(f"  {s}x{s} saved: {p}")


if __name__ == "__main__":
    main()
