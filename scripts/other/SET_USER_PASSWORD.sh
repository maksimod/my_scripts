#!/bin/bash

# Скрипт для изменения пароля root, имени пользователя и пароля пользователя
# Требуются права суперпользователя для выполнения

# Проверка на запуск с правами суперпользователя
if [ "$(id -u)" -ne 0 ]; then
   echo "Этот скрипт должен быть запущен с правами суперпользователя (sudo)."
   exit 1
fi

# Функция для подтверждения действия
confirm() {
    read -p "$1 (д/н): " response
    case "$response" in
        [дДyY]* ) return 0;;
        * ) return 1;;
    esac
}

# Изменение пароля root
change_root_password() {
    if confirm "Хотите изменить пароль пользователя root?"; then
        echo "Введите новый пароль для root:"
        passwd root
        echo "Пароль root успешно изменен."
    else
        echo "Изменение пароля root отменено."
    fi
}

# Изменение имени пользователя
change_username() {
    read -p "Введите текущее имя пользователя, которое нужно изменить: " current_user
    
    # Проверка существования пользователя
    if id "$current_user" &>/dev/null; then
        read -p "Введите новое имя пользователя: " new_username
        
        # Проверка не занято ли новое имя
        if id "$new_username" &>/dev/null; then
            echo "Пользователь с именем $new_username уже существует. Выберите другое имя."
            return 1
        fi
        
        if confirm "Вы уверены, что хотите изменить имя пользователя $current_user на $new_username?"; then
            # Получение домашнего каталога пользователя
            user_home=$(eval echo ~$current_user)
            
            # Создание нового пользователя
            usermod -l "$new_username" "$current_user"
            
            # Переименование группы, если она существует и названа так же, как пользователь
            if getent group "$current_user" &>/dev/null; then
                groupmod -n "$new_username" "$current_user"
            fi
            
            # Изменение домашнего каталога
            usermod -d "/home/$new_username" -m "$new_username"
            
            echo "Имя пользователя успешно изменено с $current_user на $new_username."
        else
            echo "Изменение имени пользователя отменено."
        fi
    else
        echo "Пользователь $current_user не существует."
    fi
}

# Изменение пароля пользователя
change_user_password() {
    read -p "Введите имя пользователя, для которого нужно изменить пароль: " username
    
    # Проверка существования пользователя
    if id "$username" &>/dev/null; then
        if confirm "Вы уверены, что хотите изменить пароль для пользователя $username?"; then
            echo "Введите новый пароль для пользователя $username:"
            passwd "$username"
            echo "Пароль для пользователя $username успешно изменен."
        else
            echo "Изменение пароля отменено."
        fi
    else
        echo "Пользователь $username не существует."
    fi
}

# Основное меню
echo "===== Управление пользователями Ubuntu ====="
echo "Этот скрипт позволяет изменить:"
echo "1. Пароль пользователя root"
echo "2. Имя существующего пользователя"
echo "3. Пароль существующего пользователя"
echo "4. Выполнить все три операции"
echo "5. Выход"

read -p "Выберите опцию (1-5): " option

case $option in
    1)
        change_root_password
        ;;
    2)
        change_username
        ;;
    3)
        change_user_password
        ;;
    4)
        change_root_password
        change_username
        change_user_password
        ;;
    5)
        echo "Выход из программы."
        exit 0
        ;;
    *)
        echo "Неверная опция. Выход из программы."
        exit 1
        ;;
esac

echo "Операции завершены."