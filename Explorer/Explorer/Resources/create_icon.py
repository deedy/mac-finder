#!/usr/bin/env python3
import os
import subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Create directories
resources_dir = os.path.dirname(os.path.abspath(__file__))
app_dir = os.path.join(resources_dir, "../../Explorer.app")
iconset_dir = os.path.join(resources_dir, "AppIcon.iconset")
icns_file = os.path.join(resources_dir, "AppIcon.icns")

os.makedirs(iconset_dir, exist_ok=True)

# Create the icon
def create_icon(size=1024):
    # Create a new RGBA image with a transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Background rounded rectangle (blue gradient simulated)
    margin = int(size * 0.11)
    rect_size = size - 2 * margin
    radius = int(size * 0.22)
    
    # Draw blue background rounded rectangle
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius,
        fill=(26, 128, 229, 255)  # Bright blue
    )
    
    # Folder body (translucent white)
    folder_width = int(size * 0.7)
    folder_height = int(size * 0.4)
    folder_left = int((size - folder_width) / 2)
    folder_top = int(size * 0.45)
    folder_radius = int(size * 0.05)
    
    draw.rounded_rectangle(
        [folder_left, folder_top, folder_left + folder_width, folder_top + folder_height],
        folder_radius,
        fill=(255, 255, 255, 51)  # Semi-transparent white
    )
    
    # Folder tab
    tab_width = int(size * 0.25)
    tab_height = int(size * 0.06)
    tab_left = folder_left
    tab_top = folder_top - tab_height - int(size * 0.05)
    tab_radius = int(size * 0.02)
    
    draw.rounded_rectangle(
        [tab_left, tab_top, tab_left + tab_width, tab_top + tab_height],
        tab_radius,
        fill=(255, 255, 255, 51)  # Semi-transparent white
    )
    
    # Speed lines
    line_width = int(size * 0.4)
    line_height = int(size * 0.025)
    line_radius = int(size * 0.01)
    
    # Create a new image for rotated lines
    lines_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    lines_draw = ImageDraw.Draw(lines_img)
    
    # Draw three lines with spacing
    for i in range(3):
        y_pos = int(size * 0.4 + i * size * 0.1)
        lines_draw.rounded_rectangle(
            [int(size * 0.4), y_pos, int(size * 0.4) + line_width, y_pos + line_height],
            line_radius,
            fill=(255, 255, 255, 204)  # Semi-opaque white
        )
    
    # Rotate lines slightly
    lines_img = lines_img.rotate(-10, resample=Image.BICUBIC, expand=False, center=(size/2, size/2))
    
    # Paste rotated lines onto the main image
    img.paste(lines_img, (0, 0), lines_img)
    
    # Add a subtle shadow
    shadow = img.copy()
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=int(size * 0.02)))
    shadow_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow_img.paste((0, 0, 0, 76), (int(size * 0.02), int(size * 0.02)), shadow)
    
    # Create the final image with shadow
    final_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    final_img.paste(shadow_img, (0, 0), shadow_img)
    final_img.paste(img, (0, 0), img)
    
    return final_img

# Create base icon at 1024x1024
icon = create_icon(1024)
temp_icon_path = os.path.join(resources_dir, "temp_icon.png")
icon.save(temp_icon_path)

# Create all required icon sizes
sizes = [16, 32, 128, 256, 512]
for size in sizes:
    # 1x version
    resized_icon = icon.resize((size, size), Image.LANCZOS)
    resized_icon.save(os.path.join(iconset_dir, f"icon_{size}x{size}.png"))
    
    # 2x version (except for 1024 which would be too large)
    if size < 512:
        resized_icon = icon.resize((size*2, size*2), Image.LANCZOS)
        resized_icon.save(os.path.join(iconset_dir, f"icon_{size}x{size}@2x.png"))
    else:
        # For 512@2x, use the original 1024 image
        icon.save(os.path.join(iconset_dir, f"icon_{size}x{size}@2x.png"))

# Create icns file using iconutil
try:
    subprocess.run(['iconutil', '-c', 'icns', iconset_dir], check=True)
    print(f"Created {icns_file}")
    
    # Copy to app bundle
    app_resources = os.path.join(app_dir, "Contents/Resources")
    if os.path.exists(app_resources):
        subprocess.run(['cp', icns_file, os.path.join(app_resources, "AppIcon.icns")], check=True)
        print(f"Copied AppIcon.icns to {app_resources}")
        
        # Update Info.plist to use the icon
        info_plist = os.path.join(app_dir, "Contents/Info.plist")
        if os.path.exists(info_plist):
            with open(info_plist, 'r') as f:
                content = f.read()
            
            if 'CFBundleIconFile' not in content:
                # Add icon entry if it doesn't exist
                new_content = content.replace('</dict>', '    <key>CFBundleIconFile</key>\n    <string>AppIcon</string>\n</dict>')
                with open(info_plist, 'w') as f:
                    f.write(new_content)
                print("Updated Info.plist to use the icon")
    
except Exception as e:
    print(f"Error creating or installing icon: {e}")

# Clean up
try:
    os.remove(temp_icon_path)
except:
    pass

print("Icon creation complete!")