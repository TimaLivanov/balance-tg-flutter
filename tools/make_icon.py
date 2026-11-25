#!/usr/bin/env python3
"""Генератор иконки BitBalance: растущий график в форме горы.

Только стандартная библиотека Python — PNG собирается вручную.
"""
import math
import struct
import zlib
from pathlib import Path

SIZE = 512
SS = 2  # суперсэмплинг для сглаживания
N = SIZE * SS


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(lerp(c1[i], c2[i], t) for i in range(3))


def clamp(c):
    return tuple(max(0, min(255, int(round(v)))) for v in c)


# Вершина маршрута: ascending mountain-like chart
PEAKS = [
    (0.12, 0.74),
    (0.28, 0.62),
    (0.40, 0.67),
    (0.57, 0.40),
    (0.72, 0.49),
    (0.88, 0.20),
]
BASE = 0.90


def line_y(nx):
    for (x1, y1), (x2, y2) in zip(PEAKS, PEAKS[1:]):
        if x1 <= nx <= x2:
            t = (nx - x1) / (x2 - x1)
            return lerp(y1, y2, t)
    return PEAKS[-1][1]


def dist_to_segment(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    if l2 == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def render():
    buf = bytearray()
    summit_x, summit_y = PEAKS[-1][0] * N, PEAKS[-1][1] * N
    for y in range(N):
        row = bytearray()
        ny = y / N
        for x in range(N):
            nx = x / N
            # Фон: тёмный синий -> индиго
            color = mix((9, 17, 36), (30, 58, 138), ny)
            # Мягкое свечение у вершины
            glow = math.hypot(x - summit_x, y - summit_y) / (N * 0.42)
            if glow < 1:
                color = mix(color, (34, 211, 238), (1 - glow) ** 3 * 0.28)

            # Зема под графиком
            py = line_y(nx) * N
            if py <= y <= BASE * N:
                depth = (y - py) / max(1.0, (BASE * N - py))
                fill = mix((16, 185, 129), (8, 45, 75), depth)
                color = mix(color, fill, 0.72 - depth * 0.35)

            # Свечи у основания
            for i, cx in enumerate((0.18, 0.32, 0.46, 0.60, 0.74)):
                dx = abs(nx - cx) * N
                if dx < 4:
                    top = (0.79 - (i % 3) * 0.035) * N
                    bottom = (0.86 - (i % 2) * 0.02) * N
                    if top <= y <= bottom:
                        color = mix(color, (125, 249, 187), 0.55)
                if dx < 1.5 and (0.755 - (i % 3) * 0.035) * N <= y <= (0.88 - (i % 2) * 0.02) * N:
                    color = mix(color, (167, 243, 208), 0.45)

            # Линия графика (толстая, с подсветкой)
            d = min(
                dist_to_segment(
                    x, y,
                    a[0] * N, a[1] * N,
                    b[0] * N, b[1] * N,
                )
                for a, b in zip(PEAKS, PEAKS[1:])
            )
            if d < 16:
                color = mix(color, (34, 211, 238), (1 - d / 16) * 0.35)
            if d < 9:
                color = mix(color, (110, 255, 190), (1 - d / 9) * 0.95)

            # Солнце на вершине
            sd = math.hypot(x - summit_x, y - summit_y)
            if sd < 60:
                color = mix(color, (167, 243, 208), (1 - sd / 60) ** 2 * 0.35)
            if sd < 24:
                color = mix(color, (236, 255, 245), (1 - sd / 24) * 0.95)

            row.extend(clamp(color))
            row.append(255)
        buf.append(0)
        buf.extend(row)
    return bytes(buf)


def downsample(src):
    out = bytearray()
    for y in range(SIZE):
        out.append(0)
        for x in range(SIZE):
            acc = [0, 0, 0]
            for dy in range(SS):
                for dx in range(SS):
                    sy = y * SS + dy
                    sx = x * SS + dx
                    idx = sy * (N * 4 + 1) + 1 + sx * 4
                    for k in range(3):
                        acc[k] += src[idx + k]
            out.extend(int(v / (SS * SS)) for v in acc)
    return bytes(out)


def png_chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def write_png(path, raw, size):
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n"
    data += png_chunk(b"IHDR", ihdr)
    data += png_chunk(b"IDAT", zlib.compress(raw, 9))
    data += png_chunk(b"IEND", b"")
    Path(path).write_bytes(data)


def main():
    supersampled = render()
    raw = downsample(supersampled)
    root = Path(__file__).resolve().parent.parent
    web = root / "web"
    icons = web / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    def shrink(size):
        small = bytearray()
        for y in range(size):
            small.append(0)
            for x in range(size):
                sx = x * SIZE // size
                sy = y * SIZE // size
                idx = sy * (SIZE * 4 + 1) + 1 + sx * 4
                small.extend(raw[idx:idx + 4])
        return bytes(small)

    # Имена совпадают с манифестом Flutter Web и apple-touch-icon.
    write_png(icons / "Icon-512.png", raw, SIZE)
    write_png(icons / "Icon-192.png", shrink(192), 192)
    write_png(icons / "Icon-maskable-512.png", raw, SIZE)
    write_png(icons / "Icon-maskable-192.png", shrink(192), 192)
    write_png(web / "favicon.png", shrink(64), 64)
    print("Готово: Icon-512/192.png, Icon-maskable-512/192.png, favicon.png")


if __name__ == "__main__":
    main()
