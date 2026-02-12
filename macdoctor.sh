#!/bin/zsh

# Reset to standard zsh behavior regardless of caller shell options.
emulate -R zsh

# Prevent inherited shell tracing from polluting interactive menus.
unsetopt xtrace verbose 2>/dev/null
set +x +v 2>/dev/null
PS4=''
# Prevent local/typeset from printing variable assignments to stdout.
setopt typeset_silent 2>/dev/null
# Load zsh datetime module for high-resolution timing.
zmodload zsh/datetime 2>/dev/null

# =============================================================================
# MACDOCTOR - MACOS SYSTEM UTILITY
# Version: 6.0 (Obsidian Edition)
# Architecture: Apple Silicon M-series
# OS Support: macOS Tahoe 26.2+ on Apple Silicon (M1/M2/M3+)
# =============================================================================

# --- CONFIGURATION & CONSTANTS ---
VERSION="6.0.0"
LOG_FILE="$HOME/.macdoctor.log"
REPORT_FILE="$HOME/Desktop/MacDoctor_Report_$(date +%Y-%m-%d_%H%M).txt"
BACKUP_DIR_BASE="$HOME/MacDoctorBackup"
BIN_DIR="$HOME/bin"
SELF_NAME="macdoctor"
DATE_STR=$(date "+%Y-%m-%d_%H-%M-%S")
CURRENT_BACKUP_DIR="${BACKUP_DIR_BASE}-${DATE_STR}"

# Colors & Formatting
ESC_SEQ=$'\x1b['
RESET=$ESC_SEQ"39;49;00m"
BOLD=$ESC_SEQ"01m"
ITALIC=$ESC_SEQ"03m"
RED=$ESC_SEQ"31m"
GREEN=$ESC_SEQ"32m"
YELLOW=$ESC_SEQ"33m"
BLUE=$ESC_SEQ"34m"
MAGENTA=$ESC_SEQ"35m"
CYAN=$ESC_SEQ"36m"
WHITE=$ESC_SEQ"37m"
ORANGE=$ESC_SEQ"38;5;208m"
PURPLE=$ESC_SEQ"38;5;141m"
TEAL=$ESC_SEQ"38;5;51m"
BG_RED=$ESC_SEQ"41m"
BG_BLUE=$ESC_SEQ"44m"

# Symbols & Icons
ICON_CPU="🧠"
ICON_GPU="🎮"
ICON_RAM="💾"
ICON_DISK="💿"
ICON_NET="🌐"
ICON_BATT="🔋"
ICON_TRASH="🗑️"
ICON_WARN="⚠️"
ICON_INFO="ℹ️"
ICON_OK="✅"
ICON_FAIL="❌"
ICON_ROCKET="🚀"
ICON_DOC="💎"
ICON_SEC="🔒"
ICON_WIZARD="🧙"
ICON_SEARCH="🔍"
ICON_CLOUD="☁️"
ICON_TOOL="🛠️"
ICON_EYE="👁️"
ICON_UPD="🔄"
ICON_KEY="🔑"
ICON_FIRE="🔥"

# State Variables
MODE="STANDARD" # SAFE, STANDARD, FULL
SUDO_ACTIVE=0
AUTO_INSTALL=1            # Silent fallback: auto-install missing deps via brew
USE_EMOJI=0
SHOW_PREFLIGHT=0
FIRST_RUN=1
REPORT_BUFFER=""
REPORT_CAPTURE=0
SUDO_KEEPALIVE_PID=""

# Detect macOS version for compatibility
MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "0.0")
MACOS_MAJOR="${MACOS_VERSION%%.*}"
MACOS_BUILD=$(sw_vers -buildVersion 2>/dev/null || echo "")
CHIP_TYPE=$(uname -m 2>/dev/null || echo "unknown")

# Theme & Display Settings
THEME="classic"           # bronze, terminal, neon, amber, classic, minimal, frost, solar, midnight, atom, warm
RESULT_STYLE="cards"      # cards, table, dashboard, summary, visual
USER_LEVEL="power"        # beginner, intermediate, power
DASHBOARD_STYLE="static"  # top_like, static, animated, minimal
COMPACT_MODE=0            # 0=off, 1=on
SHOW_TECHNICAL_DETAILS=1  # 0=off, 1=on
HOME_SHOW_BATTERY=1       # Show battery on home screen
HOME_SHOW_NETWORK=0       # Show network on home screen
HOME_SHOW_UPTIME=1        # Show uptime on home screen
HOME_SHOW_THERMAL=0       # Show thermal on home screen
ANALYSIS_DEPTH="standard" # quick, standard, thorough

# Paths / Storage — follow XDG convention, fallback to ~/.config
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/macdoctor"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/macdoctor"
LAST_REPORT_PATH_FILE="$CONFIG_DIR/last_report_path"
SETTINGS_FILE="$CONFIG_DIR/settings.conf"

# Migrate old config location if it exists
if [[ -d "$HOME/.macdoctor_config" && ! -f "$SETTINGS_FILE" ]]; then
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    [[ -f "$HOME/.macdoctor_config/settings.env" ]] && cp "$HOME/.macdoctor_config/settings.env" "$SETTINGS_FILE" 2>/dev/null
fi

# Apply icon theme (emoji on/off)
set_icons_for_current_theme() {
    if [[ $USE_EMOJI -eq 1 ]]; then
        ICON_CPU="🧠"; ICON_GPU="🎮"; ICON_RAM="💾"; ICON_DISK="💿"; ICON_NET="🌐"
        ICON_BATT="🔋"; ICON_TRASH="🗑️"; ICON_WARN="⚠️"; ICON_INFO="ℹ️"; ICON_OK="✅"; ICON_FAIL="❌"
        ICON_ROCKET="🚀"; ICON_DOC="💎"; ICON_SEC="🔒"; ICON_WIZARD="🧙"; ICON_SEARCH="🔍"
        ICON_CLOUD="☁️"; ICON_TOOL="🛠️"; ICON_EYE="👁️"; ICON_UPD="🔄"; ICON_KEY="🔑"; ICON_FIRE="🔥"
    else
        ICON_CPU="CPU"; ICON_GPU="GPU"; ICON_RAM="RAM"; ICON_DISK="DISK"; ICON_NET="NET"
        ICON_BATT="BAT"; ICON_TRASH="DEL"; ICON_WARN="WARN"; ICON_INFO="INFO"; ICON_OK="OK"; ICON_FAIL="FAIL"
        ICON_ROCKET="FAST"; ICON_DOC="DOC"; ICON_SEC="SEC"; ICON_WIZARD="WIZ"; ICON_SEARCH="FIND"
        ICON_CLOUD="CLOUD"; ICON_TOOL="TOOL"; ICON_EYE="EYE"; ICON_UPD="UPD"; ICON_KEY="KEY"; ICON_FIRE="FIRE"
    fi
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Capitalize first letter (zsh-compatible)
capitalize_first() {
    local str="$1"
    [[ -z "$str" ]] && return
    local first="${str:0:1}"
    first="${first:u}"
    echo "${first}${str:1}"
}

# ============================================================================
# THEME SYSTEM (Bronze/Terminal/Neon and more)
# ============================================================================

# Apply color theme based on THEME variable
apply_theme() {
    # Default box-drawing characters (themed per-theme below)
    BOX_TL="╭"; BOX_TR="╮"; BOX_BL="╰"; BOX_BR="╯"
    BOX_H="─"; BOX_V="│"; BOX_CROSS="┼"
    BOX_LT="├"; BOX_RT="┤"; BOX_TT="┬"; BOX_BT="┴"
    HEADER_L="▐"; HEADER_R="▌"
    BAR_FULL="█"; BAR_MED="▓"; BAR_LOW="░"; BAR_EMPTY="·"
    BULLET="›"

    case "$THEME" in
        bronze|steampunk)
            PRIMARY=$ESC_SEQ"38;5;172m"      # Warm bronze
            SECONDARY=$ESC_SEQ"38;5;208m"    # Copper orange
            ACCENT=$ESC_SEQ"38;5;220m"       # Gold
            HIGHLIGHT=$ESC_SEQ"38;5;223m"    # Cream highlight
            SUCCESS=$ESC_SEQ"38;5;107m"      # Olive/brass green
            WARNING=$ESC_SEQ"38;5;214m"      # Amber
            ERROR=$ESC_SEQ"38;5;124m"        # Dark red (oxidized)
            INFO=$ESC_SEQ"38;5;137m"         # Tan
            DIM=$ESC_SEQ"38;5;95m"           # Dark bronze
            BOX_TL="⚙"; BOX_TR="⚙"; BOX_BL="╰"; BOX_BR="╯"
            BULLET="⚬"
            ;;
        terminal|hacker)
            PRIMARY=$ESC_SEQ"38;5;46m"       # Neon green
            SECONDARY=$ESC_SEQ"38;5;40m"     # Green
            ACCENT=$ESC_SEQ"38;5;82m"        # Lime
            HIGHLIGHT=$ESC_SEQ"38;5;156m"    # Light green glow
            SUCCESS=$ESC_SEQ"38;5;46m"       # Neon green
            WARNING=$ESC_SEQ"38;5;226m"      # Yellow
            ERROR=$ESC_SEQ"38;5;196m"        # Red
            INFO=$ESC_SEQ"38;5;48m"          # Cyan-green
            DIM=$ESC_SEQ"38;5;22m"           # Dark green
            BOX_TL="┌"; BOX_TR="┐"; BOX_BL="└"; BOX_BR="┘"
            BAR_FULL="▮"; BAR_EMPTY="▯"
            BULLET=">"
            ;;
        neon|cyberpunk)
            PRIMARY=$ESC_SEQ"38;5;201m"      # Hot magenta
            SECONDARY=$ESC_SEQ"38;5;51m"     # Electric cyan
            ACCENT=$ESC_SEQ"38;5;129m"       # Purple
            HIGHLIGHT=$ESC_SEQ"38;5;219m"    # Pink glow
            SUCCESS=$ESC_SEQ"38;5;46m"       # Neon green
            WARNING=$ESC_SEQ"38;5;226m"      # Neon yellow
            ERROR=$ESC_SEQ"38;5;196m"        # Red
            INFO=$ESC_SEQ"38;5;87m"          # Light cyan
            DIM=$ESC_SEQ"38;5;60m"           # Muted purple
            BOX_TL="╔"; BOX_TR="╗"; BOX_BL="╚"; BOX_BR="╝"
            BOX_H="═"; BOX_V="║"
            BOX_LT="╠"; BOX_RT="╣"
            BULLET="»"
            ;;
        amber|retro)
            PRIMARY=$ESC_SEQ"38;5;214m"      # Amber
            SECONDARY=$ESC_SEQ"38;5;220m"    # Warm yellow
            ACCENT=$ESC_SEQ"38;5;208m"       # Orange
            HIGHLIGHT=$ESC_SEQ"38;5;229m"    # Pale amber
            SUCCESS=$ESC_SEQ"38;5;106m"      # Yellow-green
            WARNING=$ESC_SEQ"38;5;208m"      # Orange
            ERROR=$ESC_SEQ"38;5;160m"        # Red
            INFO=$ESC_SEQ"38;5;214m"         # Amber
            DIM=$ESC_SEQ"38;5;94m"           # Dark amber
            BOX_TL="+"; BOX_TR="+"; BOX_BL="+"; BOX_BR="+"
            BOX_H="-"; BOX_V="|"
            BOX_LT="+"; BOX_RT="+"
            BAR_FULL="#"; BAR_EMPTY="."
            BULLET="*"
            ;;
        classic)
            PRIMARY=$ESC_SEQ"38;5;75m"       # Soft blue
            SECONDARY=$ESC_SEQ"38;5;111m"    # Light blue
            ACCENT=$ESC_SEQ"38;5;80m"        # Teal
            HIGHLIGHT=$ESC_SEQ"38;5;159m"    # Ice blue
            SUCCESS=$ESC_SEQ"38;5;78m"       # Clean green
            WARNING=$ESC_SEQ"38;5;222m"      # Warm yellow
            ERROR=$ESC_SEQ"38;5;203m"        # Soft red
            INFO=$ESC_SEQ"38;5;117m"         # Cyan
            DIM=$ESC_SEQ"38;5;242m"          # Gray
            ;;
        minimal|monochrome)
            PRIMARY=$ESC_SEQ"38;5;255m"      # Bright white
            SECONDARY=$ESC_SEQ"38;5;250m"    # Light gray
            ACCENT=$ESC_SEQ"38;5;245m"       # Medium gray
            HIGHLIGHT=$ESC_SEQ"38;5;255m"    # White
            SUCCESS=$ESC_SEQ"38;5;252m"      # Near-white
            WARNING=$ESC_SEQ"38;5;248m"      # Light gray
            ERROR=$ESC_SEQ"38;5;243m"        # Mid gray
            INFO=$ESC_SEQ"38;5;250m"         # Light gray
            DIM=$ESC_SEQ"38;5;238m"          # Dark gray
            BAR_FULL="▓"; BAR_EMPTY="░"
            ;;
        frost|nord)
            PRIMARY=$ESC_SEQ"38;5;110m"      # Nord Frost 1 (blue)
            SECONDARY=$ESC_SEQ"38;5;109m"    # Frost 2
            ACCENT=$ESC_SEQ"38;5;152m"       # Frost 3
            HIGHLIGHT=$ESC_SEQ"38;5;189m"    # Snow Storm 3
            SUCCESS=$ESC_SEQ"38;5;108m"      # Aurora Green
            WARNING=$ESC_SEQ"38;5;179m"      # Aurora Yellow
            ERROR=$ESC_SEQ"38;5;174m"        # Aurora Red
            INFO=$ESC_SEQ"38;5;110m"         # Frost 1
            DIM=$ESC_SEQ"38;5;60m"           # Polar Night 3
            ;;
        solar|solarized)
            PRIMARY=$ESC_SEQ"38;5;33m"       # Blue
            SECONDARY=$ESC_SEQ"38;5;37m"     # Cyan
            ACCENT=$ESC_SEQ"38;5;136m"       # Yellow
            HIGHLIGHT=$ESC_SEQ"38;5;230m"    # Base3
            SUCCESS=$ESC_SEQ"38;5;64m"       # Green
            WARNING=$ESC_SEQ"38;5;166m"      # Orange
            ERROR=$ESC_SEQ"38;5;160m"        # Red
            INFO=$ESC_SEQ"38;5;37m"          # Cyan
            DIM=$ESC_SEQ"38;5;240m"          # Base01
            ;;
        midnight|dracula)
            PRIMARY=$ESC_SEQ"38;5;141m"      # Purple
            SECONDARY=$ESC_SEQ"38;5;212m"    # Pink
            ACCENT=$ESC_SEQ"38;5;117m"       # Cyan
            HIGHLIGHT=$ESC_SEQ"38;5;231m"    # Foreground
            SUCCESS=$ESC_SEQ"38;5;84m"       # Green
            WARNING=$ESC_SEQ"38;5;228m"      # Yellow
            ERROR=$ESC_SEQ"38;5;210m"        # Orange-Red
            INFO=$ESC_SEQ"38;5;117m"         # Cyan
            DIM=$ESC_SEQ"38;5;61m"           # Comment
            BOX_TL="╭"; BOX_TR="╮"; BOX_BL="╰"; BOX_BR="╯"
            BULLET="•"
            ;;
        atom|onedark)
            PRIMARY=$ESC_SEQ"38;5;75m"       # Blue
            SECONDARY=$ESC_SEQ"38;5;176m"    # Magenta
            ACCENT=$ESC_SEQ"38;5;75m"        # Blue
            HIGHLIGHT=$ESC_SEQ"38;5;188m"    # Light fg
            SUCCESS=$ESC_SEQ"38;5;114m"      # Green
            WARNING=$ESC_SEQ"38;5;180m"      # Dark yellow
            ERROR=$ESC_SEQ"38;5;204m"        # Red
            INFO=$ESC_SEQ"38;5;38m"          # Cyan
            DIM=$ESC_SEQ"38;5;59m"           # Gutter
            ;;
        warm|gruvbox)
            PRIMARY=$ESC_SEQ"38;5;214m"      # Bright orange
            SECONDARY=$ESC_SEQ"38;5;142m"    # Bright green
            ACCENT=$ESC_SEQ"38;5;109m"       # Bright blue
            HIGHLIGHT=$ESC_SEQ"38;5;223m"    # Fg
            SUCCESS=$ESC_SEQ"38;5;142m"      # Green
            WARNING=$ESC_SEQ"38;5;214m"      # Orange
            ERROR=$ESC_SEQ"38;5;167m"        # Red
            INFO=$ESC_SEQ"38;5;109m"         # Blue
            DIM=$ESC_SEQ"38;5;243m"          # Gray
            ;;
        *)
            PRIMARY=$ESC_SEQ"38;5;75m"
            SECONDARY=$ESC_SEQ"38;5;111m"
            ACCENT=$ESC_SEQ"38;5;80m"
            HIGHLIGHT=$ESC_SEQ"38;5;159m"
            SUCCESS=$ESC_SEQ"38;5;78m"
            WARNING=$ESC_SEQ"38;5;222m"
            ERROR=$ESC_SEQ"38;5;203m"
            INFO=$ESC_SEQ"38;5;117m"
            DIM=$ESC_SEQ"38;5;242m"
            ;;
    esac
    
    # Backward compat aliases
    CYAN="$PRIMARY"; BLUE="$SECONDARY"; GREEN="$SUCCESS"
    YELLOW="$WARNING"; RED="$ERROR"; TEAL="$ACCENT"
}

# Preview theme colors — rich visual demo
preview_theme() {
    local theme_name="$1"
    local old_theme="$THEME"
    THEME="$theme_name"
    apply_theme
    
    clear
    echo ""
    ui_box_top "Theme: $(capitalize_first "$theme_name")"
    echo ""
    echo "  ${PRIMARY}${BOLD}  Primary${RESET}     ${SECONDARY}Secondary${RESET}     ${ACCENT}Accent${RESET}     ${HIGHLIGHT}Highlight${RESET}"
    echo ""
    echo "  ${SUCCESS}  ${ICON_OK} Success${RESET}    ${WARNING}${ICON_WARN} Warning${RESET}    ${ERROR}${ICON_FAIL} Error${RESET}    ${INFO}${ICON_INFO} Info${RESET}"
    echo ""
    echo "  ${DIM}  Dimmed / secondary text${RESET}"
    echo ""
    echo "  Sample gauge:"
    printf "  "
    mini_bar 72 24
    printf " ${HIGHLIGHT}72%%${RESET}\n"
    echo ""
    echo "  Box characters: ${PRIMARY}${BOX_TL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_TR}${RESET}  Bullet: ${PRIMARY}${BULLET}${RESET}  Bars: ${SUCCESS}${BAR_FULL}${BAR_FULL}${BAR_FULL}${RESET}${DIM}${BAR_EMPTY}${BAR_EMPTY}${BAR_EMPTY}${RESET}"
    echo ""
    ui_box_bottom
    echo ""
    
    THEME="$old_theme"
    apply_theme
}

# Preview result display style
preview_result_style() {
    local old_style="$RESULT_STYLE"
    clear
    echo ""
    echo "${BOLD}${PRIMARY}Result Display Styles${RESET}"
    echo ""
    
    # Cards
    echo "  ${PRIMARY}1) CARDS${RESET} — Boxed sections"
    echo "    ${PRIMARY}┌─ System Status ──────────────┐${RESET}"
    echo "    ${PRIMARY}│${RESET}  CPU: 45% | RAM: 60%      ${PRIMARY}│${RESET}"
    echo "    ${PRIMARY}│${RESET}  Disk: 30% | Battery: 85% ${PRIMARY}│${RESET}"
    echo "    ${PRIMARY}└──────────────────────────────┘${RESET}"
    echo ""
    
    # Table
    echo "  ${PRIMARY}2) TABLE${RESET} — Column format"
    echo "    ${PRIMARY}Metric         Value      Status${RESET}"
    echo "    ${DIM}──────────────────────────────────${RESET}"
    echo "    CPU            45%        Good"
    echo "    RAM            60%        Moderate"
    echo "    Disk           30%        Healthy"
    echo ""
    
    # Dashboard
    echo "  ${PRIMARY}3) DASHBOARD${RESET} — Framed layout"
    echo "    ${PRIMARY}╔═══════════════════════════════╗${RESET}"
    echo "    ${PRIMARY}║${RESET}  ${BOLD}System Health Report${RESET}       ${PRIMARY}║${RESET}"
    echo "    ${PRIMARY}╠═══════════════════════════════╣${RESET}"
    echo "    ${PRIMARY}║${RESET}  • CPU: 45%                  ${PRIMARY}║${RESET}"
    echo "    ${PRIMARY}║${RESET}  • RAM: 60%                  ${PRIMARY}║${RESET}"
    echo "    ${PRIMARY}║${RESET}  • Disk: 30%                 ${PRIMARY}║${RESET}"
    echo "    ${PRIMARY}╚═══════════════════════════════╝${RESET}"
    echo ""
    
    # Summary
    echo "  ${PRIMARY}4) SUMMARY${RESET} — Brief + detailed"
    echo "    ${BOLD}Summary:${RESET} System is running well"
    echo "    ${DIM}Press (y) to see detailed breakdown${RESET}"
    echo ""
    
    # Visual
    echo "  ${PRIMARY}5) VISUAL${RESET} — Progress bars"
    echo "    ${BOLD}CPU Usage:${RESET} ${PRIMARY}[████████░░░░░░░░░░░░░░░░░░]${RESET} 45%"
    echo "    ${BOLD}RAM Usage:${RESET} ${ACCENT}[██████████████░░░░░░░░░░░░]${RESET} 60%"
    echo "    ${BOLD}Disk Used:${RESET} ${SUCCESS}[██████░░░░░░░░░░░░░░░░░░░░░░]${RESET} 30%"
    echo ""
    
    pause_continue
}

# Preview user experience levels
preview_user_level() {
    clear
    echo ""
    echo "${BOLD}${PRIMARY}User Experience Levels${RESET}"
    echo ""
    
    echo "  ${PRIMARY}1) BEGINNER${RESET}"
    echo "    ${DIM}Simple options, clear explanations${RESET}"
    echo "    Available:"
    echo "      • Dashboard"
    echo "      • Scan System"
    echo "      • Fix & Cleanup"
    echo "      • Security Check"
    echo ""
    
    echo "  ${PRIMARY}2) INTERMEDIATE${RESET}"
    echo "    ${DIM}More features, some technical terms${RESET}"
    echo "    Available (all Beginner +):"
    echo "      • Advanced Tools"
    echo ""
    
    echo "  ${PRIMARY}3) ADVANCED${RESET}"
    echo "    ${DIM}All features, technical details${RESET}"
    echo "    Available (all above)"
    echo ""
    
    echo "  ${PRIMARY}4) EXPERT${RESET}"
    echo "    ${DIM}Full control, power tools${RESET}"
    echo "    Available (all above)"
    echo ""
    
    echo "  ${PRIMARY}5) HACKER${RESET}"
    echo "    ${DIM}Everything unlocked, raw power${RESET}"
    echo "    Available (all above + debug options)"
    echo ""
    
    pause_continue
}

# Preview dashboard live display styles
preview_dashboard_style() {
    clear
    echo ""
    echo "${BOLD}${PRIMARY}Dashboard Display Styles${RESET}"
    echo ""
    
    echo "  ${PRIMARY}1) STATIC${RESET} — Snapshot view"
    echo "    System Dashboard — Snapshot"
    echo "    CPU: 45%  RAM: 60MB  Battery: 85%"
    echo "    ${DIM}Manual refresh via button${RESET}"
    echo ""
    
    echo "  ${PRIMARY}2) TOP-LIKE${RESET} — Live updating"
    echo "    System Dashboard — Live (like top/htop)"
    echo "    CPU: 45%  RAM: 60MB  ${DIM}(updates every 1s)${RESET}"
    echo "    PID    CMD                  %CPU"
    echo "    1234   Chrome               15.2%"
    echo "    5678   Xcode                12.8%"
    echo ""
    
    echo "  ${PRIMARY}3) ANIMATED${RESET} — Visual bars"
    echo "    ${BOLD}CPU Usage:${RESET} ${PRIMARY}[████████░░░░░░░░░░]${RESET} 45%"
    echo "    ${BOLD}RAM Usage:${RESET} ${ACCENT}[██████████░░░░░░░░░░]${RESET} 60%"
    echo "    ${DIM}(bars animate with system changes)${RESET}"
    echo ""
    
    echo "  ${PRIMARY}4) MINIMAL${RESET} — Simple list"
    echo "    ${DIM}Top 5 Processes:${RESET}"
    echo "    • Chrome (15%)"
    echo "    • Xcode (12%)"
    echo "    • Safari (8%)"
    echo ""
    
    pause_continue
}

# Show settings summary at top of menu
show_settings_summary() {
    printf "  ${DIM}Theme${RESET} ${PRIMARY}$(capitalize_first "$THEME")${RESET}"
    printf "  ${DIM}${BULLET}${RESET}  ${DIM}Style${RESET} ${ACCENT}$(capitalize_first "$RESULT_STYLE")${RESET}"
    printf "  ${DIM}${BULLET}${RESET}  ${DIM}Level${RESET} ${SUCCESS}$(capitalize_first "$USER_LEVEL")${RESET}"
    printf "  ${DIM}${BULLET}${RESET}  ${DIM}Dashboard${RESET} ${INFO}$(capitalize_first "$DASHBOARD_STYLE")${RESET}\n"
    echo ""
}

# ============================================================================
# RESULT RENDERING SYSTEM (Multiple display styles)
# ============================================================================

# Render result as cards (themed boxed sections)
render_result_cards() {
    local title="$1"
    local data="$2"
    echo ""
    ui_box_top "$title"
    echo "$data" | while IFS= read -r line; do
        ui_box_row "$line"
    done
    ui_box_bottom
    echo ""
}

# Render result as table (themed)
render_result_table() {
    local title="$1"
    local data="$2"
    echo ""
    echo "  ${BOLD}${PRIMARY}${title}${RESET}"
    ui_line 58
    echo "$data" | column -t -s'|' 2>/dev/null || echo "$data"
    ui_line 58
    echo ""
}

# Render result as dashboard (double-line box)
render_result_dashboard() {
    local title="$1"
    local data="$2"
    echo ""
    echo "  ${PRIMARY}${BOX_TL}${BOX_H}${BOX_H} ${BOLD}${title}${RESET}${PRIMARY} $(printf '%0.s'"$BOX_H" {1..40})${BOX_TR}${RESET}"
    echo "$data" | while IFS= read -r line; do
        echo "  ${PRIMARY}${BOX_V}${RESET}  $line"
    done
    echo "  ${PRIMARY}${BOX_BL}$(printf '%0.s'"$BOX_H" {1..58})${BOX_BR}${RESET}"
    echo ""
}

# Render result as summary first, then details
render_result_summary() {
    local title="$1"
    local summary="$2"
    local details="$3"
    echo ""
    echo "  ${BOLD}${PRIMARY}${title}${RESET}"
    echo ""
    echo "  ${BOLD}${HIGHLIGHT}Summary:${RESET}"
    echo "  ${summary}"
    echo ""
    if [[ -n "$details" ]]; then
        if ui_confirm "Show detailed results?"; then
            echo ""
            echo "  ${BOLD}${HIGHLIGHT}Details:${RESET}"
            echo "$details"
        fi
    fi
    echo ""
}

# Render result with visual bars (themed)
render_result_visual() {
    local title="$1"
    local items="$2"
    echo ""
    echo "  ${BOLD}${PRIMARY}${title}${RESET}"
    echo ""
    echo "$items" | while IFS='|' read -r label value max; do
        local percent=0
        if [[ -n "$max" ]] && [[ "$max" != "0" ]]; then
            percent=$(LC_ALL=C awk -v v="$value" -v m="$max" 'BEGIN{printf "%.0f", (v/m)*100}')
            [[ $percent -gt 100 ]] && percent=100
        fi
        printf "  ${BOLD}%-20s${RESET} " "$label"
        mini_bar "$percent" 28
        printf " ${HIGHLIGHT}%s${RESET}\n" "$value"
    done
    echo ""
}

# Main display function - routes to correct renderer based on RESULT_STYLE
display_scan_results() {
    local title="$1"
    local data="$2"
    local summary="${3:-}"
    local details="${4:-}"
    
    case "$RESULT_STYLE" in
        cards)
            render_result_cards "$title" "$data"
            ;;
        table)
            render_result_table "$title" "$data"
            ;;
        dashboard)
            render_result_dashboard "$title" "$data"
            ;;
        summary)
            render_result_summary "$title" "$summary" "$details"
            ;;
        visual)
            render_result_visual "$title" "$data"
            ;;
        *)
            # Default to cards
            render_result_cards "$title" "$data"
            ;;
    esac
    
    # Add exit option
    echo ""
    # Automatic local semantic analysis after every scan
    run_local_semantic_analysis "scan" "" 2>/dev/null

    echo "  ${PRIMARY}0) Back to Scan Menu${RESET}"
    echo -n "  👉 Press Enter or '0' to continue: "
    read_user_line choice || choice="0"
    [[ "$choice" == "0" ]] && return 1
    return 0
}

# ============================================================================
# USER LEVEL SYSTEM (Filter menus based on experience)
# ============================================================================

# Get menu items available for current user level
get_menu_for_level() {
    local menu_type="$1"  # main, scan, fix, advanced
    local -a available_items=()
    
    case "$menu_type" in
        main)
            case "$USER_LEVEL" in
                beginner)
                    available_items=(1 2 3 4 6 0)  # Dashboard, Scan, Fix, Security, Settings, Exit
                    ;;
                intermediate)
                    available_items=(1 2 3 4 5 6 0)  # + Advanced Tools, Settings
                    ;;
                advanced)
                    available_items=(1 2 3 4 5 6 0)  # All options including Settings
                    ;;
                expert|power|hacker)
                    available_items=(1 2 3 4 5 6 0)  # All options
                    ;;
            esac
            ;;
        scan)
            case "$USER_LEVEL" in
                beginner)
                    available_items=(1 0)  # Only Quick Scan
                    ;;
                intermediate)
                    available_items=(1 2 0)  # Quick + Deep
                    ;;
                advanced|expert|power|hacker)
                    available_items=(1 2 3 0)  # All scans
                    ;;
            esac
            ;;
        fix)
            case "$USER_LEVEL" in
                beginner)
                    available_items=(1 0)  # Only Safe Cleanup
                    ;;
                intermediate)
                    available_items=(1 2 0)  # Safe + Deep
                    ;;
                advanced)
                    available_items=(1 2 3 0)  # + Aggressive
                    ;;
                expert|power|hacker)
                    available_items=(1 2 3 4 0)  # + Wizard
                    ;;
            esac
            ;;
        advanced)
            case "$USER_LEVEL" in
                beginner|intermediate)
                    available_items=(3 4 0)  # System Analysis + Utilities
                    ;;
                advanced)
                    available_items=(1 2 3 4 0)  # + Process Inspector, Monitors, System Analysis
                    ;;
                expert|power|hacker)
                    available_items=(1 2 3 4 0)  # All advanced tools
                    ;;
            esac
            ;;
    esac
    
    echo "${available_items[@]}"
}

