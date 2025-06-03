#!/bin/bash

# Claude FSD Reinstall Script
# Updates existing claude-fsd installation with minimal prompts

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

# Function to detect and report updates
detect_updates() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local version_file="$HOME/.claude-fsd-version"
    local current_commit=""
    local previous_commit=""
    
    # Get current commit hash
    if [ -d "$script_dir/.git" ]; then
        current_commit=$(cd "$script_dir" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    else
        current_commit="source"
    fi
    
    # Read previous version if exists
    if [ -f "$version_file" ]; then
        previous_commit=$(cat "$version_file")
    fi
    
    # Save current version
    echo "$current_commit" > "$version_file"
    
    # Report update status
    if [ -n "$previous_commit" ] && [ "$previous_commit" != "$current_commit" ]; then
        print_success "Claude FSD updated from $previous_commit to $current_commit"
        
        # Show recent changes if git is available
        if [ -d "$script_dir/.git" ] && [ "$previous_commit" != "unknown" ] && [ "$current_commit" != "unknown" ]; then
            echo ""
            print_info "Recent changes:"
            cd "$script_dir"
            local changes=$(git log --oneline "${previous_commit}..${current_commit}" 2>/dev/null | head -5 || echo "Unable to show changes")
            echo "$changes" | sed 's/^/  • /'
        fi
        
        # Check for new commands
        local new_commands=""
        if [ -x "$script_dir/bin/claudefsd-auto-commit" ]; then
            new_commands="$new_commands\n  • claudefsd-auto-commit - Automatic commit notes with timeout"
        fi
        if [ -x "$script_dir/bin/claudefsd-status" ]; then
            new_commands="$new_commands\n  • claudefsd-status - Project monitoring and status"
        fi
        if [ -x "$script_dir/bin/claudefsd-pause" ]; then
            new_commands="$new_commands\n  • claudefsd-pause/resume - Development session control"
        fi
        if [ -x "$script_dir/bin/claudefsd-logs" ]; then
            new_commands="$new_commands\n  • claudefsd-logs - Advanced log analysis"
        fi
        
        if [ -n "$new_commands" ]; then
            echo ""
            print_info "New commands available:"
            echo -e "$new_commands"
        fi
        
        echo ""
        print_warning "Any running claudefsd-dev sessions need to be restarted to use updates"
        print_info "Run 'claudefsd-pause' then 'claudefsd-resume' to apply changes"
        
        return 0  # Updates found
    elif [ -z "$previous_commit" ]; then
        print_warning "No previous installation detected - consider running install.sh for fresh setup"
        return 1  # No previous installation
    else
        print_info "No updates detected (version: $current_commit)"
        return 2  # No updates
    fi
}

