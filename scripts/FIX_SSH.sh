#!/bin/bash

# Скрипт восстановления SSH и сетевых соединений для Ubuntu Server
# Запускать с правами суперпользователя (sudo)

# Цветной вывод для лучшей читаемости
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Функция для вывода информации
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Функция для вывода предупреждений
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Функция для вывода ошибок
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав суперпользователя
if [ "$(id -u)" -ne 0 ]; then
    log_error "Этот скрипт должен быть запущен с правами суперпользователя. Используйте: sudo $0"
    exit 1
fi

# Создание резервной копии важных конфигурационных файлов
BACKUP_DIR="/root/network_backup_$(date +%Y%m%d_%H%M%S)"
log_info "Создание резервных копий конфигурационных файлов в $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -r /etc/network "$BACKUP_DIR/"
cp -r /etc/netplan "$BACKUP_DIR/"
cp -r /etc/ssh "$BACKUP_DIR/"
cp /etc/hosts "$BACKUP_DIR/"
cp /etc/hostname "$BACKUP_DIR/"

# Восстановление SSH
log_info "Переустановка и настройка SSH..."
apt-get update
apt-get install --reinstall openssh-server openssh-client -y

# Установка базовой конфигурации SSH
cat > /etc/ssh/sshd_config <<EOF
# Базовая конфигурация SSH
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
UsePrivilegeSeparation yes
KeyRegenerationInterval 3600
ServerKeyBits 1024
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 120
PermitRootLogin prohibit-password
StrictModes yes
RSAAuthentication yes
PubkeyAuthentication yes
IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PasswordAuthentication yes
X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
UsePAM yes
EOF

# Перезапуск SSH
log_info "Перезапуск службы SSH..."
systemctl restart ssh
systemctl enable ssh

# Определение версии Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)
log_info "Обнаружена Ubuntu версии $UBUNTU_VERSION"

# Очистка старых/поврежденных сетевых конфигураций
log_info "Очистка старых сетевых конфигураций..."
rm -f /etc/netplan/*.yaml
rm -f /etc/network/interfaces.d/*

# Остановка и отключение потенциально конфликтующих служб
log_info "Остановка и отключение потенциально конфликтующих сетевых служб..."
systemctl stop NetworkManager 2>/dev/null || true
systemctl disable NetworkManager 2>/dev/null || true
systemctl stop network-manager 2>/dev/null || true
systemctl disable network-manager 2>/dev/null || true

# Настройка базовой конфигурации сети для Netplan (для Ubuntu 18.04+)
if (( $(echo "$UBUNTU_VERSION >= 18.04" | bc -l) )); then
    log_info "Настройка сети через Netplan..."
    # Определение имени сетевого интерфейса
    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)
    
    if [ -z "$INTERFACE" ]; then
        log_error "Не удалось определить сетевой интерфейс"
        INTERFACE="eth0" # Используем eth0 как запасной вариант
        log_warning "Используем интерфейс $INTERFACE как запасной вариант"
    else
        log_info "Обнаружен сетевой интерфейс: $INTERFACE"
    fi
    
    # Создание конфигурации Netplan с поддержкой как DHCP, так и статического IP
    cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: true
      # Раскомментируйте следующие строки и настройте для статического IP
      # dhcp4: no
      # addresses: [192.168.1.100/24]
      # gateway4: 192.168.1.1
      # nameservers:
      #   addresses: [8.8.8.8, 8.8.4.4]
EOF
    
    # Применение конфигурации Netplan
    log_info "Применение конфигурации Netplan..."
    netplan generate
    netplan apply
else
    # Настройка сети через interfaces (для старых версий Ubuntu)
    log_info "Настройка сети через interfaces..."
    # Определение имени сетевого интерфейса
    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)
    
    if [ -z "$INTERFACE" ]; then
        log_error "Не удалось определить сетевой интерфейс"
        INTERFACE="eth0" # Используем eth0 как запасной вариант
        log_warning "Используем интерфейс $INTERFACE как запасной вариант"
    else
        log_info "Обнаружен сетевой интерфейс: $INTERFACE"
    fi
    
    # Создание базового файла interfaces
    cat > /etc/network/interfaces <<EOF
# Локальный интерфейс
auto lo
iface lo inet loopback

# Основной сетевой интерфейс
auto $INTERFACE
iface $INTERFACE inet dhcp
# Для статического IP раскомментируйте следующие строки и настройте
# iface $INTERFACE inet static
#     address 192.168.1.100
#     netmask 255.255.255.0
#     gateway 192.168.1.1
#     dns-nameservers 8.8.8.8 8.8.4.4
EOF
    
    # Перезапуск сети
    log_info "Перезапуск сетевых служб..."
    systemctl restart networking
fi

# Установка и настройка DHCP-клиента
log_info "Переустановка DHCP-клиента..."
apt-get install --reinstall isc-dhcp-client -y

# Удаление потенциально конфликтующих пакетов
log_info "Проверка и удаление конфликтующих пакетов..."
apt-get remove --purge resolvconf -y || true

# Настройка DNS
log_info "Настройка DNS-серверов..."
cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# Защита файла resolv.conf от изменений
chattr +i /etc/resolv.conf

# Перезапуск сетевых сервисов для применения изменений
log_info "Перезапуск сетевых сервисов..."
if (( $(echo "$UBUNTU_VERSION >= 18.04" | bc -l) )); then
    netplan apply
    systemctl restart systemd-networkd
else
    systemctl restart networking
fi

# Проверка состояния сети
log_info "Проверка состояния сети..."
echo "IP-адреса:"
ip addr show

echo "Маршруты:"
ip route

echo "DNS-серверы:"
cat /etc/resolv.conf

# Проверка состояния SSH
log_info "Проверка состояния SSH..."
systemctl status ssh

log_info "Скрипт восстановления завершил работу."
log_info "Если вам нужно настроить статический IP, отредактируйте файл конфигурации:"
if (( $(echo "$UBUNTU_VERSION >= 18.04" | bc -l) )); then
    echo "  /etc/netplan/01-netcfg.yaml"
else
    echo "  /etc/network/interfaces"
fi
log_info "После этого примените изменения командой:"
if (( $(echo "$UBUNTU_VERSION >= 18.04" | bc -l) )); then
    echo "  sudo netplan apply"
else
    echo "  sudo systemctl restart networking"
fi

echo ""
log_info "Резервные копии конфигурационных файлов сохранены в $BACKUP_DIR"
log_info "SSH должен быть доступен по IP-адресу вашего сервера на порту 22."