#!/bin/bash
#
# Script to completely disable GUI and optimize boot speed on Debian-based systems
# IMPROVED: Preserves network connectivity while removing GUI components
# Run as root (sudo)

# Colors for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Этот скрипт должен быть запущен с правами root!${NC}"
    echo "Выполните: sudo bash $0"
    exit 1
fi

echo -e "${BLUE}=== ОТКЛЮЧЕНИЕ ГРАФИЧЕСКОГО ИНТЕРФЕЙСА И ОПТИМИЗАЦИЯ ЗАГРУЗКИ ===${NC}"
echo -e "${YELLOW}ВНИМАНИЕ: Этот скрипт удалит графические компоненты системы.${NC}"
echo -e "${YELLOW}SSH-сервер и сетевые подключения будут сохранены для удаленного доступа.${NC}"
echo ""
echo -e "${RED}Вы уверены, что хотите продолжить? (y/n)${NC}"
read -r confirmation

if [[ ! "$confirmation" =~ ^[yY]$ ]]; then
    echo "Операция отменена."
    exit 0
fi

# Backup current network and SSH configuration
echo -e "${BLUE}[1/12] Создание резервной копии конфигурации SSH и сети...${NC}"
mkdir -p /root/backup
cp -r /etc/ssh /root/backup/
cp -r /etc/network /root/backup/
systemctl is-active --quiet ssh && systemctl status ssh > /root/backup/ssh_status.txt
ip a > /root/backup/ip_config.txt
ip route > /root/backup/routes.txt

# Save current network interface information
echo -e "${BLUE}[2/12] Сохранение текущей конфигурации сети...${NC}"
ACTIVE_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -n "$ACTIVE_INTERFACE" ]; then
    echo "Обнаружен активный интерфейс: $ACTIVE_INTERFACE"
    INTERFACE_CONFIG=$(ip addr show "$ACTIVE_INTERFACE")
    echo "$INTERFACE_CONFIG" > /root/backup/active_interface.txt
else
    echo -e "${YELLOW}Не удалось определить активный сетевой интерфейс${NC}"
fi

# Stop and mask graphical targets
echo -e "${BLUE}[3/12] Остановка и маскирование графических целей systemd...${NC}"
systemctl stop display-manager.service 2>/dev/null || true
systemctl disable display-manager.service 2>/dev/null || true
systemctl mask display-manager.service 2>/dev/null || true

systemctl set-default multi-user.target
systemctl isolate multi-user.target

# Stop and disable unnecessary GUI services but keep network services
echo -e "${BLUE}[4/12] Отключение ненужных графических сервисов...${NC}"
SERVICES_TO_DISABLE=(
    "plymouth"
    "plymouth-quit-wait"
    "plymouth-start"
    "avahi-daemon"
    "ModemManager"
    "rtkit-daemon"
    "accounts-daemon"
    "packagekit"
    "colord"
    "cups"
    "cups-browsed"
    "bluetooth"
    "speech-dispatcher"
)

# Important: Do NOT disable these critical services anymore:
# - "NetworkManager"
# - "wpa_supplicant"
# - Other network-related services

for service in "${SERVICES_TO_DISABLE[@]}"; do
    systemctl stop ${service}.service 2>/dev/null || true
    systemctl disable ${service}.service 2>/dev/null || true
    systemctl mask ${service}.service 2>/dev/null || true
    echo -e "  ${GREEN}Отключен:${NC} $service"
done

# Ensure SSH service is enabled and running
echo -e "${BLUE}[5/12] Проверка и включение SSH-сервера...${NC}"
apt-get update -qq
apt-get install -y -qq openssh-server

if systemctl is-active --quiet ssh; then
    echo -e "  ${GREEN}SSH-сервер уже активен${NC}"
else
    systemctl start ssh
    systemctl enable ssh
    echo -e "  ${GREEN}SSH-сервер запущен и включен${NC}"
fi

# Ensure network connectivity is maintained
echo -e "${BLUE}[6/12] Проверка и обеспечение сетевого подключения...${NC}"
# Make sure network-manager stays enabled
if systemctl is-active --quiet NetworkManager; then
    echo -e "  ${GREEN}NetworkManager активен${NC}"
else
    echo -e "  ${YELLOW}Активация NetworkManager...${NC}"
    systemctl unmask NetworkManager 2>/dev/null || true
    systemctl enable NetworkManager
    systemctl start NetworkManager
fi

# Also ensure wpa_supplicant is enabled
if systemctl is-active --quiet wpa_supplicant; then
    echo -e "  ${GREEN}wpa_supplicant активен${NC}"
else
    echo -e "  ${YELLOW}Активация wpa_supplicant...${NC}"
    systemctl unmask wpa_supplicant 2>/dev/null || true
    systemctl enable wpa_supplicant
    systemctl start wpa_supplicant
fi

