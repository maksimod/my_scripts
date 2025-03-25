#!/bin/bash

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