#!/bin/bash

# Автоматически сгенерированный композитный скрипт
# Дата создания: Ср 26 мар 2025 17:03:10 MSK
# ## BSCRIPT_META

# Настройка цветов
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функция для отображения заголовка скрипта
display_script_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${GREEN}Выполнение скрипта: $1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

## BSCRIPT_START:/root/scripts/INSTALL_SUDO.sh
display_script_header "/root/scripts/INSTALL_SUDO.sh"


# Скрипт для настройки sudo на Debian системе
# Запускать от имени root

# Проверка, что скрипт запущен от имени root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: этот скрипт должен быть запущен от имени root"
    exit 1
fi

# Интерактивный ввод имени пользователя
read -p "Введите имя пользователя для настройки sudo: " USERNAME

# Проверка, что имя пользователя было введено
if [ -z "$USERNAME" ]; then
    echo "Ошибка: имя пользователя не может быть пустым"
    exit 1
fi

# Проверка, что пользователь существует
if ! id "$USERNAME" &>/dev/null; then
    echo "Ошибка: пользователь $USERNAME не существует"
    exit 1
fi

# Установка sudo, если она еще не установлена
if ! dpkg -l | grep -q sudo; then
    echo "Установка пакета sudo..."
    apt-get update
    apt-get install -y sudo
    if [ $? -ne 0 ]; then
        echo "Ошибка: не удалось установить sudo"
        exit 1
    fi
    echo "Пакет sudo успешно установлен"
else
    echo "Пакет sudo уже установлен"
fi

# Добавление пользователя в группу sudo
if ! groups "$USERNAME" | grep -q sudo; then
    echo "Добавление пользователя $USERNAME в группу sudo..."
    usermod -aG sudo "$USERNAME"
    if [ $? -ne 0 ]; then
        echo "Ошибка: не удалось добавить пользователя в группу sudo"
        exit 1
    fi
    echo "Пользователь $USERNAME успешно добавлен в группу sudo"
else
    echo "Пользователь $USERNAME уже находится в группу sudo"
fi

# Настройка sudo без пароля (опционально)
# Запрос на настройку sudo без пароля
read -p "Настроить sudo без запроса пароля для $USERNAME? (y/n): " SUDO_WITHOUT_PASSWORD

if [[ "$SUDO_WITHOUT_PASSWORD" == "y" || "$SUDO_WITHOUT_PASSWORD" == "Y" ]]; then
    echo "Настройка sudo без запроса пароля для $USERNAME..."
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME
    chmod 440 /etc/sudoers.d/$USERNAME
    echo "Настройка sudo без пароля завершена"
fi

# Проверка конфигурации sudo
echo "Проверка конфигурации sudo..."
if visudo -c; then
    echo "Конфигурация sudo корректна"
else
    echo "Ошибка: неверная конфигурация sudo"
    exit 1
fi

echo "Настройка sudo успешно завершена для пользователя $USERNAME"
echo "Пользователь теперь может использовать команду sudo для выполнения команд с привилегиями root"
## BSCRIPT_END:/root/scripts/INSTALL_SUDO.sh

## BSCRIPT_START:/root/scripts/TURN_OFF_HIB.sh
display_script_header "/root/scripts/TURN_OFF_HIB.sh"

#
# Script to completely disable hibernation and sleep on Debian-based systems
# Run as root (sudo)

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root (sudo)!"
    exit 1
fi

echo "Начинаем отключение гибернации и спящего режима..."

# 1. Mask all sleep/hibernate systemd targets
echo "Маскирование целей systemd для спящего режима и гибернации..."
systemctl mask sleep.target
systemctl mask suspend.target
systemctl mask hibernate.target
systemctl mask hybrid-sleep.target

# 2. Configure systemd-logind
echo "Настройка systemd-logind для игнорирования событий сна..."
mkdir -p /etc/systemd/logind.conf.d/
cat > /etc/systemd/logind.conf.d/10-disable-sleep.conf << EOF
[Login]
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
IdleAction=ignore
EOF

# 3. Modify kernel parameters in GRUB
echo "Настройка параметров ядра через GRUB..."
if [ -f /etc/default/grub ]; then
    # Backup original grub config
    cp /etc/default/grub /etc/default/grub.bak
    
    # Update GRUB parameters to disable sleep/hibernate at kernel level
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nohlt acpi_sleep=0 acpi_osi=Linux"/' /etc/default/grub
    
    # Update GRUB
    update-grub
else
    echo "ПРЕДУПРЕЖДЕНИЕ: Файл /etc/default/grub не найден. Пропускаем настройку GRUB."
fi