# Check if menu item is available for current level
is_menu_item_available() {
    local menu_type="$1"
    local item="$2"
    local -a available
    available=($(get_menu_for_level "$menu_type"))
    
    for i in "${available[@]}"; do
        [[ "$i" == "$item" ]] && return 0
    done
    return 1
}

# Get level-specific description
get_level_description() {
    local item="$1"
    local level="$USER_LEVEL"
    
    case "$level" in
        beginner)
            case "$item" in
                scan) echo "Find problems quickly" ;;
                fix) echo "Make your Mac faster (safe)" ;;
                security) echo "Check security settings" ;;
                *) echo "Simple and safe option" ;;
            esac
            ;;
        intermediate)
            case "$item" in
                scan) echo "Diagnose system issues" ;;
                fix) echo "Clean up and optimize" ;;
                security) echo "Review security configuration" ;;
                *) echo "Standard feature" ;;
            esac
            ;;
        advanced|expert|power|hacker)
            case "$item" in
                scan) echo "Full system scan" ;;
                fix) echo "Advanced cleanup and optimization" ;;
                security) echo "Full security audit" ;;
                *) echo "Advanced feature" ;;
            esac
            ;;
    esac
}

# ============================================================================
# DASHBOARD STYLES (Different ways to display live processes)
# ============================================================================

# Get top processes data (clean app names, not full paths)
get_top_processes() {
    local count="${1:-10}"
    ps -A -o pid,ucomm,pcpu,pmem -r 2>/dev/null | head -n $((count + 1)) | tail -n $count
}

# ============================================================================
# HEALTH SCORE
# ============================================================================

compute_health_score() {
    local cpu_load=${1:-0} ram_pct=${2:-0} disk_pct=${3:-0}

    local cpu_s=$(( 100 - cpu_load ))
    [[ $cpu_s -lt 0 ]] && cpu_s=0

    local mem_s=100
    if [[ $ram_pct -gt 90 ]]; then mem_s=$(( 20 - (ram_pct - 90) * 2 ))
    elif [[ $ram_pct -gt 75 ]]; then mem_s=$(( 60 - (ram_pct - 75) * 2 ))
    elif [[ $ram_pct -gt 60 ]]; then mem_s=$(( 85 - (ram_pct - 60) ))
    fi
    [[ $mem_s -lt 0 ]] && mem_s=0

    local dsk_s=100
    if [[ $disk_pct -gt 95 ]]; then dsk_s=5
    elif [[ $disk_pct -gt 90 ]]; then dsk_s=$(( 30 - (disk_pct - 90) * 5 ))
    elif [[ $disk_pct -gt 80 ]]; then dsk_s=$(( 60 - (disk_pct - 80) * 3 ))
    elif [[ $disk_pct -gt 60 ]]; then dsk_s=$(( 90 - (disk_pct - 60) ))
    fi
    [[ $dsk_s -lt 0 ]] && dsk_s=0

    local score=$(( (cpu_s * 20 + mem_s * 35 + dsk_s * 45) / 100 ))
    [[ $score -gt 100 ]] && score=100
    [[ $score -lt 0 ]] && score=0
    echo "$score"
}

health_label() {
    local s=$1
    if [[ $s -ge 90 ]]; then echo "Excellent"
    elif [[ $s -ge 75 ]]; then echo "Healthy"
    elif [[ $s -ge 60 ]]; then echo "Fair"
    elif [[ $s -ge 40 ]]; then echo "Needs Attention"
    else echo "Critical"; fi
}

health_color() {
    local s=$1
    if [[ $s -ge 75 ]]; then echo "$SUCCESS"
    elif [[ $s -ge 60 ]]; then echo "$YELLOW"
    elif [[ $s -ge 40 ]]; then echo "$ORANGE"
    else echo "$RED"; fi
}

health_hint() {
    local cpu=$1 ram=$2 disk=$3
    if [[ $disk -gt 90 ]]; then echo "Disk almost full — run a cleanup."
    elif [[ $ram -gt 85 ]]; then echo "Memory pressure is high. Close unused apps."
    elif [[ $cpu -gt 80 ]]; then echo "CPU is under heavy load right now."
    elif [[ $disk -gt 75 ]]; then echo "Disk space is getting low."
    elif [[ $ram -gt 65 ]]; then echo "Memory usage is moderate."
    else echo "Your Mac is running smoothly."; fi
}

# ============================================================================
# HISTORY / TRENDS
# ============================================================================

HISTORY_FILE="${CONFIG_DIR}/health_history.log"

save_health_snapshot() {
    local score=$1 cpu=$2 ram=$3 disk=$4
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    echo "$(date +%Y-%m-%d) $score $cpu $ram $disk" >> "$HISTORY_FILE"
    tail -90 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" 2>/dev/null && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE" 2>/dev/null
}

get_health_trend() {
    [[ ! -f "$HISTORY_FILE" ]] && echo "new" && return
    local count=$(wc -l < "$HISTORY_FILE" 2>/dev/null | tr -d ' ')
    [[ $count -lt 2 ]] && echo "new" && return
    local prev=$(tail -2 "$HISTORY_FILE" | head -1 | awk '{print $2}')
    local curr=$(tail -1 "$HISTORY_FILE" | awk '{print $2}')
    if [[ $curr -gt $((prev + 3)) ]]; then echo "up"
    elif [[ $curr -lt $((prev - 3)) ]]; then echo "down"
    else echo "stable"; fi
}

trend_icon() {
    case "$1" in
        up) echo "${SUCCESS}▲${RESET}" ;;
        down) echo "${RED}▼${RESET}" ;;
        stable) echo "${DIM}═${RESET}" ;;
        *) echo "" ;;
    esac
}

# ============================================================================
# STARTUP ANIMATION
# ============================================================================

show_startup_animation() {
    [[ "$TERM" == "dumb" ]] && return
    clear
    tput civis 2>/dev/null

    local cols=$(tput cols 2>/dev/null || echo 80)
    local rows=$(tput lines 2>/dev/null || echo 24)
    local cy=$(( rows / 2 - 4 ))
    [[ $cy -lt 2 ]] && cy=2

    local pulse="──────────╮  ╭──╮  ╭──────────"
    local pulse2="          ╰──╯  ╰──╯"
    local pw=${#pulse}
    local pad=$(( (cols - pw) / 2 ))
    [[ $pad -lt 2 ]] && pad=2

    for ((i=0; i<cy; i++)); do echo ""; done

    # Animate pulse line
    printf "%*s" $pad ""
    for ((i=0; i<pw; i++)); do
        local ch="${pulse:$i:1}"
        case "$ch" in
            ╮|╭|╰|╯) printf "${BOLD}${ACCENT}${ch}${RESET}" ;;
            ─) printf "${DIM}${PRIMARY}${ch}${RESET}" ;;
            *) printf "${PRIMARY}${ch}${RESET}" ;;
        esac
        sleep 0.012
    done
    echo ""

    printf "%*s" $pad ""
    for ((i=0; i<${#pulse2}; i++)); do
        local ch="${pulse2:$i:1}"
        case "$ch" in
            ╮|╭|╰|╯) printf "${BOLD}${ACCENT}${ch}${RESET}" ;;
            *) printf "${PRIMARY}${ch}${RESET}" ;;
        esac
        sleep 0.012
    done
    echo ""; echo ""

    # App name — character reveal
    local name="MacDoctor"
    local npad=$(( (cols - ${#name} - 8) / 2 ))
    printf "%*s" $npad ""
    printf "  "
    for ((i=0; i<${#name}; i++)); do
        printf "${BOLD}${PRIMARY}${name:$i:1}${RESET}"
        sleep 0.035
    done
    sleep 0.15
    printf "  ${DIM}v${VERSION}${RESET}"
    echo ""

    # Tagline
    local tag="Your Mac's health checkup"
    printf "%*s${DIM}${tag}${RESET}" $(( (cols - ${#tag}) / 2 )) ""
    echo ""; echo ""

    # Brief loading effect
    local bar_pad=$(( (cols - 30) / 2 ))
    printf "%*s${DIM}" $bar_pad ""
    for ((i=0; i<20; i++)); do
        printf "▓"
        sleep 0.025
    done
    printf "${RESET}"
    echo ""

    sleep 0.3
    tput cnorm 2>/dev/null
    clear
}

# ============================================================================
# WIFI DIAGNOSTICS
# ============================================================================

run_wifi_diagnostics() {
    clear
    echo ""
    ui_box_top "WiFi Diagnostics"
    ui_box_row "${DIM}Signal, speed, channel & interference analysis${RESET}"
    ui_box_bottom
    echo ""

    local airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
    local iface=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}')
    [[ -z "$iface" ]] && iface="en0"

    local info=""
    if [[ -x "$airport" ]]; then
        info=$("$airport" -I 2>/dev/null)
    fi

    if [[ -z "$info" ]]; then
        echo "  ${YELLOW}${ICON_WARN}${RESET} Could not read WiFi info."
        echo "  ${DIM}On macOS 15+, the airport command may be restricted.${RESET}"
        echo ""

        local ssid=$(networksetup -getairportnetwork "$iface" 2>/dev/null | sed 's/Current Wi-Fi Network: //')
        [[ -n "$ssid" ]] && ui_kv "  Network" "$ssid"
        local wifi_ip=$(ipconfig getifaddr "$iface" 2>/dev/null)
        [[ -n "$wifi_ip" ]] && ui_kv "  IP Address" "$wifi_ip"
        local router=$(netstat -rn 2>/dev/null | awk '/default.*'"$iface"'/{print $2; exit}')
        [[ -n "$router" ]] && ui_kv "  Router" "$router"
    else
        local ssid=$(echo "$info" | awk -F': ' '/^ *SSID:/{print $2}')
        local bssid=$(echo "$info" | awk -F': ' '/BSSID/{print $2}')
        local rssi=$(echo "$info" | awk -F': ' '/agrCtlRSSI/{print $2}')
        local noise=$(echo "$info" | awk -F': ' '/agrCtlNoise/{print $2}')
        local channel=$(echo "$info" | awk -F': ' '/^ *channel/{print $2}')
        local tx_rate=$(echo "$info" | awk -F': ' '/lastTxRate/{print $2}')
        local mcs=$(echo "$info" | awk -F': ' '/MCS/{print $2}')
        local security=$(echo "$info" | awk -F': ' '/link auth/{print $2}')

        echo "  ${BOLD}${PRIMARY}  Connection${RESET}"
        echo ""
        ui_kv "  Network" "${ssid:-Unknown}"
        ui_kv "  BSSID" "${bssid:-N/A}"
        ui_kv "  Security" "${security:-N/A}"
        echo ""

        echo "  ${BOLD}${PRIMARY}  Signal Quality${RESET}"
        echo ""

        local signal_quality="Unknown"
        local sig_color="$DIM"
        if [[ -n "$rssi" ]]; then
            rssi="${rssi// /}"
            if [[ $rssi -ge -50 ]]; then signal_quality="Excellent"; sig_color="$SUCCESS"
            elif [[ $rssi -ge -60 ]]; then signal_quality="Good"; sig_color="$SUCCESS"
            elif [[ $rssi -ge -70 ]]; then signal_quality="Fair"; sig_color="$YELLOW"
            elif [[ $rssi -ge -80 ]]; then signal_quality="Weak"; sig_color="$ORANGE"
            else signal_quality="Very Weak"; sig_color="$RED"; fi
            ui_kv "  Signal" "${rssi} dBm (${signal_quality})"
        fi
        [[ -n "$noise" ]] && ui_kv "  Noise" "${noise} dBm"
        if [[ -n "$rssi" && -n "$noise" ]]; then
            local snr=$(( ${rssi// /} - ${noise// /} ))
            local snr_label="Poor"
            [[ $snr -ge 40 ]] && snr_label="Excellent"
            [[ $snr -ge 25 && $snr -lt 40 ]] && snr_label="Good"
            [[ $snr -ge 15 && $snr -lt 25 ]] && snr_label="Fair"
            ui_kv "  SNR" "${snr} dB (${snr_label})"
        fi
        echo ""

        echo "  ${BOLD}${PRIMARY}  Channel & Speed${RESET}"
        echo ""
        ui_kv "  Channel" "${channel:-N/A}"
        local band="2.4 GHz"
        if [[ -n "$channel" ]]; then
            local ch_num="${channel%%,*}"
            [[ $ch_num -gt 14 ]] && band="5 GHz"
            [[ $ch_num -gt 200 ]] && band="6 GHz"
        fi
        ui_kv "  Band" "$band"
        ui_kv "  TX Rate" "${tx_rate:+${tx_rate} Mbps}"
        echo ""

        echo "  ${BOLD}${PRIMARY}  Nearby Networks${RESET}"
        echo ""
        local scan_result=$("$airport" -s 2>/dev/null | tail -n +2 | head -10)
        if [[ -n "$scan_result" ]]; then
            local same_ch=0
            while IFS= read -r line; do
                local net_ch=$(echo "$line" | awk '{print $(NF-3)}')
                local my_ch="${channel%%,*}"
                [[ "$net_ch" == "$my_ch" ]] && ((same_ch++))
            done <<< "$scan_result"
            local total_nearby=$(echo "$scan_result" | wc -l | tr -d ' ')
            echo "  ${DIM}${total_nearby} networks detected${RESET}"
            if [[ $same_ch -gt 2 ]]; then
                echo "  ${YELLOW}${ICON_WARN}${RESET} ${YELLOW}${same_ch} networks on your channel — may cause interference${RESET}"
                echo "  ${DIM}  Try switching to a less crowded channel in your router settings${RESET}"
            elif [[ $same_ch -gt 0 ]]; then
                echo "  ${DIM}${same_ch} networks share your channel (normal)${RESET}"
            else
                echo "  ${SUCCESS}${ICON_OK}${RESET} No competing networks on your channel"
            fi
        else
            echo "  ${DIM}WiFi scan unavailable${RESET}"
        fi
    fi

    echo ""
    local pub_ip=$(curl -s --max-time 4 https://ifconfig.me 2>/dev/null)
    [[ -n "$pub_ip" ]] && ui_kv "  Public IP" "$pub_ip"
    local dns=$(scutil --dns 2>/dev/null | awk '/nameserver\[0\]/{print $3; exit}')
    [[ -n "$dns" ]] && ui_kv "  DNS Server" "$dns"
    echo ""
    pause_continue
}

# ============================================================================
# STORAGE ANALYZER
# ============================================================================

run_storage_analyzer() {
    clear
    echo ""
    ui_box_top "Storage Analyzer"
    ui_box_row "${DIM}Find what's eating your disk space${RESET}"
    ui_box_bottom
    echo ""
    echo "  ${DIM}Scanning... this takes a few seconds.${RESET}"
    echo ""

    local home="$HOME"

    echo "  ${BOLD}${PRIMARY}  Space by Category${RESET}"
    echo ""
    local sz_apps=$(du -sh /Applications 2>/dev/null | awk '{print $1}')
    local sz_downloads=$(du -sh "$home/Downloads" 2>/dev/null | awk '{print $1}')
    local sz_documents=$(du -sh "$home/Documents" 2>/dev/null | awk '{print $1}')
    local sz_desktop=$(du -sh "$home/Desktop" 2>/dev/null | awk '{print $1}')
    local sz_caches=$(du -sh "$home/Library/Caches" 2>/dev/null | awk '{print $1}')
    local sz_logs=$(du -sh "$home/Library/Logs" 2>/dev/null | awk '{print $1}')
    local sz_mail=$(du -sh "$home/Library/Mail" 2>/dev/null | awk '{print $1}')
    local sz_xcode=$(du -sh "$home/Library/Developer" 2>/dev/null | awk '{print $1}')
    local sz_docker=""
    [[ -d "$home/Library/Containers/com.docker.docker" ]] && sz_docker=$(du -sh "$home/Library/Containers/com.docker.docker" 2>/dev/null | awk '{print $1}')
    local sz_trash=$(du -sh "$home/.Trash" 2>/dev/null | awk '{print $1}')
    local sz_brew=""
    command -v brew &>/dev/null && sz_brew=$(du -sh "$(brew --cache 2>/dev/null)" 2>/dev/null | awk '{print $1}')

    printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Applications" "${sz_apps:-0B}"
    printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Downloads" "${sz_downloads:-0B}"
    printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Documents" "${sz_documents:-0B}"
    printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Desktop" "${sz_desktop:-0B}"
    printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Caches" "${sz_caches:-0B}"
    printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Logs" "${sz_logs:-0B}"
    [[ -n "$sz_mail" && "$sz_mail" != "0B" ]] && printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Mail" "$sz_mail"
    [[ -n "$sz_xcode" && "$sz_xcode" != "0B" ]] && printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Developer Tools" "$sz_xcode"
    [[ -n "$sz_docker" ]] && printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Docker" "$sz_docker"
    [[ -n "$sz_brew" ]] && printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Homebrew Cache" "$sz_brew"
    printf "  ${HIGHLIGHT}%-22s${RESET} %s\n" "Trash" "${sz_trash:-0B}"
    echo ""

    echo "  ${BOLD}${PRIMARY}  Largest Files (top 15)${RESET}"
    echo ""
    local big_files=$(find "$home" -maxdepth 5 -type f -size +100M \
        -not -path "*/Library/Mail/*" \
        -not -path "*/.Trash/*" \
        -not -path "*/Music/Music/*" \
        -not -path "*/.cache/*" \
        2>/dev/null | head -30)

    if [[ -n "$big_files" ]]; then
        local tmpfile=$(mktemp)
        while IFS= read -r f; do
            local sz=$(du -sh "$f" 2>/dev/null | awk '{print $1}')
            local sz_bytes=$(du -k "$f" 2>/dev/null | awk '{print $1}')
            echo "$sz_bytes $sz $f" >> "$tmpfile"
        done <<< "$big_files"
        sort -rn "$tmpfile" | head -15 | while IFS= read -r line; do
            local sz=$(echo "$line" | awk '{print $2}')
            local path=$(echo "$line" | cut -d' ' -f3-)
            local short="${path/#$home/~}"
            printf "  ${WARNING}%6s${RESET}  ${DIM}%s${RESET}\n" "$sz" "${short:0:55}"
        done
        rm -f "$tmpfile"
    else
        echo "  ${DIM}No files over 100MB found in home directory.${RESET}"
    fi
    echo ""

    echo "  ${BOLD}${PRIMARY}  Largest Folders${RESET}"
    echo ""
    du -sh "$home"/*/ "$home"/Library/*/ 2>/dev/null | sort -rh | head -10 | while IFS=$'\t' read -r sz path; do
        local short="${path/#$home/~}"
        short="${short%/}"
        printf "  ${ACCENT}%6s${RESET}  ${DIM}%s${RESET}\n" "$sz" "${short:0:55}"
    done
    echo ""

    echo "  ${BOLD}${PRIMARY}  Suggestions${RESET}"
    echo ""
    [[ -n "$sz_trash" && "$sz_trash" != "0B" ]] && echo "  ${YELLOW}${ICON_WARN}${RESET} Empty Trash to free ${sz_trash}"
    [[ -n "$sz_xcode" ]] && echo "  ${DIM}${BULLET}${RESET} Developer tools using ${sz_xcode} — Xcode DerivedData can be cleaned"
    [[ -n "$sz_docker" ]] && echo "  ${DIM}${BULLET}${RESET} Docker is using ${sz_docker} — run 'docker system prune' to reclaim space"
    [[ -n "$sz_brew" ]] && echo "  ${DIM}${BULLET}${RESET} Homebrew cache: ${sz_brew} — run 'brew cleanup' to reclaim"
    local sz_downloads_kb=$(du -sk "$home/Downloads" 2>/dev/null | awk '{print $1}')
    [[ ${sz_downloads_kb:-0} -gt 1048576 ]] && echo "  ${DIM}${BULLET}${RESET} Downloads folder is ${sz_downloads} — review old files"
    echo "  ${DIM}${BULLET}${RESET} Run Fix & Cleanup from the main menu to clear caches safely"
    echo ""
    pause_continue
}

# ============================================================================
# TIME MACHINE / BACKUP STATUS
# ============================================================================

check_time_machine_status() {
    local tm_dest=$(tmutil destinationinfo 2>/dev/null)
    local last_backup=$(tmutil latestbackup 2>/dev/null)
    local tm_running=$(tmutil status 2>/dev/null | grep -c "Running = 1")

    if [[ -z "$tm_dest" || "$tm_dest" == *"No destinations"* ]]; then
        _sec_check "Time Machine" "Not configured" "Set up in System Settings → General → Time Machine"
        return
    fi

    local dest_name=$(echo "$tm_dest" | awk -F': ' '/Name/{print $2; exit}')
    if [[ -n "$last_backup" ]]; then
        local backup_date=$(basename "$last_backup" | sed 's/-/:/4; s/-/:/5')
        local backup_short=$(echo "$backup_date" | cut -d'.' -f1 | sed 's/T/ /')
        local now_epoch=$(date +%s)
        local backup_epoch=$(date -j -f "%Y-%m-%d-%H%M%S" "$(basename "$last_backup" | cut -d'.' -f1)" +%s 2>/dev/null || echo 0)
        local age_hours=0
        [[ $backup_epoch -gt 0 ]] && age_hours=$(( (now_epoch - backup_epoch) / 3600 ))

        if [[ $age_hours -lt 24 ]]; then
            echo "   ${SUCCESS}✓${RESET} Time Machine: Last backup ${GREEN}${age_hours}h ago${RESET} ${DIM}(${dest_name})${RESET}"
            ((score++))
        elif [[ $age_hours -lt 168 ]]; then
            local days=$(( age_hours / 24 ))
            _sec_check "Time Machine" "${days} days since last backup" "Connect your backup disk to run a backup"
        else
            local days=$(( age_hours / 24 ))
            _sec_check "Time Machine" "${days} days since last backup!" "Your backup is very outdated — connect your disk"
        fi
    elif [[ $tm_running -gt 0 ]]; then
        echo "   ${SUCCESS}✓${RESET} Time Machine: ${GREEN}Backup in progress${RESET} ${DIM}(${dest_name})${RESET}"
        ((score++))
    else
        _sec_check "Time Machine" "Configured but no backups found" "Run a manual backup: tmutil startbackup"
    fi
}

# Dashboard style: Static snapshot — rich telemetry
show_dashboard_static() {
    clear
    echo ""

    # ── Collect all data first ──
    local cpu=$(get_cpu_load 2>/dev/null || echo "0")
    local cpu_int="${cpu%.*}"
    [[ -z "$cpu_int" ]] && cpu_int=0

    local ram_used=$(get_memory_usage 2>/dev/null || echo "0")
    local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    local total_mem=$(( ${mem_bytes:-0} / 1024 / 1024 ))
    [[ "$total_mem" -le 0 ]] 2>/dev/null && total_mem=16384
    local ram_pct=$(LC_ALL=C awk -v u="$ram_used" -v t="$total_mem" 'BEGIN{if(t>0){printf("%.0f",(u/t)*100)} else {print "0"}}')
    local ram_pct_f=$(LC_ALL=C awk -v u="$ram_used" -v t="$total_mem" 'BEGIN{if(t>0){printf("%.1f",(u/t)*100)} else {print "0.0"}}')

    local df_line=$(LC_ALL=C df -h / 2>/dev/null | tail -1)
    local disk_total=$(echo "$df_line" | awk '{print $2}')
    local disk_used=$(echo "$df_line" | awk '{print $3}')
    local disk_free=$(echo "$df_line" | awk '{print $4}')
    local disk_pct=$(echo "$df_line" | awk '{print $5}' | tr -d '%')
    [[ -z "$disk_pct" ]] && disk_pct=0

    local batt_raw=$(pmset -g batt 2>/dev/null)
    local batt_pct=$(echo "$batt_raw" | grep -o "[0-9]*%" | head -1 | tr -d '%')
    local batt_state=$(echo "$batt_raw" | grep -oE "charging|discharging|charged|finishing charge" | head -1)
    [[ -z "$batt_pct" ]] && batt_pct="N/A"
    [[ -z "$batt_state" ]] && batt_state=""

    local swap_raw=$(sysctl -n vm.swapusage 2>/dev/null)
    local swap_used=$(echo "$swap_raw" | awk '{print $7}')
    [[ -z "$swap_used" ]] && swap_used="0M"

    local thermal=$(strip_ansi "$(get_thermal_state 2>/dev/null)")
    local uptime_str=$(get_uptime_pretty 2>/dev/null)

    local net_if=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
    local net_ip=""
    [[ -n "$net_if" ]] && net_ip=$(ifconfig "$net_if" 2>/dev/null | awk '/inet /{print $2; exit}')
    [[ -z "$net_ip" ]] && net_ip="offline"

    local gpu_name=$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model/{print $2; exit}')
    [[ -z "$gpu_name" ]] && gpu_name="N/A"

    # ── Determine badge status ──
    local cpu_badge="OK"; [[ $cpu_int -gt 80 ]] && cpu_badge="FAIL"; [[ $cpu_int -gt 50 && $cpu_int -le 80 ]] && cpu_badge="WARN"
    local ram_badge="OK"; [[ $ram_pct -gt 85 ]] && ram_badge="FAIL"; [[ $ram_pct -gt 60 && $ram_pct -le 85 ]] && ram_badge="WARN"
    local dsk_badge="OK"; [[ $disk_pct -gt 90 ]] && dsk_badge="FAIL"; [[ $disk_pct -gt 75 && $disk_pct -le 90 ]] && dsk_badge="WARN"

    # ── Render ──
    ui_box_top "System Dashboard"
    ui_box_row "${DIM}$(date '+%Y-%m-%d %H:%M')  ${RESET}${DIM}${BULLET} Uptime ${uptime_str}  ${BULLET} ${net_ip}${RESET}"
    ui_box_sep
    echo ""

    echo "  ${BOLD}${PRIMARY}  Vital Signs${RESET}"
    echo ""
    ui_badge_bar "$cpu_badge" "CPU" "$cpu_int" "${cpu}%"
    ui_badge_bar "$ram_badge" "Memory" "$ram_pct" "${ram_used}/${total_mem} MB (${ram_pct_f}%)"
    ui_badge_bar "$dsk_badge" "Disk" "$disk_pct" "${disk_used}/${disk_total} (${disk_free} free)"
    if [[ "$batt_pct" != "N/A" ]]; then
        local batt_badge="OK"; [[ $batt_pct -lt 20 ]] && batt_badge="WARN"; [[ $batt_pct -lt 10 ]] && batt_badge="FAIL"
        ui_badge_bar "$batt_badge" "Battery" "$batt_pct" "${batt_pct}% ${batt_state}"
    else
        ui_badge INFO "Battery" "N/A (desktop Mac)"
    fi
    echo ""

    echo "  ${BOLD}${PRIMARY}  System Info${RESET}"
    echo ""
    ui_kv "  GPU" "$gpu_name"
    ui_kv "  Thermal" "$thermal"
    ui_kv "  Swap" "$swap_used"
    ui_kv "  Network" "${net_if:-none} (${net_ip})"

    # ── Load averages (unique to dashboard) ──
    local loadavg=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2, $3, $4}')
    [[ -n "$loadavg" ]] && ui_kv "  Load Avg" "$loadavg (1m 5m 15m)"

    # ── Memory breakdown (unique to dashboard) ──
    local vm_stat_out=$(vm_stat 2>/dev/null)
    if [[ -n "$vm_stat_out" ]]; then
        local page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
        local wired=$(echo "$vm_stat_out" | awk -v ps="$page_size" '/Pages wired/{gsub(/\./,"",$NF); printf "%.0f", ($NF*ps)/1048576}')
        local active=$(echo "$vm_stat_out" | awk -v ps="$page_size" '/Pages active/{gsub(/\./,"",$NF); printf "%.0f", ($NF*ps)/1048576}')
        local compressed=$(echo "$vm_stat_out" | awk -v ps="$page_size" '/Pages occupied by compressor/{gsub(/\./,"",$NF); printf "%.0f", ($NF*ps)/1048576}')
        local free_mem=$(echo "$vm_stat_out" | awk -v ps="$page_size" '/Pages free/{gsub(/\./,"",$NF); printf "%.0f", ($NF*ps)/1048576}')
        ui_kv "  Memory" "Wired ${wired}MB | Active ${active}MB | Compressed ${compressed}MB | Free ${free_mem}MB"
    fi

    # ── Open files / process count (unique to dashboard) ──
    local proc_count=$(ps -A -o pid= 2>/dev/null | wc -l | tr -d ' ')
    ui_kv "  Processes" "${proc_count} running"
    echo ""

    echo "  ${BOLD}${PRIMARY}  Top Processes (by CPU)${RESET}"
    echo ""
    printf "  ${DIM}%-6s %-20s %6s %6s${RESET}\n" "PID" "NAME" "%CPU" "%MEM"
    ui_line 44
    get_top_processes 8 | while read -r line; do
        [[ -z "$line" ]] && continue
        local p_pid=$(echo "$line" | awk '{print $1}')
        local p_cpu=$(echo "$line" | awk '{print $(NF-1)}')
        local p_mem=$(echo "$line" | awk '{print $NF}')
        local p_name=$(echo "$line" | awk '{$1=""; $(NF-1)=""; $NF=""; gsub(/^ +| +$/,""); print}')
        [[ -z "$p_pid" ]] && continue
        printf "  ${HIGHLIGHT}%-6s${RESET} %-20s ${PRIMARY}%5s%%${RESET} ${DIM}%5s%%${RESET}\n" "$p_pid" "${p_name:0:20}" "$p_cpu" "$p_mem"
    done
    echo ""
    ui_box_bottom
    echo ""
}

# Dashboard style: Minimal — compact one-line gauges
show_dashboard_minimal() {
    clear
    echo ""
    echo "  ${BOLD}${PRIMARY}Mac Status${RESET}  ${DIM}$(date '+%H:%M')${RESET}"
    echo ""
    
    local cpu=$(get_cpu_load 2>/dev/null || echo "0")
    local cpu_int="${cpu%.*}"; [[ -z "$cpu_int" ]] && cpu_int=0
    local ram_used=$(get_memory_usage 2>/dev/null)
    local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    local total_mem=$(( ${mem_bytes:-0} / 1024 / 1024 ))
    [[ "$total_mem" -le 0 ]] 2>/dev/null && total_mem=16384
    local ram_pct=$(LC_ALL=C awk -v u="$ram_used" -v t="$total_mem" 'BEGIN{if(t>0){printf("%.0f",(u/t)*100)} else {print "0"}}')
    local disk_pct=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    [[ -z "$disk_pct" ]] && disk_pct=0
    
    printf "  ${DIM}CPU ${RESET}"; mini_bar "$cpu_int" 12; printf " ${HIGHLIGHT}%3d%%${RESET}" "$cpu_int"
    printf "  ${DIM}RAM ${RESET}"; mini_bar "$ram_pct" 12; printf " ${HIGHLIGHT}%3d%%${RESET}" "$ram_pct"
    printf "  ${DIM}DSK ${RESET}"; mini_bar "$disk_pct" 12; printf " ${HIGHLIGHT}%3d%%${RESET}" "$disk_pct"
    printf "\n\n"
    
    printf "  ${DIM}%-22s %5s${RESET}\n" "PROCESS" "%CPU"
    ui_line 30
    get_top_processes 5 | while IFS=' ' read -r pid cmd pcpu pmem rest; do
        [[ -z "$pid" ]] && continue
        printf "  %-22s ${PRIMARY}%5s%%${RESET}\n" "${cmd:0:22}" "$pcpu"
    done
    echo ""
}

# Dashboard style: Top-like (live-updating, rich)
show_dashboard_top() {
    local running=1
    trap 'tput cnorm 2>/dev/null || true; return 0' EXIT RETURN
    trap 'running=0' INT
    tput civis 2>/dev/null || true
    
    while [[ $running -eq 1 ]]; do
        local output=""
        local cpu=$(get_cpu_load 2>/dev/null || echo "0")
        local cpu_int="${cpu%.*}"; [[ -z "$cpu_int" ]] && cpu_int=0
        local ram_used=$(get_memory_usage 2>/dev/null || echo "0")
        local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
        local total_mem=$(( ${mem_bytes:-0} / 1024 / 1024 ))
        [[ "$total_mem" -le 0 ]] 2>/dev/null && total_mem=16384
        local ram_pct=$(LC_ALL=C awk -v u="$ram_used" -v t="$total_mem" 'BEGIN{if(t>0){printf("%.1f",(u/t)*100)} else {print "0.0"}}')
        local ram_pct_int="${ram_pct%.*}"
        local swap_used=$(sysctl -n vm.swapusage 2>/dev/null | awk '{print $7}')
        [[ -z "$swap_used" ]] && swap_used="0M"
        local disk_pct=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
        [[ -z "$disk_pct" ]] && disk_pct=0
        local batt_pct=$(pmset -g batt 2>/dev/null | grep -o "[0-9]*%" | head -1 | tr -d '%')
        
        output+=$'\n'"  ${BOLD}${PRIMARY}Live Dashboard${RESET}  ${DIM}$(date '+%H:%M:%S')  (q=quit  r=refresh)${RESET}"$'\n'
        output+=$'\n'

        # Inline bars — pre-format without ANSI subshell issues
        local cpu_bar_color="$SUCCESS"
        [[ $cpu_int -gt 85 ]] && cpu_bar_color="$ERROR"
        [[ $cpu_int -gt 50 && $cpu_int -le 85 ]] && cpu_bar_color="$WARNING"
        local cpu_filled=$(( cpu_int * 20 / 100 ))
        [[ $cpu_filled -gt 20 ]] && cpu_filled=20
        local cpu_bar="${DIM}[${RESET}${cpu_bar_color}"
        for ((i=0; i<cpu_filled; i++)); do cpu_bar+="$BAR_FULL"; done
        cpu_bar+="${RESET}${DIM}"
        for ((i=cpu_filled; i<20; i++)); do cpu_bar+="$BAR_EMPTY"; done
        cpu_bar+="]${RESET}"

        local ram_bar_color="$SUCCESS"
        [[ $ram_pct_int -gt 85 ]] && ram_bar_color="$ERROR"
        [[ $ram_pct_int -gt 60 && $ram_pct_int -le 85 ]] && ram_bar_color="$WARNING"
        local ram_filled=$(( ram_pct_int * 20 / 100 ))
        [[ $ram_filled -gt 20 ]] && ram_filled=20
        local ram_bar="${DIM}[${RESET}${ram_bar_color}"
        for ((i=0; i<ram_filled; i++)); do ram_bar+="$BAR_FULL"; done
        ram_bar+="${RESET}${DIM}"
        for ((i=ram_filled; i<20; i++)); do ram_bar+="$BAR_EMPTY"; done
        ram_bar+="]${RESET}"

        output+="  ${BOLD}CPU ${RESET} ${cpu_bar} ${HIGHLIGHT}${cpu}%${RESET}    "
        output+="${BOLD}RAM ${RESET} ${ram_bar} ${HIGHLIGHT}${ram_pct}%${RESET} (${ram_used}MB)"$'\n'
        output+="  ${DIM}Swap: ${swap_used}  Disk: ${disk_pct}%"
        [[ -n "$batt_pct" ]] && output+="  Batt: ${batt_pct}%"
        output+="${RESET}"$'\n\n'

        output+="  ${DIM}%-6s %-20s %6s %6s${RESET}"$'\n'
        output=$(printf "%s" "$output" | sed "s/%-6s/PID   /;s/%-20s/COMMAND             /;s/%6s/%CPU  /;s/%6s/%MEM  /")
        # Above is tricky in printf — just hardcode the header
        output="$(printf "\n  ${BOLD}${PRIMARY}Live Dashboard${RESET}  ${DIM}$(date '+%H:%M:%S')  (q=quit  r=refresh)${RESET}\n\n")"
        output+="  ${BOLD}CPU ${RESET} ${cpu_bar} ${HIGHLIGHT}${cpu}%${RESET}    "
        output+="${BOLD}RAM ${RESET} ${ram_bar} ${HIGHLIGHT}${ram_pct}%${RESET} (${ram_used}MB)"$'\n'
        output+="  ${DIM}Swap: ${swap_used}  Disk: ${disk_pct}%"
        [[ -n "$batt_pct" ]] && output+="  Batt: ${batt_pct}%"
        output+="${RESET}"$'\n\n'
        output+="  ${DIM}PID    COMMAND              %CPU   %MEM${RESET}"$'\n'
        output+="$(get_top_processes 12 | while IFS=' ' read -r pid comm pcpu pmem; do
            [[ -z "$pid" ]] && continue
            printf "  ${HIGHLIGHT}%-6s${RESET} %-20s ${PRIMARY}%5s%%${RESET} ${DIM}%5s%%${RESET}\n" "$pid" "${comm:0:20}" "$pcpu" "$pmem"
        done)"$'\n\n'
        output+="  ${DIM}Live updating...${RESET}"$'\n'
        
        tput clear 2>/dev/null || printf "\033[2J\033[H"
        echo "$output"
        
        read -t 1 -n 1 key 2>/dev/null
        case "$key" in
            q|Q|0) running=0 ;;
            r|R) continue ;;
        esac
    done
    
    tput cnorm 2>/dev/null || true
    trap - EXIT RETURN INT
    return 0
}

# Dashboard style: Animated bars — per-process visual CPU bars
show_dashboard_animated() {
    local running=1
    trap 'tput cnorm 2>/dev/null || true; return 0' EXIT RETURN
    trap 'running=0' INT
    tput civis 2>/dev/null || true
    
    while [[ $running -eq 1 ]]; do
        local output=""
        local cpu=$(get_cpu_load 2>/dev/null || echo "0")
        cpu="${cpu%\%}"; cpu="${cpu/,/.}"; [[ -z "$cpu" ]] && cpu=0
        local cpu_int="${cpu%.*}"; [[ -z "$cpu_int" ]] && cpu_int=0
        
        local ram_used=$(get_memory_usage 2>/dev/null || echo "0")
        local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
        local total_mem=$(( ${mem_bytes:-0} / 1024 / 1024 ))
        [[ "$total_mem" -le 0 ]] 2>/dev/null && total_mem=16384
        local ram_pct=$(LC_ALL=C awk -v u="$ram_used" -v t="$total_mem" 'BEGIN{if(t>0){printf("%.0f",(u/t)*100)} else {print "0"}}')
        local disk_pct=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
        [[ -z "$disk_pct" ]] && disk_pct=0

        output+=$'\n'"  ${BOLD}${PRIMARY}Animated Dashboard${RESET}  ${DIM}$(date '+%H:%M:%S')  (q=quit)${RESET}"$'\n\n'
        
        # CPU wide bar
        local bw=40
        local cpu_f=$(( cpu_int * bw / 100 )); [[ $cpu_f -gt $bw ]] && cpu_f=$bw
        local cc="$SUCCESS"; [[ $cpu_int -gt 85 ]] && cc="$ERROR"; [[ $cpu_int -gt 50 && $cpu_int -le 85 ]] && cc="$WARNING"
        output+="  ${BOLD}CPU  ${RESET}${DIM}[${RESET}${cc}"
        for ((i=0;i<cpu_f;i++)); do output+="$BAR_FULL"; done
        output+="${RESET}${DIM}"
        for ((i=cpu_f;i<bw;i++)); do output+="$BAR_EMPTY"; done
        output+="]${RESET} ${HIGHLIGHT}${cpu}%${RESET}"$'\n'
        
        # RAM wide bar
        local ram_f=$(( ram_pct * bw / 100 )); [[ $ram_f -gt $bw ]] && ram_f=$bw
        local rc="$SUCCESS"; [[ $ram_pct -gt 85 ]] && rc="$ERROR"; [[ $ram_pct -gt 60 && $ram_pct -le 85 ]] && rc="$WARNING"
        output+="  ${BOLD}RAM  ${RESET}${DIM}[${RESET}${rc}"
        for ((i=0;i<ram_f;i++)); do output+="$BAR_FULL"; done
        output+="${RESET}${DIM}"
        for ((i=ram_f;i<bw;i++)); do output+="$BAR_EMPTY"; done
        output+="]${RESET} ${HIGHLIGHT}${ram_pct}%${RESET} ${DIM}(${ram_used}MB)${RESET}"$'\n'
        
        # Disk wide bar
        local dk_f=$(( disk_pct * bw / 100 )); [[ $dk_f -gt $bw ]] && dk_f=$bw
        local dc="$SUCCESS"; [[ $disk_pct -gt 90 ]] && dc="$ERROR"; [[ $disk_pct -gt 75 && $disk_pct -le 90 ]] && dc="$WARNING"
        output+="  ${BOLD}DISK ${RESET}${DIM}[${RESET}${dc}"
        for ((i=0;i<dk_f;i++)); do output+="$BAR_FULL"; done
        output+="${RESET}${DIM}"
        for ((i=dk_f;i<bw;i++)); do output+="$BAR_EMPTY"; done
        output+="]${RESET} ${HIGHLIGHT}${disk_pct}%${RESET}"$'\n\n'
        
        output+="  ${BOLD}${PRIMARY}Top Processes:${RESET}"$'\n'
        
        local proc_output
        proc_output=$(get_top_processes 8)
        
        while IFS=' ' read -r pid comm pcpu pmem; do
            [[ -z "$pid" ]] && continue
            local pbar_width=22
            pcpu="${pcpu/,/.}"
            pcpu="${pcpu%.*}"
            [[ -z "$pcpu" ]] && pcpu=0
            local pfilled=$(( pcpu * pbar_width / 100 ))
            [[ $pfilled -lt 0 ]] && pfilled=0
            [[ $pfilled -gt $pbar_width ]] && pfilled=$pbar_width
            local pc="$SUCCESS"; [[ $pcpu -gt 50 ]] && pc="$ERROR"; [[ $pcpu -gt 20 && $pcpu -le 50 ]] && pc="$WARNING"
            local pbar="${DIM}[${RESET}${pc}"
            for ((i=0;i<pfilled;i++)); do pbar+="$BAR_FULL"; done
            pbar+="${RESET}${DIM}"
            for ((i=pfilled;i<pbar_width;i++)); do pbar+="$BAR_EMPTY"; done
            pbar+="]${RESET}"
            output+="  ${HIGHLIGHT}$(printf '%-18s' "${comm:0:18}")${RESET} ${pbar} ${HIGHLIGHT}${pcpu}%${RESET}"$'\n'
        done <<< "$proc_output"
        
        output+=$'\n'"  ${DIM}Live updating...${RESET}"$'\n'
        
        tput clear 2>/dev/null || printf "\033[2J\033[H"
        echo "$output"
        
        read -t 1 -n 1 key 2>/dev/null
        case "$key" in
            q|Q|0) running=0 ;;
        esac
    done
    
    tput cnorm 2>/dev/null || true
    trap - EXIT RETURN INT
    return 0
}

# ============================================================================
# UI TOOLKIT (Beautiful, themed, consistent)
# ============================================================================

# ---- Themed box drawing helpers ----

# Draw a themed horizontal line spanning $1 chars (default 58)
ui_line() {
    local w="${1:-58}"
    local i
    printf "  ${DIM}"
    for ((i=0; i<w; i++)); do printf "%s" "$BOX_H"; done
    printf "${RESET}\n"
}

# Draw a themed box header:  ╭── Title ──────────────────────╮
ui_box_top() {
    local title="$1"
    local w=58
    local tlen=${#title}
    local pad=$(( w - tlen - 4 ))
    [[ $pad -lt 2 ]] && pad=2
    printf "  ${PRIMARY}%s%s%s " "$BOX_TL" "$BOX_H" "$BOX_H"
    printf "${BOLD}%s${RESET}${PRIMARY} " "$title"
    for ((i=0; i<pad; i++)); do printf "%s" "$BOX_H"; done
    printf "%s${RESET}\n" "$BOX_TR"
}

# Draw a themed box bottom
ui_box_bottom() {
    local w=58
    printf "  ${PRIMARY}%s" "$BOX_BL"
    for ((i=0; i<w; i++)); do printf "%s" "$BOX_H"; done
    printf "%s${RESET}\n" "$BOX_BR"
}

# Draw a themed box content line
ui_box_row() {
    echo "  ${PRIMARY}${BOX_V}${RESET}  $1"
}

# Draw a themed separator inside a box
ui_box_sep() {
    local w=58
    printf "  ${DIM}%s" "$BOX_LT"
    for ((i=0; i<w; i++)); do printf "%s" "$BOX_H"; done
    printf "%s${RESET}\n" "$BOX_RT"
}

# ---- Mini bar (inline gauge) ----
# Usage: mini_bar <percent> [width] [color]
# Returns string like: [████████··········] 45%
mini_bar() {
    local pct="${1:-0}"
    local w="${2:-20}"
    local clr="${3:-$PRIMARY}"
    [[ "$pct" -gt 100 ]] 2>/dev/null && pct=100
    [[ "$pct" -lt 0 ]]   2>/dev/null && pct=0
    local filled=$(( pct * w / 100 ))
    local empty=$(( w - filled ))
    local bar_color="$clr"
    # Auto-color by severity
    if [[ "$pct" -gt 85 ]]; then bar_color="$ERROR"
    elif [[ "$pct" -gt 65 ]]; then bar_color="$WARNING"
    else bar_color="$SUCCESS"
    fi
    printf "${DIM}[${RESET}"
    printf "${bar_color}"
    for ((i=0; i<filled; i++)); do printf "%s" "$BAR_FULL"; done
    printf "${RESET}${DIM}"
    for ((i=0; i<empty; i++)); do printf "%s" "$BAR_EMPTY"; done
    printf "]${RESET}"
}

# ---- Status badge (OK/WARN/FAIL/INFO) ----
ui_badge() {
    local badge_status="$1"
    local title="$2"
    local message="$3"
    
    local icon color
    case "$badge_status" in
        OK)   icon="$ICON_OK";   color="$SUCCESS" ;;
        WARN) icon="$ICON_WARN"; color="$WARNING" ;;
        FAIL) icon="$ICON_FAIL"; color="$ERROR" ;;
        INFO) icon="$ICON_INFO"; color="$INFO" ;;
        *)    icon="$ICON_INFO"; color="$PRIMARY" ;;
    esac
    
    if [[ -n "$message" ]]; then
        printf "  ${color}%s${RESET} ${BOLD}%-8s${RESET} %s\n" "$icon" "$title" "$message"
    else
        printf "  ${color}%s${RESET} ${BOLD}%s${RESET}\n" "$icon" "$title"
    fi
}

# Status badge with inline bar: ✅ CPU   [████··········] 23%
ui_badge_bar() {
    local badge_status="$1" title="$2" pct="$3" extra="${4:-}"
    local icon color
    case "$badge_status" in
        OK)   icon="$ICON_OK";   color="$SUCCESS" ;;
        WARN) icon="$ICON_WARN"; color="$WARNING" ;;
        FAIL) icon="$ICON_FAIL"; color="$ERROR" ;;
        INFO) icon="$ICON_INFO"; color="$INFO" ;;
        *)    icon="$ICON_INFO"; color="$PRIMARY" ;;
    esac
    printf "  ${color}%s${RESET} ${BOLD}%-8s${RESET} " "$icon" "$title"
    mini_bar "$pct" 18
    printf " ${HIGHLIGHT}%3d%%${RESET}" "$pct"
    [[ -n "$extra" ]] && printf "  ${DIM}%s${RESET}" "$extra"
    printf "\n"
}

