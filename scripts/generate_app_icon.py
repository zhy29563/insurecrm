#!/usr/bin/env python3
"""Generate app icon images from a shield design matching the splash page."""

from PIL import Image, ImageDraw
import os

sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}

output_dir = '/home/u2x/Documents/com.weapon.insurer/assets/app_icon'
os.makedirs(output_dir, exist_ok=True)

def create_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background rounded rectangle (blue #1565C0)
    padding = size // 8
    corner_radius = size // 5
    draw.rounded_rectangle(
        [padding, padding, size - padding, size - padding],
        radius=corner_radius,
        fill=(21, 101, 192, 255)
    )

    # Shield shape (white) centered
    center = size // 2
    s = size / 32  # scale factor

    shield_points = [
        (center - 6*s, center - 8*s),
        (center + 6*s, center - 8*s),
        (center + 8*s, center - 5*s),
        (center + 8*s, center + 1*s),
        (center, center + 9*s),
        (center - 8*s, center + 1*s),
        (center - 8*s, center - 5*s),
    ]
    draw.polygon(shield_points, fill='white')

    return img

# Generate density-specific icons
for density, size in sizes.items():
    img = create_icon(size)
    filepath = os.path.join(output_dir, f'icon_{density}.png')
    img.save(filepath)
    print(f'Created {filepath} ({size}x{size})')

# Generate 1024x1024 master icon
img = create_icon(1024)
filepath = os.path.join(output_dir, 'icon.png')
img.save(filepath)
print(f'Created {filepath} (1024x1024)')

print('Done!')
