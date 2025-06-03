#!/bin/bash

# Claude FSD Install Script
# Fresh installation of claude-fsd from source including optional Codex integration

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if Node.js is available (for Codex only)
check_node_for_codex() {
    local required_major=22
    if command_exists node; then
        local node_version=$(node --version | sed 's/v//')
        local node_major=$(echo $node_version | cut -d. -f1)
        if [ "$node_major" -ge "$required_major" ]; then
            return 0
        fi
    fi
    return 1
}

# Function to install Node.js via nvm (only for Codex)
install_nodejs_for_codex() {
    print_info "Installing Node.js v22+ for Codex CLI..."
    
    # Install nvm if not present
    if ! command_exists nvm; then
        print_info "Installing nvm (Node Version Manager)..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        
        # Source nvm for current session
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    fi
    
    # Install Node v22 specifically for Codex
    nvm install 22
    nvm use 22
    
    print_success "Node.js v22 installed for Codex CLI"
}

# Function to install Claude CLI
install_claude_cli() {
    print_info "Installing Claude CLI..."
    
    if command_exists claude; then
        print_warning "Claude CLI already installed, skipping..."
        return 0
    fi
    
    print_info "Please install Claude CLI manually from: https://docs.anthropic.com/en/docs/claude-code"
    print_info "After installation, run 'claude' once to complete OAuth setup"
    
    # Wait for user confirmation
    read -p "Press Enter after installing Claude CLI..."
    
    if command_exists claude; then
        print_success "Claude CLI detected successfully"
    else
        print_error "Claude CLI not found. Please install it manually and re-run this script."
        exit 1
    fi
}

