#!/bin/bash

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