# 4. Create a service to disable sleep via sysfs
echo "Создание systemd-сервиса для отключения спящего режима..."
cat > /etc/systemd/system/disable-sleep.service << EOF
[Unit]
Description=Disable Sleep and Hibernation
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c "if [ -f /sys/power/pm_async ]; then echo 0 > /sys/power/pm_async; fi; if [ -f /sys/power/autosleep ]; then echo 0 > /sys/power/autosleep; fi; if [ -f /sys/power/disk ]; then echo off > /sys/power/disk; fi"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl enable disable-sleep.service
systemctl start disable-sleep.service

# 5. Set up rc.local for systems that still use it
echo "Создание резервного метода через rc.local..."
cat > /etc/rc.local << EOF
#!/bin/sh -e
# Disable sleep/suspend/hibernate
if [ -f /sys/power/pm_async ]; then echo 0 > /sys/power/pm_async; fi
if [ -f /sys/power/autosleep ]; then echo 0 > /sys/power/autosleep; fi
if [ -f /sys/power/disk ]; then echo off > /sys/power/disk; fi
exit 0
EOF

chmod +x /etc/rc.local

# 6. Disable graphical power management (if X11 is installed)
if [ -d /etc/X11/xorg.conf.d ]; then
    echo "Отключение энергосбережения в X11..."
    mkdir -p /etc/X11/xorg.conf.d/
    cat > /etc/X11/xorg.conf.d/10-no-dpms.conf << EOF
Section "ServerFlags"
  Option "BlankTime" "0"
  Option "StandbyTime" "0"
  Option "SuspendTime" "0"
  Option "OffTime" "0"
EndSection
EOF
fi

# 7. Install acpid if not already installed
if ! dpkg -l | grep -q acpid; then
    echo "Установка acpid для лучшего управления энергопотреблением..."
    apt-get update
    apt-get install -y acpid
fi

# Apply immediate settings
echo "Применение немедленных настроек..."
if [ -f /sys/power/pm_async ]; then echo 0 > /sys/power/pm_async; fi
if [ -f /sys/power/autosleep ]; then echo 0 > /sys/power/autosleep; fi
if [ -f /sys/power/disk ]; then echo off > /sys/power/disk; fi

echo "Готово! Гибернация и спящий режим отключены."
echo "Для применения всех изменений рекомендуется перезагрузить систему."
## BSCRIPT_END:/root/scripts/TURN_OFF_HIB.sh

## BSCRIPT_START:/root/scripts/SSH_ROOT.sh
display_script_header "/root/scripts/SSH_ROOT.sh"


# Проверка, запущен ли скрипт с правами sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами sudo."
    echo "Запустите: sudo $0"
    exit 1
fi

echo "Включение SSH доступа для пользователя root..."

# Запрос текущего пароля sudo
echo "Для установки такого же пароля для root, введите текущий пароль sudo:"
read -s SUDO_PASSWORD
echo

# Установка пароля root такого же, как и sudo пароль
echo "Установка пароля для root..."
echo "root:$SUDO_PASSWORD" | chpasswd

# Изменение конфигурации SSH для разрешения входа root
echo "Настройка SSH для разрешения входа root..."
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# Если строка уже изменена, но без yes
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# Если строка с другими параметрами
sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config

# Если строка отсутствует, добавляем ее
if ! grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
fi

# Перезапуск службы SSH
echo "Перезапуск службы SSH..."
systemctl restart ssh

echo "Готово! Теперь вы можете подключиться к серверу по SSH как root."
echo "Используйте: ssh root@ваш-сервер-ip"
echo "Пароль root такой же, как и ваш пароль sudo."
## BSCRIPT_END:/root/scripts/SSH_ROOT.sh

## BSCRIPT_START:/root/scripts/SET_USER_PASSWORD.sh
display_script_header "/root/scripts/SET_USER_PASSWORD.sh"


# Скрипт для гарантированного изменения пароля root, создания пользователя
# и настройки SSH-доступа для этого пользователя

# Проверка, запущен ли скрипт от имени root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен от имени root" >&2
    exit 1
fi

# Функция для получения защищенного ввода (пароля)
function get_secure_input() {
    local prompt="$1"
    local password=""
    local verify=""
    
    while true; do
        read -s -p "$prompt: " password
        echo
        read -s -p "Повторите ввод: " verify
        echo
        
        if [ "$password" = "$verify" ]; then
            if [ -z "$password" ]; then
                echo "Ошибка: пароль не может быть пустым. Попробуйте снова."
            else
                echo "$password"
                return 0
            fi
        else
            echo "Ошибка: введенные значения не совпадают. Попробуйте снова."
        fi
    done
}

echo "=== Настройка пользователей и SSH ==="

# Изменение пароля root
echo -e "\n[1] Изменение пароля root"
current_root_hash=$(grep "^root:" /etc/shadow | cut -d: -f2)
while true; do
    new_root_pass=$(get_secure_input "Введите новый пароль для root")
    
    # Проверка, отличается ли хеш нового пароля от текущего
    temp_hash=$(echo "$new_root_pass" | mkpasswd -m sha-512 -s)
    
    if [ "$current_root_hash" != "$temp_hash" ]; then
        # Установка нового пароля
        echo "root:$new_root_pass" | chpasswd
        echo "Пароль root успешно изменен."
        break
    else
        echo "Новый пароль совпадает с текущим. Пожалуйста, введите другой пароль."
    fi