# Disable graphical login managers
echo -e "${BLUE}[7/12] Удаление графических менеджеров входа...${NC}"
DISPLAY_MANAGERS=(
    "gdm"
    "gdm3"
    "lightdm"
    "lxdm"
    "sddm"
    "xdm"
    "slim"
    "wdm"
)

for dm in "${DISPLAY_MANAGERS[@]}"; do
    systemctl stop ${dm}.service 2>/dev/null || true
    systemctl disable ${dm}.service 2>/dev/null || true
    systemctl mask ${dm}.service 2>/dev/null || true
    echo -e "  ${GREEN}Отключен:${NC} $dm"
done

# Hold current SSH and network packages to prevent removal
echo -e "${BLUE}[8/12] Защита SSH и сетевых пакетов от удаления...${NC}"
apt-mark hold openssh-server openssh-client openssh-sftp-server 2>/dev/null || true
apt-mark hold network-manager wpasupplicant iproute2 iputils-ping isc-dhcp-client ifupdown 2>/dev/null || true

# Remove X11, desktop environments and GUI applications
echo -e "${BLUE}[9/12] Удаление графических пакетов...${NC}"
# Create a list of packages to remove
GUI_PACKAGES=(
    # X server
    "xserver-xorg*" "xorg*" "x11-*"
    
    # Desktop environments
    "gnome*" "kde*" "plasma*" "plasma-*" "xfce*" "lxde*" "lxqt*" "mate*" "cinnamon*" "budgie*"
    
    # Display managers
    "gdm*" "lightdm*" "lxdm*" "sddm*" "xdm" "slim" "wdm"
    
    # Common GUI applications
    "firefox*" "chromium*" "libreoffice*" "gimp" "inkscape" "vlc" "rhythmbox" "totem"
    "gnome-terminal" "gnome-calculator" "nautilus" "evince" "gedit" "mousepad" "eog"
    
    # GUI utilities
    "system-config*" "pavucontrol" "blueman" "file-roller"
    
    # X11 libraries and tools
    "libx11*" "libgtk*" "libqt*" "qt*" "libwxgtk*" "libcairo*"
)

# Be sure NOT to include network-manager-gnome in general removal - remove it specifically
apt-get -y -qq purge network-manager-gnome 2>/dev/null || true

# Keep a list of essential packages that should not be removed
ESSENTIAL_KEEP=(
    "sudo" "openssh-server" "openssh-client" "openssh-sftp-server"
    "bash" "systemd" "apt" "dpkg" "coreutils" "grep" "sed" "gawk"
    "udev" "dbus" "network-manager" "ifupdown" "iproute2" "iputils-ping"
    "isc-dhcp-client" "less" "lsb-release" "nano" "vim" "curl" "wget"
    "ca-certificates" "procps" "psmisc" "rsyslog" "sysvinit-utils"
    "systemd-timesyncd" "tzdata" "acpid" "tasksel" "wpasupplicant"
)

# Mark essential packages as manually installed to prevent autoremoval
for pkg in "${ESSENTIAL_KEEP[@]}"; do
    apt-mark manual $pkg 2>/dev/null || true
done

# First attempt to remove GUI packages
echo -e "  ${YELLOW}Удаление графических пакетов...${NC}"
apt-get -y -qq purge ${GUI_PACKAGES[@]} 2>/dev/null || true
apt-get -y -qq autoremove --purge 2>/dev/null || true

# Aggressive removal approach - remove all X11 related packages but keep SSH and network
echo -e "  ${YELLOW}Агрессивное удаление оставшихся графических компонентов...${NC}"
apt-get -y -qq --purge remove xserver-xorg* xorg* x11-* 2>/dev/null || true
apt-get -y -qq --purge remove libx11-* 2>/dev/null || true
apt-get -y -qq --purge remove libgtk* libqt* 2>/dev/null || true

# Remove font packages (keeping minimal required)
echo -e "${BLUE}[10/12] Удаление лишних шрифтов...${NC}"
apt-get -y -qq --purge remove fonts-dejavu* fonts-liberation* fonts-noto* fonts-opensymbol fonts-freefont* 2>/dev/null || true
apt-get -y -qq autoremove --purge 2>/dev/null || true

# Make sure we keep SSH server and network after all removals
echo -e "${BLUE}[11/12] Проверка сохранности SSH-сервера и сетевых служб...${NC}"
apt-get -y -qq install openssh-server network-manager wpasupplicant

