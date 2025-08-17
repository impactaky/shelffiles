#!/bin/sh
# Script to generate environment file by checking and concatenating .env files for specific packages

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if we have the required arguments
if [ $# -ne 1 ]; then
    echo "Usage: echo \"package1 package2 ...\" | $0 <output_path>"
    echo "Example: echo \"npm starship claude\" | $0 /tmp/env.sh"
    exit 1
fi

# Output file path
OUTPUT="$1"

# Read package names from stdin
PACKAGES="$(cat)"

# Create output directory if needed
mkdir -p "$(dirname "$OUTPUT")"

# Start with header
cat > "$OUTPUT" << 'EOF'
# Auto-generated environment setup

EOF

# Process each package
for package_name in $PACKAGES; do
    generalized_pacakge_name="$(echo "$package_name" | sed -e "s/^nodejs_[0-9]\+$/nodejs/")"
    env_file="$SCRIPT_DIR/packages/${generalized_pacakge_name}.sh"

    if [ -f "$env_file" ]; then
        {
            echo "# Package ${package_name}"
            cat "$env_file"
            echo ""
        } >> "$OUTPUT"
    else
        {
            echo "# Package ${package_name}: no .sh file found"
            echo ""
        } >> "$OUTPUT"
    fi
done

# Make executable
chmod +x "$OUTPUT"

echo "Generated $OUTPUT with environment for:$(echo "$PACKAGES" | tr '\n' ' ')"
