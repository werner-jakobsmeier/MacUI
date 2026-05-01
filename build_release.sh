#!/bin/sh
# MacUI Release Build Script
# Creates a clean addon folder in the parent release directory.

TARGET="../release/MacUI"

echo "Building MacUI release in $TARGET..."

# Ensure the target directory exists
mkdir -p "$TARGET"

# Remove any existing files in the target folder to ensure a clean build
rm -rf "$TARGET"
mkdir -p "$TARGET"

# Copy only WoW-specific files (No hidden files, no previews, no dotfiles)
cp MacUI.toc *.lua MinimapIcon.tga LICENSE README.md "$TARGET/"

echo "Success: Clean release folder created at $TARGET"
