#!/bin/bash

# Script to render containerlab configuration templates
# This script substitutes environment variables in template files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_msg "$RED" "Error: .env file not found!"
    print_msg "$YELLOW" "Creating .env from .env.example..."
    cp .env.example .env
    print_msg "$GREEN" "Created .env file. Please edit it with your configuration."
    exit 1
fi

# Load environment variables
print_msg "$YELLOW" "Loading environment variables from .env..."
export $(grep -v '^#' .env | xargs)

# Function to render a template
render_template() {
    local template_file=$1
    local output_file=$2

    if [ ! -f "$template_file" ]; then
        print_msg "$RED" "Template file not found: $template_file"
        return 1
    fi

    print_msg "$YELLOW" "Rendering: $template_file -> $output_file"

    # Use envsubst to replace environment variables
    envsubst < "$template_file" > "$output_file"

    if [ $? -eq 0 ]; then
        print_msg "$GREEN" "✓ Successfully rendered: $output_file"
    else
        print_msg "$RED" "✗ Failed to render: $output_file"
        return 1
    fi
}

# Main rendering process
print_msg "$GREEN" "Starting template rendering..."

# Render topology.yaml
render_template "topology.yaml.tpl" "topology.yaml"

# Render FRR configuration
render_template "configs/frr/core-router/frr.conf.tpl" "configs/frr/core-router/frr.conf"

# Check if daemons.tpl exists before rendering
if [ -f "configs/frr/core-router/daemons.tpl" ]; then
    render_template "configs/frr/core-router/daemons.tpl" "configs/frr/core-router/daemons"
fi

print_msg "$GREEN" "Template rendering complete!"

# Validate the rendered files
print_msg "$YELLOW" "Validating rendered files..."

# Check if topology.yaml is valid YAML
if command -v yq &> /dev/null; then
    if yq eval '.' topology.yaml > /dev/null 2>&1; then
        print_msg "$GREEN" "✓ topology.yaml is valid YAML"
    else
        print_msg "$RED" "✗ topology.yaml validation failed"
    fi
else
    print_msg "$YELLOW" "yq not installed, skipping YAML validation"
fi

# Check if required files exist
required_files=(
    "topology.yaml"
    "configs/frr/core-router/frr.conf"
    "configs/frr/core-router/daemons"
)

all_files_exist=true
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_msg "$GREEN" "✓ $file exists"
    else
        print_msg "$RED" "✗ $file missing"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = true ]; then
    print_msg "$GREEN" "All required files are ready!"
    print_msg "$YELLOW" "You can now run: sudo containerlab deploy -t topology.yaml"
else
    print_msg "$RED" "Some required files are missing. Please check the output above."
    exit 1
fi
