#!/bin/bash
# =============================================================================
# TurnStay Cursor Rules Installer
# =============================================================================
# Usage:
#   ./install-rules.sh python     # Install/update Python/FastAPI rules
#   ./install-rules.sh nextjs     # Install/update Next.js rules
#   ./install-rules.sh python --local  # Use local cursor-rules repo
#
# This repo is the source of truth: existing rules are always overwritten
# with the latest from the selected rule set. Stale rules (removed from
# source) are deleted from the project.
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
    echo "║               TurnStay Cursor Rules Installer                 ║"
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
    
    # Collect source .mdc basenames (for pruning stale rules later)
    local source_basenames=""
    for dir in "$temp_dir/$rule_type/rules" "$temp_dir/$rule_type" "$temp_dir/.cursor/rules"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' f; do
                source_basenames="$source_basenames $(basename "$f")"
            done < <(find "$dir" -maxdepth 1 -name "*.mdc" -print0 2>/dev/null)
        fi
    done

    # Copy .mdc rule files (overwrite existing — this repo is source of truth)
    print_info "Installing rules to $project_root/.cursor/rules/"
    if [ -d "$temp_dir/$rule_type/rules" ]; then
        find "$temp_dir/$rule_type/rules" -name "*.mdc" -exec cp {} "$project_root/.cursor/rules/" \;
    fi
    if [ -d "$temp_dir/$rule_type" ]; then
        find "$temp_dir/$rule_type" -maxdepth 1 -name "*.mdc" -exec cp {} "$project_root/.cursor/rules/" \;
    fi
    if [ -d "$temp_dir/.cursor/rules" ]; then
        find "$temp_dir/.cursor/rules" -name "*.mdc" -exec cp {} "$project_root/.cursor/rules/" \;
    fi

    # Remove stale rules: .mdc in target that are not in source
    for f in "$project_root/.cursor/rules"/*.mdc; do
        [ -f "$f" ] || continue
        local name=$(basename "$f")
        if ! echo "$source_basenames" | grep -qF "$name"; then
            rm -f "$f"
            print_info "Removed stale rule: $name"
        fi
    done

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
        "$HOME/TurnStay/src/Tools/cursor-rules"
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

    # Collect source .mdc basenames (for pruning stale rules later)
    local source_basenames=""
    for dir in "$rules_repo/$rule_type/rules" "$rules_repo/$rule_type" "$rules_repo/.cursor/rules"; do
        if [ -d "$dir" ]; then
            for f in "$dir"/*.mdc; do
                [ -f "$f" ] && source_basenames="$source_basenames $(basename "$f")"
            done
        fi
    done

    # Create .cursor/rules directory
    mkdir -p "$project_root/.cursor/rules"

    # Copy .mdc rule files (overwrite existing — this repo is source of truth)
    print_info "Installing rules to $project_root/.cursor/rules/"
    if [ -d "$rules_repo/$rule_type/rules" ]; then
        find "$rules_repo/$rule_type/rules" -name "*.mdc" -exec cp {} "$project_root/.cursor/rules/" \;
    fi
    if [ -d "$rules_repo/$rule_type" ]; then
        find "$rules_repo/$rule_type" -maxdepth 1 -name "*.mdc" -exec cp {} "$project_root/.cursor/rules/" \;
    fi
    if [ -d "$rules_repo/.cursor/rules" ]; then
        find "$rules_repo/.cursor/rules" -name "*.mdc" -exec cp {} "$project_root/.cursor/rules/" \;
    fi

    # Remove stale rules: .mdc in target that are not in source
    for f in "$project_root/.cursor/rules"/*.mdc; do
        [ -f "$f" ] || continue
        local name=$(basename "$f")
        if ! echo "$source_basenames" | grep -qF "$name"; then
            rm -f "$f"
            print_info "Removed stale rule: $name"
        fi
    done

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
        for rule_file in "$project_root/.cursor/rules"/*.mdc; do
            if [ -f "$rule_file" ]; then
                local rule_name=$(basename "$rule_file" .mdc)
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
        echo "Usage: $0 <python|nextjs|sdk> [--local]"
        echo ""
        echo "Options:"
        echo "  python   Install/update Python/FastAPI rules (source of truth)"
        echo "  nextjs   Install/update Next.js rules (source of truth)"
        echo "  sdk      Install/update Python SDK rules (source of truth)"
        echo "  --local  Use local cursor-rules repo instead of GitHub"
        exit 1
    fi
    
    local rule_type=$1
    local use_local=false

    # Parse additional arguments
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --local)
                use_local=true
                ;;
            --update)
                # Deprecated: we always update now (source of truth)
                ;;
        esac
        shift
    done
    
    # Validate rule type
    if [[ "$rule_type" != "python" && "$rule_type" != "nextjs" && "$rule_type" != "sdk" ]]; then
        print_error "Invalid rule type: $rule_type"
        echo "Valid types: python, nextjs, sdk"
        exit 1
    fi
    
    # Check we're in a git repo
    check_git_repo
    
    local project_root=$(get_project_root)

    if [ -d "$project_root/.cursor/rules" ] && ls "$project_root/.cursor/rules"/*.mdc 1>/dev/null 2>&1; then
        print_info "Updating existing rules (cursor-rules repo is source of truth)..."
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
