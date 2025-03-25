#!/bin/bash

# Автоматически сгенерированный композитный скрипт
# Дата создания: Tue Mar 25 11:13:30 AM UTC 2025

# Начало скрипта: INSTALL_SUDO.sh
echo -e "\033[1;33mВыполнение скрипта: INSTALL_SUDO.sh\033[0m"


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
# Конец скрипта: INSTALL_SUDO.sh

# Начало скрипта: CLIENT_INSTALL.sh
echo -e "\033[1;33mВыполнение скрипта: CLIENT_INSTALL.sh\033[0m"

#
# Script to install development tools (Git, Node.js, Python3, npm) on Debian
# Run as root (sudo)

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root (sudo)!"
    exit 1
fi

echo "Начинаем установку инструментов разработки (Git, Node.js, Python3, npm)..."

# Update package lists
echo "Обновление списка пакетов..."
apt-get update

# Install Git
echo "Установка Git..."
apt-get install -y git

# Check Git installation
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    echo "✅ Git успешно установлен: $GIT_VERSION"
else
    echo "❌ Ошибка: Git не установлен!"
fi

# Install Python3 and pip
echo "Установка Python3 и pip..."
apt-get install -y python3 python3-pip

# Check Python installation
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "✅ Python3 успешно установлен: $PYTHON_VERSION"
else
    echo "❌ Ошибка: Python3 не установлен!"
fi

# Install Node.js and npm using NodeSource repository
echo "Установка Node.js и npm..."

# Add NodeSource repository (latest LTS version)
if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
    echo "Добавление репозитория NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
fi

# Install Node.js (npm will be installed as a dependency)
apt-get install -y nodejs

# Check Node.js and npm installation
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo "✅ Node.js успешно установлен: $NODE_VERSION"
else
    echo "❌ Ошибка: Node.js не установлен!"
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    echo "✅ npm успешно установлен: $NPM_VERSION"
else
    echo "❌ Ошибка: npm не установлен!"
fi

# Install development tools
echo "Установка дополнительных инструментов разработки..."
apt-get install -y build-essential

echo "Установка завершена!"
echo ""
echo "Установленные версии:"
echo "--------------------"
[ -x "$(command -v git)" ] && echo "Git: $(git --version)"
[ -x "$(command -v python3)" ] && echo "Python: $(python3 --version)"
[ -x "$(command -v pip3)" ] && echo "pip: $(pip3 --version | awk '{print $2}')"
[ -x "$(command -v node)" ] && echo "Node.js: $(node --version)"
[ -x "$(command -v npm)" ] && echo "npm: $(npm --version)"
# Конец скрипта: CLIENT_INSTALL.sh

# Начало скрипта: DOWNLOAD_IQBANANA_DRIVE.sh
echo -e "\033[1;33mВыполнение скрипта: DOWNLOAD_IQBANANA_DRIVE.sh\033[0m"

#
# Script to set up Git credentials and clone the iqbanana_space_disk repository
# This script sets the Git username to "Maksimod" and email to "maksumonka@gmail.com"
# and then clones the repository into the current directory

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Настройка учетных данных Git и клонирование репозитория...${NC}"

# Check if Git is installed
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Git не установлен. Устанавливаем Git...${NC}"
    sudo apt-get update
    sudo apt-get install -y git
    
    if [ $? -ne 0 ]; then
        echo "Не удалось установить Git. Пожалуйста, установите Git вручную и запустите скрипт снова."
        exit 1
    fi
fi

# Set Git global configuration for username and email
echo -e "${BLUE}Настройка имени пользователя и почты для Git...${NC}"
git config --global user.name "Maksimod"
git config --global user.email "maksumonka@gmail.com"

# Check if config was set correctly
GIT_NAME=$(git config --global user.name)
GIT_EMAIL=$(git config --global user.email)

if [ "$GIT_NAME" = "Maksimod" ] && [ "$GIT_EMAIL" = "maksumonka@gmail.com" ]; then
    echo -e "${GREEN}Git настроен успешно:${NC}"
    echo -e "Имя: ${GREEN}$GIT_NAME${NC}"
    echo -e "Почта: ${GREEN}$GIT_EMAIL${NC}"
else
    echo "Не удалось настроить учетные данные Git."
    exit 1
fi

# Define repository URL
REPO_URL="https://github.com/maksimod/iqbanana_space_disk"
REPO_NAME="iqbanana_space_disk"