# Function to setup OpenAI Codex CLI
setup_codex_cli() {
    print_info "Setting up OpenAI Codex CLI..."
    
    if command_exists codex; then
        print_warning "Codex CLI already installed, skipping..."
        return 0
    fi
    
    print_warning "Codex CLI setup requires Node.js v22+ and is completely optional"
    print_info "Claude-fsd works perfectly without Codex - it just provides enhanced code review"
    echo
    read -p "Do you want to install Node.js v22+ and set up Codex CLI? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping Codex CLI setup - claude-fsd will work without it"
        return 0
    fi
    
    # Check if Node.js v22+ is available
    if ! check_node_for_codex; then
        print_info "Node.js v22+ not found, installing for Codex..."
        install_nodejs_for_codex
    else
        print_success "Node.js v22+ detected, proceeding with Codex setup"
    fi
    
    print_info "Installing Codex CLI from source..."
    print_info "Cloning OpenAI Codex repository..."
    
    local temp_dir=$(mktemp -d)
    local install_dir="$HOME/.local/share/codex"
    
    if git clone https://github.com/openai/codex.git "$temp_dir/codex" 2>/dev/null; then
        cd "$temp_dir/codex"
        
        # Check what package manager to use
        local package_manager=""
        if [ -f "pnpm-lock.yaml" ] && command_exists pnpm; then
            package_manager="pnpm"
        elif [ -f "yarn.lock" ] && command_exists yarn; then
            package_manager="yarn"
        elif command_exists npm; then
            package_manager="npm"
        else
            print_error "No suitable package manager found (npm, yarn, or pnpm required)"
            rm -rf "$temp_dir"
            return 1
        fi
        
        print_info "Using $package_manager for installation..."
        
        # Install pnpm if needed and not available
        if [ "$package_manager" = "pnpm" ] && ! command_exists pnpm; then
            print_info "Installing pnpm..."
            npm install -g pnpm
        fi
        
        # Install dependencies
        case "$package_manager" in
            pnpm)
                pnpm install || {
                    print_warning "pnpm install failed, trying npm..."
                    npm install || {
                        print_error "Failed to install dependencies"
                        rm -rf "$temp_dir"
                        return 1
                    }
                }
                ;;
            yarn)
                yarn install || {
                    print_error "Failed to install dependencies with yarn"
                    rm -rf "$temp_dir"
                    return 1
                }
                ;;
            npm)
                npm install || {
                    print_error "Failed to install dependencies with npm"
                    rm -rf "$temp_dir"
                    return 1
                }
                ;;
        esac
        
        # Try to build
        local build_success=false
        if [ "$package_manager" = "pnpm" ]; then
            pnpm run build && build_success=true
        else
            npm run build && build_success=true
        fi
        
        if [ "$build_success" = false ]; then
            print_warning "Build failed, trying alternative approach..."
            # Try direct node execution if build fails
            if [ -f "build.mjs" ]; then
                node build.mjs && build_success=true
            elif [ -f "src/cli.ts" ] || [ -f "src/cli.js" ]; then
                print_info "Using source files directly..."
                build_success=true
            fi
        fi
        
        # Find the executable
        local codex_bin=""
        local codex_source_dir="$temp_dir/codex"
        
        # Check common build output locations
        for possible_bin in "dist/cli.js" "build/cli.js" "lib/cli.js" "codex-cli/dist/cli.js" "cli.js" "src/cli.js"; do
            if [ -f "$possible_bin" ]; then
                codex_bin="$possible_bin"
                break
            fi
        done
        
        # If no built executable found, look for TypeScript source
        if [ -z "$codex_bin" ]; then
            for possible_bin in "src/cli.ts" "cli.ts"; do
                if [ -f "$possible_bin" ]; then
                    codex_bin="$possible_bin"
                    print_info "Using TypeScript source directly"
                    break
                fi
            done
        fi
        
        if [ -n "$codex_bin" ]; then
            # Create permanent installation directory
            mkdir -p "$install_dir"
            cp -r "$temp_dir/codex"/* "$install_dir/"
            
            # Create wrapper script
            local bin_dir="$HOME/.local/bin"
            mkdir -p "$bin_dir"
            
            # Determine execution method
            local exec_cmd=""
            if [[ "$codex_bin" == *.ts ]]; then
                # TypeScript file - need to use ts-node or compile on the fly
                if command_exists tsx; then
                    exec_cmd="tsx \"$install_dir/$codex_bin\""
                elif command_exists ts-node; then
                    exec_cmd="ts-node \"$install_dir/$codex_bin\""
                else
                    print_warning "TypeScript executable found but no ts-node/tsx available"
                    exec_cmd="node \"$install_dir/$codex_bin\""
                fi
            else
                exec_cmd="node \"$install_dir/$codex_bin\""
            fi
            
            cat > "$bin_dir/codex" << EOF
#!/bin/bash
cd "$install_dir"
exec $exec_cmd "\$@"
EOF
            chmod +x "$bin_dir/codex"
            
            # Add to PATH if not already there
            if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
                local shell_config=""
                case "$SHELL" in
                    */zsh) shell_config="$HOME/.zshrc" ;;
                    */bash) shell_config="$HOME/.bashrc" ;;
                esac
                
                if [ -n "$shell_config" ]; then
                    echo "export PATH=\"$bin_dir:\$PATH\"" >> "$shell_config"
                fi
                export PATH="$bin_dir:$PATH"
            fi
            
            print_success "Codex CLI installed from source"
            print_info "Executable: $bin_dir/codex"
            print_info "Source: $install_dir"
        else
            print_error "Could not find Codex CLI executable after build"
            print_info "Checked locations: dist/cli.js, build/cli.js, lib/cli.js, cli.js, src/cli.js, src/cli.ts"
            rm -rf "$temp_dir"
            return 1
        fi
        
        cd - >/dev/null
        rm -rf "$temp_dir"
    else
        print_error "Failed to clone Codex repository"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Prompt for OpenAI API key
    print_info "Codex CLI requires an OpenAI API key"
    print_info "Get your API key from: https://platform.openai.com/api-keys"
    
    if [ -z "${OPENAI_API_KEY:-}" ]; then
        print_warning "OPENAI_API_KEY environment variable not set"
        print_info "You can set it later with: export OPENAI_API_KEY='your-key-here'"
    else
        print_success "OPENAI_API_KEY environment variable is already set"
    fi
}

# Function to setup claude-fsd from source
setup_claude_fsd() {
    print_info "Setting up claude-fsd from source..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Make all scripts executable
    chmod +x "$script_dir"/bin/*
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$script_dir/bin:"* ]]; then
        print_info "Adding claude-fsd bin directory to PATH..."
        
        # Determine shell config file
        local shell_config=""
        case "$SHELL" in
            */zsh) shell_config="$HOME/.zshrc" ;;
            */bash) shell_config="$HOME/.bashrc" ;;
            *) 
                print_warning "Unknown shell: $SHELL"
                print_info "Please manually add $script_dir/bin to your PATH"
                return 0
                ;;
        esac
        
        # Add to shell config
        echo "" >> "$shell_config"
        echo "# Claude FSD - added by install script" >> "$shell_config"
        echo "export PATH=\"$script_dir/bin:\$PATH\"" >> "$shell_config"
        
        print_success "Added to $shell_config"
        print_info "Restart your shell or run: source $shell_config"
    else
        print_success "claude-fsd bin directory already in PATH"
    fi
}