# Function to update claude-fsd scripts
update_claude_fsd() {
    print_info "Updating claude-fsd scripts..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Make all scripts executable
    chmod +x "$script_dir"/bin/*
    
    # Check if PATH is already configured
    if [[ ":$PATH:" != *":$script_dir/bin:"* ]]; then
        print_warning "claude-fsd bin directory not in PATH"
        
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
        
        # Check if it's already in config but not current session
        if grep -q "claude-fsd" "$shell_config" 2>/dev/null; then
            print_info "PATH already configured in $shell_config"
            print_info "Restart your shell or run: source $shell_config"
        else
            read -p "Add claude-fsd bin directory to PATH? [Y/n]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                echo "" >> "$shell_config"
                echo "# Claude FSD - added by reinstall script" >> "$shell_config"
                echo "export PATH=\"$script_dir/bin:\$PATH\"" >> "$shell_config"
                print_success "Added to $shell_config"
                print_info "Restart your shell or run: source $shell_config"
            fi
        fi
    else
        print_success "claude-fsd bin directory already in PATH"
    fi
}

# Function to update zsh aliases if they exist
update_zsh_aliases() {
    local aliases_file="$HOME/.claude-fsd-aliases"
    
    if [ -f "$aliases_file" ]; then
        print_info "Updating zsh aliases..."
        
        # Create updated aliases (same content as install.sh)
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
alias cfsd-status='claudefsd-status'  # Show project status
alias cfsd-logs='claudefsd-logs'  # Show/analyze logs
alias cfsd-pause='claudefsd-pause'  # Pause development
alias cfsd-resume='claudefsd-resume'  # Resume development

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
    claudefsd-logs tail "$log_type"
}
EOF
        
        print_success "Updated zsh aliases"
    else
        print_info "No existing aliases found - skipping alias update"
        if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
            read -p "Create zsh aliases? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Create aliases using the content above
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
alias cfsd-status='claudefsd-status'  # Show project status
alias cfsd-logs='claudefsd-logs'  # Show/analyze logs
alias cfsd-pause='claudefsd-pause'  # Pause development
alias cfsd-resume='claudefsd-resume'  # Resume development

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
    claudefsd-logs tail "$log_type"
}
EOF
                
                # Add source line to .zshrc if not present
                local zshrc="$HOME/.zshrc"
                if [ -f "$zshrc" ] && ! grep -q "claude-fsd-aliases" "$zshrc"; then
                    echo "" >> "$zshrc"
                    echo "# Claude FSD aliases" >> "$zshrc"
                    echo "source ~/.claude-fsd-aliases" >> "$zshrc"
                fi
                
                print_success "Created zsh aliases at: $aliases_file"
            fi
        fi
    fi
}

# Function to check if Codex should be installed/updated
check_codex_install() {
    if ! command_exists codex; then
        print_info "Codex CLI not found"
        read -p "Install Codex CLI for enhanced code review? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Please run install.sh for full Codex setup, or manually install from source"
            print_info "Codex requires Node.js v22+ and OpenAI API key"
        fi
    else
        print_success "Codex CLI detected"
    fi
}

# Function to verify dependencies
verify_dependencies() {
    print_info "Verifying dependencies..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -x "$script_dir/bin/claudefsd-check-dependencies" ]; then
        "$script_dir/bin/claudefsd-check-dependencies"
    else
        # Basic dependency check
        if command_exists claude; then
            print_success "Claude CLI detected"
        else
            print_error "Claude CLI not found - please install from https://docs.anthropic.com/en/docs/claude-code"
        fi
        
        check_codex_install
    fi
}

# Main reinstall flow
main() {
    echo -e "${BLUE}Claude FSD Reinstall Script${NC}"
    echo -e "${BLUE}===========================${NC}"
    echo ""
    
    print_info "Updating existing claude-fsd installation"
    echo ""
    
    # Detect updates first
    local update_status
    detect_updates
    update_status=$?
    echo ""
    
    case $update_status in
        0)
            print_info "Updates detected - proceeding with reinstall"
            ;;
        1)
            print_warning "No previous installation detected"
            print_info "Consider running install.sh for fresh setup"
            read -p "Continue with reinstall anyway? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Cancelled - run install.sh for fresh installation"
                exit 0
            fi
            ;;
        2)
            print_info "No updates found, but will refresh configuration"
            ;;
    esac
    
    # Update claude-fsd
    update_claude_fsd
    echo ""
    
    # Update aliases if they exist
    update_zsh_aliases
    echo ""
    
    # Verify dependencies
    verify_dependencies
    echo ""
    
    print_success "Reinstall complete!"
    echo ""
    print_info "Changes applied:"
    echo "  • Scripts made executable"
    echo "  • PATH configuration verified"
    echo "  • Aliases updated (if they existed)"
    echo "  • Dependencies verified"
    echo ""
    
    if [ $update_status -eq 0 ]; then
        print_warning "Running claudefsd-dev sessions need restart to use updates"
        print_info "Use 'claudefsd-pause' then 'claudefsd-resume' to apply changes"
        echo ""
    fi
    
    print_info "To restart shell configuration: source ~/.zshrc"
    echo ""
}

# Run main function
main "$@"