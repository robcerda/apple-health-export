#!/usr/bin/env python3
"""
Generate app icons for iOS app store submission.
Creates simple placeholder icons with health theme.
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_icon(size, output_path):
    """Create a simple health-themed icon."""
    # Create a square image with health-themed colors
    img = Image.new('RGB', (size, size), color='#2E8B57')  # Sea green background
    draw = ImageDraw.Draw(img)
    
    # Draw a simple cross (medical symbol)
    cross_width = size // 8
    cross_height = size // 2
    
    # Vertical bar of cross
    left = (size - cross_width) // 2
    top = (size - cross_height) // 2
    right = left + cross_width
    bottom = top + cross_height
    draw.rectangle([left, top, right, bottom], fill='white')
    
    # Horizontal bar of cross
    cross_width_h = size // 2
    cross_height_h = size // 8
    left_h = (size - cross_width_h) // 2
    top_h = (size - cross_height_h) // 2
    right_h = left_h + cross_width_h
    bottom_h = top_h + cross_height_h
    draw.rectangle([left_h, top_h, right_h, bottom_h], fill='white')
    
    # Add a border
    border_width = max(1, size // 40)
    draw.rectangle([0, 0, size-1, size-1], outline='#1F5F3F', width=border_width)
    
    # Save the image
    img.save(output_path, 'PNG')
    print(f"Created {size}x{size} icon: {output_path}")

def main():
    """Generate all required icon sizes."""
    icon_dir = "/Users/rob/Scripts/Personal/apple-health-export/HealthExporter/Assets.xcassets/AppIcon.appiconset"
    
    # Required icon sizes for iOS App Store
    icon_sizes = [
        (40, "icon_20pt@2x.png"),      # 20pt@2x
        (60, "icon_20pt@3x.png"),      # 20pt@3x
        (58, "icon_29pt@2x.png"),      # 29pt@2x
        (87, "icon_29pt@3x.png"),      # 29pt@3x
        (80, "icon_40pt@2x.png"),      # 40pt@2x
        (120, "icon_40pt@3x.png"),     # 40pt@3x
        (120, "icon_60pt@2x.png"),     # 60pt@2x (iPhone app icon)
        (180, "icon_60pt@3x.png"),     # 60pt@3x (iPhone app icon)
        (20, "icon_20pt.png"),         # 20pt iPad
        (40, "icon_20pt@2x_ipad.png"), # 20pt@2x iPad
        (29, "icon_29pt.png"),         # 29pt iPad
        (58, "icon_29pt@2x_ipad.png"), # 29pt@2x iPad
        (40, "icon_40pt.png"),         # 40pt iPad
        (80, "icon_40pt@2x_ipad.png"), # 40pt@2x iPad
        (152, "icon_76pt@2x.png"),     # 76pt@2x iPad
        (167, "icon_83.5pt@2x.png"),   # 83.5pt@2x iPad Pro
        (1024, "icon_1024pt.png"),     # App Store
    ]
    
    for size, filename in icon_sizes:
        output_path = os.path.join(icon_dir, filename)
        create_icon(size, output_path)
    
    print(f"\n✅ Generated {len(icon_sizes)} icon files in {icon_dir}")
    print("📱 Icons ready for App Store submission!")

if __name__ == "__main__":
    main()