# Check if the repository directory already exists
if [ -d "$REPO_NAME" ]; then
    echo -e "${YELLOW}Папка '$REPO_NAME' уже существует. Проверяем, является ли она Git-репозиторием...${NC}"
    
    if [ -d "$REPO_NAME/.git" ]; then
        echo -e "${YELLOW}Репозиторий уже склонирован. Обновляем до последней версии...${NC}"
        cd "$REPO_NAME"
        git pull
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Репозиторий успешно обновлен.${NC}"
        else
            echo "Не удалось обновить репозиторий."
            exit 1
        fi
    else
        echo -e "${YELLOW}Папка '$REPO_NAME' существует, но не является Git-репозиторием.${NC}"
        echo -e "${YELLOW}Переименовываем существующую папку и клонируем репозиторий...${NC}"
        
        # Rename existing directory with timestamp
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        mv "$REPO_NAME" "${REPO_NAME}_backup_${TIMESTAMP}"
        
        # Clone the repository
        git clone "$REPO_URL"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Репозиторий успешно склонирован.${NC}"
            echo -e "${YELLOW}Предыдущая папка была переименована в '${REPO_NAME}_backup_${TIMESTAMP}'${NC}"
        else
            echo "Не удалось склонировать репозиторий."
            exit 1
        fi
    fi
else
    # Clone the repository since the directory doesn't exist
    echo -e "${BLUE}Клонирование репозитория $REPO_URL...${NC}"
    git clone "$REPO_URL"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Репозиторий успешно склонирован в папку $REPO_NAME${NC}"
    else
        echo "Не удалось склонировать репозиторий."
        exit 1
    fi
fi

echo -e "${GREEN}Все операции успешно выполнены!${NC}"
echo -e "${BLUE}Учетные данные Git настроены:${NC}"
echo -e "Имя: ${GREEN}$GIT_NAME${NC}"
echo -e "Почта: ${GREEN}$GIT_EMAIL${NC}"
echo -e "${BLUE}Репозиторий находится в папке:${NC} ${GREEN}$REPO_NAME${NC}"
# Конец скрипта: DOWNLOAD_IQBANANA_DRIVE.sh

# Начало скрипта: TURN_OFF_HIB.sh
echo -e "\033[1;33mВыполнение скрипта: TURN_OFF_HIB.sh\033[0m"

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
# Конец скрипта: TURN_OFF_HIB.sh

# Начало скрипта: SYSTEM_SET.sh
echo -e "\033[1;33mВыполнение скрипта: SYSTEM_SET.sh\033[0m"


# Проверка прав root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root!"
    echo "Выполните: sudo bash $0"
    exit 1
fi

# Функция для смены root-пароля
change_root_password() {
    while true; do
        echo "Смена пароля root:"
        passwd root
        if [ $? -eq 0 ]; then
            echo "Пароль root успешно изменен."
            break
        else
            echo "Ошибка смены пароля. Попробуйте снова."
        fi
    done
}

# Функция для смены имени пользователя
change_username() {
    # Список текущих пользователей (кроме root и системных)
    CURRENT_USERS=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/passwd)
    
    echo "Текущие пользователи:"
    echo "$CURRENT_USERS"
    
    read -p "Введите текущее имя пользователя: " old_username
    
    # Проверка существования пользователя
    if ! id "$old_username" &>/dev/null; then
        echo "Пользователь $old_username не существует!"
        return 1
    fi
    
    read -p "Введите новое имя пользователя: " new_username
    
    # Проверка существования нового имени
    if id "$new_username" &>/dev/null; then
        echo "Пользователь $new_username уже существует!"
        return 1
    fi
    
    # Смена имени пользователя
    usermod -l "$new_username" "$old_username"
    
    # Смена домашней директории
    usermod -d "/home/$new_username" -m "$new_username"
    
    echo "Имя пользователя изменено с $old_username на $new_username"
}

# Функция для смены пароля пользователя
change_user_password() {
    read -p "Введите имя пользователя: " username
    
    # Проверка существования пользователя
    if ! id "$username" &>/dev/null; then
        echo "Пользователь $username не существует!"
        return 1
    fi
    
    while true; do
        echo "Смена пароля для пользователя $username:"
        passwd "$username"
        if [ $? -eq 0 ]; then
            echo "Пароль пользователя $username успешно изменен."
            break
        else
            echo "Ошибка смены пароля. Попробуйте снова."
        fi
    done
}