# Key-value pair (compact, themed)
ui_kv() {
    local key="$1"
    local value="$2"
    printf "  ${DIM}%-24s${RESET} ${HIGHLIGHT}%s${RESET}\n" "${key}" "${value}"
}

# Section divider
ui_hr() {
    ui_line 58
}

# Explanation text (dimmed)
ui_explain() {
    echo "  ${DIM}${ITALIC}${1}${RESET}"
}

# Numbered list item
ui_list_item() {
    local number="$1"
    local label="$2"
    local description="${3:-}"
    
    if [[ -n "$description" ]]; then
        printf "  ${HIGHLIGHT}%2s${RESET}${DIM})${RESET} ${BOLD}${PRIMARY}%-22s${RESET}  ${DIM}%s${RESET}\n" "$number" "$label" "$description"
    else
        printf "  ${HIGHLIGHT}%2s${RESET}${DIM})${RESET} ${BOLD}${PRIMARY}%s${RESET}\n" "$number" "$label"
    fi
}

# Simple progress bar
ui_progress() {
    local percent="$1"
    local width=30
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    
    printf "  ${DIM}[${RESET}${SUCCESS}"
    for ((i=0; i<filled; i++)); do printf "%s" "$BAR_FULL"; done
    printf "${RESET}${DIM}"
    for ((i=0; i<empty; i++)); do printf "%s" "$BAR_EMPTY"; done
    printf "] ${HIGHLIGHT}%3d%%${RESET}\n" "$percent"
}

# Toast feedback
ui_toast() {
    local message="$1"
    local toast_status="${2:-INFO}"
    local icon color
    case "$toast_status" in
        OK)   icon="$ICON_OK"; color="$SUCCESS" ;;
        WARN) icon="$ICON_WARN"; color="$WARNING" ;;
        FAIL) icon="$ICON_FAIL"; color="$ERROR" ;;
        *)    icon="$ICON_INFO"; color="$INFO" ;;
    esac
    echo ""
    echo "  ${color}${icon}${RESET} ${message}"
    echo ""
}

# Read one line from the active terminal when possible; fallback to stdin.
read_user_line() {
    local target_var="$1"
    local value=""

    if [[ -t 0 ]]; then
        IFS= read -r value || return 1
    elif [[ -t 1 ]]; then
        IFS= read -r value < /dev/tty || return 1
    else
        IFS= read -r value || return 1
    fi

    printf -v "$target_var" "%s" "$value"
    return 0
}

# Menu choice validation
ui_choose() {
    local prompt="${1:-Choice}"
    local max_choice="${2:-1}"
    local choice
    
    while true; do
        echo -n "  👉 ${prompt} [0-${max_choice}]: " >&2
        read_user_line choice || { echo "0"; return 0; }
        
        [[ -z "$choice" ]] && continue
        [[ ! "$choice" =~ ^[0-9]+$ ]] && { echo "  ${ERROR}Invalid input${RESET}" >&2; continue; }
        # Allow 0 as valid choice (for "Back" or "Exit" options)
        if [[ $choice -lt 0 ]] || [[ $choice -gt $max_choice ]]; then
            echo "  ${ERROR}Choose 0-${max_choice}${RESET}" >&2
            continue
        fi
        
        echo "$choice"
        return 0
    done
}

# Yes/No confirmation
ui_confirm() {
    local prompt="$1"
    local response
    
    echo ""
    echo "${YELLOW}${prompt}${RESET}"
    echo -n "  (y/n) [n]: "
    read_user_line response || response=""
    
    [[ "$response" =~ ^[Yy]$ ]] && return 0
    return 1
}

# Type-to-confirm for risky actions
ui_confirm_risky() {
    local action="$1"
    local description="$2"
    local backup_path="$3"
    
    echo ""
    echo "  ${RED}${BOLD}⚠️  CONFIRM: ${action}${RESET}"
    echo "  ${description}"
    [[ -n "$backup_path" ]] && echo "  ${GREEN}💾 Backup: ${backup_path}${RESET}"
    echo ""
    echo "  Type ${BOLD}${action}${RESET} to proceed, press Ctrl+C to cancel"
    echo ""
    
    echo -n "  Confirm: "
    local confirmation
    read_user_line confirmation || confirmation=""
    
    if [[ "$confirmation" == "$action" ]]; then
        return 0
    else
        echo "  ${YELLOW}Cancelled.${RESET}"
        return 1
    fi
}

# Pause and continue
pause_continue() {
    echo ""
    echo "  👉 Press Enter to continue..."
    local tmp
    read_user_line tmp || true
}

# Pause with option to exit (0) or continue
pause_or_exit() {
    echo ""
    echo "  0) Back to previous menu"
    echo -n "  👉 Press Enter or '0' to exit: "
    read_user_line choice || choice=""
    [[ "$choice" == "0" ]] && return 1
    return 0
}
safe_sleep_frac() {
    # macOS sleep natively supports fractional seconds.
    local duration="${1/,/.}"
    sleep "$duration" 2>/dev/null || sleep "${duration%.*}" 2>/dev/null || true
}

ui_title() {
    echo "${BOLD}${CYAN}$1${RESET}"
}

ui_subtitle() {
    echo "${CYAN}$1${RESET}"
}

ui_hint() {
    echo "${ITALIC}${YELLOW}$1${RESET}"
}

ui_divider() {
    echo "${TEAL}------------------------------------------------------------------------------${RESET}"
}

mode_description() {
    case "$MODE" in
        SAFE) echo "Read-only checks and low-risk actions only." ;;
        FULL) echo "Includes advanced and potentially disruptive actions." ;;
        *) echo "Balanced diagnostics and maintenance actions." ;;
    esac
}

log_action() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
    REPORT_BUFFER+="$msg\n"
}

add_to_report() {
    REPORT_BUFFER+="$1\n"
}

# Print to terminal and append to report buffer (for Ultra scan / consistent logging).
report_print() {
    local line="$1"
    echo "$line"
    REPORT_BUFFER+="$line\n"
}

check_brew() {
    if command -v brew &> /dev/null; then
        return 0
    else
        return 1
    fi
}

color_label() {
    case "$1" in
        "Critical" | "Pressure") echo "${RED}$1${RESET}" ;;
        "High") echo "${ORANGE}$1${RESET}" ;;
        "Moderate") echo "${YELLOW}$1${RESET}" ;;
        *) echo "${GREEN}$1${RESET}" ;;
    esac
}

# Ensure proper directories exist and check dependencies
init_system() {
    mkdir -p "$BIN_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CACHE_DIR"
    touch "$LOG_FILE"
    
    # Load settings first (if they exist)
    load_settings
    
    # Check if this is first run (no settings file exists)
    if [[ $FIRST_RUN -eq 1 ]] && [[ ! -f "$SETTINGS_FILE" ]]; then
        first_run_setup
        FIRST_RUN=0
    fi
    
    # Apply theme and icons
    apply_theme
    set_icons_for_current_theme
    
    # Check Architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" != "arm64" ]]; then
        echo "${ERROR}Warning: This script is optimized for Apple Silicon. Intel Macs may experience reduced functionality.${RESET}"
        sleep 1
    fi

    # Optional dependency bootstrap (explicitly controlled in Settings).
    if [[ $AUTO_INSTALL -eq 1 ]]; then
        if check_brew; then
            ensure_brew_dep "jq" "jq"
            ensure_brew_dep "smartmontools" "smartctl"
            ensure_brew_dep "python3" "python3"
        else
            status_line INFO "Homebrew" "Not installed. Auto-install skipped."
        fi
    fi
}

# Run command; capture exit code. Usage: run_cmd "description" cmd [args...]
# Returns 0 on success. On failure, logs and prints message, returns 1.
run_cmd() {
    local desc="$1"
    shift
    "$@" 2>/dev/null
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        echo "${RED}$desc failed (exit $ret). Skipping.${RESET}"
        log_action "FAIL: $desc (exit $ret)"
        return 1
    fi
    return 0
}

# Print a line to the terminal and (optionally) to the report buffer.
# - REPORT_CAPTURE=1 enables capture into REPORT_BUFFER (used by Ultra report sections).
out() {
    local line="$1"
    echo "$line"
    if [[ ${REPORT_CAPTURE:-0} -eq 1 ]]; then
        REPORT_BUFFER+="$line\n"
    fi
}

status_line() {
    # Usage: status_line OK|WARN|FAIL|INFO "Title" "Message" - Uses theme colors
    local level="$1"
    local title="$2"
    local msg="$3"
    local icon color
    case "$level" in
        OK)   icon="$ICON_OK";   color="$SUCCESS"  ;;
        WARN) icon="$ICON_WARN"; color="$WARNING" ;;
        FAIL) icon="$ICON_FAIL"; color="$ERROR"    ;;
        INFO) icon="$ICON_INFO"; color="$INFO"   ;;
        *)    icon="$ICON_INFO"; color="$PRIMARY"   ;;
    esac
    if [[ -n "$msg" ]]; then
        out "   ${color}${icon} ${title}${RESET} — ${msg}"
    else
        out "   ${color}${icon} ${title}${RESET}"
    fi
}

section_title() {
    # Usage: section_title "Title" - Uses theme colors
    out ""
    out "${BOLD}${PRIMARY}$1${RESET}"
}

explain() {
    # Usage: explain "What this means..." - Uses theme colors
    out "   ${ITALIC}${DIM}$1${RESET}"
}

strip_ansi() {
    # Usage: strip_ansi "text"
    # Strip ANSI escape codes from a string.
    echo "$1" | sed $'s/\x1b\\[[0-9;]*m//g'
}

# Check if a command exists. Usage: require_cmd "cmdname"
# - Returns 0 if available, 1 if missing (and prints a consistent message).
require_cmd() {
    local cmdname="$1"
    if command -v "$cmdname" &> /dev/null; then
        return 0
    fi
    status_line WARN "$cmdname" "not available on this system."
    return 1
}

load_settings() {
    [[ -f "$SETTINGS_FILE" ]] || return 0

    local key value
    while IFS='=' read -r key value; do
        key="${key#${key%%[![:space:]]*}}"; key="${key%${key##*[![:space:]]}}"
        value="${value#${value%%[![:space:]]*}}"; value="${value%${value##*[![:space:]]}}"
        [[ -z "$key" || "$key" == \#* ]] && continue
        
        case "$key" in
            MODE)          [[ "$value" == SAFE || "$value" == STANDARD || "$value" == FULL ]] && MODE="$value" ;;
            AUTO_INSTALL)  [[ "$value" == "0" || "$value" == "1" ]] && AUTO_INSTALL="$value" ;;
            USE_EMOJI)     [[ "$value" == "0" || "$value" == "1" ]] && USE_EMOJI="$value" ;;
            SHOW_PREFLIGHT) [[ "$value" == "0" || "$value" == "1" ]] && SHOW_PREFLIGHT="$value" ;;
            THEME)
                case "$value" in
                    bronze|steampunk|terminal|hacker|neon|cyberpunk|amber|retro|classic|minimal|monochrome|frost|nord|solar|solarized|midnight|dracula|atom|onedark|warm|gruvbox) THEME="$value" ;;
                esac ;;
            RESULT_STYLE)
                case "$value" in cards|table|dashboard|summary|visual) RESULT_STYLE="$value" ;; esac ;;
            USER_LEVEL)
                case "$value" in beginner|intermediate|advanced|expert|power|hacker) USER_LEVEL="$value" ;; esac ;;
            DASHBOARD_STYLE)
                case "$value" in top_like|static|animated|minimal) DASHBOARD_STYLE="$value" ;; esac ;;
            COMPACT_MODE)          [[ "$value" == "0" || "$value" == "1" ]] && COMPACT_MODE="$value" ;;
            SHOW_TECHNICAL_DETAILS) [[ "$value" == "0" || "$value" == "1" ]] && SHOW_TECHNICAL_DETAILS="$value" ;;
            HOME_SHOW_BATTERY)     [[ "$value" == "0" || "$value" == "1" ]] && HOME_SHOW_BATTERY="$value" ;;
            HOME_SHOW_NETWORK)     [[ "$value" == "0" || "$value" == "1" ]] && HOME_SHOW_NETWORK="$value" ;;
            HOME_SHOW_UPTIME)      [[ "$value" == "0" || "$value" == "1" ]] && HOME_SHOW_UPTIME="$value" ;;
            HOME_SHOW_THERMAL)     [[ "$value" == "0" || "$value" == "1" ]] && HOME_SHOW_THERMAL="$value" ;;
            ANALYSIS_DEPTH)
                case "$value" in quick|standard|thorough) ANALYSIS_DEPTH="$value" ;; esac ;;
        esac
    done < "$SETTINGS_FILE"
    
    apply_theme
    export MODE AUTO_INSTALL USE_EMOJI SHOW_PREFLIGHT THEME RESULT_STYLE USER_LEVEL
    export DASHBOARD_STYLE COMPACT_MODE SHOW_TECHNICAL_DETAILS ANALYSIS_DEPTH
}