done

# Создание нового пользователя
echo -e "\n[2] Создание нового пользователя"
while true; do
    read -p "Введите имя для нового пользователя: " new_username
    
    if id "$new_username" &>/dev/null; then
        echo "Пользователь $new_username уже существует. Хотите обновить его? [y/n]: "
        read update_choice
        if [[ "$update_choice" =~ ^[Yy]$ ]]; then
            break
        fi
    else
        # Создаем нового пользователя
        useradd -m -s /bin/bash "$new_username"
        echo "Пользователь $new_username создан."
        break
    fi
done

# Установка пароля для пользователя
echo -e "\n[3] Установка пароля для пользователя $new_username"
if id "$new_username" &>/dev/null; then
    current_user_hash=$(grep "^$new_username:" /etc/shadow | cut -d: -f2)
    
    while true; do
        new_user_pass=$(get_secure_input "Введите пароль для пользователя $new_username")
        
        # Проверка, отличается ли хеш нового пароля от текущего
        temp_hash=$(echo "$new_user_pass" | mkpasswd -m sha-512 -s)
        
        if [ -z "$current_user_hash" ] || [ "$current_user_hash" != "$temp_hash" ]; then
            # Установка нового пароля
            echo "$new_username:$new_user_pass" | chpasswd
            echo "Пароль для пользователя $new_username успешно установлен."
            break
        else
            echo "Новый пароль совпадает с текущим. Пожалуйста, введите другой пароль."
        fi
    done
else
    echo "Ошибка: пользователь $new_username не существует."
    exit 1
fi

# Настройка SSH
echo -e "\n[4] Настройка SSH для пользователя $new_username"

# Проверка установлен ли SSH-сервер
if ! command -v sshd &> /dev/null; then
    echo "SSH-сервер не установлен. Устанавливаем..."
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y openssh-server
    elif command -v yum &> /dev/null; then
        yum install -y openssh-server
    elif command -v dnf &> /dev/null; then
        dnf install -y openssh-server
    elif command -v zypper &> /dev/null; then
        zypper install -y openssh
    elif command -v apk &> /dev/null; then
        apk add openssh
    else
        echo "Не удалось определить пакетный менеджер. Установите SSH вручную."
        exit 1
    fi
fi

# Настройка SSH-сервера
if [ -f /etc/ssh/sshd_config ]; then
    # Делаем резервную копию
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Настраиваем SSH для разрешения входа по паролю
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    
    # Добавляем пользователя в группу sudo/wheel если она существует
    if getent group sudo &>/dev/null; then
        usermod -aG sudo "$new_username"
        echo "Пользователь $new_username добавлен в группу sudo."
    elif getent group wheel &>/dev/null; then
        usermod -aG wheel "$new_username"
        echo "Пользователь $new_username добавлен в группу wheel."
    fi
    
    # Перезапуск SSH-сервиса
    if systemctl is-active sshd &>/dev/null; then
        systemctl restart sshd
    elif service ssh status &>/dev/null; then
        service ssh restart
    else
        echo "Не удалось перезапустить SSH-сервис. Сделайте это вручную."
    fi
    
    # Включение SSH-сервиса при загрузке
    if command -v systemctl &> /dev/null; then
        systemctl enable sshd
    fi
    
    # Получение текущего IP-адреса
    current_ip=$(hostname -I | awk '{print $1}')
    
    echo -e "\n=== Настройка завершена ==="
    echo "SSH настроен для пользователя $new_username"
    echo "Информация для подключения по SSH:"
    echo "IP-адрес: $current_ip"
    echo "Пользователь: $new_username"
    echo "Порт: 22 (стандартный)"
    echo "Команда для подключения: ssh $new_username@$current_ip"
else
    echo "Файл конфигурации SSH не найден. Убедитесь, что SSH установлен корректно."
fi

# Проверка состояния брандмауэра
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
    echo -e "\n[5] Настройка брандмауэра (ufw)"
    ufw allow ssh
    echo "Добавлено правило в ufw для разрешения SSH."
elif command -v firewall-cmd &> /dev/null && firewall-cmd --state | grep -q "running"; then
    echo -e "\n[5] Настройка брандмауэра (firewalld)"
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload
    echo "Добавлено правило в firewalld для разрешения SSH."
fi

echo -e "\nНастройка успешно завершена!"
exit 0
## BSCRIPT_END:/root/scripts/SET_USER_PASSWORD.sh

## BSCRIPT_START:/root/scripts/SET_SSH_IP.sh
display_script_header "/root/scripts/SET_SSH_IP.sh"


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
## BSCRIPT_END:/root/scripts/SET_SSH_IP.sh