# Функция для настройки статического IP
setup_static_ip() {
    # Проверяем, существует ли скрипт из предыдущего документа
    if [ ! -f /root/set_ip.sh ]; then
        # Копируем скрипт в /root, если его нет
        cat > /root/set_ip.sh << 'EOFIP'
#!/bin/bash
#
# БЕЗОПАСНЫЙ скрипт настройки статического IP
# Не разрывает текущее SSH-соединение
# Применяет настройки только при перезагрузке
#

# Проверка root прав
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root!"
    echo "Выполните: sudo bash $0"
    exit 1
fi

# Найдем сетевой интерфейс
IFACE=$(ip -o link show | grep -v lo | grep 'state UP' | awk -F': ' '{print $2}' | head -n 1)
if [ -z "$IFACE" ]; then
    IFACE=$(ip -o link show | grep -v lo | head -n 1 | awk -F': ' '{print $2}')
fi

echo "Настройка статического IP на интерфейсе: $IFACE"

# Получаем текущий IP для значений по умолчанию
CURRENT_IP=$(ip -4 addr show $IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP="192.168.0.104"
fi

CURRENT_GATEWAY=$(ip route | grep default | awk '{print $3}')
if [ -z "$CURRENT_GATEWAY" ]; then
    CURRENT_GATEWAY="192.168.0.1"
fi

# Запрашиваем параметры с дефолтными значениями
echo -n "Введите IP-адрес (например, 192.168.0.104) [$CURRENT_IP]: "
read -r IP_INPUT
IP_ADDR=${IP_INPUT:-$CURRENT_IP}

echo -n "Введите маску подсети (например, 255.255.255.0) [255.255.255.0]: "
read -r MASK_INPUT
NETMASK=${MASK_INPUT:-"255.255.255.0"}

echo -n "Введите шлюз по умолчанию (например, 192.168.0.1) [$CURRENT_GATEWAY]: "
read -r GATEWAY_INPUT
GATEWAY=${GATEWAY_INPUT:-$CURRENT_GATEWAY}

# Создаем резервные копии файлов
echo "Создание резервных копий..."
mkdir -p /root/network_backup
cp /etc/network/interfaces /root/network_backup/interfaces.backup.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
cp /etc/resolv.conf /root/network_backup/resolv.conf.backup.$(date +%Y%m%d%H%M%S) 2>/dev/null || true

# Создаем новый файл interfaces
echo "Подготовка файла /etc/network/interfaces..."
cat > /etc/network/interfaces.new << EOF
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $IP_ADDR
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers 8.8.8.8 8.8.4.4
EOF

# Создаем скрипт, который будет выполняться при загрузке
echo "Создание скрипта автозапуска..."
cat > /etc/network/apply-static-ip.sh << EOFA
#!/bin/bash
# Скрипт применения статического IP при загрузке

# Остановка NetworkManager (если установлен)
systemctl stop NetworkManager 2>/dev/null || true
systemctl disable NetworkManager 2>/dev/null || true

# Копирование подготовленных файлов
cp /etc/network/interfaces.new /etc/network/interfaces

# Настройка DNS
cat > /etc/resolv.conf << ENDDNS
nameserver 8.8.8.8
nameserver 8.8.4.4
ENDDNS

# Применение настроек
ifdown $IFACE 2>/dev/null || true
sleep 2
ifup $IFACE 2>/dev/null || true

# Резервный способ на случай отказа ifup/ifdown
ip link set $IFACE down
ip link set $IFACE up
ip addr flush dev $IFACE
ip addr add $IP_ADDR/$NETMASK dev $IFACE
ip route add default via $GATEWAY dev $IFACE

exit 0
EOFA

chmod +x /etc/network/apply-static-ip.sh

# Настройка автозапуска
echo "Настройка автозапуска..."
if [ ! -f /etc/rc.local ]; then
    echo '#!/bin/bash' > /etc/rc.local
    echo 'exit 0' >> /etc/rc.local
    chmod +x /etc/rc.local
fi

# Удалим предыдущие записи нашего скрипта, если они есть
sed -i '/apply-static-ip/d' /etc/rc.local
# Добавим новую запись
sed -i '/exit 0/i /etc/network/apply-static-ip.sh' /etc/rc.local

echo
echo "====== ПОДГОТОВКА ЗАВЕРШЕНА ======"
echo "Настройки статического IP подготовлены, но НЕ ПРИМЕНЕНЫ!"
echo "IP: $IP_ADDR"
echo "Маска: $NETMASK"
echo "Шлюз: $GATEWAY"
echo "DNS: 8.8.8.8, 8.8.4.4"
echo
echo "Настройки будут применены после перезагрузки."
echo "Текущее соединение SSH не будет разорвано."
echo
echo -n "Перезагрузить сейчас? (y/n) [n]: "
read -r answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Перезагрузка через 5 секунд..."
    echo "Подключитесь после перезагрузки к новому IP: $IP_ADDR"
    sleep 5
    reboot
else
    echo "Когда будете готовы, выполните: sudo reboot"
    echo "После перезагрузки подключитесь к новому IP: $IP_ADDR"
fi
EOFIP

    chmod +x /root/set_ip.sh
    fi

    # Запуск скрипта настройки статического IP
    bash /root/set_ip.sh
}

# Главное меню
while true; do
    clear
    echo "===== МЕНЮ НАСТРОЙКИ СИСТЕМЫ ====="
    echo "1. Сменить пароль root"
    echo "2. Сменить имя пользователя"
    echo "3. Сменить пароль пользователя"
    echo "4. Настроить статический IP"
    echo "5. Выйти"
    
    read -p "Выберите действие (1-5): " choice
    
    case $choice in
        1) change_root_password ;;
        2) change_username ;;
        3) change_user_password ;;
        4) setup_static_ip ;;
        5) 
            echo "Выход..."
            exit 0
            ;;
        *) 
            echo "Неверный выбор. Нажмите Enter для продолжения..."
            read
            ;;
    esac
    
    echo -n "Нажмите Enter для возврата в меню..."
    read
done
# Конец скрипта: SYSTEM_SET.sh