save_settings() {
    mkdir -p "$CONFIG_DIR" 2>/dev/null || {
        status_line FAIL "Save Settings" "Could not create config directory"
        return 1
    }
    
    local tmpfile="$CONFIG_DIR/settings.conf.tmp$$"
    (
        umask 077
        cat > "$tmpfile" <<EOF
# MacDoctor settings — auto-generated
MODE=$MODE
USE_EMOJI=$USE_EMOJI
SHOW_PREFLIGHT=$SHOW_PREFLIGHT
THEME=$THEME
RESULT_STYLE=$RESULT_STYLE
USER_LEVEL=$USER_LEVEL
DASHBOARD_STYLE=$DASHBOARD_STYLE
COMPACT_MODE=$COMPACT_MODE
SHOW_TECHNICAL_DETAILS=$SHOW_TECHNICAL_DETAILS
HOME_SHOW_BATTERY=$HOME_SHOW_BATTERY
HOME_SHOW_NETWORK=$HOME_SHOW_NETWORK
HOME_SHOW_UPTIME=$HOME_SHOW_UPTIME
HOME_SHOW_THERMAL=$HOME_SHOW_THERMAL
ANALYSIS_DEPTH=$ANALYSIS_DEPTH
EOF
    ) 2>/dev/null || {
        status_line FAIL "Save Settings" "Could not write to temp file"
        rm -f "$tmpfile"
        return 1
    }
    
    mv "$tmpfile" "$SETTINGS_FILE" 2>/dev/null || {
        status_line FAIL "Save Settings" "Could not move temp file to settings"
        rm -f "$tmpfile"
        return 1
    }
    
    chmod 644 "$SETTINGS_FILE" 2>/dev/null
    export MODE AUTO_INSTALL USE_EMOJI SHOW_PREFLIGHT THEME RESULT_STYLE USER_LEVEL
    export DASHBOARD_STYLE COMPACT_MODE SHOW_TECHNICAL_DETAILS ANALYSIS_DEPTH
    return 0
}

get_uptime_pretty() {
    local up_raw
    up_raw=$(LC_ALL=C uptime 2>/dev/null)
    if [[ -z "$up_raw" ]]; then
        echo "N/A"
        return
    fi
    echo "$up_raw" | sed -E 's/^.* up //; s/, [0-9]+ users?,.*$//; s/, load averages:.*$//' | xargs
}

# ============================================================================
# FIRST-RUN SETUP (Guided configuration)
# ============================================================================

first_run_setup() {
    clear
    echo ""
    echo "${BOLD}${PRIMARY}╔═══════════════════════════════════════════════════════════════╗${RESET}"
    echo "${BOLD}${PRIMARY}║${RESET}                                                           ${BOLD}${PRIMARY}║${RESET}"
    echo "${BOLD}${PRIMARY}║${RESET}  ${BOLD}Welcome to MacDoctor v${VERSION}${RESET}"
    echo "${BOLD}${PRIMARY}║${RESET}  ${DIM}Let's customize your experience${RESET}"
    echo "${BOLD}${PRIMARY}║${RESET}                                                           ${BOLD}${PRIMARY}║${RESET}"
    echo "${BOLD}${PRIMARY}╚═══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    # Step 1: Choose Theme
    echo "${BOLD}${PRIMARY}Step 1/5: Choose Your Theme${RESET}"
    echo ""
    echo "  ${DIM}Pick a visual style that matches your vibe:${RESET}"
    echo ""
    echo "  1) ${BOLD}Bronze${RESET} - Warm orange/gold tones"
    echo "  2) ${BOLD}Terminal${RESET} - Classic green-on-dark"
    echo "  3) ${BOLD}Neon${RESET} - Vibrant magenta/cyan"
    echo "  4) ${BOLD}Amber${RESET} - Vintage amber glow"
    echo "  5) ${BOLD}Classic${RESET} - Clean blue/cyan (default)"
    echo "  6) ${BOLD}Minimal${RESET} - Greyscale, distraction-free"
    echo "  7) ${BOLD}Frost${RESET} - Cool arctic blues"
    echo "  8) ${BOLD}Solar${RESET} - Precision color palette"
    echo "  9) ${BOLD}Midnight${RESET} - Deep purple dark theme"
    echo "  10) ${BOLD}Atom${RESET} - Modern dark blue"
    echo "  11) ${BOLD}Warm${RESET} - Earthy retro tones"
    echo ""
    
    local theme_choice
    theme_choice=$(ui_choose "Select theme" 11)
    
    case $theme_choice in
        1) THEME="bronze" ;;
        2) THEME="terminal" ;;
        3) THEME="neon" ;;
        4) THEME="amber" ;;
        5) THEME="classic" ;;
        6) THEME="minimal" ;;
        7) THEME="frost" ;;
        8) THEME="solar" ;;
        9) THEME="midnight" ;;
        10) THEME="atom" ;;
        11) THEME="warm" ;;
    esac
    
    apply_theme
    preview_theme "$THEME"
    echo ""
    echo "  ${SUCCESS}Theme applied!${RESET}"
    echo ""
    pause_continue
    
    # Step 2: Choose Result Style
    clear
    echo ""
    echo "${BOLD}${PRIMARY}Step 2/5: How Should Results Be Displayed?${RESET}"
    echo ""
    echo "  ${DIM}Choose how scan results appear:${RESET}"
    echo ""
    echo "  1) ${BOLD}Cards${RESET} - Boxed cards with clear sections"
    echo "  2) ${BOLD}Table${RESET} - Clean table format"
    echo "  3) ${BOLD}Dashboard${RESET} - Dashboard view with graphs"
    echo "  4) ${BOLD}Summary${RESET} - Summary first, details on demand"
    echo "  5) ${BOLD}Visual${RESET} - Visual bars and progress indicators"
    echo ""
    
    local style_choice
    style_choice=$(ui_choose "Select result style" 5)
    
    case $style_choice in
        1) RESULT_STYLE="cards" ;;
        2) RESULT_STYLE="table" ;;
        3) RESULT_STYLE="dashboard" ;;
        4) RESULT_STYLE="summary" ;;
        5) RESULT_STYLE="visual" ;;
    esac
    
    echo ""
    echo "  ${SUCCESS}Result style set to: ${RESULT_STYLE}${RESET}"
    echo ""
    pause_continue
    
    # Step 3: Choose User Level
    clear
    echo ""
    echo "${BOLD}${PRIMARY}Step 3/5: What's Your Experience Level?${RESET}"
    echo ""
    echo "  ${DIM}This affects which features are shown:${RESET}"
    echo ""
    echo "  1) ${BOLD}Beginner${RESET} - Simple options, clear explanations"
    echo "  2) ${BOLD}Intermediate${RESET} - More features, some technical terms"
    echo "  3) ${BOLD}Advanced${RESET} - All features, technical details"
    echo "  4) ${BOLD}Expert${RESET} - Full control, advanced tools"
    echo "  5) ${BOLD}Power User${RESET} - Everything unlocked"
    echo ""
    
    local level_choice
    level_choice=$(ui_choose "Select your level" 5)
    
    case $level_choice in
        1) USER_LEVEL="beginner" ;;
        2) USER_LEVEL="intermediate" ;;
        3) USER_LEVEL="advanced" ;;
        4) USER_LEVEL="expert" ;;
        5) USER_LEVEL="power" ;;
    esac
    
    echo ""
    echo "  ${SUCCESS}User level set to: ${USER_LEVEL}${RESET}"
    echo ""
    pause_continue
    
    # Step 4: Choose Dashboard Style
    clear
    echo ""
    echo "${BOLD}${PRIMARY}Step 4/5: Dashboard Style for Live Processes${RESET}"
    echo ""
    echo "  ${DIM}How should the live dashboard update?${RESET}"
    echo ""
    echo "  1) ${BOLD}Top-like${RESET} - Updates every second (like top/htop)"
    echo "  2) ${BOLD}Static${RESET} - Snapshot, refresh manually"
    echo "  3) ${BOLD}Animated${RESET} - Animated bars for CPU/RAM"
    echo "  4) ${BOLD}Minimal${RESET} - Simple list, top 5-10 processes"
    echo ""
    
    local dash_choice
    dash_choice=$(ui_choose "Select dashboard style" 4)
    
    case $dash_choice in
        1) DASHBOARD_STYLE="top_like" ;;
        2) DASHBOARD_STYLE="static" ;;
        3) DASHBOARD_STYLE="animated" ;;
        4) DASHBOARD_STYLE="minimal" ;;
    esac
    
    echo ""
    echo "  ${SUCCESS}Dashboard style set to: ${DASHBOARD_STYLE}${RESET}"
    echo ""
    pause_continue
    
    # Step 5: Extras
    clear
    echo ""
    echo "${BOLD}${PRIMARY}Step 5/5: Additional Preferences${RESET}"
    echo ""
    if ui_confirm "Use emojis in interface? (recommended)"; then
        USE_EMOJI=1
    else
        USE_EMOJI=0
    fi
    
    set_icons_for_current_theme
    
    # Save all settings
    save_settings
    
    clear
    echo ""
    echo "${BOLD}${SUCCESS}╔═══════════════════════════════════════════════════════════════╗${RESET}"
    echo "${BOLD}${SUCCESS}║${RESET}                                                           ${BOLD}${SUCCESS}║${RESET}"
    echo "${BOLD}${SUCCESS}║${RESET}  ${BOLD}✅ Setup Complete!${RESET}"
    echo "${BOLD}${SUCCESS}║${RESET}"
    echo "${BOLD}${SUCCESS}║${RESET}  Theme: $(capitalize_first "$THEME")"
    echo "${BOLD}${SUCCESS}║${RESET}  Result Style: $(capitalize_first "$RESULT_STYLE")"
    echo "${BOLD}${SUCCESS}║${RESET}  User Level: $(capitalize_first "$USER_LEVEL")"
    echo "${BOLD}${SUCCESS}║${RESET}  Dashboard: $(capitalize_first "$DASHBOARD_STYLE")"
    echo "${BOLD}${SUCCESS}║${RESET}"
    echo "${BOLD}${SUCCESS}║${RESET}  ${DIM}You can change these anytime in Settings${RESET}"
    echo "${BOLD}${SUCCESS}║${RESET}                                                           ${BOLD}${SUCCESS}║${RESET}"
    echo "${BOLD}${SUCCESS}╚═══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    pause_continue
}

# Ensure a Homebrew dependency is installed, based on a real binary name.
# Usage: ensure_brew_dep "brew_package_name" "binary_name"
ensure_brew_dep() {
    local pkg="$1"
    local bin="$2"

    command -v "$bin" &> /dev/null && return 0

    if [[ ${AUTO_INSTALL:-0} -ne 1 ]]; then
        return 1
    fi
    if ! check_brew; then
        return 1
    fi

    out "${YELLOW}Installing missing dependency: ${pkg} (for ${bin})...${RESET}"
    if brew install "$pkg" &> /dev/null; then
        return 0
    fi

    status_line WARN "Homebrew" "Install failed for $pkg. Skipping."
    log_action "FAIL: Homebrew install failed for $pkg"
    return 1
}

# Confirm a risky/destructive action.
# Usage: confirm_dangerous "What will happen" "TYPE_THIS_WORD"
confirm_dangerous() {
    local what="$1"
    local codeword="$2"
    out "${BG_RED}${BOLD}WARNING${RESET} ${YELLOW}${what}${RESET}"
    out "   Type ${BOLD}${codeword}${RESET} to confirm, or press Enter to cancel."
    echo -n "   Confirm: "
    local resp
    read_user_line resp || resp=""
    [[ "$resp" == "$codeword" ]]
}

# --- LIGHTWEIGHT CACHE HELPERS (FILE-BASED, TTL) ---
_cache_path_for_key() {
    local key="$1"
    # Keep filename safe and stable.
    local safe_key
    safe_key=$(echo "$key" | tr '/ :\t' '____' | tr -cd 'A-Za-z0-9._-')
    echo "$CACHE_DIR/${safe_key}.cache"
}

cache_get() {
    # Usage: cache_get "key" ttl_seconds cmd [args...]
    # Prints cached output to stdout, or runs the command and caches it.
    local key="$1"
    local ttl="$2"
    shift 2
    local path="$(_cache_path_for_key "$key")"

    if [[ -f "$path" ]]; then
        local now mtime age
        now=$(date +%s)
        mtime=$(stat -f %m "$path" 2>/dev/null || echo 0)
        age=$(( now - mtime ))
        if [[ $age -ge 0 && $age -le $ttl ]]; then
            cat "$path"
            return 0
        fi
    fi

    # Refresh cache
    "$@" > "$path" 2>/dev/null
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        rm -f "$path" 2>/dev/null
        return $ret
    fi
    cat "$path"
}

preflight_summary() {
    # Preflight is intentionally quiet by default (no bloat).
    # It only shows when something important is missing, or when SHOW_PREFLIGHT=1.
    local required_cmds=(awk df top vm_stat python3)
    local optional_cmds=(bc memory_pressure smartctl powermetrics mactop asitop macmon nettop fs_usage)

    local missing_required=()
    local missing_optional=()

    local c
    for c in "${required_cmds[@]}"; do
        command -v "$c" &> /dev/null || missing_required+=("$c")
    done
    for c in "${optional_cmds[@]}"; do
        command -v "$c" &> /dev/null || missing_optional+=("$c")
    done

    if [[ ${SHOW_PREFLIGHT:-0} -ne 1 && ${#missing_required[@]} -eq 0 ]]; then
        return
    fi

    clear
    ui_title "🧭 MacDoctor Preflight (short)"
    out "🖥️  System: $(sw_vers -productName) $(sw_vers -productVersion) | Arch: $(uname -m)"
    out "🧭 Mode: ${MODE} | 📝 Log: $LOG_FILE"
    out "------------------------------------------------"

    if [[ ${#missing_required[@]} -gt 0 ]]; then
        status_line FAIL "Required tools missing" "$(printf "%s " "${missing_required[@]}")"
        explain "MacDoctor may not run correctly until these are available."
    else
        status_line OK "Required tools" "All present."
    fi

    if [[ ${SHOW_PREFLIGHT:-0} -eq 1 ]]; then
        if [[ ${#missing_optional[@]} -gt 0 ]]; then
            status_line WARN "Optional tools missing" "$(printf "%s " "${missing_optional[@]}")"
            explain "These only affect specific features (monitors, smart health, etc.)."
        else
            status_line OK "Optional tools" "All present."
        fi
    fi

    out "------------------------------------------------"
    out "Tip: Settings → Startup Check can be turned OFF/ON."
    pause_continue
}

draw_header() {
    clear
    echo "${BOLD}${CYAN}MacDoctor v${VERSION}${RESET}  ${TEAL}$(date '+%Y-%m-%d %H:%M')${RESET}"
    echo "System: $(sw_vers -productName) $(sw_vers -productVersion) | Arch: $(uname -m)"
    echo "User: $(whoami) | Mode: ${BOLD}${MODE}${RESET}"
    echo "Mode hint: $(mode_description)"
    ui_divider
}

draw_progress_bar() {
    local duration=$1
    local label="${2:-Scanning}"
    local width=35
    local steps=50
    local sleep_slice=$(LC_ALL=C awk -v d="$duration" -v s="$steps" 'BEGIN{if(s==0){print 0}else{printf("%.3f", d/s)}}')
    local spinchars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local spin_len=${#spinchars}

    for ((i=0; i<=steps; i++)); do
        local percent=$(LC_ALL=C awk -v i="$i" -v s="$steps" 'BEGIN{if(s==0){print 0}else{printf("%d",(i*100)/s)}}')
        local filled=$(LC_ALL=C awk -v i="$i" -v s="$steps" -v w="$width" 'BEGIN{printf("%d",(i*w)/s)}')
        local empty=$((width - filled))

        # Color transitions
        local bar_color="$SUCCESS"
        [[ $percent -gt 50 ]] && bar_color="$PRIMARY"
        [[ $percent -gt 80 ]] && bar_color="$ACCENT"

        # Spinner character
        local spin_idx=$((i % spin_len))
        local spinner="${spinchars:$spin_idx:1}"

        # Render
        printf "\r  ${bar_color}${spinner}${RESET} ${DIM}${label}${RESET}  ${DIM}${HEADER_L}${RESET}${bar_color}"
        for ((j=0; j<filled; j++)); do printf "%s" "$BAR_FULL"; done
        printf "${RESET}${DIM}"
        for ((j=0; j<empty; j++)); do printf "%s" "$BAR_EMPTY"; done
        printf "${HEADER_R}${RESET} ${BOLD}%3d%%${RESET}  " "$percent"

        safe_sleep_frac "$sleep_slice"
    done
    printf "\r  ${SUCCESS}${ICON_OK}${RESET} ${label}  "
    for ((j=0; j<width+12; j++)); do printf " "; done
    echo ""
}

ask_sudo() {
    # Re-validate existing sudo token if we have one
    if [[ $SUDO_ACTIVE -eq 1 ]]; then
        if sudo -n true 2>/dev/null; then
            return 0
        else
            SUDO_ACTIVE=0
        fi
    fi

    echo ""
    echo "${YELLOW}${ICON_SEC} Admin access needed for this action.${RESET}"
    echo "   🔐 You will be asked for your macOS password after you confirm."
    while true; do
        echo -n "   Authorize sudo access? (y/n): "
        local response
        read_user_line response || response="n"
        case "$response" in
            [Yy]*)
                if sudo -v &> /dev/null; then
                    SUDO_ACTIVE=1
                    if [[ "$MODE" == "FULL" && -z "$SUDO_KEEPALIVE_PID" ]]; then
                        (while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null) &
                        SUDO_KEEPALIVE_PID=$!
                        # Cleanup handled by main EXIT trap (combined save_settings + kill keepalive)
                    fi
                    return 0
                else
                    echo "${RED}Authentication failed.${RESET}"
                    SUDO_ACTIVE=0
                    return 1
                fi
                ;;
            [Nn]*)
                echo "${RED}Action cancelled.${RESET}"
                return 1
                ;;
            *)
                echo "   Please answer y or n."
                ;;
        esac
    done
}

safe_delete() {
    local target="$1"
    local force_sudo="$2" # "sudo" or empty
    
    if [[ ! -e "$target" ]]; then return; fi
    if [[ "$target" == "/" || "$target" == "$HOME" || -z "$target" ]]; then
        echo "${RED}Refusing to delete top-level path: $target${RESET}"
        return
    fi
    
    # Create backup dir if not exists
    mkdir -p "$CURRENT_BACKUP_DIR"
    
    # Move logic
    echo -n "   ${ICON_TRASH} Archiving $(basename "$target")... "
    
    if [[ -n "$force_sudo" ]]; then
        if sudo mv "$target" "$CURRENT_BACKUP_DIR/" 2>/dev/null; then
            echo "${GREEN}Done${RESET}"
            log_action "Archived (Sudo): $target"
        else
            echo "${RED}Failed${RESET}"
            log_action "FAIL: Archive (Sudo) failed for $target"
        fi
    else
        if mv "$target" "$CURRENT_BACKUP_DIR/" 2>/dev/null; then
            echo "${GREEN}Done${RESET}"
            log_action "Archived: $target"
        else
            echo "${RED}Failed (Permission?)${RESET}"
            log_action "FAIL: Archive failed for $target"
        fi
    fi
}

# --- EXTENDED METRICS & DASHBOARD ---

get_cpu_load() {
    # Force C locale so decimals use '.' (not ',') and math works reliably.
    LC_ALL=C top -l 1 2>/dev/null | awk -F'[:,%]+' '/CPU usage/ {printf("%.1f", $2 + $4); exit}' | tr ',' '.'
}

get_memory_usage() {
    local vm_out
    vm_out=$(LC_ALL=C vm_stat 2>/dev/null) || { echo "0"; return; }

    local page_size
    page_size=$(echo "$vm_out" | awk 'match($0,/page size of ([0-9]+)/,a){print a[1]; exit}' 2>/dev/null)
    [[ -z "$page_size" ]] && page_size=4096
    page_size=${page_size//[^0-9]/}
    [[ -z "$page_size" ]] && page_size=4096

    local pages_active pages_spec pages_wired
    pages_active=$(echo "$vm_out" | awk '/Pages active/{gsub(/\./,""); print $3; exit}' 2>/dev/null)
    pages_spec=$(echo "$vm_out"   | awk '/Pages speculative/{gsub(/\./,""); print $3; exit}' 2>/dev/null)
    pages_wired=$(echo "$vm_out"  | awk '/Pages wired/{gsub(/\./,""); print $3; exit}' 2>/dev/null)

    pages_active=${pages_active//[^0-9]/}
    pages_spec=${pages_spec//[^0-9]/}
    pages_wired=${pages_wired//[^0-9]/}
    [[ -z "$pages_active" ]] && pages_active=0
    [[ -z "$pages_spec" ]] && pages_spec=0
    [[ -z "$pages_wired" ]] && pages_wired=0

    local total_used=$(( (pages_active + pages_wired + pages_spec) * page_size / 1024 / 1024 ))
    echo "$total_used"
}

get_thermal_state() {
    local pressure=$(sysctl -n kern.thermal_level 2>/dev/null)
    if [[ -z "$pressure" ]]; then echo "Normal"; return; fi
    case $pressure in
        0) echo "${GREEN}Normal${RESET}" ;;
        1) echo "${YELLOW}Fair${RESET}" ;;
        2) echo "${ORANGE}High${RESET}" ;;
        *) echo "${BG_RED}CRITICAL${RESET}" ;;
    esac
}

get_disk_health() {
    if ! command -v smartctl &> /dev/null; then
        echo "N/A (missing)"
        return
    fi
    local root_disk=$(diskutil info / 2>/dev/null | awk -F': *' '/Device Identifier/{print $2; exit}')
    [[ -z "$root_disk" ]] && root_disk="disk0"
    if [[ $SUDO_ACTIVE -eq 1 ]]; then
        local smart_output
        if smart_output=$(sudo smartctl -H "/dev/${root_disk}" 2>&1); then
            if echo "$smart_output" | grep -q "SMART support is: Unavailable"; then
                echo "SMART: Unavailable on this hardware."
                return
            fi
            local health=$(echo "$smart_output" | grep "assessment" | awk '{print $6}' | head -1)
            if [[ "$health" == "PASSED" ]]; then echo "${GREEN}PASSED${RESET}"; return; fi
            if [[ "$health" == "FAILED" ]]; then echo "${BG_RED}FAILED${RESET}"; return; fi
            echo "${YELLOW}Unknown${RESET}"
        else
            echo "SMART: Unavailable on this hardware."
            log_action "FAIL: smartctl command failed."
        fi
    else
        echo "N/A (no sudo)"
    fi
}

show_dashboard() {
    # Route to correct dashboard style based on DASHBOARD_STYLE setting
    case "$DASHBOARD_STYLE" in
        top_like)
            show_dashboard_top
            ;;
        animated)
            show_dashboard_animated
            ;;
        minimal)
            show_dashboard_minimal
            ;;
        static|*)
            show_dashboard_static
            ;;
    esac
}

# Dashboard menu with exit option
show_dashboard_menu() {
    while true; do
        show_dashboard
        echo ""
        ui_list_item 1 "🔄 Refresh" "Update all readings"
        ui_list_item 2 "🧠 Semantic Analysis" "Analyze process, memory, and disk patterns"
        ui_list_item 0 "Back to Main Menu"
        echo ""

        local choice
        choice=$(ui_choose "Choose action" 2)
        case "$choice" in
            1) continue ;;
            2)
                run_local_semantic_analysis "dashboard" ""
                pause_continue
                ;;
            0) return ;;
        esac
    done
}

# --- SECURITY & PRIVACY AUDIT ---

_sec_check() {
    # Usage: _sec_check "label" "pass/fail" "recommendation"
    local label="$1" st="$2" rec="${3:-}"
    if [[ "$st" == "pass" ]]; then
        echo "   ${SUCCESS}✓${RESET} ${label}: ${GREEN}OK${RESET}"
        return 0
    else
        echo "   ${ERROR}✗${RESET} ${label}: ${RED}${st}${RESET}"
        [[ -n "$rec" ]] && echo "     ${DIM}→ ${rec}${RESET}"
        return 1
    fi
}