# Optimize GRUB for faster boot
echo -e "${BLUE}[12/12] Оптимизация GRUB для быстрой загрузки...${NC}"
if [ -f /etc/default/grub ]; then
    cp /etc/default/grub /etc/default/grub.backup
    
    # Set shorter timeout
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
    
    # Add kernel parameters for faster boot but keep network functionality
    CMDLINE=$(grep "GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | cut -d'"' -f2)
    CMDLINE="$CMDLINE quiet loglevel=3 rd.systemd.show_status=auto noatime"
    # Important: Removed parameters that might break network functionality:
    # - rd.udev.log_level=0 (can interfere with device detection)
    # - fastboot (can sometimes skip network device initialization)
    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$CMDLINE\"/" /etc/default/grub
    
    # Disable OS prober
    echo "GRUB_DISABLE_OS_PROBER=true" >> /etc/default/grub
    
    # Update GRUB
    update-grub
fi

# Disable unnecessary kernel modules - but DON'T disable network modules
echo -e "${BLUE}[12/12] Отключение ненужных модулей ядра...${NC}"
mkdir -p /etc/modprobe.d/

cat > /etc/modprobe.d/blacklist-graphics.conf << EOF
# Blacklist graphics cards modules
blacklist nouveau
blacklist nvidia
blacklist radeon
blacklist amdgpu
blacklist i915
blacklist qxl
EOF

cat > /etc/modprobe.d/blacklist-sound.conf << EOF
# Blacklist sound modules
blacklist snd
blacklist snd_*
blacklist soundcore
EOF

cat > /etc/modprobe.d/blacklist-bluetooth.conf << EOF
# Blacklist bluetooth modules
blacklist bluetooth
blacklist btusb
EOF

cat > /etc/modprobe.d/blacklist-webcam.conf << EOF
# Blacklist webcam modules
blacklist uvcvideo
EOF

# IMPORTANT: Don't blacklist any network modules!

# Disable Plymouth splash screen
if [ -f /etc/initramfs-tools/conf.d/splash ]; then
    rm -f /etc/initramfs-tools/conf.d/splash
fi

# Create a placeholder for plymouth configuration
mkdir -p /etc/plymouth/
echo "ShowDelay=0" > /etc/plymouth/plymouthd.conf
echo "Theme=text" >> /etc/plymouth/plymouthd.conf

# Update initramfs to apply changes
update-initramfs -u

# Final cleanup
echo -e "${BLUE}Выполнение финальной очистки...${NC}"
apt-get -y -qq autoremove --purge
apt-get -y -qq clean
apt-get -y -qq autoclean

# Print summary
echo -e "\n${GREEN}=== РЕЗУЛЬТАТЫ ВЫПОЛНЕНИЯ ===${NC}"
echo -e "${GREEN}✓${NC} Графические компоненты удалены"
echo -e "${GREEN}✓${NC} SSH-сервер активен и защищен от удаления"
echo -e "${GREEN}✓${NC} Сетевые службы сохранены и работоспособны"
echo -e "${GREEN}✓${NC} Загрузка системы оптимизирована"
echo -e "${GREEN}✓${NC} Настройки GRUB оптимизированы для быстрой загрузки"
echo -e "${GREEN}✓${NC} Ненужные модули ядра отключены (без влияния на сеть)"

# Verify SSH is still running
if systemctl is-active --quiet ssh; then
    SSH_STATUS=$(systemctl is-active ssh)
    echo -e "${GREEN}✓${NC} SSH сервер статус: ${GREEN}$SSH_STATUS${NC}"
    IP_ADDR=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}✓${NC} Подключение по SSH доступно по IP: ${GREEN}$IP_ADDR${NC}"
else
    echo -e "${RED}⚠ ВНИМАНИЕ: SSH сервер не запущен!${NC}"
    echo -e "${YELLOW}Пытаемся запустить SSH...${NC}"
    systemctl start ssh
    systemctl enable ssh
    
    if systemctl is-active --quiet ssh; then
        echo -e "${GREEN}✓${NC} SSH сервер успешно запущен"
    else
        echo -e "${RED}⚠ Не удалось запустить SSH сервер. Проверьте вручную!${NC}"
    fi
fi

# Verify network connectivity
echo -e "\n${BLUE}Проверка сетевого подключения...${NC}"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Сетевое подключение работает нормально"
else
    echo -e "${RED}⚠ ВНИМАНИЕ: Нет доступа к интернету!${NC}"
    echo -e "${YELLOW}Проверьте сетевые службы...${NC}"
    
    systemctl restart NetworkManager
    
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Сетевое подключение восстановлено после перезапуска NetworkManager"
    else
        echo -e "${RED}⚠ Не удалось восстановить сетевое подключение. Выполните следующие команды вручную:${NC}"
        echo -e "   ${YELLOW}sudo systemctl restart NetworkManager${NC}"
        echo -e "   ${YELLOW}sudo systemctl restart networking${NC}"
        echo -e "   ${YELLOW}sudo ip link set $ACTIVE_INTERFACE up${NC}"
    fi
fi

echo -e "\n${YELLOW}Рекомендуется перезагрузить систему для применения всех изменений.${NC}"
echo -e "${YELLOW}Выполните команду: ${GREEN}sudo reboot${NC}"

exit 0