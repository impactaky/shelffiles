#!/bin/sh
# Script to generate environment file by checking and concatenating .env files for specific packages

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if we have the required arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <output_path> <package1> [package2] [package3] ..."
    echo "Example: $0 /tmp/env.sh npm starship claude"
    exit 1
fi

# Output file path
OUTPUT="$1"
shift

# Remaining arguments are package names
PACKAGES="$*"

# Create output directory if needed
mkdir -p "$(dirname "$OUTPUT")"

# Start with header
cat > "$OUTPUT" << 'EOF'
# Auto-generated environment setup

EOF

# Process each package
for package_name in $PACKAGES; do
    env_file="$SCRIPT_DIR/package_env/${package_name}.env"

    if [ -f "$env_file" ]; then
        {
            echo "# From ${package_name}.env"
            cat "$env_file"
            echo ""
        } >> "$OUTPUT"
    else
        {
            echo "# Package ${package_name}: no .env file found"
            echo ""
        } >> "$OUTPUT"
    fi
done

# Make executable
chmod +x "$OUTPUT"

echo "Generated $OUTPUT with environment for: $PACKAGES"