run_security_audit() {
    clear
    echo ""
    ui_box_top "Security & Privacy Audit"
    ui_box_row "${DIM}Checking your Mac's security settings${RESET}"
    ui_box_bottom
    echo ""
    draw_progress_bar 3 "Auditing"
    echo ""

    local score=0 max_score=0

    # ═══════════════════════════════════════════
    echo "  ${BOLD}${PRIMARY}  Core Protections${RESET}"
    echo ""

    # 1. FileVault
    local filevault_ok=0
    ((max_score++))
    if fdesetup status 2>/dev/null | grep -q "On"; then
        _sec_check "FileVault (disk encryption)" "pass" && ((score++))
        filevault_ok=1
    else
        _sec_check "FileVault (disk encryption)" "Disabled" "Enable in System Settings → Privacy & Security → FileVault"
    fi

    # 2. Firewall
    local firewall_ok=0
    ((max_score++))
    if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q "enabled"; then
        _sec_check "Application Firewall" "pass" && ((score++))
        firewall_ok=1
    else
        _sec_check "Application Firewall" "Disabled" "Enable in System Settings → Network → Firewall"
    fi

    # 3. Gatekeeper
    local gatekeeper_ok=0
    ((max_score++))
    if spctl --status 2>/dev/null | grep -q "assessments enabled"; then
        _sec_check "Gatekeeper" "pass" && ((score++))
        gatekeeper_ok=1
    else
        _sec_check "Gatekeeper" "Disabled" "sudo spctl --master-enable"
    fi

    # 4. SIP
    ((max_score++))
    if command -v csrutil &>/dev/null; then
        if csrutil status 2>/dev/null | grep -q "enabled"; then
            _sec_check "System Integrity Protection" "pass" && ((score++))
        else
            _sec_check "System Integrity Protection" "Disabled" "Re-enable via Recovery Mode (csrutil enable)"
        fi
    else
        _sec_check "System Integrity Protection" "pass" && ((score++))
    fi

    # 5. Xprotect / MRT
    ((max_score++))
    local xp_version=$(defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "")
    if [[ -n "$xp_version" ]]; then
        echo "   ${SUCCESS}✓${RESET} XProtect (malware definitions): ${GREEN}v${xp_version}${RESET}"
        ((score++))
    else
        local xp_alt=$(system_profiler SPInstallHistoryDataType 2>/dev/null | grep -A1 "XProtect" | grep "Version" | tail -1 | awk '{print $NF}')
        if [[ -n "$xp_alt" ]]; then
            echo "   ${SUCCESS}✓${RESET} XProtect: ${GREEN}${xp_alt}${RESET}"
            ((score++))
        else
            _sec_check "XProtect (malware definitions)" "Unknown" "Check Software Update for security updates"
        fi
    fi

    echo ""
    echo "  ${BOLD}${PRIMARY}  Access & Sharing${RESET}"
    echo ""

    # 6. Remote Login (SSH)
    ((max_score++))
    if systemsetup -getremotelogin 2>/dev/null | grep -qi "on"; then
        _sec_check "Remote Login (SSH)" "Enabled" "Disable if not needed: System Settings → General → Sharing"
    else
        _sec_check "Remote Login (SSH)" "pass" && ((score++))
    fi

    # 7. Screen Sharing
    ((max_score++))
    if launchctl list 2>/dev/null | grep -q "com.apple.screensharing"; then
        _sec_check "Screen Sharing" "Enabled" "Disable if not needed: System Settings → General → Sharing"
    else
        _sec_check "Screen Sharing" "pass" && ((score++))
    fi

    # 8. File Sharing
    ((max_score++))
    if launchctl list 2>/dev/null | grep -q "com.apple.smbd"; then
        _sec_check "File Sharing (SMB)" "Enabled" "Disable if not needed: System Settings → General → Sharing"
    else
        _sec_check "File Sharing (SMB)" "pass" && ((score++))
    fi

    # 9. Remote Management
    ((max_score++))
    if launchctl list 2>/dev/null | grep -q "com.apple.ARDAgent"; then
        _sec_check "Remote Management" "Enabled" "Disable if not needed: System Settings → General → Sharing"
    else
        _sec_check "Remote Management" "pass" && ((score++))
    fi

    # 10. AirDrop Discoverability
    ((max_score++))
    local airdrop_val=$(defaults read com.apple.sharingd DiscoverableMode 2>/dev/null)
    if [[ "$airdrop_val" == "Everyone" ]]; then
        _sec_check "AirDrop" "Open to Everyone" "Set to Contacts Only in Finder → AirDrop"
    else
        _sec_check "AirDrop" "pass" && ((score++))
    fi

    echo ""
    echo "  ${BOLD}${PRIMARY}  Login & Authentication${RESET}"
    echo ""

    # 11. Automatic Login
    ((max_score++))
    if defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null | grep -q "."; then
        _sec_check "Automatic Login" "Enabled" "Disable in System Settings → Users & Groups"
    else
        _sec_check "Automatic Login" "pass" && ((score++))
    fi

    # 12. Password after sleep
    ((max_score++))
    local screen_lock_delay=$(sysadminctl -screenLock status 2>/dev/null | grep -oE "[0-9]+" | head -1)
    local ask_pwd=$(defaults read com.apple.screensaver askForPassword 2>/dev/null)
    if [[ "$ask_pwd" == "1" || -z "$ask_pwd" ]]; then
        _sec_check "Password on wake/screensaver" "pass" && ((score++))
    else
        _sec_check "Password on wake" "Disabled" "Enable in System Settings → Lock Screen"
    fi

    # 13. Find My Mac
    ((max_score++))
    if nvram -x -p 2>/dev/null | grep -q "fmm-mobileme-token-FMM"; then
        _sec_check "Find My Mac" "pass" && ((score++))
    else
        local fmm_alt=$(defaults read /Library/Preferences/com.apple.FindMyMac.plist 2>/dev/null)
        if [[ -n "$fmm_alt" ]]; then
            _sec_check "Find My Mac" "pass" && ((score++))
        else
            _sec_check "Find My Mac" "Unknown/Off" "Enable in System Settings → Apple ID → Find My"
        fi
    fi

    # 14. Admin accounts
    ((max_score++))
    local admin_count=$(dscl . -read /Groups/admin GroupMembership 2>/dev/null | tr ' ' '\n' | tail -n +2 | wc -l | tr -d ' ')
    if [[ $admin_count -gt 1 ]]; then
        _sec_check "Admin accounts" "${admin_count} found" "Consider using a standard account for daily use"
    else
        _sec_check "Admin accounts" "pass" && ((score++))
    fi

    echo ""
    echo "  ${BOLD}${PRIMARY}  Software & Updates${RESET}"
    echo ""

    # 15. Auto-updates
    ((max_score++))
    local auto_check=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null)
    local auto_download=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload 2>/dev/null)
    if [[ "$auto_check" == "1" ]]; then
        _sec_check "Automatic update check" "pass" && ((score++))
    else
        _sec_check "Automatic update check" "Disabled" "Enable in System Settings → General → Software Update"
    fi

    ((max_score++))
    if [[ "$auto_download" == "1" ]]; then
        _sec_check "Automatic update download" "pass" && ((score++))
    else
        _sec_check "Automatic update download" "Disabled" "Enable auto-download for security patches"
    fi

    echo ""
    echo "  ${BOLD}${PRIMARY}  Backup${RESET}"
    echo ""

    ((max_score++))
    check_time_machine_status

    echo ""
    echo "  ${BOLD}${PRIMARY}  Privacy Permissions${RESET}"
    echo ""

    # TCC database — list apps with sensitive permissions
    local tcc_db="/Library/Application Support/com.apple.TCC/TCC.db"
    if [[ -r "$tcc_db" ]]; then
        for svc_pair in "kTCCServiceAccessibility:Accessibility" "kTCCServiceScreenCapture:Screen Recording" "kTCCServiceSystemPolicyAllFiles:Full Disk Access" "kTCCServiceCamera:Camera"; do
            local svc="${svc_pair%%:*}" svc_name="${svc_pair##*:}"
            local app_count=$(sqlite3 "$tcc_db" "SELECT COUNT(*) FROM access WHERE service='$svc' AND allowed=1;" 2>/dev/null || echo "0")
            if [[ $app_count -gt 0 ]]; then
                echo "   ${DIM}${BULLET}${RESET} ${svc_name}: ${HIGHLIGHT}${app_count}${RESET} ${DIM}apps with access${RESET}"
            else
                echo "   ${DIM}${BULLET}${RESET} ${svc_name}: ${DIM}No apps${RESET}"
            fi
        done
    else
        # Try user-level TCC
        local user_tcc="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
        if [[ -r "$user_tcc" ]]; then
            for svc_pair in "kTCCServiceAccessibility:Accessibility" "kTCCServiceScreenCapture:Screen Recording" "kTCCServiceCamera:Camera" "kTCCServiceMicrophone:Microphone"; do
                local svc="${svc_pair%%:*}" svc_name="${svc_pair##*:}"
                local app_count=$(sqlite3 "$user_tcc" "SELECT COUNT(*) FROM access WHERE service='$svc' AND auth_value=2;" 2>/dev/null || echo "?")
                echo "   ${DIM}${BULLET}${RESET} ${svc_name}: ${HIGHLIGHT}${app_count}${RESET} ${DIM}apps${RESET}"
            done
        else
            echo "   ${DIM}${BULLET} Privacy database not readable (needs Full Disk Access)${RESET}"
        fi
    fi

    echo ""
    echo "  ${BOLD}${PRIMARY}  Network${RESET}"
    echo ""

    # 20. Open listening ports
    local open_ports=$(lsof -iTCP -sTCP:LISTEN -nP 2>/dev/null | awk 'NR>1{print $1":"$9}' | sort -u)
    local port_count=$(echo "$open_ports" | grep -c "." 2>/dev/null || echo "0")
    if [[ $port_count -gt 0 ]]; then
        echo "   ${DIM}${BULLET}${RESET} Listening ports: ${HIGHLIGHT}${port_count}${RESET}"
        echo "$open_ports" | head -8 | while IFS= read -r pline; do
            echo "     ${DIM}${pline}${RESET}"
        done
        [[ $port_count -gt 8 ]] && echo "     ${DIM}... and $((port_count - 8)) more${RESET}"
    else
        echo "   ${SUCCESS}✓${RESET} No unusual listening ports"
    fi

    # 21. DNS servers
    local dns_servers=$(scutil --dns 2>/dev/null | grep "nameserver\[" | awk '{print $3}' | sort -u | tr '\n' ', ' | sed 's/,$//')
    echo "   ${DIM}${BULLET}${RESET} DNS servers: ${DIM}${dns_servers:-system default}${RESET}"

    # 22. VPN status
    local vpn_active=$(ifconfig 2>/dev/null | grep -c "utun[0-9]")
    if [[ $vpn_active -gt 0 ]]; then
        echo "   ${SUCCESS}✓${RESET} VPN tunnel active (utun interfaces: ${vpn_active})"
    else
        echo "   ${DIM}${BULLET}${RESET} VPN: ${DIM}No active tunnel${RESET}"
    fi

    echo ""
    echo "  ${BOLD}${PRIMARY}  Startup Items${RESET}"
    echo ""

    # 23. Launch Agents/Daemons — flag non-Apple ones
    local user_agents=$(( $(ls -1 ~/Library/LaunchAgents/ 2>/dev/null | grep -v "^com\.apple\." | wc -l) ))
    local sys_agents=$(( $(ls -1 /Library/LaunchAgents/ 2>/dev/null | grep -v "^com\.apple\." | wc -l) ))
    local sys_daemons=$(( $(ls -1 /Library/LaunchDaemons/ 2>/dev/null | grep -v "^com\.apple\." | wc -l) ))
    local total_third=$((user_agents + sys_agents + sys_daemons))

    if [[ $total_third -gt 0 ]]; then
        echo "   ${YELLOW}!${RESET} Third-party startup items: ${HIGHLIGHT}${total_third}${RESET}"
        [[ $user_agents -gt 0 ]] && echo "     ${DIM}User agents: ${user_agents}${RESET}"
        [[ $sys_agents -gt 0 ]] && echo "     ${DIM}System agents: ${sys_agents}${RESET}"
        [[ $sys_daemons -gt 0 ]] && echo "     ${DIM}System daemons: ${sys_daemons}${RESET}"
        # Show names of non-Apple user agents
        ls -1 ~/Library/LaunchAgents/ 2>/dev/null | grep -v "^com\.apple\." | head -5 | while IFS= read -r agent; do
            echo "     ${DIM}→ ${agent}${RESET}"
        done
    else
        echo "   ${SUCCESS}✓${RESET} No third-party startup items"
    fi

    # ═══════════════════════════════════════════
    echo ""
    ui_line 55
    local pct=$((score * 100 / max_score))
    local grade="F"
    [[ $pct -ge 90 ]] && grade="A"
    [[ $pct -ge 80 && $pct -lt 90 ]] && grade="B"
    [[ $pct -ge 65 && $pct -lt 80 ]] && grade="C"
    [[ $pct -ge 50 && $pct -lt 65 ]] && grade="D"

    local grade_color="$ERROR"
    [[ "$grade" == "A" ]] && grade_color="$SUCCESS"
    [[ "$grade" == "B" ]] && grade_color="$GREEN"
    [[ "$grade" == "C" ]] && grade_color="$YELLOW"

    echo ""
    echo "  ${BOLD}Security Score: ${grade_color}${score}/${max_score}${RESET} ${DIM}(${pct}%)${RESET}  Grade: ${BOLD}${grade_color}${grade}${RESET}"
    mini_bar "$pct" 30
    echo ""

    # Quick fix menu — only show fixes for things that are actually broken
    ui_line 55
    echo ""
    local fix_num=0
    local fix_map=()
    if [[ $gatekeeper_ok -eq 0 || $firewall_ok -eq 0 || $filevault_ok -eq 0 ]]; then
        echo "  ${BOLD}Quick Fixes${RESET}"
        if [[ $gatekeeper_ok -eq 0 ]]; then
            ((fix_num++)); fix_map[$fix_num]="gatekeeper"
            echo "  ${fix_num}) Enable Gatekeeper (sudo)"
        fi
        if [[ $firewall_ok -eq 0 ]]; then
            ((fix_num++)); fix_map[$fix_num]="firewall"
            echo "  ${fix_num}) Enable Firewall (sudo)"
        fi
        if [[ $filevault_ok -eq 0 ]]; then
            ((fix_num++)); fix_map[$fix_num]="filevault"
            echo "  ${fix_num}) Enable FileVault (opens System Settings)"
        fi
    else
        echo "  ${SUCCESS}All core protections are enabled.${RESET}"
    fi
    echo "  0) Back"
    echo ""
    echo -n "  👉 Choice: "
    local sec_choice
    read_user_line sec_choice || sec_choice=""

    if [[ "$sec_choice" =~ ^[1-9]$ && -n "${fix_map[$sec_choice]:-}" ]]; then
        case "${fix_map[$sec_choice]}" in
            gatekeeper)
                if ask_sudo; then
                    sudo spctl --master-enable 2>/dev/null && echo "  ${GREEN}Gatekeeper enabled.${RESET}" || echo "  ${RED}Failed.${RESET}"
                    log_action "SECURITY: Gatekeeper enabled."
                fi
                pause_continue ;;
            firewall)
                if ask_sudo; then
                    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null && echo "  ${GREEN}Firewall enabled.${RESET}" || echo "  ${RED}Failed.${RESET}"
                    log_action "SECURITY: Firewall enabled."
                fi
                pause_continue ;;
            filevault)
                open "x-apple.systempreferences:com.apple.preference.security?FileVault" 2>/dev/null || open "/System/Library/PreferencePanes/Security.prefPane" 2>/dev/null
                echo "  ${DIM}Opening System Settings...${RESET}"
                pause_continue ;;
        esac
    fi
}

# --- ADVANCED PROCESS INSPECTOR ---

advanced_process_inspector() {
    while true; do
        clear
        ui_title "${ICON_EYE} ADVANCED PROCESS INSPECTOR"
        ui_hint "🧭 Top 10 processes by CPU usage. Enter PID to inspect."
        echo ""
        echo "   ${BOLD}PID      COMMAND              %CPU   %MEM   THREADS${RESET}"
        echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Get top 10 processes
        ps -A -o pid,comm,pcpu,pmem,threads -r 2>/dev/null | head -n 11 | tail -n 10 | while IFS=' ' read -r pid comm pcpu pmem threads; do
            [[ -z "$pid" ]] && continue
            # Truncate comm to 18 chars
            comm_short="${comm:0:18}"
            printf "   %-8s %-18s %-6s %-6s %s\n" "$pid" "$comm_short" "$pcpu" "$pmem" "$threads"
        done
        
        echo ""
        echo "   ${PRIMARY}0) Back to Advanced Menu${RESET}"
        echo -n "   Enter PID to inspect (or '0' to exit): "
        local target_pid
        read_user_line target_pid || target_pid="0"
        
        if [[ "$target_pid" == "0" ]]; then return; fi
        
        if [[ "$target_pid" =~ ^[0-9]+$ ]]; then
            clear
            echo "${BOLD}${PRIMARY}INSPECTING PID: $target_pid${RESET}"
            local proc_name=$(ps -p $target_pid -o comm= 2>/dev/null)
            if [[ -z "$proc_name" ]]; then 
                echo "${RED}Process not found.${RESET}"
                sleep 2
                continue
            fi
            echo "Process: $proc_name"
            echo ""
            
            echo "${CYAN}--- Basic Stats ---${RESET}"
            ps -p $target_pid -o %cpu,%mem,th,state,user,vsize,rss 2>/dev/null | awk 'NR==2 {printf "CPU: %s%% | Memory: %s%% | Threads: %s | State: %s | User: %s | VSz: %s | RSS: %s\n", $1, $2, $3, $4, $5, $6, $7}'
            
            echo ""
            echo "${CYAN}--- Energy Stats ---${RESET}"
            local pwr=$(top -l 1 -pid $target_pid -stats power 2>/dev/null | tail -1)
            echo "Power Usage: $pwr"
            
            echo ""
            pause_continue
        fi
    done
}

# --- EXTERNAL MONITORS (Mactop/Asitop/Macmon) ---

run_macmon() {
    clear
    ui_title "${ICON_GPU} MACMON (NO-SUDO APPLE SILICON MONITOR)"
    ui_hint "⚡ Lightweight SoC monitor. No sudo required."
    
    if command -v macmon &> /dev/null; then
        echo "macmon: Apple Silicon monitoring tool (CPU/GPU/SoC, no sudo)."
        if ! macmon; then
            echo "macmon failed on this macOS version. Skipping."
        fi
    elif check_brew; then
        echo "macmon is not installed. Install via Homebrew? (y/n): "
        read -r confirm_install
        if [[ "$confirm_install" =~ ^[Yy]$ ]]; then
            if brew install macmon; then
                echo -n "Run macmon now? (y/n): "
                read -r confirm_run
                if [[ "$confirm_run" =~ ^[Yy]$ ]]; then
                    echo "macmon: Apple Silicon monitoring tool (CPU/GPU/SoC, no sudo)."
                    if ! macmon; then
                        echo "macmon failed on this macOS version. Skipping."
                    fi
                fi
            else
                echo "Install failed."
            fi
        fi
    else
        echo "macmon and Homebrew unavailable. Skipping."
    fi
    pause_continue
}


external_monitors() {
    while true; do
        clear
        ui_title "${ICON_GPU} REAL-TIME SOC MONITORS"
        ui_hint "🎮 Live CPU/GPU/SoC monitoring tools."
        echo "1. Run mactop (Homebrew, requires Sudo)"
        echo "2. Run asitop (Python/Pip, requires Sudo)"
        echo "3. Run macmon (No-Sudo Apple Silicon monitor) ${ICON_ROCKET}"
        echo "4. Back"
        echo -n "👉 Selection: "
        local mon_choice
        read_user_line mon_choice || mon_choice="4"
        
        case $mon_choice in
            1)
                if ! command -v mactop &> /dev/null; then
                    echo "Tool mactop unavailable on this system."
                    if check_brew; then
                        echo "${YELLOW}mactop not found. Offering installation...${RESET}"
                        echo -n "Install mactop now? (y/n): "
                        read -r inst_mactop
                        if [[ "$inst_mactop" =~ ^[Yy]$ ]]; then
                            if brew install mactop &> /dev/null; then
                                if ask_sudo; then
                                    echo "${YELLOW}Press CTRL+C to exit${RESET}"
                                    if ! sudo mactop; then
                                        echo "mactop failed on this macOS version. Skipping."
                                    fi
                                fi
                            else
                                echo "brew failed on this macOS version. Skipping."
                            fi
                        fi
                    else
                        echo "Homebrew unavailable. Skipping."
                    fi
                else
                    echo "${YELLOW}Starting mactop (Press CTRL+C to exit). Requires sudo.${RESET}"
                    if ask_sudo; then
                        echo "${YELLOW}Press CTRL+C to exit${RESET}"
                        if ! sudo mactop; then
                            echo "mactop failed on this macOS version. Skipping."
                        fi
                    fi
                fi
                ;;
            2)
                if ! command -v pip3 &> /dev/null; then
                    echo "Tool pip3 unavailable on this system."
                    sleep 2
                    continue
                fi
                if ! pip3 show asitop &> /dev/null; then
                    echo "${YELLOW}asitop not installed. Installing via pip...${RESET}"
                    if pip3 install asitop; then
                        :
                    else
                        echo "pip3 failed on this macOS version. Skipping."
                        sleep 2
                        continue
                    fi
                fi
                echo "${YELLOW}Starting asitop (Press CTRL+C to exit). Requires sudo.${RESET}"
                if ask_sudo; then
                    echo "${YELLOW}Press CTRL+C to exit${RESET}"
                    if ! sudo asitop; then
                        echo "asitop failed on this macOS version. Skipping."
                    fi
                fi
                ;;
            3) run_macmon ;;
            4) return ;;
        esac
    done
}

# --- LOGIN & BACKGROUND ITEMS ---

login_items_manager() {
    while true; do
        clear
        ui_title "${ICON_TOOL} LOGIN ITEMS & LAUNCH AGENTS"
        ui_hint "🚀 Manage startup items and background agents."
        echo "Scanning system (uses sfltool & launchctl)..."
        
        echo ""
        echo "${CYAN}--- User Login Items (sfltool) ---${RESET}"
        if ask_sudo; then
            if ! command -v sfltool &> /dev/null; then
                echo "Tool sfltool unavailable on this system."
            else
                local sfl_output
                if sfl_output=$(sudo sfltool dumpbtm 2>&1); then
                    # Attempt to parse
                    local items=$(echo "$sfl_output" | grep -E 'Name:|Path:' | paste -d'|' - -)
                    if [[ -n "$items" ]]; then
                        echo "$items" | head -n 10
                    else
                        echo "${YELLOW}Apple changed login item internals on this version – limited CLI visibility.${RESET}"
                        log_action "WARN: sfltool dumpbtm parsing failed on beta."
                    fi
                else
                    echo "sfltool failed on this macOS version. Skipping."
                    log_action "FAIL: sfltool dumpbtm failed."
                fi
            fi
        else 
            echo "(Requires sudo to list BT login items)"
        fi
        
        echo ""
        echo "${CYAN}--- Active Launch Agents (Non-Apple) ---${RESET}"
        if ! command -v launchctl &> /dev/null; then
            echo "Tool launchctl unavailable on this system."
        else
            if launchctl list 2>/dev/null | awk 'NR>1 && $3 !~ /^com\.apple/ && !($1==0 && $2==0)' | head -n 10; then
                : # Success
            else
                echo "launchctl failed on this macOS version. Skipping."
            fi
        fi
        
        echo ""
        echo "1. Remove a Login Item (via sfltool label)"
        echo "2. Unload a Launch Agent (via launchctl)"
        echo "3. Reset All Login Items Database (Use with caution)"
        echo "4. Back"
        echo -n "👉 Choice: "
        local li_choice
        read_user_line li_choice || li_choice="4"
        
        case $li_choice in
            1)
                if ask_sudo; then
                    if ! command -v sfltool &> /dev/null; then
                        echo "Tool sfltool unavailable on this system."
                    else
                        echo -n "Enter Exact Label Name: "
                        read -r label_name
                        if sudo sfltool remove --label "$label_name" 2>/dev/null; then
                            echo "${GREEN}Attempted removal of $label_name. Check system logs.${RESET}"
                            log_action "LOGIN_ITEMS: Attempted removal of $label_name."
                        else
                            echo "sfltool failed on this macOS version. Skipping."
                            log_action "FAIL: sfltool removal failed for $label_name."
                        fi
                    fi
                fi
                sleep 2
                ;;
            2)
                if ask_sudo; then
                    if ! command -v launchctl &> /dev/null; then
                        echo "Tool launchctl unavailable on this system."
                    else
                        echo -n "Enter Service Label (e.g. com.google.keystone): "
                        read -r svc_label
                        if ! launchctl bootout gui/$(id -u) "$svc_label" 2>/dev/null; then
                            echo "launchctl failed on this macOS version. Skipping."
                        fi
                        if ! launchctl disable gui/$(id -u)/"$svc_label" 2>/dev/null; then
                            echo "launchctl failed on this macOS version. Skipping."
                        else
                            echo "Attempted unload/disable. Check system logs for status."
                            log_action "LAUNCH_AGENT: Attempted unload/disable of $svc_label."
                        fi
                    fi
                fi
                sleep 2
                ;;
            3)
                if ask_sudo; then
                    if ! command -v sfltool &> /dev/null; then
                        echo "Tool sfltool unavailable on this system."
                    else
                        echo "${BG_RED}${BOLD}WARNING: This resets all login items, potentially breaking third-party apps.${RESET}"
                        echo -n "Confirm Global Reset (type 'RESET'): "
                        read -r confirm_reset
                        if [[ "$confirm_reset" == "RESET" ]]; then
                            if sudo sfltool resetbtm 2>/dev/null; then
                                echo "${GREEN}Login Item Database Reset Complete (resetbtm).${RESET}"
                                log_action "LOGIN_ITEMS: Global database reset (sfltool resetbtm)."
                            else
                                echo "sfltool failed on this macOS version. Skipping."
                                log_action "FAIL: sfltool resetbtm failed."
                            fi
                        fi
                    fi
                fi
                sleep 2
                ;;
            4) return ;;
        esac
    done
}

# --- ADVANCED BATTERY ---

battery_extended() {
    clear
    ui_title "${ICON_BATT} ADVANCED BATTERY HEALTH"
    ui_hint "Clear battery health + what it means."
    
    local is_laptop
    is_laptop=$(pmset -g batt 2>/dev/null | grep "Battery")
    if [[ -z "$is_laptop" ]]; then
        status_line INFO "Battery" "No battery detected (desktop Mac)."
        pause_continue
        return
    fi

    section_title "Live status (pmset)"
    explain "This shows current charge, charging state, and power source."
    if pmset -g batt 2>/dev/null; then
        : # ok
    else
        status_line WARN "pmset" "failed to read battery status. Some details may be unavailable."
    fi
    
    section_title "Hardware stats (System Profiler)"
    explain "Cycle Count = full charge cycles. Condition = Apple's health assessment. Maximum Capacity = % of original."
    local power_data
    power_data=$(cache_get "system_profiler_SPPowerDataType" 60 system_profiler SPPowerDataType)
    if [[ -z "$power_data" ]]; then
        status_line FAIL "system_profiler" "No battery data returned."
        log_action "FAIL: system_profiler SPPowerDataType failed."
    else
        echo "$power_data" | grep -E "Cycle Count|Condition|Maximum Capacity|Amperage|Voltage" | sed 's/^/   /'
    fi
    
    section_title "Raw capacity (pmset XML)"
    explain "These values come from the battery controller (mAh). Useful to spot sudden degradation."
    local pmset_xml raw_max cur_cap
    pmset_xml=$(cache_get "pmset_ps_xml" 15 pmset -g ps -xml)
    raw_max=$(echo "$pmset_xml" | grep -A 1 "MaxCapacity" | tail -1 | grep -o "[0-9]*")
    cur_cap=$(echo "$pmset_xml" | grep -A 1 "CurrentCapacity" | tail -1 | grep -o "[0-9]*")
    if [[ -n "$raw_max" && -n "$cur_cap" ]]; then
        out "   Raw Current / Max: $cur_cap / $raw_max (mAh)"
        status_line OK "Capacity reading" "Available."
    else
        status_line WARN "Capacity reading" "Unavailable on this macOS/hardware."
    fi

    section_title "Recommendations"
    explain "Rule of thumb: >800 cycles often means noticeable wear (varies by model/usage)."
    local cycle_count
    cycle_count=$(echo "$power_data" | grep "Cycle Count" | awk '{print $3}' 2>/dev/null)
    if [[ -z "$cycle_count" ]]; then
        status_line WARN "Cycle Count" "Could not be parsed from System Profiler output."
    elif [[ "$cycle_count" -gt 800 ]]; then
        status_line WARN "Cycle Count" "High ($cycle_count). If you see fast drain, consider battery service."
    else
        status_line OK "Cycle Count" "Looks reasonable ($cycle_count)."
    fi
    
    echo ""
    echo "1. Enable Low Power Mode"
    echo "2. Disable Low Power Mode"
    echo "3. Back"
    echo -n "👉 Choice: "
    local b_choice
    read_user_line b_choice || b_choice="3"
    case $b_choice in
        1) if ask_sudo; then sudo pmset -b lowpowermode 1; log_action "BATTERY: Low Power Mode enabled."; fi ;;
        2) if ask_sudo; then sudo pmset -b lowpowermode 0; log_action "BATTERY: Low Power Mode disabled."; fi ;;
    esac
}

# --- SOFTWARE UPDATES ---

software_update_check() {
    clear
    ui_title "${ICON_UPD} CHECKING FOR UPDATES"
    ui_hint "Clear update overview + what to do next."
    draw_progress_bar 3
    
    section_title "macOS updates (softwareupdate)"
    explain "Lists available system updates. This does not install anything."
    if require_cmd softwareupdate; then
        local su_out su_ret
        su_out=$(softwareupdate -l 2>&1)
        su_ret=$?
        if [[ $su_ret -ne 0 ]]; then
            status_line WARN "softwareupdate" "Failed to list updates (exit $su_ret)."
            log_action "FAIL: softwareupdate -l failed (exit $su_ret)."
        else
            if echo "$su_out" | grep -qi "No new software available"; then
                status_line OK "macOS updates" "No new software available."
            else
                status_line INFO "macOS updates" "Updates may be available. Review the list below."
                echo "$su_out"
                out "   Tip: softwareupdate -d <label> (download), -i <label> (install)"
            fi
            log_action "softwareupdate check successful."
        fi
    fi
    
    echo ""
    section_title "Homebrew updates (outdated packages)"
    explain "Shows outdated CLI tools/apps installed via Homebrew."
    if check_brew && require_cmd brew; then
        local brew_out brew_ret
        brew_out=$(brew outdated --greedy 2>/dev/null | head -n 10)
        brew_ret=$?
        if [[ $brew_ret -ne 0 ]]; then
            status_line WARN "brew outdated" "Failed to check outdated packages."
        elif [[ -z "$brew_out" ]]; then
            status_line OK "Homebrew" "No outdated packages found (or none in top list)."
        else
            status_line INFO "Homebrew" "Top outdated packages:"
            echo "$brew_out"
            out "   Tip: brew upgrade (upgrade everything)"
        fi
    else
        status_line INFO "Homebrew" "Not installed or not available."
    fi

    echo ""
    # Optional Super integration (check only, no install)
    if command -v super &> /dev/null; then
        echo "${CYAN}--- External Utility 'super' Found ---${RESET}"
        echo "   'super' is installed. Run it manually for advanced update control."
    fi
    
    echo ""
    pause_continue
}

# --- DEEP I/O MONITOR ---

io_monitor_menu() {
    while true; do
        clear
        ui_title "${ICON_DISK} DEEP I/O & DISK MONITOR"
        ui_hint "📈 Live disk and network activity tools."
        echo "1. File System Activity (fs_usage - Warning: High Volume)"
        echo "2. Network Activity Stream (nettop)"
        echo "3. Per-Process I/O (iotop/fs_usage fallback)"
        echo "4. Back"
        echo -n "👉 Selection: "
        local io_choice
        read_user_line io_choice || io_choice="4"
        
        if [[ "$io_choice" =~ ^[12]$ ]] && ! ask_sudo; then continue; fi

        case $io_choice in
            1) 
                if ! command -v fs_usage &> /dev/null; then
                    echo "Tool fs_usage unavailable on this system."
                else
                        echo "${YELLOW}Press CTRL+C to stop fs_usage${RESET}"
                        sleep 1
                    if ! sudo fs_usage -w -f filesys; then
                        echo "fs_usage failed on this macOS version. Skipping."
                    fi
                fi
                ;;
            2)
                if ! command -v nettop &> /dev/null; then
                    echo "Tool nettop unavailable on this system."
                else
                    echo "${YELLOW}Press CTRL+C to stop nettop${RESET}"
                    sleep 1
                    if ! sudo nettop; then
                        echo "nettop failed on this macOS version. Skipping."
                    fi
                fi
                ;;
            3)
                # DTrace / iotop check
                local sip_status=""
                if command -v csrutil &> /dev/null; then
                    sip_status=$(csrutil status 2>/dev/null | grep -o "enabled\|disabled")
                fi
                
                if ! command -v iotop &> /dev/null; then
                    echo "Tool iotop unavailable on this system."
                    if check_brew; then
                        echo -n "Install iotop via Homebrew now? (y/n): "
                        read -r inst_iotop
                        if [[ "$inst_iotop" =~ ^[Yy]$ ]]; then
                            if brew install iotop &> /dev/null; then
                                if ask_sudo; then
                                    echo "${YELLOW}Press CTRL+C to exit${RESET}"
                                    if ! sudo iotop; then
                                        echo "SIP restrictions: tool not available. Falling back."
                                        log_action "IO_MONITOR: iotop failed to run."
                                    fi
                                fi
                            else
                                echo "brew failed on this macOS version. Skipping."
                            fi
                        fi
                    else
                        echo "Homebrew unavailable. Skipping."
                    fi
                else
                    if [[ "$sip_status" == "enabled" ]]; then
                        echo "SIP restrictions: tool not available. Falling back."
                        log_action "IO_MONITOR: iotop blocked by SIP, skipping."
                        sleep 2
                    else
                        echo "${YELLOW}Starting iotop (Press CTRL+C to stop). Requires sudo.${RESET}"
                        if ask_sudo; then
                            echo "${YELLOW}Press CTRL+C to exit${RESET}"
                            if ! sudo iotop; then
                                echo "SIP restrictions: tool not available. Falling back."
                                log_action "IO_MONITOR: iotop failed to run."
                            fi
                        fi
                    fi
                fi
                ;;
            4) return ;;
        esac
    done
}

# --- EXISTING MODULES (EXPANDED) ---

check_gpu_diagnostics() {
    out "${BOLD}${ICON_GPU} GPU & Graphics Diagnostics${RESET}"
    cache_get "system_profiler_SPDisplaysDataType" 60 system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Chipset Model|Total Number of Cores|Metal Support" | sed 's/^/   /' | while read -r line; do out "$line"; done
    
    if ask_sudo; then
        out "   ${YELLOW}Running Deep GPU Analysis (Metal/AGX Power)...${RESET}"
        if ! require_cmd powermetrics; then
            : # message already printed
        else
            local pm_out pm_ret
            pm_out=$(sudo powermetrics -n 1 -s gpu_power --format csv 2>/dev/null)
            pm_ret=$?
            if [[ $pm_ret -ne 0 ]]; then
                status_line WARN "powermetrics" "failed (exit $pm_ret). Skipping."
                log_action "FAIL: powermetrics failed (exit $pm_ret)."
            else
                echo "$pm_out" | grep -A 2 "GPU Power" | while read -r line; do out "$line"; done
            fi
        fi
    else
        out "   (Enable Full Mode/Sudo for deep GPU power analysis)"
    fi
    add_to_report "Ran GPU Diagnostics"
}

check_network_deep() {
    out "${BOLD}${ICON_NET} Deep Network Analysis${RESET}"
    out "   Active Interfaces:"
    networksetup -listallhardwareports 2>/dev/null | grep -A 1 "Device: en" | sed 's/^/   /' | while read -r line; do out "$line"; done
    out "   ${CYAN}DNS Configuration:${RESET}"
    scutil --dns 2>/dev/null | grep "nameserver" | head -n 4 | sed 's/^/      /' | while read -r line; do out "$line"; done
    out "   ${CYAN}Latency Check:${RESET}"
    local ping_output=$(ping -c 3 1.1.1.1 2>/dev/null)
    local ping_ms=$(echo "$ping_output" | tail -1 | awk -F '/' '{print $5}')
    if [[ -n "$ping_ms" ]]; then
        out "      Cloudflare DNS: ${ping_ms}ms"
        add_to_report "Ran Network Deep Analysis. Latency: ${ping_ms}ms"
    else
        out "      Ping failed on 1.1.1.1."
    fi
}

