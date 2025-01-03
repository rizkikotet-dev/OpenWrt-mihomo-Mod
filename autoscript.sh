#!/bin/bash

# Script configuration
VERSION="2.6"
LOCKFILE="/tmp/mihomotproxy.lock"
BACKUP_DIR="/root/backups-mihomo"
TEMP_DIR="/tmp"
MIHOMO_DIR="/etc/mihomo"
MIHOMO_CONFIG="/etc/config/mihomo"

# Logging and Color Configurations
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r NC='\033[0m'

# Enhanced logging function with timestamp and log file
log_file="/var/log/mihomotproxy.log"
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # Console output
    case "$level" in
        "info")
            echo -e "${timestamp} ${GREEN}[INFO]${NC} $message" >&2
            ;;
        "warn")
            echo -e "${timestamp} ${YELLOW}[WARN]${NC} $message" >&2
            ;;
        "error")
            echo -e "${timestamp} ${RED}[ERROR]${NC} $message" >&2
            ;;
    esac

    # Log to file
    echo "$timestamp [$level] $message" >> "$log_file"
}

# Improved error handling
handle_error() {
    local error_message="$1"
    log_message "error" "$error_message"
    cleanup
    exit 1
}

# Dependency check with more robust verification
check_dependencies() {
    local required_commands=("wget" "unzip" "tar" "curl" "jq")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        handle_error "Missing required commands: ${missing_commands[*]}"
    fi
}

# Enhanced cleanup function
cleanup() {
    log_message "info" "Performing cleanup..."
    rm -f "$LOCKFILE"
    rm -rf "$TEMP_DIR/Config-Open-ClashMeta-main" "$TEMP_DIR/Yacd-meta-gh-pages"
    rm -f "$TEMP_DIR/main.zip" "$TEMP_DIR/gh-pages.zip"
}

# Network connectivity check
check_network() {
    log_message "info" "Checking network connectivity..."
    if ! ping -c 3 github.com &> /dev/null; then
        handle_error "No internet connection available"
    fi
}

# Backup functions with improved error checking
ensure_backup_dir() {
    mkdir -p "$BACKUP_DIR" || handle_error "Failed to create backup directory"
}

perform_backup() {
    ensure_backup_dir
    local current_time=$(date +"%Y-%m-%d_%H-%M-%S")
    local output_tar_gz="$BACKUP_DIR/backup_config_mihomo_${current_time}.tar.gz"
    local files_to_backup=(
        "$MIHOMO_DIR/mixin.yaml"
        "$MIHOMO_DIR/profiles"
        "$MIHOMO_DIR/run"
        "$MIHOMO_CONFIG"
    )

    log_message "info" "Starting backup process..."
    
    # Validate files before backup
    for file in "${files_to_backup[@]}"; do
        if [[ ! -e "$file" ]]; then
            log_message "warn" "Warning: $file does not exist"
        fi
    done

    tar -czvf "$output_tar_gz" "${files_to_backup[@]}" 2>/dev/null || 
        handle_error "Backup failed"
    
    log_message "info" "Backup successfully created at: $output_tar_gz"
}

perform_restore() {
    local backup_file="$1"
    [[ -f "$backup_file" ]] || handle_error "Backup file not found: $backup_file"

    log_message "info" "Starting restore process..."
    
    mkdir -p "$MIHOMO_DIR/profiles" "$MIHOMO_DIR/run" || 
        handle_error "Failed to create directories"
    
    [[ -f "$MIHOMO_CONFIG" ]] && cp "$MIHOMO_CONFIG" "$MIHOMO_CONFIG.bak"

    tar -xzvf "$backup_file" -C / --overwrite || 
        handle_error "Restore failed"

    mv "$MIHOMO_DIR/mihomo" "$MIHOMO_CONFIG" 2>/dev/null
    chmod 644 "$MIHOMO_CONFIG"

    log_message "info" "Restore completed successfully"
}

