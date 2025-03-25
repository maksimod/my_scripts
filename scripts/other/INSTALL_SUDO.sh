#!/bin/bash

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