# Function to create zsh aliases
create_zsh_aliases() {
    print_info "Creating zsh aliases for claude-fsd..."
    
    local aliases_file="$HOME/.claude-fsd-aliases"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    cat > "$aliases_file" << 'EOF'
# Claude FSD Aliases
# Source this file in your .zshrc with: source ~/.claude-fsd-aliases

# Main commands
alias cfsd='claude-fsd'
alias cfsd-dev='claudefsd-dev'
alias cfsd-plan='claudefsd-create-plan'
alias cfsd-analyze='claudefsd-analyze-brief'
alias cfsd-deps='claudefsd-check-dependencies'

# Development shortcuts
alias cfsd-init='claude-fsd'  # Interactive setup
alias cfsd-go='claude-fsd dev'  # Jump straight to development
alias cfsd-status='cat docs/PLAN.md | grep -E "^\s*-\s*\["'  # Show task status
alias cfsd-logs='ls -la logs/ | tail -10'  # Show recent logs

# Quick project setup
cfsd-new() {
    local project_name="$1"
    if [ -z "$project_name" ]; then
        echo "Usage: cfsd-new <project-name>"
        return 1
    fi
    
    mkdir -p "$project_name"
    cd "$project_name"
    
    echo "# $project_name" > BRIEF.md
    echo "" >> BRIEF.md
    echo "## Project Description" >> BRIEF.md
    echo "Describe your project here..." >> BRIEF.md
    
    mkdir -p docs
    echo "# Development Plan" > docs/PLAN.md
    echo "" >> docs/PLAN.md
    echo "- [ ] Initial project setup" >> docs/PLAN.md
    
    echo "Created new claude-fsd project in: $(pwd)"
    echo "Edit BRIEF.md to describe your project, then run: cfsd"
}

# Log analysis helpers
cfsd-last-error() {
    local last_log=$(ls logs/claude-*.txt 2>/dev/null | tail -1)
    if [ -n "$last_log" ]; then
        echo "Last log: $last_log"
        grep -i "error\|fail\|exception" "$last_log" | head -20
    else
        echo "No logs found"
    fi
}

cfsd-tail() {
    local log_type="${1:-developer}"  # developer, planner, tester, reviewer
    local pattern="claude-*-${log_type}"
    local last_log=$(ls logs/${pattern} 2>/dev/null | tail -1)
    
    if [ -n "$last_log" ]; then
        echo "Tailing: $last_log"
        tail -f "$last_log"
    else
        echo "No ${log_type} logs found"
        echo "Available log types: developer, planner, tester, reviewer"
    fi
}
EOF
    
    # Add source line to .zshrc if not present
    local zshrc="$HOME/.zshrc"
    if [ -f "$zshrc" ] && ! grep -q "claude-fsd-aliases" "$zshrc"; then
        echo "" >> "$zshrc"
        echo "# Claude FSD aliases" >> "$zshrc"
        echo "source ~/.claude-fsd-aliases" >> "$zshrc"
        print_success "Added aliases to $zshrc"
    fi
    
    print_success "Created zsh aliases at: $aliases_file"
    print_info "Restart your shell or run: source ~/.claude-fsd-aliases"
}

# Function to save installation info
save_installation_info() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local version_file="$HOME/.claude-fsd-version"
    local current_commit=""
    
    # Get current commit hash
    if [ -d "$script_dir/.git" ]; then
        current_commit=$(cd "$script_dir" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    else
        current_commit="source"
    fi
    
    # Save current version
    echo "$current_commit" > "$version_file"
    print_info "Installation info saved (version: $current_commit)"
}

# Function to run dependency check
verify_installation() {
    print_info "Verifying installation..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "$script_dir/bin/claudefsd-check-dependencies"
    
    print_success "Installation verification complete"
}

# Main installation flow
main() {
    echo -e "${BLUE}Claude FSD Install Script${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo ""
    
    print_info "Fresh installation of claude-fsd from source"
    print_success "Claude-fsd is pure bash - no Node.js required for core functionality"
    echo ""
    
    # Install Claude CLI
    install_claude_cli
    
    # Setup Codex CLI (optional)
    echo ""
    read -p "Setup OpenAI Codex CLI for enhanced code review? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_codex_cli
    else
        print_warning "Skipping Codex CLI setup"
        print_info "You can set it up later by running reinstall.sh"
    fi
    
    # Setup claude-fsd
    echo ""
    setup_claude_fsd
    
    # Create aliases
    echo ""
    if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
        read -p "Create zsh aliases for easier usage? [Y/n]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            create_zsh_aliases
        fi
    fi
    
    # Save installation info
    echo ""
    save_installation_info
    
    # Verify installation
    echo ""
    verify_installation
    
    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Restart your shell or run: source ~/.zshrc"
    echo "  2. Create a new project: mkdir my-project && cd my-project"
    echo "  3. Run: claude-fsd"
    echo ""
    print_info "Available commands:"
    echo "  claude-fsd        - Interactive setup mode"
    echo "  claude-fsd dev    - Jump to development mode"
    echo "  claudefsd-dev     - Direct development loop"
    echo ""
    print_info "For updates, run: ./reinstall.sh"
    echo ""
}

# Run main function
main "$@"