# Download and install configuration with progress tracking
install_config() {
    log_message "info" "Downloading configuration files..."
    
    wget -q --show-progress -O "$TEMP_DIR/main.zip" \
        "https://github.com/rizkikotet-dev/Config-Open-ClashMeta/archive/refs/heads/main.zip" || 
        handle_error "Failed to download configuration"
    
    unzip -o "$TEMP_DIR/main.zip" -d "$TEMP_DIR" 2>/dev/null || 
        handle_error "Failed to extract configuration"
    cd "$TEMP_DIR/Config-Open-ClashMeta-main" || handle_error "Failed to change directory"
    
    mv -f config/Country.mmdb "$MIHOMO_DIR/run/Country.mmdb" && chmod +x "$MIHOMO_DIR/run/Country.mmdb"
    mv -f config/GeoIP.dat "$MIHOMO_DIR/run/GeoIP.dat" && chmod +x "$MIHOMO_DIR/run/GeoIP.dat"
    mv -f config/GeoSite.dat "$MIHOMO_DIR/run/GeoSite.dat" && chmod +x "$MIHOMO_DIR/run/GeoSite.dat"
    mv -f config/proxy_provider/* "$MIHOMO_DIR/run/proxy_provider/" 2>/dev/null && chmod -R 755 "$MIHOMO_DIR/run/proxy_provider"
    mv -f config/rule_provider/* "$MIHOMO_DIR/run/rule_provider/" 2>/dev/null  && chmod -R 755 "$MIHOMO_DIR/run/rule_provider"
    mv -f config/config/* "$MIHOMO_DIR/profiles/" 2>/dev/null && chmod -R 755 "$MIHOMO_DIR/profiles"
    mv -f config/mihomo $MIHOMO_CONFIG && chmod 644 $MIHOMO_CONFIG
    
    log_message "info" "Installing Yacd dashboard..."
    cd "$TEMP_DIR" || handle_error "Failed to change directory"
    wget -q --show-progress -O "$TEMP_DIR/gh-pages.zip" \
        "https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip" || 
        handle_error "Failed to download dashboard"
    
    unzip -o "$TEMP_DIR/gh-pages.zip" -d "$TEMP_DIR" 2>/dev/null || handle_error "Failed to extract dashboard"
    if [[ -d "$MIHOMO_DIR/run/ui/dashboard" ]]; then
        rm -rf "$MIHOMO_DIR/run/ui/dashboard"
    fi
    mv -fT "$TEMP_DIR/Yacd-meta-gh-pages" "$MIHOMO_DIR/run/ui/dashboard" || handle_error "Failed to install dashboard"
    log_message "info" "Configuration installation completed successfully!"
}

# System information function
system_info() {
    clear
    printf "\033[0;34m╔═══════════════════════════════════════════╗\033[0m\n"
    printf "\033[0;34m║\033[1;36m         System Information Details        \033[0;34m║\033[0m\n"
    printf "\033[0;34m╠═══════════════════════════════════════════╣\033[0m\n"

    # Hostname
    printf "\033[0;32m » Hostname:\033[0m \033[1;33m%s\033[0m\n" "$(cat /proc/sys/kernel/hostname)"

    # Operating System
    os_info=$(cat /etc/openwrt_release | grep DISTRIB_DESCRIPTION | cut -d\' -f2)
    printf "\033[0;32m » OS:\033[0m \033[1;33m%s\033[0m\n" "$os_info"

    # Kernel Version
    printf "\033[0;32m » Kernel:\033[0m \033[1;33m%s\033[0m\n" "$(uname -r)"

    # Architecture
    printf "\033[0;32m » Architecture:\033[0m \033[1;33m%s\033[0m\n" "$(uname -m)"

    # Uptime
    uptime_info=$(cat /proc/uptime | awk '{printf "%d days, %d hours, %d minutes", 
        int($1/86400), int(($1%86400)/3600), int(($1%3600)/60)}')
    printf "\033[0;32m » Uptime:\033[0m \033[1;33m%s\033[0m\n" "$uptime_info"

    printf "\033[0;34m╠═══════════════════════════════════════════╣\033[0m\n"

    # Memory Information
    total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    free=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    used=$((total - free))
    memory_percent=$(awk "BEGIN {printf \"%.1f\", ($used/$total)*100}")

    printf "\033[0;32m » Total Memory:\033[0m \033[1;33m%d MB\033[0m\n" $((total/1024))
    printf "\033[0;32m » Used Memory:\033[0m \033[1;33m%d MB (%s%%)\033[0m\n" $((used/1024)) "$memory_percent"
    printf "\033[0;32m » Free Memory:\033[0m \033[1;33m%d MB\033[0m\n" $((free/1024))

    printf "\033[0;34m╠═══════════════════════════════════════════╣\033[0m\n"

    # Disk Usage
    root_usage=$(df / | awk '/\// {print $5}')
    root_total=$(df / | awk '/\// {print $2/1024}')
    root_used=$(df / | awk '/\// {print $3/1024}')

    printf "\033[0;32m » Disk Total:\033[0m \033[1;33m%.1f MB\033[0m\n" "$root_total"
    printf "\033[0;32m » Disk Used:\033[0m \033[1;33m%.1f MB (%s)\033[0m\n" "$root_used" "$root_usage"

    printf "\033[0;34m╚═══════════════════════════════════════════╝\033[0m\n"
}

install_mihomo() {
    log_message "info" "Starting MihomoTProxy installation..."

    # Check environment
    if [[ ! -x "/bin/opkg" && ! -x "/usr/bin/apk" || ! -x "/sbin/fw4" ]]; then
        handle_error "System requirements not met. Only supports OpenWrt build with firewall4!"
    fi

    # Include openwrt_release
    if [[ ! -f "/etc/openwrt_release" ]]; then
        handle_error "OpenWrt release file not found"
    fi
    . /etc/openwrt_release

    # Get branch/arch
    arch="$DISTRIB_ARCH"
    [[ -z "$arch" ]] && handle_error "Could not determine system architecture"
    
    # Determine branch
    case "$DISTRIB_RELEASE" in
        *"23.05"*)
            branch="openwrt-23.05"
            ;;
        *"24.10"*)
            branch="openwrt-24.10"
            ;;
        "SNAPSHOT")
            branch="SNAPSHOT"
            ;;
        *)
            handle_error "Unsupported OpenWrt release: $DISTRIB_RELEASE"
            ;;
    esac

    # Create temporary directory for downloads
    local temp_dir=$(mktemp -d)
    [[ ! -d "$temp_dir" ]] && handle_error "Failed to create temporary directory"
    
    # Download tarball
    log_message "info" "Downloading MihomoTProxy package..."
    local tarball="mihomo_$arch-$branch.tar.gz"
    local download_url="https://github.com/rizkikotet-dev/OpenWrt-mihomo-Mod/releases/latest/download/$tarball"
    
    if ! curl -s -L -o "$temp_dir/$tarball" "$download_url"; then
        rm -rf "$temp_dir"
        handle_error "Failed to download MihomoTProxy package"
    fi

    # Extract tarball
    log_message "info" "Extracting package..."
    if ! tar -xzf "$temp_dir/$tarball" -C "$temp_dir"; then
        rm -rf "$temp_dir"
        handle_error "Failed to extract package"
    fi

    # Install packages based on package manager
    if [ -x "/bin/opkg" ]; then
        log_message "info" "Updating package feeds..."
        if ! opkg update; then
            rm -rf "$temp_dir"
            handle_error "Failed to update package feeds"
        fi

        log_message "info" "Installing MihomoTProxy packages..."
        cd "$temp_dir" || handle_error "Failed to change to temporary directory"
        
        if ! opkg install mihomo_*.ipk; then
            rm -rf "$temp_dir"
            handle_error "Failed to install mihomo package"
        fi
        
        if ! opkg install luci-app-mihomo_*.ipk; then
            rm -rf "$temp_dir"
            handle_error "Failed to install luci-app-mihomo package"
        fi
    elif [ -x "/usr/bin/apk" ]; then
        log_message "info" "Updating Alpine package repository..."
        if ! apk update; then
            rm -rf "$temp_dir"
            handle_error "Failed to update package repository"
        fi

        log_message "info" "Installing MihomoTProxy packages..."
        cd "$temp_dir" || handle_error "Failed to change to temporary directory"
        
        if ! apk add --allow-untrusted mihomo-*.apk; then
            rm -rf "$temp_dir"
            handle_error "Failed to install mihomo package"
        fi
        
        if ! apk add --allow-untrusted luci-app-mihomo-*.apk; then
            rm -rf "$temp_dir"
            handle_error "Failed to install luci-app-mihomo package"
        fi
    fi

    # Cleanup
    rm -rf "$temp_dir"
    log_message "info" "MihomoTProxy installation completed successfully!"
}

uninstall_mihomo() {
    log_message "info" "Starting MihomoTProxy uninstallation..."

    # Create backup before uninstalling
    local backup_name="pre_uninstall_backup_$(date +%Y%m%d_%H%M%S)"
    log_message "info" "Creating backup before uninstallation..."
    perform_backup

    # Remove packages based on package manager
    if [ -x "/bin/opkg" ]; then
        log_message "info" "Removing MihomoTProxy packages..."
        if ! opkg remove luci-app-mihomo; then
            log_message "warn" "Failed to remove luci-app-mihomo package"
        fi
        if ! opkg remove mihomo; then
            log_message "warn" "Failed to remove mihomo package"
        fi
    elif [ -x "/usr/bin/apk" ]; then
        log_message "info" "Removing MihomoTProxy packages..."
        if ! apk del luci-app-mihomo; then
            log_message "warn" "Failed to remove luci-app-mihomo package"
        fi
        if ! apk del mihomo; then
            log_message "warn" "Failed to remove mihomo package"
        fi
    else
        handle_error "No supported package manager found"
    fi

    # Remove configuration files
    log_message "info" "Removing configuration files..."
    if [ -d "/etc/mihomo" ]; then
        rm -rf "/etc/mihomo" || log_message "warn" "Failed to remove /etc/mihomo directory"
    fi
    
    if [ -f "/etc/config/mihomo" ]; then
        rm -f "/etc/config/mihomo" || log_message "warn" "Failed to remove /etc/config/mihomo file"
    fi

    log_message "info" "MihomoTProxy uninstallation completed successfully!"
    log_message "info" "A backup was created before uninstallation in case you need to restore later."
}

# Display menu with system info option
display_menu() {
    clear
    printf "\033[0;34m╔═══════════════════════════════════════════╗\033[0m\n"
    printf "\033[0;34m║\033[0;32m         Auto Script | MihomoTProxy        \033[0;34m║\033[0m\n"
    printf "\033[0;34m╠═══════════════════════════════════════════╣\033[0m\n"
    printf "\033[1;33m    [*]\033[0m   Auto Script By : \033[0;31mRizkiKotet\033[0m   \033[1;33m[*]\033[0m\n"
    printf "\033[0;32m                 Version: \033[1;33m$VERSION\033[0m\n\n"
    
    printf "\033[0;34m╠═══════════════════════════════════════════╣\033[0m\n"
    printf "\033[0;32m >> MIHOMO MENU\033[0m\n"
    printf " > \033[1;33m1\033[0m - \033[0;34mInstall MihomoTProxy\033[0m\n\n"
    printf " > \033[1;33m2\033[0m - \033[0;34mUninstall MihomoTProxy\033[0m\n\n"

    printf "\033[0;32m >> BACKUP MENU\033[0m\n"
    printf " > \033[1;33m3\033[0m - \033[0;34mBackup Full Config\033[0m\n\n"
    
    printf "\033[0;32m >> RESTORE MENU\033[0m\n"
    printf " > \033[1;33m4\033[0m - \033[0;34mRestore Backup Full Config\033[0m\n\n"
    
    printf "\033[0;32m >> CONFIG MENU\033[0m\n"
    printf " > \033[1;33m5\033[0m - \033[0;34mDownload Full Backup Config By RTA-WRT\033[0m\n\n"
    
    printf "\033[0;32m >> SYSTEM INFO\033[0m\n"
    printf " > \033[1;33m6\033[0m - \033[0;34mDisplay System Information\033[0m\n"
    
    printf "\033[0;34m╠═══════════════════════════════════════════╣\033[0m\n"
    printf " > \033[0;31mX\033[0m - Exit Script\n"
    printf "\033[0;34m╚═══════════════════════════════════════════╝\033[0m\n"
}

main() {
    [[ -f "$LOCKFILE" ]] && handle_error "Script is already running"

    touch "$LOCKFILE" || handle_error "Failed to create lock file"
    trap cleanup EXIT

    check_dependencies

    while true; do
        display_menu
        read -r choice

        case "$choice" in
            1) install_mihomo ;;
            2) uninstall_mihomo ;;
            3) perform_backup ;;
            4) 
                read -p "Enter backup file path: " backup_file
                perform_restore "$backup_file"
                ;;
            5) install_config ;;
            6) system_info ;;
            [xX]) 
                log_message "info" "Exiting..."
                exit 0 
                ;;
            *) 
                log_message "warn" "Invalid option selected!" 
                ;;
        esac

        read -p "Press Enter to continue..."
    done
}

main