check_storage_deep() {
    out "${BOLD}${ICON_DISK} Deep Storage & SSD Health${RESET}"
    out "   ${CYAN}APFS Snapshot Usage:${RESET}"
    if ! require_cmd tmutil; then
        : # message already printed
    else
        tmutil listlocalsnapshots / 2>/dev/null | head -n 5 | sed 's/^/      /' | while read -r line; do out "$line"; done
    fi

    out "   ${CYAN}Large File Detection (>1GB in Home):${RESET}"
    out "      Scanning..."
    find "$HOME" -type f -size +1G -not -path "*/Library/*" -maxdepth 4 2>/dev/null | head -n 5 | sed 's/^/      /' | while read -r line; do out "$line"; done
    
    # Smartctl check
    if ! require_cmd smartctl; then
        : # message already printed
    elif [[ $SUDO_ACTIVE -eq 1 ]]; then
        out "   ${CYAN}SSD Wear & Life Indicators:${RESET}"
        local root_disk=$(diskutil info / 2>/dev/null | awk -F': *' '/Device Identifier/{print $2; exit}')
        [[ -z "$root_disk" ]] && root_disk="disk0"
        local smart_output=$(sudo smartctl -a "/dev/${root_disk}" 2>&1)
        if [[ $? -eq 0 ]]; then
             if echo "$smart_output" | grep -q "SMART support is: Unavailable"; then
                out "SMART: Unavailable on this hardware."
             else
                echo "$smart_output" | grep -E "Percentage Used|Data Units Read|Data Units Written|Temperature" | sed 's/^/      /' | while read -r line; do out "$line"; done
             fi
        else
            out "SMART: Unavailable on this hardware."
            log_action "FAIL: smartctl deep check failed."
        fi
    fi
}

prompt_semantic_analysis() {
    local context_label="$1"
    local report_file="${2:-}"
    local resp

    echo ""
    echo -n "  Show semantic AI analysis for ${context_label}? (y/n): "
    read_user_line resp || resp=""
    [[ "$resp" =~ ^[Yy]$ ]] || return 0

    run_local_semantic_analysis "$context_label" "$report_file"
}

# ============================================================================
# LOCAL SEMANTIC ANALYSIS
# ============================================================================

# Produce human-readable semantic insights from system data.
# Called automatically after every scan — no user prompt needed.
run_local_semantic_analysis() {
    local context="${1:-scan}"
    local report_file="${2:-}"
    local insights=()

    # ── Collect data ──
    local cpu=$(get_cpu_load 2>/dev/null || echo "0")
    cpu="${cpu/,/.}"; local cpu_int="${cpu%.*}"; [[ -z "$cpu_int" ]] && cpu_int=0

    local ram_used=$(get_memory_usage 2>/dev/null || echo "0")
    local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    local total_mem=$(( ${mem_bytes:-0} / 1024 / 1024 ))
    [[ "$total_mem" -le 0 ]] 2>/dev/null && total_mem=16384
    local ram_pct=$(LC_ALL=C awk -v u="$ram_used" -v t="$total_mem" 'BEGIN{if(t>0){printf "%.0f",(u/t)*100} else {print "0"}}')

    local disk_pct=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    [[ -z "$disk_pct" ]] && disk_pct=0

    local swap_used_raw=$(sysctl -n vm.swapusage 2>/dev/null | awk '{print $7}')
    [[ -z "$swap_used_raw" ]] && swap_used_raw="0M"

    local zombies=$(ps aux 2>/dev/null | grep -c " <defunct>" || echo "0")
    [[ "$zombies" -gt 0 ]] && zombies=$((zombies - 1))

    # Top process
    local top_line=$(ps aux 2>/dev/null | awk 'NR>1 {gsub(/,/,".",$3); printf "%s %s\n",$3,$11}' | sort -rn | head -1)
    local top_cpu=$(echo "$top_line" | awk '{print $1}')
    local top_proc=$(echo "$top_line" | awk '{print $2}' | sed 's|.*/||')
    [[ -z "$top_proc" ]] && top_proc="N/A"
    [[ -z "$top_cpu" ]] && top_cpu=0
    local top_cpu_int="${top_cpu%.*}"

    # Startup items count
    local startup_count=0
    startup_count=$(( $(ls -1 ~/Library/LaunchAgents 2>/dev/null | wc -l) + $(ls -1 ~/Library/LaunchDaemons 2>/dev/null | wc -l) ))

    # Cache size
    local cache_raw=$(du -sh ~/Library/Caches 2>/dev/null | awk '{print $1}')
    [[ -z "$cache_raw" ]] && cache_raw="0"

    local batt_pct=$(pmset -g batt 2>/dev/null | grep -o "[0-9]*%" | head -1 | tr -d '%')
    local batt_state=$(pmset -g batt 2>/dev/null | grep -oE "charging|discharging|charged" | head -1)

    # ── Build insights based on data patterns ──

    # CPU patterns
    if [[ $cpu_int -gt 80 ]]; then
        insights+=("CPU load is at ${cpu}%, indicating heavy system workload.")
    elif [[ $cpu_int -gt 40 ]]; then
        insights+=("CPU usage is moderate (${cpu}%) — the system is active but not overloaded.")
    else
        insights+=("CPU load is low (${cpu}%) — plenty of processing power available.")
    fi

    # Top process dominance
    if [[ $top_cpu_int -gt 50 ]]; then
        insights+=("${top_proc} is dominating CPU at ${top_cpu}% — a single process is driving most of the load.")
    elif [[ $top_cpu_int -gt 20 ]]; then
        insights+=("${top_proc} is the most active process at ${top_cpu}% CPU.")
    fi

    # Memory patterns
    if [[ $ram_pct -gt 85 ]]; then
        insights+=("Memory usage is high (${ram_pct}%) — the system may need to free up resources soon.")
    elif [[ $ram_pct -gt 60 ]]; then
        insights+=("Memory is at ${ram_pct}% — normal during active use but worth monitoring.")
    else
        insights+=("Memory usage is comfortable (${ram_pct}%) with plenty of room for more applications.")
    fi

    # Swap
    if [[ "$swap_used_raw" != "0M" && "$swap_used_raw" != "0.00M" && "$swap_used_raw" != "free" ]]; then
        insights+=("Swap memory is in use (${swap_used_raw}) — the system has experienced memory pressure at some point.")
    fi

    # Disk patterns
    if [[ $disk_pct -gt 90 ]]; then
        insights+=("Disk is nearly full (${disk_pct}%) — risk of performance issues and system instability.")
    elif [[ $disk_pct -gt 75 ]]; then
        insights+=("Disk usage is getting high (${disk_pct}%) — a cleanup could improve performance.")
    else
        insights+=("Storage space is healthy (${disk_pct}% used) — no action needed.")
    fi

    # Cache
    if [[ "$cache_raw" == *G* ]]; then
        local cache_gb="${cache_raw//[^0-9.,]/}"; cache_gb="${cache_gb/,/.}"
        local cache_int="${cache_gb%.*}"
        if [[ $cache_int -gt 5 ]] 2>/dev/null; then
            insights+=("Cache directories are using ${cache_raw} — a safe cleanup could free significant space.")
        fi
    fi

    # Startup
    if [[ $startup_count -gt 10 ]]; then
        insights+=("There are ${startup_count} startup processes — many of these may be unnecessary and slowing boot time.")
    elif [[ $startup_count -gt 5 ]]; then
        insights+=("${startup_count} applications start automatically at login.")
    fi

    # Zombies
    if [[ $zombies -gt 0 ]]; then
        insights+=("${zombies} zombie processes found — terminated but not properly cleaned up.")
    fi

    # Battery
    if [[ -n "$batt_pct" ]]; then
        if [[ $batt_pct -lt 20 && "$batt_state" == "discharging" ]]; then
            insights+=("Battery is low (${batt_pct}%) and not charging — connect power soon.")
        fi
    fi

    # Cross-correlation: high CPU + discharging
    if [[ $cpu_int -gt 60 && "$batt_state" == "discharging" ]]; then
        insights+=("High CPU load while on battery power means increased energy consumption.")
    fi

    # ── Display ──
    echo ""
    echo "  ${BOLD}${PRIMARY}${BULLET} Semantic Analysis${RESET}"
    ui_line 50
    echo ""

    for insight in "${insights[@]}"; do
        echo "  ${DIM}${BULLET}${RESET} ${insight}"
    done
    echo ""

    # Append to report file if provided
    if [[ -n "$report_file" ]]; then
        echo "" >> "$report_file"
        echo "--- SEMANTIC ANALYSIS ---" >> "$report_file"
        for insight in "${insights[@]}"; do
            echo "  $insight" >> "$report_file"
        done
    fi
    echo "  👉 Press Enter to continue..."
    read_user_line _ || true
    return 0
}

run_quick_scan() {
    ui_title "⚡ Quick System Scan"
    ui_hint "Fast snapshot of disk, memory, and top CPU."
    draw_progress_bar 1
    
    # Collect scan data
    local disk_info=$(df -h / 2>/dev/null | tail -1)
    local disk_total=$(echo "$disk_info" | awk '{print $2}')
    local disk_used=$(echo "$disk_info" | awk '{print $3}')
    local disk_free=$(echo "$disk_info" | awk '{print $4}')
    local disk_pct=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')
    
    local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    local total_mem=$(( ${mem_bytes:-0} / 1024 / 1024 ))
    local ram_used=$(get_memory_usage 2>/dev/null)
    [[ "$total_mem" -le 0 ]] 2>/dev/null && total_mem=16384
    local ram_pct=$(LC_ALL=C awk -v u="$ram_used" -v t="$total_mem" 'BEGIN{printf "%.0f", (u/t)*100}')
    
    local cpu=$(get_cpu_load 2>/dev/null || echo "0")
    local cpu_int="${cpu%.*}"; [[ -z "$cpu_int" ]] && cpu_int=0
    local top_procs=$(ps -A -o pid,comm,pcpu,pmem -r 2>/dev/null | head -n 6 | tail -n 5)

    local batt_pct=$(pmset -g batt 2>/dev/null | grep -o "[0-9]*%" | head -1 | tr -d '%')
    local swap_used=$(sysctl -n vm.swapusage 2>/dev/null | awk '{print $7}')
    [[ -z "$swap_used" ]] && swap_used="0M"
    
    # Build rich results string using themed bars (for cards/dashboard/table)
    local results=""
    # Use subshell to capture mini_bar output
    local cpu_badge_s="OK"; [[ $cpu_int -gt 80 ]] && cpu_badge_s="FAIL"; [[ $cpu_int -gt 50 && $cpu_int -le 80 ]] && cpu_badge_s="WARN"
    local ram_badge_s="OK"; [[ $ram_pct -gt 85 ]] && ram_badge_s="FAIL"; [[ $ram_pct -gt 60 && $ram_pct -le 85 ]] && ram_badge_s="WARN"
    local dsk_badge_s="OK"; [[ $disk_pct -gt 90 ]] && dsk_badge_s="FAIL"; [[ $disk_pct -gt 75 && $disk_pct -le 90 ]] && dsk_badge_s="WARN"

    results+="CPU Load:  ${cpu}%\n"
    results+="Memory:    ${ram_used}/${total_mem} MB (${ram_pct}%)\n"
    results+="Disk:      ${disk_used}/${disk_total} (${disk_free} free) ${disk_pct}%\n"
    [[ -n "$batt_pct" ]] && results+="Battery:   ${batt_pct}%\n"
    results+="Swap:      ${swap_used}\n"
    results+="\nTop 5 Processes:\n${top_procs}"

    local summary="Disk: ${disk_pct}% | RAM: ${ram_pct}% | CPU: ${cpu}%"
    local details="$results"
    
    case "$RESULT_STYLE" in
        visual)
            results="Disk Usage|${disk_pct}|100\nMemory Usage|${ram_pct}|100\nCPU Load|${cpu_int}|100"
            ;;
    esac
    
    display_scan_results "Quick Scan Results" "$results" "$summary" "$details"
    add_to_report "Quick Scan Completed - Disk: ${disk_pct}%, RAM: ${ram_pct}%, CPU: ${cpu}%"
}

