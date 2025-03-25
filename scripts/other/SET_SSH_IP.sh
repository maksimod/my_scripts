#!/bin/bash

# Скрипт настройки статического IP и обеспечения работы SSH
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

# Определение версии Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)
log_info "Обнаружена Ubuntu версии $UBUNTU_VERSION"

# Определение сетевого интерфейса
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)

if [ -z "$INTERFACE" ]; then
    log_error "Не удалось определить сетевой интерфейс"
    exit 1
else
    log_info "Обнаружен сетевой интерфейс: $INTERFACE"
fi

# Получение текущего IP-адреса, маски и шлюза
CURRENT_IP=$(ip -4 addr show dev $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
CURRENT_PREFIX=$(ip -4 addr show dev $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\K\d+')
CURRENT_GATEWAY=$(ip route | grep default | grep $INTERFACE | awk '{print $3}')

log_info "Текущие сетевые настройки:"
log_info "IP-адрес: $CURRENT_IP"
log_info "Префикс маски: $CURRENT_PREFIX"
log_info "Шлюз: $CURRENT_GATEWAY"

# Запрос новых сетевых настроек или использование текущих
echo ""
read -p "Введите статический IP-адрес [$CURRENT_IP]: " STATIC_IP
STATIC_IP=${STATIC_IP:-$CURRENT_IP}

read -p "Введите префикс маски подсети (например, 24 для 255.255.255.0) [$CURRENT_PREFIX]: " PREFIX
PREFIX=${PREFIX:-$CURRENT_PREFIX}

read -p "Введите IP-адрес шлюза [$CURRENT_GATEWAY]: " GATEWAY
GATEWAY=${GATEWAY:-$CURRENT_GATEWAY}

read -p "Введите первичный DNS-сервер [8.8.8.8]: " DNS1
DNS1=${DNS1:-"8.8.8.8"}

read -p "Введите вторичный DNS-сервер [8.8.4.4]: " DNS2
DNS2=${DNS2:-"8.8.4.4"}

# Преобразование префикса в маску подсети для старых версий Ubuntu
get_netmask() {
    local prefix=$1
    local mask=""
    
    case $prefix in
        8) mask="255.0.0.0" ;;
        16) mask="255.255.0.0" ;;
        24) mask="255.255.255.0" ;;
        32) mask="255.255.255.255" ;;
        *)
            # Вычисление маски для других префиксов
            local full_octets=$(($prefix / 8))
            local partial_octet_bits=$(($prefix % 8))
            local partial_octet_value=0
            
            for ((i=0; i<$partial_octet_bits; i++)); do
                partial_octet_value=$(($partial_octet_value | (1 << (7 - $i))))
            done
            
            for ((i=0; i<4; i++)); do
                if [ $i -lt $full_octets ]; then
                    mask+="255"
                elif [ $i -eq $full_octets ] && [ $partial_octet_bits -gt 0 ]; then
                    mask+="$partial_octet_value"
                else
                    mask+="0"
                fi
                
                if [ $i -lt 3 ]; then
                    mask+="."
                fi
            done
            ;;
    esac
    
    echo $mask
}

NETMASK=$(get_netmask $PREFIX)
log_info "Маска подсети: $NETMASK (/$PREFIX)"

# Создание резервной копии текущих конфигураций
BACKUP_DIR="/root/static_ip_backup_$(date +%Y%m%d_%H%M%S)"
log_info "Создание резервных копий конфигурационных файлов в $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -r /etc/network "$BACKUP_DIR/" 2>/dev/null || true
cp -r /etc/netplan "$BACKUP_DIR/" 2>/dev/null || true
cp -r /etc/ssh "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/hosts "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/hostname "$BACKUP_DIR/" 2>/dev/null || true

# Установка и настройка SSH для гарантированной работы
log_info "Настройка SSH для работы на статическом IP..."
apt-get update
apt-get install --reinstall openssh-server openssh-client -y

# Настройка SSH для прослушивания на конкретном IP
cat > /etc/ssh/sshd_config <<EOF
# Базовая конфигурация SSH с привязкой к статическому IP
Port 22
Protocol 2
ListenAddress $STATIC_IP
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

