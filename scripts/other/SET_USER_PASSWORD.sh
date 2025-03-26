#!/bin/bash

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