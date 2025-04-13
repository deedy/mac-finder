#!/bin/bash

# This script creates a simple app icon for Explorer

RESOURCES_DIR=$(dirname "$0")
APP_DIR="$RESOURCES_DIR/../../Explorer.app"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
ICNS_FILE="$RESOURCES_DIR/AppIcon.icns"

# Create the iconset directory
mkdir -p "$ICONSET_DIR"

# Create a temporary PNG icon - a simple blue square
convert -size 1024x1024 xc:none \
    -fill "gradient:blue-darkblue" \
    -draw "roundrectangle 112,112,912,912,224,224" \
    -fill "white" -opacity 0.2 \
    -draw "roundrectangle 192,448,832,832,48,48" \
    -draw "roundrectangle 192,320,448,384,24,24" \
    -fill "white" -opacity 0.8 \
    -draw "rotate -10 512,512 rectangle 460,380,820,404" \
    -draw "rotate -10 512,512 rectangle 460,480,820,504" \
    -draw "rotate -10 512,512 rectangle 460,580,820,604" \
    "$RESOURCES_DIR/temp_icon.png"

# Create iconset files with sips
sips -z 16 16 "$RESOURCES_DIR/temp_icon.png" --out "${ICONSET_DIR}/icon_16x16.png"
sips -z 32 32 "$RESOURCES_DIR/temp_icon.png" --out "${ICONSET_DIR}/icon_16x16@2x.png"
sips -z 32 32 "$RESOURCES_DIR/temp_icon.png" --out "${ICONSET_DIR}/icon_32x32.png"
sips -z 64 64 "$RESOURCES_DIR/temp_icon.png" --out "${ICONSET_DIR}/icon_32x32@2x.png"
sips -z 128 128 "$RESOURCES_DIR/temp_icon.png" --out "${ICONSET_DIR}/icon_128x128.png"
sips -z 256 256 "$RESOURCES_DIR/temp_icon.png" --out "${ICONSET_DIR}/icon_128x128@2x.png"
sips -z 256 256 "$RESOURCES_DIR/temp_icon.png" --out "${ICONSET_DIR}/icon_256x256.png"
sips -z 512 512 "$RESOURCES_DIR/temp_icon.png" --out "${ICONSET_DIR}/icon_256x256@2x.png"
sips -z 512 512 "$RESOURCES_DIR/temp_icon.png" --out "${ICONSET_DIR}/icon_512x512.png"
sips -z 1024 1024 "$RESOURCES_DIR/temp_icon.png" --out "${ICONSET_DIR}/icon_512x512@2x.png"

# Create icns file
iconutil -c icns "$ICONSET_DIR"

# Copy to app bundle
cp "$ICNS_FILE" "$APP_DIR/Contents/Resources/"

# Clean up temporary files
rm "$RESOURCES_DIR/temp_icon.png"

echo "Icon created and installed to the app bundle!"