# Настройка статического IP в зависимости от версии Ubuntu
if (( $(echo "$UBUNTU_VERSION >= 18.04" | bc -l) )); then
    # Для Ubuntu 18.04 и новее (Netplan)
    log_info "Настройка статического IP через Netplan..."
    
    # Создание конфигурации Netplan для статического IP
    cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses: [$STATIC_IP/$PREFIX]
      gateway4: $GATEWAY
      nameservers:
        addresses: [$DNS1, $DNS2]
EOF
    
    # Применение конфигурации Netplan
    log_info "Применение конфигурации Netplan..."
    netplan generate
    netplan apply
    
    # Создание systemd-сервиса для запуска SSH после инициализации сети
    log_info "Создание systemd-сервиса для гарантированного запуска SSH..."
    cat > /etc/systemd/system/ssh-restart.service <<EOF
[Unit]
Description=Restart SSH after network is online
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c "systemctl restart ssh"

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable ssh-restart.service
    
else
    # Для Ubuntu 16.04 и старее (interfaces)
    log_info "Настройка статического IP через interfaces..."
    
    # Создание конфигурации interfaces для статического IP
    cat > /etc/network/interfaces <<EOF
# Локальный интерфейс
auto lo
iface lo inet loopback

# Основной сетевой интерфейс
auto $INTERFACE
iface $INTERFACE inet static
    address $STATIC_IP
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS1 $DNS2
EOF
    
    # Перезапуск сети
    log_info "Перезапуск сетевых служб..."
    systemctl restart networking
    
    # Добавление скрипта в rc.local для гарантированного запуска SSH
    log_info "Настройка автоматического запуска SSH после загрузки..."
    if [ ! -f /etc/rc.local ]; then
        echo '#!/bin/sh -e' > /etc/rc.local
        echo 'exit 0' >> /etc/rc.local
        chmod +x /etc/rc.local
    fi
    
    # Вставка команды перед 'exit 0'
    sed -i '/^exit 0/i # Перезапуск SSH для гарантированной работы на статическом IP\nsystemctl restart ssh' /etc/rc.local
fi

# Настройка DNS
log_info "Настройка DNS-серверов..."
if [ -f /etc/resolv.conf ]; then
    # Снятие атрибута неизменяемости, если установлен
    chattr -i /etc/resolv.conf 2>/dev/null || true
fi

cat > /etc/resolv.conf <<EOF
nameserver $DNS1
nameserver $DNS2
EOF

# Защита файла resolv.conf от изменений
chattr +i /etc/resolv.conf

# Добавление записи в /etc/hosts для локального разрешения имен
HOSTNAME=$(hostname)
log_info "Добавление статического IP в /etc/hosts..."
# Удаление старых записей для этого хоста
sed -i "/\s$HOSTNAME$/d" /etc/hosts
# Добавление новой записи
echo "$STATIC_IP $HOSTNAME" >> /etc/hosts

# Перезапуск SSH
log_info "Перезапуск SSH..."
systemctl restart ssh
systemctl enable ssh

# Создание скрипта для восстановления SSH при проблемах
log_info "Создание скрипта аварийного восстановления SSH..."
cat > /usr/local/bin/fix-ssh.sh <<EOF
#!/bin/bash
# Скрипт для восстановления SSH сервиса
systemctl restart ssh
ip addr add $STATIC_IP/$PREFIX dev $INTERFACE 2>/dev/null || true
EOF

chmod +x /usr/local/bin/fix-ssh.sh

# Добавление задания в crontab для проверки и восстановления SSH
log_info "Настройка периодической проверки и восстановления SSH..."
(crontab -l 2>/dev/null | grep -v "fix-ssh.sh"; echo "*/5 * * * * /usr/local/bin/fix-ssh.sh > /dev/null 2>&1") | crontab -

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

log_info "Настройка статического IP-адреса $STATIC_IP завершена."
log_info "SSH настроен и работает на адресе $STATIC_IP, порт 22."
log_info "Резервные копии конфигурационных файлов сохранены в $BACKUP_DIR"

echo ""
log_info "Важная информация:"
log_info "1. Если вы подключены по SSH через DHCP, ваше соединение может прерваться."
log_info "2. Подключитесь заново используя новый IP-адрес: ssh username@$STATIC_IP"
log_info "3. В случае проблем с SSH, запустите скрипт аварийного восстановления: sudo /usr/local/bin/fix-ssh.sh"
log_info "4. Для возврата к DHCP запустите предыдущий скрипт восстановления."