run_deep_scan() {
    ui_title "🧪 Deep Diagnostic Scan"
    ui_hint "More detail on caches, logs, and startup items."
    draw_progress_bar 3
    
    # Collect scan data
    local cache_info=$(du -sh ~/Library/Caches/* 2>/dev/null | sort -rh | head -n 5)
    local log_info=""
    if ask_sudo; then
        log_info=$(sudo du -sh /var/log/* 2>/dev/null | sort -rh | head -n 5)
    else
        log_info="(Sudo required for system logs)"
    fi
    local launch_agents=$(ls -1 ~/Library/LaunchAgents 2>/dev/null || echo "(No user agents found)")
    
    # Format results
    local results=""
    local summary="Deep scan found cache directories and startup items."
    local details=""
    
    case "$RESULT_STYLE" in
        cards|dashboard|table)
            results="Heavy Cache Directories:\n${cache_info}\n\nLarge Log Files:\n${log_info}\n\nLaunchAgents (Startup Items):\n${launch_agents}"
            ;;
        summary)
            summary="Deep scan completed. Found $(echo "$cache_info" | wc -l | tr -d ' ') cache directories."
            details="Caches:\n${cache_info}\n\nLogs:\n${log_info}\n\nStartup Items:\n${launch_agents}"
            ;;
        visual)
            # Calculate total cache size
            local total_cache=$(echo "$cache_info" | awk '{sum+=$1} END {print sum}')
            results="Cache Size|${total_cache}|100\nLog Files|$(echo "$log_info" | wc -l | tr -d ' ')|10"
            ;;
    esac
    
    display_scan_results "Deep Scan Results" "$results" "$summary" "$details"
    add_to_report "Deep Scan Completed."
}

run_ultra_scan() {
    local report_file="$HOME/Desktop/MacDoctor_Report_$(date +%Y-%m-%d_%H%M%S).txt"
    REPORT_FILE="$report_file"

    ui_title "${ICON_ROCKET} ULTRA SYSTEM SCAN (FULL)"
    ui_hint "🚀 Covers CPU, GPU, Disk, Network, Security, Daemons, and Risk Analysis."
    echo "MacDoctor Ultra Scan Report - $(date '+%Y-%m-%d_%H-%M-%S')" > "$report_file"
    echo "================================================================================" >> "$report_file"
    draw_progress_bar 5
    
    # Capture key module output into the report (terminal + report file).
    local report_save="$REPORT_BUFFER"
    REPORT_BUFFER=""
    REPORT_CAPTURE=1

    out "--- 1. CPU / GPU DIAGNOSTICS ---"
    check_gpu_diagnostics
    out ""
    echo -e "$REPORT_BUFFER" >> "$report_file"
    REPORT_BUFFER=""

    out "--- 2. NETWORK DIAGNOSTICS ---"
    check_network_deep
    out ""
    echo -e "$REPORT_BUFFER" >> "$report_file"
    REPORT_BUFFER=""

    out "--- 3. DISK / SSD HEALTH ---"
    check_storage_deep
    out ""
    echo -e "$REPORT_BUFFER" >> "$report_file"
    REPORT_BUFFER=""

    REPORT_CAPTURE=0
    REPORT_BUFFER="$report_save"
    
    echo "--- 4. SECURITY AUDIT ---" >> "$report_file"
    fdesetup status 2>/dev/null | grep -q "On" && echo "FileVault: On" >> "$report_file" || echo "FileVault: Off" >> "$report_file"
    /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q "enabled" && echo "Firewall: On" >> "$report_file" || echo "Firewall: Off" >> "$report_file"
    spctl --status 2>/dev/null | grep -q "assessments enabled" && echo "Gatekeeper: On" >> "$report_file" || echo "Gatekeeper: Off" >> "$report_file"
    command -v csrutil &>/dev/null && (csrutil status 2>/dev/null | grep -q "enabled" && echo "SIP: On" >> "$report_file" || echo "SIP: Off" >> "$report_file") || echo "SIP: N/A" >> "$report_file"

    echo "" >> "$report_file"
    echo "--- 5. LOGIN ITEMS / DAEMONS ---" >> "$report_file"
    if command -v launchctl &> /dev/null; then
        launchctl list 2>/dev/null | awk 'NR>1 && $3 !~ /^com\.apple/' | head -n 10 | sed 's/^/   /' >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "--- 6. CLEANUP & RECOMMENDATIONS ---" >> "$report_file"
    echo "Heavy Caches:" >> "$report_file"
    du -sh ~/Library/Caches/* 2>/dev/null | sort -rh | head -n 5 >> "$report_file"

    echo ""
    echo "${GREEN}${ICON_OK} Ultra Scan Complete. Report saved to Desktop.${RESET}"
    echo "Report saved to: $report_file"
    add_to_report "Ultra Scan Finished."
    echo "$report_file" > "$LAST_REPORT_PATH_FILE" 2>/dev/null

    run_local_semantic_analysis "ultra" "$report_file"
}

cleanup_safe() {
    echo "${BOLD}${GREEN}Starting Safe Cleanup...${RESET}"
    draw_progress_bar 2
    # Standard caches
    safe_delete "$HOME/Library/Caches/com.apple.Safari"
    safe_delete "$HOME/Library/Caches/Firefox"
    safe_delete "$HOME/Library/Caches/Spotify"
    safe_delete "$HOME/Library/Caches/com.google.Chrome"
    # New App Caches
    safe_delete "$HOME/Library/Caches/JetBrains"
    safe_delete "$HOME/Library/Caches/com.microsoft.teams"
    safe_delete "$HOME/Library/Caches/us.zoom.xos"
    safe_delete "$HOME/Library/Caches/Slack"
    safe_delete "$HOME/Library/Caches/Discord"
    
    out "   ${YELLOW}${ICON_WARN} User logs will be archived to backup (reversible).${RESET}"
    if confirm_dangerous "Archive ALL user logs under ~/Library/Logs" "ARCHIVE"; then
        if [[ -d "$HOME/Library/Logs" ]]; then
            while IFS= read -r -d '' log_path; do
                safe_delete "$log_path"
            done < <(find "$HOME/Library/Logs" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
            log_action "Archived User Logs"
            status_line OK "User logs" "Archived to backup."
        else
            status_line INFO "User logs" "Directory not found. Nothing to clear."
        fi
    else
        status_line INFO "User logs" "Skipped."
    fi
    
    echo "   ${ICON_TRASH} Resetting QuickLook..."
    qlmanage -r cache &> /dev/null
    
    add_to_report "Safe Cleanup executed."
    echo "${GREEN}Safe Cleanup Complete.${RESET}"
}

cleanup_deep() {
    echo "${BOLD}${YELLOW}Starting Deep Cleanup...${RESET}"
    cleanup_safe
    
    # Xcode items
    if [[ -d "$HOME/Library/Developer/Xcode/DerivedData" ]]; then
        echo -n "   Clean Xcode DerivedData? (y/n): "
        read -r resp
        if [[ "$resp" =~ ^[Yy]$ ]]; then safe_delete "$HOME/Library/Developer/Xcode/DerivedData"; fi
    fi
    if [[ -d "$HOME/Library/Developer/Xcode/Archives" ]]; then
        echo -n "   Clean Xcode Archives? (y/n): "
        read -r resp
        if [[ "$resp" =~ ^[Yy]$ ]]; then safe_delete "$HOME/Library/Developer/Xcode/Archives"; fi
    fi
    
    # Homebrew
    if check_brew; then
        echo "   ${ICON_TRASH} Running Homebrew Cleanup..."
        if brew cleanup -s &> /dev/null; then
            log_action "Homebrew cleanup successful."
        else
            echo "brew failed on this macOS version. Skipping."
            log_action "FAIL: Homebrew cleanup failed."
        fi
    else
        echo "Homebrew unavailable. Skipping."
    fi
    
    # Docker
    if command -v docker &> /dev/null; then
        echo -n "   Prune Docker? (y/n): "
        read -r resp
        if [[ "$resp" =~ ^[Yy]$ ]]; then
            if ! docker system prune -f &> /dev/null; then
                echo "docker failed on this macOS version. Skipping."
            else
                log_action "Docker system pruned."
            fi
        fi
    fi

    # Skip destructive full-container cleanup by default (too risky)
    echo "   ${ICON_TRASH} Skipping bulk Container/Application Support removal (safety)."
    
    add_to_report "Deep Cleanup executed."
    echo "${GREEN}Deep Cleanup Complete.${RESET}"
}

cleanup_aggressive() {
    if [[ "$MODE" != "FULL" ]]; then
        echo "${RED}Aggressive cleanup is only available in FULL mode for safety.${RESET}"
        sleep 1
        return
    fi
    if ! ask_sudo; then return; fi
    echo "${BOLD}${BG_RED}WARNING: Aggressive Cleanup initiated.${RESET}"
    echo "Includes: Logs, Snapshots, RAM, DNS, Maintenance Scripts."
    echo -n "Confirm (type 'YES'): "
    read -r resp
    if [[ "$resp" != "YES" ]]; then echo "Aborted."; return; fi
    
    draw_progress_bar 4
    echo "   ${ICON_TRASH} Skipping wholesale removal of /var/log (safety)."
    log_action "Aggressive cleanup started (logs preserved)."
    
    # Periodic Maintenance
    echo "   ${ICON_TOOL} Running Periodic Maintenance..."
    if confirm_dangerous "Run periodic daily/weekly/monthly maintenance (sudo periodic)" "YES"; then
        sudo periodic daily weekly monthly
        log_action "Ran sudo periodic maintenance."
    else
        status_line INFO "periodic" "Skipped."
    fi
    
    echo "   ${ICON_DISK} Cleaning Local Snapshots..."
    if command -v tmutil &> /dev/null; then
        if confirm_dangerous "Delete ALL local APFS snapshots (tmutil deletelocalsnapshots)" "DELETE"; then
            tmutil listlocalsnapshots / 2>/dev/null | cut -d'.' -f4 | while read -r snap; do
                if [[ -n "$snap" ]]; then sudo tmutil deletelocalsnapshots "$snap" >/dev/null; fi
            done
            log_action "Cleaned local APFS snapshots."
        else
            status_line INFO "Snapshots" "Skipped."
        fi
    else
        echo "Tool tmutil unavailable on this system."
    fi
    
    echo "   ${ICON_NET} Flushing DNS..."
    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null
    log_action "Flushed DNS cache."
    
    echo "   ${ICON_RAM} Purging RAM..."
    if confirm_dangerous "Purge RAM (sudo purge). May briefly stall apps." "PURGE"; then
        sudo purge
        log_action "Ran sudo purge."
    else
        status_line INFO "purge" "Skipped."
    fi
    
    echo -n "   Rebuild Spotlight? (y/n): "
    read -r spot
    if [[ "$spot" =~ ^[Yy]$ ]]; then
        if ! command -v mdutil &> /dev/null; then
            echo "Tool mdutil unavailable on this system."
        else
            if ! sudo mdutil -E / >/dev/null; then
                echo "mdutil failed on this macOS version. Skipping."
            else
                log_action "Rebuilt Spotlight index."
            fi
        fi
    fi
    
    add_to_report "Aggressive Cleanup executed."
    echo "${GREEN}Aggressive Optimization Complete.${RESET}"
}

run_mac_cleanup_py() {
    clear
    ui_title "${ICON_TRASH} MAC-CLEANUP-PY (EXTERNAL)"
    ui_hint "⚠️  External tool. Review prompts carefully."
    
    if command -v mac-cleanup-py &> /dev/null; then
        echo "mac-cleanup-py is an external, opinionated deep-clean tool."
        echo "It may remove additional caches beyond MacDoctor's own cleanup."
        echo -n "Run mac-cleanup-py now? (y/n): "
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            log_action "Running mac-cleanup-py."
            if ! mac-cleanup-py; then
                echo "mac-cleanup-py failed on this system. Skipping."
            fi
        fi
    elif check_brew; then
        echo "mac-cleanup-py is not installed. Install via Homebrew and run it? (y/n): "
        read -r confirm_install
        if [[ "$confirm_install" =~ ^[Yy]$ ]]; then
            if brew install mac-cleanup-py; then
                echo -n "Run mac-cleanup-py now? (y/n): "
                read -r confirm_run
                if [[ "$confirm_run" =~ ^[Yy]$ ]]; then
                    log_action "Running mac-cleanup-py."
                    if ! mac-cleanup-py; then
                        echo "mac-cleanup-py failed on this system. Skipping."
                    fi
                fi
            else
                echo "Install failed."
            fi
        fi
    else
        echo "mac-cleanup-py and Homebrew unavailable. Skipping."
    fi
    pause_continue
}

cleanup_dsstore() {
    echo "This will delete .DS_Store metadata files only."
    echo "It only runs under your Home folder ($HOME)."
    echo "It can reset folder view preferences, but does NOT delete user data."
    echo -n "Proceed with .DS_Store cleanup in your Home folder? (y/n): "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        find "$HOME" -name ".DS_Store" -delete 2>/dev/null
        log_action "Cleaned .DS_Store files in $HOME"
        echo "${GREEN}.DS_Store cleanup complete.${RESET}"
    fi
}

handle_cleanup() {
    while true; do
        clear
        ui_title "CLEANUP & OPTIMIZATION"
        ui_hint "Start with option 1. It archives data to backup when possible."
        echo "1. ${GREEN}Safe Cleanup (recommended)${RESET}"
        echo "2. ${YELLOW}Deep Cleanup (developer + package cleanup)${RESET}"
        echo "3. ${RED}Aggressive Cleanup (FULL mode only, risky)${RESET}"
        echo "4. ${PURPLE}Run mac-cleanup-py (external tool)${RESET}"
        echo "5. Clean .DS_Store files in Home folder"
        echo "6. Back"
        echo -n "👉 Selection: "
        local choice
        read_user_line choice || choice="6"
        case $choice in
            1) cleanup_safe; pause_continue ;;
            2) cleanup_deep; pause_continue ;;
            3) cleanup_aggressive; pause_continue ;;
            4) run_mac_cleanup_py ;;
            5) cleanup_dsstore; pause_continue ;;
            6) return ;;
            *) echo "Invalid option." ;;
        esac
    done
}

run_wizard() {
    clear
    ui_title "${ICON_WIZARD} SYSTEM OPTIMIZATION WIZARD"
    ui_hint "🧠 I will suggest a few safe, targeted tweaks. You decide each step."
    echo "Scanning system for recommendations... ⏳"
    draw_progress_bar 2
    local rec_count=0
    
    # Network
    echo ""
    echo "${BOLD}1. 🌐 Network Optimization (DNS)${RESET}"
    echo "   This can fix slow lookups or stale DNS records."
    echo -n "   Apply DNS Flush? (y/n): "
    read -r r1
    if [[ "$r1" =~ ^[Yy]$ ]]; then 
        if ask_sudo; then 
            sudo dscacheutil -flushcache 2>/dev/null; sudo killall -HUP mDNSResponder 2>/dev/null; 
            log_action "WIZARD: DNS Flushed."
            ((rec_count++)); 
        fi
    fi
    
    # RAM
    echo ""
    echo "${BOLD}2. 💾 Memory Optimization${RESET}"
    echo "   Frees inactive memory. Safe, but may briefly slow apps."
    echo -n "   Purge RAM? (y/n): "
    read -r r2
    if [[ "$r2" =~ ^[Yy]$ ]]; then 
        if ask_sudo; then 
            sudo purge; 
            log_action "WIZARD: RAM Purged."
            ((rec_count++)); 
        fi
    fi
    
    # Security Risk Check
    echo ""
    echo "${BOLD}3. 🔒 Security Risk Fixes${RESET}"
    local gatekeeper_status=$(spctl --status 2>/dev/null | grep -o "enabled\|disabled")
    
    if [[ "$gatekeeper_status" != "enabled" ]]; then
        echo "   ${RED}Gatekeeper is OFF.${RESET}"
        echo "   This helps block unsigned apps."
        echo -n "   Enable Gatekeeper now? (y/n): "
        read -r r3
        if [[ "$r3" =~ ^[Yy]$ ]]; then
             if ask_sudo; then sudo spctl --master-enable 2>/dev/null; ((rec_count++)); log_action "WIZARD: Gatekeeper enabled."; fi
        fi
    fi
    
    echo ""
    echo "${GREEN}${ICON_OK} Wizard Complete. Applied $rec_count optimizations.${RESET}"
    add_to_report "Wizard ran $rec_count optimizations."
    pause_continue
}

live_monitor() {
    echo "${YELLOW}📈 Live Mode (Press q + Enter to exit, or wait to refresh)${RESET}"
    while true; do 
        show_dashboard
        echo "${YELLOW}📈 Live Mode (Press q + Enter to exit, Enter to refresh)${RESET}"
        read -r -t 2 user_live
        if [[ "$user_live" == "q" || "$user_live" == "Q" ]]; then break; fi
    done
}

rebuild_font_caches() {
    if ! command -v atsutil &> /dev/null; then
        echo "atsutil not available on this system. Skipping."
        return
    fi
    echo "Clearing font caches may cause some apps to reload fonts."
    echo "No user documents or data are removed."
    echo -n "Rebuild font caches now? (y/n): "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if ask_sudo; then
            if ! sudo atsutil databases -remove 2>/dev/null; then
                echo "atsutil failed on this macOS version. Skipping."
            fi
            if ! sudo atsutil server -shutdown 2>/dev/null; then
                echo "atsutil failed on this macOS version. Skipping."
            fi
            sleep 1
            if ! sudo atsutil server -ping 2>/dev/null; then
                echo "atsutil failed on this macOS version. Skipping."
            else
                log_action "Font caches rebuilt."
            fi
        fi
    fi
}

network_reset_refresh() {
    echo "This will flush DNS cache and attempt to renew DHCP on active interfaces."
    echo "It will NOT delete Wi-Fi networks or system configs."
    echo -n "Run network reset/refresh now? (y/n): "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if ask_sudo; then
            if ! command -v dscacheutil &> /dev/null; then
                echo "Tool dscacheutil unavailable on this system."
            else
                if ! sudo dscacheutil -flushcache 2>/dev/null; then
                    echo "dscacheutil failed on this macOS version. Skipping."
                fi
            fi
            if ! command -v killall &> /dev/null; then
                echo "Tool killall unavailable on this system."
            else
                if ! sudo killall -HUP mDNSResponder 2>/dev/null; then
                    echo "killall failed on this macOS version. Skipping."
                fi
            fi
            if ! command -v networksetup &> /dev/null; then
                echo "Tool networksetup unavailable on this system."
            else
                local hw_ports=$(networksetup -listallhardwareports 2>/dev/null)
                if [[ -z "$hw_ports" ]]; then
                    echo "networksetup failed on this macOS version. Skipping."
                else
                    echo "$hw_ports" | grep -A 1 "Device:" | grep "Device:" | awk '{print $2}' | while read -r device; do
                        if [[ -n "$device" ]]; then
                            if ! command -v ipconfig &> /dev/null; then
                                echo "Tool ipconfig unavailable on this system."
                            else
                                if ! sudo ipconfig set "$device" DHCP 2>/dev/null; then
                                    echo "DHCP renew failed on $device (skipping)."
                                fi
                            fi
                        fi
                    done
                fi
            fi
            log_action "Network reset/refresh completed."
        fi
    fi
}

system_maintenance_menu() {
    while true; do
        clear
        ui_title "${ICON_TOOL} SYSTEM MAINTENANCE & UTILITIES"
        ui_hint "🧼 Small fixes that can help performance or networking."
        echo "1. Clean .DS_Store files in Home directory"
        echo "2. Rebuild Font Caches (atsutil)"
        echo "3. Network Reset / Refresh (DNS + DHCP Renew)"
        echo "4. Back"
        echo -n "👉 Selection: "
        local maint_choice
        read_user_line maint_choice || maint_choice="4"
        
        case $maint_choice in
            1) cleanup_dsstore; pause_continue ;;
            2) rebuild_font_caches; pause_continue ;;
            3) network_reset_refresh; pause_continue ;;
            4) return ;;
            *) echo "Invalid option."; sleep 1 ;;
        esac
    done
}

run_super_update() {
    clear
    ui_title "${ICON_UPD} SUPER ADVANCED MACOS UPDATE REPORT"
    ui_hint "🧩 External utility detected. Launch manually for full control."
    
    if ! command -v super &> /dev/null; then
        echo "super is not installed on this system."
        pause_continue
        return
    fi
    
    echo "super is installed. Please run it manually for advanced update flows."
    pause_continue
}

settings_menu() {
    while true; do
        clear
        echo ""
        ui_box_top "Settings"
        ui_box_row "${DIM}Customize MacDoctor${RESET}"
        ui_box_bottom
        echo ""
        
        # Show current settings summary
        show_settings_summary
        
        ui_hint "Settings auto-saved"
        echo ""
        
        echo "  ${BOLD}${PRIMARY}  Look & Feel${RESET}"
        ui_list_item 1 "🎨 Theme" "$(capitalize_first "$THEME")"
        ui_list_item 2 "📋 Scan Results Style" "$(capitalize_first "$RESULT_STYLE")"
        ui_list_item 3 "📊 Dashboard Style" "$(capitalize_first "$DASHBOARD_STYLE")"
        ui_list_item 4 "😀 Emoji" "$([ $USE_EMOJI -eq 1 ] && echo "${SUCCESS}ON${RESET}" || echo "${DIM}OFF${RESET}")"
        echo ""
        echo "  ${BOLD}${PRIMARY}  How Much to Show${RESET}"
        ui_list_item 5 "👤 Simple / Expert" "$(capitalize_first "$USER_LEVEL")"
        ui_list_item 6 "🔧 Show Extra Details" "$([ $SHOW_TECHNICAL_DETAILS -eq 1 ] && echo "${SUCCESS}ON${RESET}" || echo "${DIM}OFF${RESET}")"
        ui_list_item 7 "📐 Smaller Layout" "$([ $COMPACT_MODE -eq 1 ] && echo "${SUCCESS}ON${RESET}" || echo "${DIM}OFF${RESET}")"
        ui_list_item 8 "🏠 Home Screen Widgets" "Choose what to show"
        ui_list_item 9 "🔍 Scan Depth" "$(capitalize_first "$ANALYSIS_DEPTH")"
        echo ""
        echo "  ${BOLD}${PRIMARY}  Advanced${RESET}"
        ui_list_item 10 "⚡ Safety Mode" "${MODE}"
        ui_list_item 11 "🚦 Startup Check" "$([ $SHOW_PREFLIGHT -eq 1 ] && echo "${SUCCESS}ON${RESET}" || echo "${DIM}OFF${RESET}")"
        echo ""
        ui_line 50
        ui_list_item 12 "🔄 Reset to Defaults" "Restore recommended settings"
        ui_list_item 0 "Back" "Return to main menu"
        echo ""

        # ── Setting descriptions (shown after selection) ──
        _settings_desc() {
            local d=""
            case "$1" in
                1)  d="Theme: Changes all the colors in the app." ;;
                2)  d="Scan Results Style: Changes how results look after you run a scan." ;;
                3)  d="Dashboard Style: How the dashboard page refreshes — snapshot or live." ;;
                4)  d="Emoji: Show or hide emoji icons in menus." ;;
                5)  d="Simple / Expert: Simple shows fewer menus. Expert shows everything." ;;
                6)  d="Show Extra Details: Show extra numbers and technical info in scan results." ;;
                7)  d="Smaller Layout: Reduces spacing — useful if your terminal window is small." ;;
                8)  d="Home Screen Widgets: Choose what stats (battery, network, etc.) show on the main screen." ;;
                9)  d="Scan Depth: How thorough each scan is — Quick, Standard, or Thorough." ;;
                10) d="Safety Mode: Safe = read-only. Standard = normal. Full = can make system changes." ;;
                11) d="Startup Check: Show a quick check when MacDoctor launches." ;;
                12) d="Reset: Restore all settings to their defaults." ;;
            esac
            [[ -n "$d" ]] && echo "  ${DIM}${BOX_V} ${d}${RESET}"
        }
        echo ""
        
        local choice
        choice=$(ui_choose "Select setting" 12)

        # Show description for selected item
        [[ "$choice" =~ ^[0-9]+$ && $choice -ge 1 && $choice -le 12 ]] && _settings_desc "$choice"
        
        case $choice in
            1)
                clear; echo ""
                ui_box_top "Choose Theme"
                ui_box_row "${DIM}Changes all the colors in the app${RESET}"
                ui_box_bottom
                echo ""
                echo "  ${ESC_SEQ}38;5;172m█${RESET} ${HIGHLIGHT}1${RESET}${DIM})${RESET} Bronze        ${ESC_SEQ}38;5;46m█${RESET} ${HIGHLIGHT}2${RESET}${DIM})${RESET} Terminal      ${ESC_SEQ}38;5;201m█${RESET} ${HIGHLIGHT}3${RESET}${DIM})${RESET} Neon"
                echo "  ${ESC_SEQ}38;5;214m█${RESET} ${HIGHLIGHT}4${RESET}${DIM})${RESET} Amber         ${ESC_SEQ}38;5;75m█${RESET} ${HIGHLIGHT}5${RESET}${DIM})${RESET} Classic       ${ESC_SEQ}38;5;250m█${RESET} ${HIGHLIGHT}6${RESET}${DIM})${RESET} Minimal"
                echo "  ${ESC_SEQ}38;5;110m█${RESET} ${HIGHLIGHT}7${RESET}${DIM})${RESET} Frost         ${ESC_SEQ}38;5;33m█${RESET} ${HIGHLIGHT}8${RESET}${DIM})${RESET} Solar         ${ESC_SEQ}38;5;141m█${RESET} ${HIGHLIGHT}9${RESET}${DIM})${RESET} Midnight"
                echo "  ${ESC_SEQ}38;5;75m█${RESET} ${HIGHLIGHT}10${RESET}${DIM})${RESET} Atom         ${ESC_SEQ}38;5;214m█${RESET} ${HIGHLIGHT}11${RESET}${DIM})${RESET} Warm"
                echo ""; ui_list_item 0 "Back" ""; echo ""
                local theme_choice
                theme_choice=$(ui_choose "Select theme" 11)
                case $theme_choice in
                    1) THEME="bronze" ;; 2) THEME="terminal" ;; 3) THEME="neon" ;;
                    4) THEME="amber" ;; 5) THEME="classic" ;; 6) THEME="minimal" ;;
                    7) THEME="frost" ;; 8) THEME="solar" ;; 9) THEME="midnight" ;;
                    10) THEME="atom" ;; 11) THEME="warm" ;; 0) continue ;;
                esac
                apply_theme; preview_theme "$THEME"; save_settings; pause_continue ;;
            2)
                clear; echo ""
                ui_box_top "Scan Results Style"
                ui_box_row "${DIM}Changes how results look after you run a scan${RESET}"
                ui_box_bottom; echo ""
                ui_list_item 1 "Cards" "Clean boxed sections (recommended)"
                ui_list_item 2 "Table" "Compact rows and columns"
                ui_list_item 3 "Visual" "Progress bars and gauges"
                ui_list_item 0 "Back" ""; echo ""
                local style_choice
                style_choice=$(ui_choose "Select style" 3)
                case $style_choice in
                    1) RESULT_STYLE="cards" ;; 2) RESULT_STYLE="table" ;; 3) RESULT_STYLE="visual" ;; 0) continue ;;
                esac
                [[ $style_choice -ne 0 ]] && { save_settings; ui_toast "Style: $(capitalize_first "$RESULT_STYLE")" "OK"; pause_continue; } ;;
            3)
                clear; echo ""
                ui_box_top "Dashboard Style"
                ui_box_row "${DIM}How the dashboard page refreshes${RESET}"
                ui_box_bottom; echo ""
                ui_list_item 1 "Live" "Auto-refreshes every second"
                ui_list_item 2 "Static" "Snapshot, refresh manually"
                ui_list_item 3 "Animated" "Visual bars with auto-refresh"
                ui_list_item 4 "Minimal" "Compact one-line gauges"
                ui_list_item 0 "Back" ""; echo ""
                local dash_choice
                dash_choice=$(ui_choose "Select" 4)
                case $dash_choice in
                    1) DASHBOARD_STYLE="top_like" ;; 2) DASHBOARD_STYLE="static" ;;
                    3) DASHBOARD_STYLE="animated" ;; 4) DASHBOARD_STYLE="minimal" ;; 0) continue ;;
                esac
                [[ $dash_choice -ne 0 ]] && { save_settings; ui_toast "Dashboard: $(capitalize_first "$DASHBOARD_STYLE")" "OK"; pause_continue; } ;;
            4) USE_EMOJI=$((1 - USE_EMOJI)); set_icons_for_current_theme; save_settings ;;
            5)
                clear; echo ""
                ui_box_top "Simple / Expert"
                ui_box_row "${DIM}Controls how many features are visible in menus${RESET}"
                ui_box_bottom; echo ""
                ui_list_item 1 "Simple" "Just the basics"
                ui_list_item 2 "Standard" "Most features"
                ui_list_item 3 "Expert" "Everything unlocked"
                ui_list_item 0 "Back" ""; echo ""
                local level_choice
                level_choice=$(ui_choose "Select" 3)
                case $level_choice in
                    1) USER_LEVEL="beginner" ;; 2) USER_LEVEL="intermediate" ;; 3) USER_LEVEL="power" ;; 0) continue ;;
                esac
                [[ $level_choice -ne 0 ]] && { save_settings; ui_toast "Level: $(capitalize_first "$USER_LEVEL")" "OK"; pause_continue; } ;;
            6) SHOW_TECHNICAL_DETAILS=$((1 - SHOW_TECHNICAL_DETAILS)); save_settings ;;
            7) COMPACT_MODE=$((1 - COMPACT_MODE)); save_settings ;;
            8)
                while true; do
                    clear; echo ""
                    ui_box_top "Home Screen Widgets"
                    ui_box_row "${DIM}Choose what stats appear on the main screen${RESET}"
                    ui_box_bottom; echo ""
                    ui_list_item 1 "Battery" "$([ $HOME_SHOW_BATTERY -eq 1 ] && echo "${SUCCESS}ON${RESET}" || echo "${DIM}OFF${RESET}")"
                    ui_list_item 2 "Network" "$([ $HOME_SHOW_NETWORK -eq 1 ] && echo "${SUCCESS}ON${RESET}" || echo "${DIM}OFF${RESET}")"
                    ui_list_item 3 "Uptime" "$([ $HOME_SHOW_UPTIME -eq 1 ] && echo "${SUCCESS}ON${RESET}" || echo "${DIM}OFF${RESET}")"
                    ui_list_item 4 "Thermal" "$([ $HOME_SHOW_THERMAL -eq 1 ] && echo "${SUCCESS}ON${RESET}" || echo "${DIM}OFF${RESET}")"
                    ui_list_item 0 "Back" ""; echo ""
                    local hc
                    hc=$(ui_choose "Toggle" 4)
                    case $hc in
                        0) break ;;
                        1) HOME_SHOW_BATTERY=$((1 - HOME_SHOW_BATTERY)); save_settings ;;
                        2) HOME_SHOW_NETWORK=$((1 - HOME_SHOW_NETWORK)); save_settings ;;
                        3) HOME_SHOW_UPTIME=$((1 - HOME_SHOW_UPTIME)); save_settings ;;
                        4) HOME_SHOW_THERMAL=$((1 - HOME_SHOW_THERMAL)); save_settings ;;
                    esac
                done ;;
            9)
                clear; echo ""
                ui_box_top "Scan Depth"
                ui_box_row "${DIM}How thoroughly MacDoctor inspects your system${RESET}"
                ui_box_bottom; echo ""
                ui_list_item 1 "Quick" "Fast overview"
                ui_list_item 2 "Standard" "Recommended for most people"
                ui_list_item 3 "Thorough" "Checks everything"
                echo ""
                local ad
                ad=$(ui_choose "Select depth" 3)
                case $ad in 1) ANALYSIS_DEPTH="quick" ;; 2) ANALYSIS_DEPTH="standard" ;; 3) ANALYSIS_DEPTH="thorough" ;; esac
                save_settings ;;
            10)
                clear; echo ""
                ui_box_top "Safety Mode"
                ui_box_row "${DIM}What kind of changes MacDoctor is allowed to make${RESET}"
                ui_box_bottom; echo ""
                ui_list_item 1 "Safe" "Read-only, no changes"
                ui_list_item 2 "Standard" "Normal operations (recommended)"
                ui_list_item 3 "Full" "Everything, including system changes"
                echo ""
                local mode_choice
                mode_choice=$(ui_choose "Select mode" 3)
                case $mode_choice in 1) MODE="SAFE" ;; 2) MODE="STANDARD" ;; 3) MODE="FULL" ;; esac
                save_settings ;;
            11) SHOW_PREFLIGHT=$((1 - SHOW_PREFLIGHT)); save_settings ;;
            12)
                if ui_confirm "Reset all settings to defaults?"; then
                    THEME="classic"; RESULT_STYLE="cards"; USER_LEVEL="power"
                    DASHBOARD_STYLE="static"; MODE="STANDARD"; AUTO_INSTALL=1
                    USE_EMOJI=0; SHOW_PREFLIGHT=0; COMPACT_MODE=0
                    SHOW_TECHNICAL_DETAILS=1; ANALYSIS_DEPTH="standard"
                    HOME_SHOW_BATTERY=1; HOME_SHOW_NETWORK=0; HOME_SHOW_UPTIME=1; HOME_SHOW_THERMAL=0
                    apply_theme; set_icons_for_current_theme; save_settings
                    ui_toast "All settings reset to defaults" "OK"; pause_continue
                fi ;;
            0) return ;;
            *) ui_toast "Invalid option" "WARN"; sleep 1 ;;
        esac
    done
}

utilities_menu() {
    while true; do
        clear
        echo ""
        ui_box_top "Utilities & Maintenance"
        ui_box_bottom
        echo ""
        ui_list_item 1 "🔋 Battery Health" "Extended battery diagnostics"
        ui_list_item 2 "📦 Software Updates" "Check for macOS updates"
        ui_list_item 3 "📋 Update Report" "Detailed update analysis"
        ui_list_item 4 "🔑 Login Items" "Manage startup applications"
        ui_list_item 5 "🔧 Maintenance" "System maintenance tasks"
        ui_list_item 0 "Back" ""
        echo ""
        
        local util_choice
        util_choice=$(ui_choose "Select" 5)
        
        case $util_choice in
            1) battery_extended; pause_continue ;;
            2) software_update_check ;;
            3) run_super_update ;;
            4) login_items_manager ;;
            5) system_maintenance_menu ;;
            0) return ;;
            *) ui_toast "Invalid option" "WARN"; sleep 1 ;;
        esac
    done
}

# --- MAIN MENU ---

show_main_menu() {
    while true; do
        clear

        # ── Header ──
        echo ""
        echo "  ${DIM}${BOX_TL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_TR}${RESET}"
        printf "  ${DIM}${BOX_V}${RESET}  ${BOLD}${PRIMARY}MacDoctor${RESET} ${DIM}v${VERSION}${RESET}"
        printf "%*s" $(( 43 - ${#VERSION} )) ""
        printf "${DIM}${BOX_V}${RESET}\n"
        printf "  ${DIM}${BOX_V}${RESET}  ${DIM}Your Mac's health checkup${RESET}"
        printf "%*s${DIM}${BOX_V}${RESET}\n" 28 ""
        echo "  ${DIM}${BOX_BL}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_BR}${RESET}"
        echo ""

        # ── Quick status bars ──
        local cpu=$(get_cpu_load 2>/dev/null || echo "0")
        local cpu_int="${cpu%.*}"; [[ -z "$cpu_int" ]] && cpu_int=0
        local mem_bytes_main=$(sysctl -n hw.memsize 2>/dev/null)
        local total_mem_main=$(( ${mem_bytes_main:-0} / 1024 / 1024 ))
        [[ "$total_mem_main" -le 0 ]] 2>/dev/null && total_mem_main=16384
        local ram_used_main=$(get_memory_usage 2>/dev/null || echo 0)
        local ram_pct=$(LC_ALL=C awk -v u="$ram_used_main" -v t="$total_mem_main" 'BEGIN{if(t>0){printf "%.0f", (u/t)*100} else {print "0"}}')
        local disk_pct=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' 2>/dev/null || echo "0")
        [[ -z "$disk_pct" ]] && disk_pct=0
        local disk_free=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}')

        local cpu_badge="OK"; [[ $cpu_int -gt 80 ]] && cpu_badge="FAIL"; [[ $cpu_int -gt 50 && $cpu_int -le 80 ]] && cpu_badge="WARN"
        local ram_badge="OK"; [[ $ram_pct -gt 85 ]] && ram_badge="FAIL"; [[ $ram_pct -gt 60 && $ram_pct -le 85 ]] && ram_badge="WARN"
        local dsk_badge="OK"; [[ $disk_pct -gt 90 ]] && dsk_badge="FAIL"; [[ $disk_pct -gt 75 && $disk_pct -le 90 ]] && dsk_badge="WARN"

        ui_badge_bar "$cpu_badge" "CPU" "$cpu_int" "${cpu}%"
        ui_badge_bar "$ram_badge" "Memory" "$ram_pct" "${ram_used_main}MB / ${total_mem_main}MB"
        ui_badge_bar "$dsk_badge" "Disk" "$disk_pct" "${disk_pct}% used (${disk_free} free)"

        # ── Configurable extra data points ──
        if [[ $HOME_SHOW_BATTERY -eq 1 ]]; then
            local batt_pct=$(pmset -g batt 2>/dev/null | grep -o "[0-9]*%" | head -1 | tr -d '%')
            if [[ -n "$batt_pct" ]]; then
                local batt_state=$(pmset -g batt 2>/dev/null | grep -oE "charging|discharging|charged|AC Power" | head -1)
                local batt_badge="OK"; [[ $batt_pct -lt 20 ]] && batt_badge="WARN"; [[ $batt_pct -lt 10 ]] && batt_badge="FAIL"

                local batt_detail="${batt_pct}% ${batt_state}"
                local ioreg_out=$(ioreg -r -c AppleSmartBattery 2>/dev/null)
                if [[ -n "$ioreg_out" ]]; then
                    local cycles=$(echo "$ioreg_out" | grep '"CycleCount" =' | awk '{print $NF}' | head -1)
                    local nom_cap=$(echo "$ioreg_out" | grep '"NominalChargeCapacity" =' | awk '{print $NF}' | head -1)
                    local design_cap=$(echo "$ioreg_out" | grep '"DesignCapacity" =' | awk '{print $NF}' | head -1)
                    cycles="${cycles//[^0-9]/}"
                    nom_cap="${nom_cap//[^0-9]/}"
                    design_cap="${design_cap//[^0-9]/}"
                    if [[ -n "$nom_cap" && -n "$design_cap" && "${design_cap:-0}" != "0" && "${nom_cap:-0}" != "0" ]]; then
                        local health_pct=$(( nom_cap * 100 / design_cap ))
                        [[ $health_pct -gt 100 ]] && health_pct=100
                        local h_word="healthy"
                        [[ $health_pct -lt 80 ]] && h_word="degraded"
                        [[ $health_pct -lt 60 ]] && h_word="replace soon"
                        batt_detail="${batt_pct}% ${batt_state} | Health ${health_pct}% · ${cycles:-?} cycles (${h_word})"
                    elif [[ -n "$cycles" ]]; then
                        batt_detail="${batt_pct}% ${batt_state} | ${cycles} cycles"
                    fi
                fi
                ui_badge_bar "$batt_badge" "Battery" "$batt_pct" "$batt_detail"
            fi
        fi
        if [[ $HOME_SHOW_NETWORK -eq 1 ]]; then
            local net_if=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
            local net_ip=$(ipconfig getifaddr "$net_if" 2>/dev/null)
            if [[ -n "$net_ip" ]]; then
                echo "  ${SUCCESS}${ICON_OK}${RESET} Network    ${DIM}${net_if}: ${net_ip}${RESET}"
            else
                echo "  ${YELLOW}${ICON_WARN}${RESET} Network    ${DIM}No active connection${RESET}"
            fi
        fi
        if [[ $HOME_SHOW_UPTIME -eq 1 ]]; then
            local up=$(get_uptime_pretty 2>/dev/null)
            echo "  ${SUCCESS}${ICON_OK}${RESET} Uptime     ${DIM}${up}${RESET}"
        fi
        if [[ $HOME_SHOW_THERMAL -eq 1 ]]; then
            local thermal=$(pmset -g therm 2>/dev/null | grep -i "CPU_Speed_Limit" | awk '{print $3}')
            [[ -z "$thermal" ]] && thermal="100"
            if [[ $thermal -ge 80 ]]; then
                echo "  ${SUCCESS}${ICON_OK}${RESET} Thermal    ${DIM}Normal (${thermal}%)${RESET}"
            elif [[ $thermal -ge 60 ]]; then
                echo "  ${YELLOW}${ICON_WARN}${RESET} Thermal    ${YELLOW}Warm — throttled to ${thermal}%${RESET}"
            else
                echo "  ${RED}${ICON_WARN}${RESET} Thermal    ${RED}Hot — throttled to ${thermal}%${RESET}"
            fi
        fi

        # Health Score
        local health=$(compute_health_score "$cpu_int" "$ram_pct" "$disk_pct")
        local h_color=$(health_color "$health")
        local h_label=$(health_label "$health")
        local h_hint=$(health_hint "$cpu_int" "$ram_pct" "$disk_pct")
        local h_filled=$(( health * 20 / 100 ))
        local h_bar="${DIM}["
        for ((i=0; i<h_filled; i++)); do h_bar+="▪"; done
        for ((i=h_filled; i<20; i++)); do h_bar+="·"; done
        h_bar+="]${RESET}"

        local trend=$(get_health_trend)
        local t_icon=$(trend_icon "$trend")
        save_health_snapshot "$health" "$cpu_int" "$ram_pct" "$disk_pct"

        echo ""
        echo "  ${DIM}Health${RESET}  ${h_color}${health}${RESET}${DIM}/100${RESET}  ${h_bar}  ${DIM}${h_label}${RESET} ${t_icon}"
        echo "  ${DIM}${h_hint}${RESET}"

        echo "  ${DIM}${BULLET} macOS $MACOS_VERSION ($CHIP_TYPE)${RESET}"
        echo ""
        ui_line 55
        echo ""
        
        # Filter menu items based on user level
        local available_items
        available_items=($(get_menu_for_level "main"))
        local max_choice=0
        
        for item in "${available_items[@]}"; do
            case $item in
                1) 
                    ui_list_item 1 "📊 Dashboard" "$(get_level_description dashboard)"
                    [[ $item -gt $max_choice ]] && max_choice=$item
                    ;;
                2)
                    ui_list_item 2 "🔍 Scan System" "$(get_level_description scan)"
                    [[ $item -gt $max_choice ]] && max_choice=$item
                    ;;
                3)
                    ui_list_item 3 "🚀 Fix & Cleanup" "$(get_level_description fix)"
                    [[ $item -gt $max_choice ]] && max_choice=$item
                    ;;
                4)
                    ui_list_item 4 "🔒 Security Check" "$(get_level_description security)"
                    [[ $item -gt $max_choice ]] && max_choice=$item
                    ;;
                5)
                    ui_list_item 5 "🛠  Advanced Tools" "Monitors, processes, utilities"
                    [[ $item -gt $max_choice ]] && max_choice=$item
                    ;;
                6)
                    ui_list_item 6 "⚙️  Settings" "Customize MacDoctor behavior"
                    [[ $item -gt $max_choice ]] && max_choice=$item
                    ;;
                0)
                    ui_list_item 0 "Exit" "Close MacDoctor"
                    ;;
            esac
        done

        echo ""
        
        local choice
        choice=$(ui_choose "What's your next step?" $max_choice)
        
        # Validate choice is available for user level
        local valid_choice=0
        for item in "${available_items[@]}"; do
            [[ "$item" == "$choice" ]] && valid_choice=1 && break
        done
        
        if [[ $valid_choice -eq 0 ]]; then
            ui_toast "This option is not available for your user level" "WARN"
            sleep 2
            continue
        fi
        
        case $choice in
            1) show_dashboard_menu ;;
            2) show_scan_menu ;;
            3) show_fix_menu ;;
            4) run_security_audit ;;
            5) show_advanced_menu ;;
            6) settings_menu ;;
            0) 
                clear
                echo ""
                echo "  ${SUCCESS}${ICON_OK} Stay healthy!${RESET}"
                echo ""
                exit 0
                ;;
        esac
    done
}

# --- SCAN MENU (Choose depth) ---

show_scan_menu() {
    while true; do
        clear
        echo ""
        ui_box_top "System Scan"
        ui_box_row "${DIM}Find what needs attention${RESET}"
        ui_box_bottom
        echo ""
        
        # Filter scan options based on user level
        local available_items
        available_items=($(get_menu_for_level "scan"))
        local max_choice=0
        
        for item in "${available_items[@]}"; do
            case $item in
                1)
                    ui_list_item 1 "⚡ Quick Scan" "Fast | CPU, memory, disk"
                    ui_explain "    Daily check-ins"
                    echo ""
                    max_choice=1
                    ;;
                2)
                    ui_list_item 2 "🔬 Deep Scan" "Moderate | Caches, logs, startup"
                    ui_explain "    Troubleshooting slowdowns"
                    echo ""
                    max_choice=2
                    ;;
                3)
                    ui_list_item 3 "🧪 Ultra Scan" "Thorough | Full report saved to file"
                    ui_explain "    Complete health report"
                    echo ""
                    max_choice=3
                    ;;
                0)
                    ui_list_item 0 "Back" "Return to main menu"
                    ;;
            esac
        done
        echo ""
        
        local choice
        choice=$(ui_choose "Choose scan" $max_choice)
        
        local valid_choice=0
        for item in "${available_items[@]}"; do
            [[ "$item" == "$choice" ]] && valid_choice=1 && break
        done
        
        if [[ $valid_choice -eq 0 ]]; then
            ui_toast "This scan is not available for your user level" "WARN"
            sleep 2
            continue
        fi
        
        case $choice in
            1) run_quick_scan ;;
            2) run_deep_scan ;;
            3) run_ultra_scan ;;
            0) break ;;
        esac
    done
}

# --- FIX & CLEANUP MENU ---

show_fix_menu() {
    while true; do
        clear
        echo ""
        ui_box_top "Fix & Cleanup"
        ui_box_row "${DIM}Make your Mac faster & freer${RESET}"
        ui_box_bottom
        echo ""
        
        echo "  ${SUCCESS}1${RESET}${DIM})${RESET} ${BOLD}🟢 Safe Cleanup${RESET}"
        echo "     ${DIM}Browser cache, old logs, temp files${RESET}"
        printf "     ${DIM}Risk: ${SUCCESS}Very Low${RESET} ${DIM}${BULLET} Quick${RESET}\n"
        echo ""
        echo "  ${WARNING}2${RESET}${DIM})${RESET} ${BOLD}🟡 Deeper Cleanup${RESET}"
        echo "     ${DIM}+ Xcode cache, Docker, old backups${RESET}"
        printf "     ${DIM}Risk: ${WARNING}Low${RESET} ${DIM}${BULLET} Moderate${RESET}\n"
        echo ""
        echo "  ${ERROR}3${RESET}${DIM})${RESET} ${BOLD}🔴 Aggressive Cleanup${RESET}"
        echo "     ${DIM}+ APFS snapshots, RAM purge, system logs${RESET}"
        printf "     ${DIM}Risk: ${ERROR}Medium${RESET} ${DIM}${BULLET} Takes longer ${BULLET} ${ERROR}Requires password${RESET}\n"
        echo ""
        echo "  ${HIGHLIGHT}4${RESET}${DIM})${RESET} ${BOLD}🧙 Optimization Wizard${RESET}"
        echo "     ${DIM}Let MacDoctor suggest safe tweaks${RESET}"
        echo ""
        ui_list_item 0 "Back" "Return to main menu"
        echo ""
        
        local choice
        choice=$(ui_choose "Choose cleanup depth" 4)
        
        case $choice in
            1) show_cleanup_preview "SAFE" ;;
            2) show_cleanup_preview "DEEP" ;;
            3) show_cleanup_preview "AGGRESSIVE" ;;
            4) run_wizard ;;
            0) break ;;
        esac
    done
}

# --- CLEANUP PREVIEW ---

show_cleanup_preview() {
    local depth="$1"
    clear
    echo ""
    echo "${BOLD}${CYAN}Cleanup Preview: ${depth}${RESET}"
    echo ""
    
    echo "  ${CYAN}We will clean:${RESET}"
    echo ""
    
    # Compute real sizes for common targets
    local sz_safari=$(du -sh "$HOME/Library/Caches/com.apple.Safari" 2>/dev/null | awk '{print $1}')
    local sz_firefox=$(du -sh "$HOME/Library/Caches/Firefox" 2>/dev/null | awk '{print $1}')
    local sz_chrome=$(du -sh "$HOME/Library/Caches/com.google.Chrome" 2>/dev/null | awk '{print $1}')
    local sz_logs=$(du -sh "$HOME/Library/Logs" 2>/dev/null | awk '{print $1}')
    local sz_xcode=$(du -sh "$HOME/Library/Developer/Xcode/DerivedData" 2>/dev/null | awk '{print $1}')
    local sz_brew_cache=""
    command -v brew &>/dev/null && sz_brew_cache=$(du -sh "$(brew --cache 2>/dev/null)" 2>/dev/null | awk '{print $1}')
    
    case "$depth" in
        SAFE)
            [[ -n "$sz_safari" ]]  && echo "  📁 Safari cache — ${sz_safari}"
            [[ -n "$sz_firefox" ]] && echo "  📁 Firefox cache — ${sz_firefox}"
            [[ -n "$sz_chrome" ]]  && echo "  📁 Chrome cache — ${sz_chrome}"
            [[ -n "$sz_logs" ]]    && echo "  📁 User logs — ${sz_logs}"
            echo "  📁 Other app caches (Spotify, Teams, Slack, Discord)"
            echo ""
            echo "  ${DIM}All items are backed up before removal.${RESET}"
            echo ""
            ;;
        DEEP)
            echo "  📁 All from Safe cleanup (browser caches, logs)"
            [[ -n "$sz_xcode" ]]      && echo "  📁 Xcode DerivedData — ${sz_xcode}"
            [[ -n "$sz_brew_cache" ]]  && echo "  📦 Homebrew cache — ${sz_brew_cache}"
            command -v docker &>/dev/null && echo "  🐳 Docker unused images"
            echo ""
            echo "  ${DIM}All items are backed up before removal.${RESET}"
            echo ""
            ;;
        AGGRESSIVE)
            echo "  📁 All from Safe + Deep cleanup"
            echo "  📸 APFS snapshots (Time Machine local)"
            echo "  🧠 RAM purge (inactive memory)"
            echo "  📋 System logs (requires password)"
            echo "  🔎 Spotlight re-index (optional)"
            echo ""
            echo "  ${RED}Requires password. Uses sudo.${RESET}"
            echo ""
            ;;
    esac
    
    # Backup location
    local backup_dir="$HOME/MacDoctorBackup-$(date +%Y-%m-%d_%H%M)"
    echo "  ${CYAN}Safety Information:${RESET}"
    echo ""
    ui_badge INFO "Backup" "${backup_dir}"
    ui_explain "All deleted files saved here for 30 days"
    echo ""
    ui_badge OK "Restore" "Settings > Backups > Restore"
    echo ""
    
    # Current disk
    local disk_usage=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}')
    local disk_free=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}')
    ui_kv "Current disk" "${disk_usage} used | ${disk_free} free"
    echo ""
    
    # Confirm
    echo "  ${CYAN}Ready to proceed?${RESET}"
    echo "  ${DIM}This is safe — everything is backed up.${RESET}"
    echo ""
    
    local confirmed=1
    case "$depth" in
        SAFE)
            ui_confirm_risky "CLEANUP" "Clean browser caches, logs, and temp files" "$backup_dir" && confirmed=0
            ;;
        DEEP)
            ui_confirm_risky "CLEANUP" "Clean caches, dev tools, and packages" "$backup_dir" && confirmed=0
            ;;
        AGGRESSIVE)
            if ! ask_sudo; then return; fi
            ui_confirm_risky "CLEANUP" "Deep system cleanup (requires password)" "$backup_dir" && confirmed=0
            ;;
    esac
    
    if [[ $confirmed -eq 0 ]]; then
        show_cleanup_running "$depth"
    fi
}

# --- CLEANUP EXECUTION ---

show_cleanup_running() {
    local depth="$1"
    
    # Measure disk before
    local disk_before=$(df -k / 2>/dev/null | tail -1 | awk '{print $3}')
    
    clear
    echo ""
    echo "${BOLD}${CYAN}Cleanup in progress...${RESET}"
    echo ""
    
    # Execute cleanup
    case "$depth" in
        SAFE)
            cleanup_safe
            ;;
        DEEP)
            cleanup_deep
            ;;
        AGGRESSIVE)
            cleanup_aggressive
            ;;
    esac
    
    # Measure disk after and calculate freed space
    local disk_after=$(df -k / 2>/dev/null | tail -1 | awk '{print $3}')
    local freed_kb=$(( disk_before - disk_after ))
    [[ $freed_kb -lt 0 ]] && freed_kb=0
    local freed_display=""
    if [[ $freed_kb -gt 1048576 ]]; then
        freed_display="$(LC_ALL=C awk -v k="$freed_kb" 'BEGIN{printf "%.1f GB", k/1048576}' )"
    elif [[ $freed_kb -gt 1024 ]]; then
        freed_display="$(LC_ALL=C awk -v k="$freed_kb" 'BEGIN{printf "%.1f MB", k/1024}' )"
    else
        freed_display="${freed_kb} KB"
    fi
    
    local disk_pct_now=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}')
    local disk_free_now=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}')
    
    local disk_pct_before=$(LC_ALL=C awk -v b="$disk_before" -v a="$disk_after" -v t="$disk_before" 'BEGIN{if(t>0){printf "%.0f", (b/(b+(a-b+t-b)))*100} else {print "?"}}' 2>/dev/null)
    disk_pct_before=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')

    echo ""
    ui_box_top "Cleanup Complete"
    ui_box_bottom
    echo ""
    echo "  ${BOLD}${SUCCESS}Before → After${RESET}"
    echo ""
    echo "  ${DIM}Disk Used   ${RESET}${YELLOW}${disk_pct_before:-?}%${RESET}  →  ${SUCCESS}${disk_pct_now}${RESET}"
    echo "  ${DIM}Free Space  ${RESET}                ${SUCCESS}${disk_free_now}${RESET}"
    echo "  ${DIM}Freed       ${RESET}${BOLD}${SUCCESS}${freed_display}${RESET}"
    echo ""
    local h_before=$(compute_health_score "$cpu_int" "$ram_pct" "${disk_pct_before:-0}")
    local disk_pct_now_num=$(echo "$disk_pct_now" | tr -d '%')
    local h_after=$(compute_health_score 0 0 "${disk_pct_now_num:-0}")
    if [[ $h_after -gt $h_before ]]; then
        echo "  ${DIM}Health Score ${RESET}${YELLOW}${h_before}${RESET}  →  ${SUCCESS}${BOLD}${h_after}${RESET}  ${SUCCESS}▲${RESET}"
    else
        echo "  ${DIM}Health Score ${RESET}${h_before}  →  ${h_after}"
    fi
    echo ""
    ui_explain "Backup saved to: ${CURRENT_BACKUP_DIR}"
    echo ""

    pause_continue
}

# --- ADVANCED MENU ---

show_advanced_menu() {
    while true; do
        clear
        echo ""
        ui_box_top "Advanced Tools"
        ui_box_row "${DIM}Power user features${RESET}"
        ui_box_bottom
        echo ""
        ui_list_item 1 "🔭 Process Inspector" "Monitor individual processes"
        ui_list_item 2 "📊 Live Monitors" "Real-time SoC/GPU/I-O"
        ui_list_item 3 "🧠 System Analysis" "Semantic analysis"
        ui_list_item 4 "⚙️  Utilities" "Battery, updates, network"
        ui_list_item 5 "🌐 Network Test" "Connectivity, latency & DNS"
        ui_list_item 6 "📶 WiFi Diagnostics" "Signal, channel & interference"
        ui_list_item 7 "💾 Storage Analyzer" "Find what's eating your disk"
        ui_list_item 8 "💿 Disk Benchmark" "Measure read/write speed"
        ui_list_item 0 "Back" "Return to main menu"
        echo ""
        
        local choice
        choice=$(ui_choose "Choose tool" 8)
        
        case $choice in
            1) advanced_process_inspector ;;
            2) 
                while true; do
                    clear
                    echo ""
                    ui_box_top "Monitoring Toolkit"
                    ui_box_bottom
                    echo ""
                    ui_list_item 1 "SoC Monitors" "mactop/asitop/macmon"
                    ui_list_item 2 "I/O Monitor" "fs_usage/nettop/iotop"
                    ui_list_item 0 "Back" ""
                    echo ""
                    
                    local mon_c
                    mon_c=$(ui_choose "Choose monitor" 2)
                    case $mon_c in
                        1) external_monitors ;;
                        2) io_monitor_menu ;;
                        0) break ;;
                    esac
                done
                ;;
            3) analyze_system_semantics ;;
            4) utilities_menu ;;
            5) run_network_test ;;
            6) run_wifi_diagnostics ;;
            7) run_storage_analyzer ;;
            8) run_disk_benchmark ;;
            0) break ;;
        esac
    done
}

# --- Network connectivity & DNS test ---
run_network_test() {
    clear
    echo ""
    ui_box_top "Network Test"
    ui_box_row "${DIM}Measuring connectivity, latency & DNS${RESET}"
    ui_box_bottom
    echo ""

    # Gateway
    local gw=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')
    local iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
    local ip=$(ifconfig "$iface" 2>/dev/null | awk '/inet /{print $2; exit}')
    [[ -z "$gw" ]] && gw="N/A"
    [[ -z "$ip" ]] && ip="N/A"

    ui_kv "  Interface" "$iface"
    ui_kv "  Local IP" "$ip"
    ui_kv "  Gateway" "$gw"
    echo ""

    # Ping gateway
    echo "  ${BOLD}${PRIMARY}${BULLET} Gateway Latency${RESET}"
    if [[ "$gw" != "N/A" ]]; then
        local gw_ping=$(ping -c 3 -t 2 "$gw" 2>/dev/null | tail -1 | awk -F'/' '{printf "%.1f ms", $5}')
        [[ -z "$gw_ping" ]] && gw_ping="unreachable"
        echo "    ${HIGHLIGHT}${gw_ping}${RESET}"
    else
        echo "    ${ERROR}No default route${RESET}"
    fi
    echo ""

    # Ping external
    echo "  ${BOLD}${PRIMARY}${BULLET} Internet Latency${RESET}"
    local targets=("1.1.1.1" "8.8.8.8" "apple.com")
    for t in "${targets[@]}"; do
        local ms=$(ping -c 2 -t 3 "$t" 2>/dev/null | tail -1 | awk -F'/' '{printf "%.1f", $5}')
        if [[ -n "$ms" ]]; then
            echo "    ${HIGHLIGHT}${t}${RESET} ${DIM}${BULLET}${RESET} ${SUCCESS}${ms} ms${RESET}"
        else
            echo "    ${HIGHLIGHT}${t}${RESET} ${DIM}${BULLET}${RESET} ${ERROR}timeout${RESET}"
        fi
    done
    echo ""

    # DNS resolution
    echo "  ${BOLD}${PRIMARY}${BULLET} DNS Resolution${RESET}"
    local dns_start=$EPOCHREALTIME
    local dns_res=$(dig +short apple.com A 2>/dev/null | head -1)
    local dns_end=$EPOCHREALTIME
    if [[ -n "$dns_res" ]]; then
        local dns_ms=$(LC_ALL=C awk -v s="$dns_start" -v e="$dns_end" 'BEGIN{printf "%.0f", (e-s)*1000}')
        echo "    apple.com ${DIM}${BULLET}${RESET} ${SUCCESS}${dns_res}${RESET} ${DIM}(${dns_ms} ms)${RESET}"
    else
        echo "    ${ERROR}DNS lookup failed${RESET}"
    fi
    echo ""

    # Download speed (small file)
    echo "  ${BOLD}${PRIMARY}${BULLET} Download Speed (approx.)${RESET}"
    local dl_start=$EPOCHREALTIME
    curl -s -o /dev/null -w "%{size_download}" "https://cdn.apple.com/content/downloads/13/62/002-57047-A_27LOQHKVUT/dntx7do0xkh19aygm2rpyh6n4s2w3z6ald/InstallAssistant.pkg" --max-time 5 --range 0-1048575 2>/dev/null
    local dl_bytes=$?
    dl_bytes=$(curl -s -o /dev/null -w "%{size_download}" "https://speed.cloudflare.com/__down?bytes=2000000" --max-time 8 2>/dev/null)
    local dl_end=$EPOCHREALTIME
    if [[ -n "$dl_bytes" && "$dl_bytes" -gt 0 ]] 2>/dev/null; then
        local dl_secs=$(LC_ALL=C awk -v s="$dl_start" -v e="$dl_end" 'BEGIN{printf "%.2f", e-s}')
        local dl_mbps=$(LC_ALL=C awk -v b="$dl_bytes" -v s="$dl_secs" 'BEGIN{if(s>0){printf "%.1f", (b*8)/(s*1000000)} else {print "?"}}')
        echo "    ${HIGHLIGHT}~${dl_mbps} Mbps${RESET} ${DIM}(${dl_bytes} bytes in ${dl_secs}s)${RESET}"
    else
        echo "    ${DIM}Could not measure (network issue or timeout)${RESET}"
    fi
    echo ""
    
    pause_continue
}

# --- Disk benchmark ---
run_disk_benchmark() {
    clear
    echo ""
    ui_box_top "Disk Benchmark"
    ui_box_row "${DIM}Measuring sequential read & write speed${RESET}"
    ui_box_bottom
    echo ""

    local test_file="/tmp/.macdoctor_diskbench_$$"
    local bs="1m"
    local count=256  # 256 MB

    # Write test
    echo "  ${BOLD}${PRIMARY}${BULLET} Write Speed${RESET}  ${DIM}(256 MB sequential)${RESET}"
    local w_start=$EPOCHREALTIME
    dd if=/dev/zero of="$test_file" bs="$bs" count=$count 2>/dev/null
    sync
    local w_end=$EPOCHREALTIME
    local w_secs=$(LC_ALL=C awk -v s="$w_start" -v e="$w_end" 'BEGIN{printf "%.2f", e-s}')
    local w_mbps=$(LC_ALL=C awk -v c=$count -v s="$w_secs" 'BEGIN{if(s>0){printf "%.0f", c/s} else {print "?"}}')
    echo "    ${HIGHLIGHT}${w_mbps} MB/s${RESET} ${DIM}(${w_secs}s)${RESET}"
    echo ""

    # Purge disk cache before read test
    sudo purge 2>/dev/null

    # Read test
    echo "  ${BOLD}${PRIMARY}${BULLET} Read Speed${RESET}  ${DIM}(256 MB sequential)${RESET}"
    local r_start=$EPOCHREALTIME
    dd if="$test_file" of=/dev/null bs="$bs" 2>/dev/null
    local r_end=$EPOCHREALTIME
    local r_secs=$(LC_ALL=C awk -v s="$r_start" -v e="$r_end" 'BEGIN{printf "%.2f", e-s}')
    local r_mbps=$(LC_ALL=C awk -v c=$count -v s="$r_secs" 'BEGIN{if(s>0){printf "%.0f", c/s} else {print "?"}}')
    echo "    ${HIGHLIGHT}${r_mbps} MB/s${RESET} ${DIM}(${r_secs}s)${RESET}"
    echo ""

    rm -f "$test_file" 2>/dev/null

    # Summary gauge
    echo "  ${BOLD}${PRIMARY}${BULLET} Summary${RESET}"
    printf "    Write: "; mini_bar "$(( w_mbps > 3000 ? 100 : w_mbps * 100 / 3000 ))" 20; printf " ${HIGHLIGHT}${w_mbps} MB/s${RESET}\n"
    printf "    Read:  "; mini_bar "$(( r_mbps > 3000 ? 100 : r_mbps * 100 / 3000 ))" 20; printf " ${HIGHLIGHT}${r_mbps} MB/s${RESET}\n"
    echo ""
    ui_explain "  Typical Apple Silicon SSD: 2000-3500 MB/s"
    echo ""

    pause_continue
}

# --- SEMANTIC CODE & SYSTEM ANALYSIS ---

analyze_system_semantics() {
    local level="$ANALYSIS_DEPTH"
    # Map depth names to analysis levels
    case "$level" in quick) level="basic" ;; standard) level="intermediate" ;; thorough) level="expert" ;; esac
    
    
    clear
    echo ""
    echo "${BOLD}${PRIMARY}🧠 System Semantic Analysis${RESET}  — Level: $(capitalize_first "$level")"
    echo ""
    
    case "$level" in
        basic)
            basic_semantic_analysis
            ;;
        intermediate)
            basic_semantic_analysis
            echo ""
            intermediate_semantic_analysis
            ;;
        expert)
            basic_semantic_analysis
            echo ""
            intermediate_semantic_analysis
            echo ""
            expert_semantic_analysis
            ;;
    esac
    
    pause_continue
}

# BASIC: High-level overview
basic_semantic_analysis() {
    
    echo "${BOLD}${PRIMARY}1. PROCESS HEALTH${RESET}"
    echo ""
    
    # Get zombie processes
    local zombies=$(ps aux 2>/dev/null | grep -c " <defunct>" || echo "0")
    
    
    if [[ $zombies -gt 1 ]]; then
        echo "  ${WARNING}⚠️  Zombie Processes: $((zombies-1)) found${RESET}"
        echo "     Consider: Kill parent processes or restart"
    else
        echo "  ${SUCCESS}✅ No zombie processes${RESET}"
    fi
    
    echo ""
    echo "${BOLD}${PRIMARY}2. STARTUP ITEMS${RESET}"
    echo ""
    
    # Check login items
    local login_items=$(launchctl list 2>/dev/null | grep -v "com.apple" | wc -l || echo "0")
    
    
    echo "  ${PRIMARY}Third-party launch agents: $login_items${RESET}"
    
    if [[ $login_items -gt 20 ]]; then
        echo "  ${WARNING}⚠️  Many startup items detected${RESET}"
        echo "     High count may slow boot time"
    fi
    
    echo ""
    echo "${BOLD}${PRIMARY}3. DISK FRAGMENTATION${RESET}"
    echo ""
    
    # Check for many small files (fragmentation indicator) - with timeout
    local small_files=0
    if command -v timeout &>/dev/null; then
        small_files=$(timeout 3 find "$HOME" -maxdepth 3 -type f -size -1k 2>/dev/null | wc -l || echo "0")
    else
        small_files=$(find "$HOME" -maxdepth 2 -type f -size -1k 2>/dev/null | wc -l || echo "0")
    fi
    
    
    echo "  ${PRIMARY}Small files (<1KB, limited search): $small_files${RESET}"
    
    if [[ $small_files -gt 100000 ]]; then
        echo "  ${WARNING}⚠️  High count of small files${RESET}"
        echo "     May indicate fragmentation or bloat"
    fi
}

# INTERMEDIATE: Detailed diagnostics
intermediate_semantic_analysis() {
    echo "${BOLD}${PRIMARY}4. DAEMON ANALYSIS${RESET}"
    echo ""
    
    # CPU-hungry daemons - with proper quoting
    local top_daemons
    top_daemons=$(ps aux 2>/dev/null | awk 'NR>1{printf "%s %.1f\n", $11, $3}' | sort -k2 -rn | head -5 | awk '{printf "%s (%.1f%%CPU)\n", $1, $2}')
    echo "  ${PRIMARY}Top CPU consumers:${RESET}"
    if [[ -n "$top_daemons" ]]; then
        echo "$top_daemons" | head -3 | while IFS= read -r line; do
            echo "     • $line"
        done
    else
        echo "     (No data available)"
    fi
    
    echo ""
    echo "${BOLD}${PRIMARY}5. MEMORY PRESSURE${RESET}"
    echo ""
    
    # Memory pressure indicator
    if command -v memory_pressure &>/dev/null; then
        local pressure=$(memory_pressure 2>/dev/null | head -1)
        echo "  ${PRIMARY}System memory pressure:${RESET} $pressure"
        
        if echo "$pressure" | grep -q "High"; then
            echo "  ${ERROR}🔴 High memory pressure detected${RESET}"
            echo "     Consider: Close unused apps, increase RAM, or enable swap"
        elif echo "$pressure" | grep -q "Normal"; then
            echo "  ${SUCCESS}✅ Memory pressure is healthy${RESET}"
        fi
    fi
    
    echo ""
    echo "${BOLD}${PRIMARY}6. NETWORK INTERFACES${RESET}"
    echo ""
    
    # Active network interfaces
    local net_count=$(ifconfig 2>/dev/null | grep -c "flags=")
    echo "  ${PRIMARY}Active network interfaces: $net_count${RESET}"
    
    # Check for connectivity issues
    local dns_ok=0
    if ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
        dns_ok=1
        echo "  ${SUCCESS}✅ Internet connectivity: OK${RESET}"
    else
        echo "  ${WARNING}⚠️  Internet connectivity: FAILED${RESET}"
    fi
}

# EXPERT: Deep semantic analysis
expert_semantic_analysis() {
    echo "${BOLD}${PRIMARY}7. KERNEL EXTENSIONS (KEXTS)${RESET}"
    echo ""
    
    # List suspicious kexts
    local kexts=$(kextstat 2>/dev/null | grep -v "com.apple" | wc -l)
    echo "  ${PRIMARY}Third-party kernel extensions: $kexts${RESET}"
    
    if [[ $kexts -gt 10 ]]; then
        echo "  ${WARNING}⚠️  Many third-party kexts loaded${RESET}"
        echo "     May impact system stability"
        kextstat 2>/dev/null | grep -v "com.apple" | tail -5 | while IFS= read -r line; do
            [[ -n "$line" ]] && echo "     • $(echo "$line" | awk '{print $NF}')"
        done
    fi
    
    echo ""
    echo "${BOLD}${PRIMARY}8. CODE SIGNATURE VERIFICATION${RESET}"
    echo ""
    
    # Check for unsigned binaries in common locations - with timeout
    local unsigned=0
    if command -v timeout &>/dev/null; then
        unsigned=$(timeout 5 find /Applications -maxdepth 2 -type f -perm /111 2>/dev/null | head -20 | while read -r f; do
            timeout 1 codesign -v "$f" 2>&1 | grep -q "invalid\|not signed" && echo "1"
        done | wc -l)
    else
        unsigned=$(find /Applications -maxdepth 1 -type f -perm /111 2>/dev/null | wc -l)
    fi
    
    echo "  ${PRIMARY}Unsigned/invalid binaries in /Applications: $unsigned${RESET}"
    
    if [[ $unsigned -gt 5 ]]; then
        echo "  ${ERROR}❌ Many unsigned binaries detected${RESET}"
        echo "     Security risk: Consider reinstalling affected apps"
    fi
    
    echo ""
    echo "${BOLD}${PRIMARY}9. CACHE COHERENCY${RESET}"
    echo ""
    
    # Check mdutil (Spotlight) status
    local mdutil_status=$(mdutil -s / 2>/dev/null | grep -o "indexing" || echo "indexed")
    echo "  ${PRIMARY}Spotlight indexing status: $mdutil_status${RESET}"
    
    echo ""
    echo "${BOLD}${PRIMARY}10. SYSTEM ENTROPY${RESET}"
    echo ""
    
    # macOS uses /dev/random (Yarrow/Fortuna CSPRNG) — no /proc entropy interface.
    echo "  ${PRIMARY}macOS uses a cryptographically secure PRNG (/dev/random).${RESET}"
    echo "  ${DIM}No separate entropy pool counter (unlike Linux).${RESET}"
}

# ============================================================================
# PHASE 1: DATA COLLECTION
# ============================================================================

# Collect process data for semantic analysis
collect_process_data() {
    local data="$1"  # "full" or "top5"
    local output=""
    
    # macOS: ps aux outputs USER PID %CPU %MEM VSZ RSS TT STAT STARTED TIME COMMAND
    # Sort by %CPU (column 3) in descending order
    export LC_ALL=C
    if [[ "$data" == "full" ]]; then
        # Get all processes with CPU > 0.1%
        output=$(ps aux 2>/dev/null | awk 'NR>1 && $3>0.1 {gsub(/,/, ".", $3); gsub(/,/, ".", $4); printf "{\"pid\":%s,\"cpu\":%.1f,\"mem\":%.1f,\"name\":\"%s\"}\n", $2, $3, $4, $11}' | sort -t: -k2 -rn | head -20)
    else
        # Get top 5 processes only (sort by CPU descending)
        output=$(ps aux 2>/dev/null | awk 'NR>1 {gsub(/,/, ".", $3); gsub(/,/, ".", $4); printf "{\"pid\":%s,\"cpu\":%.1f,\"mem\":%.1f,\"name\":\"%s\"}\n", $2, $3, $4, $11}' | sort -t: -k2 -rn | head -5)
    fi
    
    echo "$output"
}

# Collect startup items
collect_startup_items() {
    local user_agents=0
    local user_daemons=0
    local system_agents=0
    
    # Count user LaunchAgents
    [[ -d "$HOME/Library/LaunchAgents" ]] && user_agents=$(ls -1 "$HOME/Library/LaunchAgents" 2>/dev/null | wc -l)
    
    # Count user LaunchDaemons
    [[ -d "$HOME/Library/LaunchDaemons" ]] && user_daemons=$(ls -1 "$HOME/Library/LaunchDaemons" 2>/dev/null | wc -l)
    
    # Count system LaunchAgents (via launchctl)
    system_agents=$(launchctl list 2>/dev/null | grep -v "com.apple" | wc -l)
    
    printf '{"user_agents":%d,"user_daemons":%d,"system_agents":%d}' "$user_agents" "$user_daemons" "$system_agents"
}

# Collect disk & file metrics
collect_disk_metrics() {
    local cache_size=0
    local small_files=0
    local total_duplicates=0
    
    # Cache size — parse du output into GB
    local cache_raw=$(du -sh ~/Library/Caches 2>/dev/null | awk '{print $1}')
    if [[ "$cache_raw" == *G* ]]; then
        cache_size="${cache_raw//[^0-9.,]/}"
        cache_size="${cache_size/,/.}"
    elif [[ "$cache_raw" == *M* ]]; then
        local mb="${cache_raw//[^0-9.,]/}"
        mb="${mb/,/.}"
        cache_size=$(LC_ALL=C awk -v m="$mb" 'BEGIN{printf "%.1f", m/1024}')
    elif [[ "$cache_raw" == *K* ]]; then
        cache_size="0.0"
    else
        cache_size="${cache_raw//[^0-9.,]/}"
        cache_size="${cache_size/,/.}"
    fi
    [[ -z "$cache_size" ]] && cache_size=0
    
    # Small files (with timeout)
    if command -v timeout &>/dev/null; then
        small_files=$(timeout 2 find "$HOME" -maxdepth 2 -type f -size -1k 2>/dev/null | wc -l)
    else
        small_files=$(find "$HOME" -maxdepth 1 -type f -size -1k 2>/dev/null | wc -l)
    fi
    
    printf '{"cache_size_gb":"%.1f","small_files":%d}' "$cache_size" "$small_files"
}

# Collect system load & correlation data
collect_system_load() {
    local cpu_load=$(get_cpu_load 2>/dev/null || echo "0")
    cpu_load="${cpu_load/,/.}"
    [[ -z "$cpu_load" ]] && cpu_load=0
    
    local mem_used=$(get_memory_usage 2>/dev/null || echo "0")
    local disk_pct=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    [[ -z "$disk_pct" ]] && disk_pct=0
    
    # Get top process name for correlation (sort by CPU) — single ps call
    local top_line
    top_line=$(ps aux 2>/dev/null | awk 'NR>1 {gsub(/,/, ".", $3); printf "%s %s\n", $3, $11}' | sort -rn | head -1)
    local top_proc_cpu=$(echo "$top_line" | awk '{print $1}')
    local top_proc=$(echo "$top_line" | awk '{print $2}')
    [[ -z "$top_proc" ]] && top_proc="N/A"
    [[ -z "$top_proc_cpu" ]] && top_proc_cpu=0
    
    printf '{"cpu_load":"%.2f","mem_used_mb":%d,"disk_pct":%d,"top_process":"%s","top_cpu":"%.1f"}' \
        "$cpu_load" "$mem_used" "$disk_pct" "$top_proc" "$top_proc_cpu"
}

# Detect zombie processes
detect_zombies() {
    local zombies=$(ps aux 2>/dev/null | grep -c " <defunct>" || echo "0")
    [[ "$zombies" -gt 0 ]] && zombies=$((zombies - 1))
    echo "$zombies"
}

# Compile all data into JSON for AI
compile_semantic_data() {
    local level="$1"  # basic, intermediate, expert
    [[ -z "$level" ]] && level="basic"
    
    # Collect data silently with error handling
    local processes="" startups="" disk="" system="" zombies=0
    
    # Collect processes (returns JSON array items, one per line)
    # Join with commas, ensuring proper JSON array format
    local processes_raw=""
    if [[ "$level" == "basic" ]]; then
        processes_raw=$(collect_process_data "top5" 2>/dev/null)
    else
        processes_raw=$(collect_process_data "full" 2>/dev/null)
    fi
    
    # Join JSON objects with commas (remove trailing newline, replace newlines with commas)
    local processes=""
    if [[ -n "$processes_raw" ]]; then
        processes=$(printf '%s' "$processes_raw" | tr '\n' ',' | sed 's/,$//')
    else
        processes=""
    fi
    
    # Collect startup items
    local startups=$(collect_startup_items 2>/dev/null)
    [[ -z "$startups" ]] && startups='{"user_agents":0,"user_daemons":0,"system_agents":0}'
    
    # Collect disk metrics (only for intermediate/expert)
    local disk=""
    if [[ "$level" != "basic" ]]; then
        disk=$(collect_disk_metrics 2>/dev/null)
        [[ -z "$disk" ]] && disk='{"cache_size_gb":0,"small_files":0}'
    fi
    
    # Collect system load
    local system=$(collect_system_load 2>/dev/null)
    [[ -z "$system" ]] && system='{"cpu_load":0,"mem_used_mb":0,"disk_pct":0,"top_process":"N/A","top_cpu":0}'
    
    # Detect zombies
    local zombies=$(detect_zombies 2>/dev/null)
    [[ -z "$zombies" ]] && zombies=0
    
    # Build final JSON - use proper array construction
    local json_output=""
    case "$level" in
        basic)
            json_output=$(cat <<EOF
{"level":"basic","processes":[$processes],"startups":$startups,"system":$system,"zombies":$zombies}
EOF
            )
            ;;
        intermediate)
            json_output=$(cat <<EOF
{"level":"intermediate","processes":[$processes],"startups":$startups,"disk":$disk,"system":$system,"zombies":$zombies}
EOF
            )
            ;;
        *)
            json_output=$(cat <<EOF
{"level":"expert","processes":[$processes],"startups":$startups,"disk":$disk,"system":$system,"zombies":$zombies}
EOF
            )
            ;;
    esac
    
    # Output the JSON so it can be captured by calling code
    # Remove any trailing newlines
    echo -n "$json_output" | tr -d '\n'
}

init_system
show_startup_animation
preflight_summary

trap '[[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null; save_settings' EXIT

show_main_menu
