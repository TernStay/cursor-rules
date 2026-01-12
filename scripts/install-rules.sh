#!/bin/bash
# =============================================================================
# TurnStay Cursor Rules Installer
# =============================================================================
# Usage:
#   ./install-rules.sh python     # Install Python/FastAPI rules
#   ./install-rules.sh nextjs     # Install Next.js rules
#   ./install-rules.sh python --update  # Update existing rules
# =============================================================================

set -e

# Configuration
REPO_URL="https://github.com/TernStay/cursor-rules"
RAW_URL="https://raw.githubusercontent.com/TernStay/cursor-rules/main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           TurnStay Cursor Rules Installer                     ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}→ $1${NC}"
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        print_error "Not inside a git repository. Please run from your project root."
        exit 1
    fi
}

# Get the project root
get_project_root() {
    git rev-parse --show-toplevel
}

# Install rules from GitHub
install_from_github() {
    local rule_type=$1
    local project_root=$(get_project_root)
    local temp_dir=$(mktemp -d)
    
    print_info "Downloading ${rule_type} rules from GitHub..."
    
    # Clone the repo (shallow)
    git clone --depth 1 --quiet "$REPO_URL" "$temp_dir"
    
    if [ ! -d "$temp_dir/$rule_type" ]; then
        print_error "Rule type '$rule_type' not found in repository."
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Create .cursor/rules directory
    mkdir -p "$project_root/.cursor/rules"
    
    # Copy rules
    print_info "Installing rules to $project_root/.cursor/rules/"
    cp -r "$temp_dir/$rule_type/rules/"* "$project_root/.cursor/rules/"
    
    # Copy AGENTS.md if it exists
    if [ -f "$temp_dir/$rule_type/AGENTS.md" ]; then
        print_info "Installing AGENTS.md to project root..."
        cp "$temp_dir/$rule_type/AGENTS.md" "$project_root/AGENTS.md"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    print_success "Rules installed successfully!"
}

# Install rules from local cursor-rules repo
install_from_local() {
    local rule_type=$1
    local project_root=$(get_project_root)
    
    # Try common locations for the cursor-rules repo
    local possible_paths=(
        "$HOME/cursor-rules"
        "$HOME/TurnStay/src/cursor-rules"
        "../cursor-rules"
        "../../cursor-rules"
    )
    
    local rules_repo=""
    for path in "${possible_paths[@]}"; do
        if [ -d "$path/$rule_type" ]; then
            rules_repo="$path"
            break
        fi
    done
    
    if [ -z "$rules_repo" ]; then
        print_warning "Local cursor-rules repo not found, downloading from GitHub..."
        install_from_github "$rule_type"
        return
    fi
    
    print_info "Using local rules from: $rules_repo"
    
    # Create .cursor/rules directory
    mkdir -p "$project_root/.cursor/rules"
    
    # Copy rules
    print_info "Installing rules to $project_root/.cursor/rules/"
    cp -r "$rules_repo/$rule_type/rules/"* "$project_root/.cursor/rules/"
    
    # Copy AGENTS.md if it exists
    if [ -f "$rules_repo/$rule_type/AGENTS.md" ]; then
        print_info "Installing AGENTS.md to project root..."
        cp "$rules_repo/$rule_type/AGENTS.md" "$project_root/AGENTS.md"
    fi
    
    print_success "Rules installed successfully!"
}

# Show what was installed
show_installed_rules() {
    local project_root=$(get_project_root)
    
    echo ""
    print_info "Installed rules:"
    if [ -d "$project_root/.cursor/rules" ]; then
        for rule_dir in "$project_root/.cursor/rules"/*/; do
            if [ -d "$rule_dir" ]; then
                local rule_name=$(basename "$rule_dir")
                echo "  • $rule_name"
            fi
        done
    fi
    
    if [ -f "$project_root/AGENTS.md" ]; then
        echo "  • AGENTS.md (root)"
    fi
    echo ""
}

# Main
main() {
    print_header
    
    # Check arguments
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <python|nextjs> [--update] [--local]"
        echo ""
        echo "Options:"
        echo "  python   Install Python/FastAPI rules"
        echo "  nextjs   Install Next.js rules"
        echo "  --update Force update existing rules"
        echo "  --local  Use local repo instead of GitHub"
        exit 1
    fi
    
    local rule_type=$1
    local use_local=false
    local force_update=false
    
    # Parse additional arguments
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --local)
                use_local=true
                ;;
            --update)
                force_update=true
                ;;
        esac
        shift
    done
    
    # Validate rule type
    if [[ "$rule_type" != "python" && "$rule_type" != "nextjs" ]]; then
        print_error "Invalid rule type: $rule_type"
        echo "Valid types: python, nextjs"
        exit 1
    fi
    
    # Check we're in a git repo
    check_git_repo
    
    local project_root=$(get_project_root)
    
    # Check if rules already exist
    if [ -d "$project_root/.cursor/rules" ] && [ "$force_update" = false ]; then
        print_warning "Rules already exist at $project_root/.cursor/rules"
        read -p "Do you want to overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cancelled."
            exit 0
        fi
    fi
    
    # Install rules
    if [ "$use_local" = true ]; then
        install_from_local "$rule_type"
    else
        # Try local first, fall back to GitHub
        install_from_local "$rule_type"
    fi
    
    show_installed_rules
    
    echo -e "${GREEN}Done!${NC} Your Cursor IDE will now use these rules."
    echo ""
    echo "Next steps:"
    echo "  1. Open your project in Cursor"
    echo "  2. The rules will be automatically applied"
    echo "  3. Use @rule-name in chat to manually apply specific rules"
}

main "$@"
