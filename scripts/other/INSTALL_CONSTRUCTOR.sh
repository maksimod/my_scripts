#!/bin/bash

# Конструктор установочных скриптов
# Автор: Claude
# Дата: 26.03.2025

SCRIPTS_DIR="./installation_scripts"

# Создаем директорию для скриптов, если она не существует
mkdir -p "$SCRIPTS_DIR"

# Функция для очистки экрана
clear_screen() {
    clear
}

# Функция для отображения заголовка
show_header() {
    echo "============================================"
    echo "      КОНСТРУКТОР УСТАНОВОЧНЫХ СКРИПТОВ     "
    echo "============================================"
    echo ""
}

# Функция для создания нового скрипта
create_new_script() {
    clear_screen
    show_header
    
    echo "Создание нового установочного скрипта"
    echo "-------------------------------------"
    
    # Получаем имя нового скрипта
    read -p "Введите имя для нового скрипта (без расширения): " script_name
    
    # Проверяем, существует ли уже такой скрипт
    if [ -f "$SCRIPTS_DIR/$script_name.sh" ]; then
        echo "Скрипт с таким именем уже существует!"
        read -p "Нажмите Enter, чтобы продолжить..."
        return
    fi
    
    # Создаем временный файл для хранения списка пакетов
    temp_pkg_file=$(mktemp)
    
    echo "Введите пакеты для установки (по одному на строку)."
    echo "Когда закончите, введите 'готово' или нажмите Ctrl+D."
    
    counter=1
    while true; do
        read -p "Пакет #$counter: " package
        
        # Проверяем, закончил ли пользователь ввод
        if [[ "$package" == "готово" ]]; then
            break
        fi
        
        # Если пользователь ввел пустую строку, игнорируем
        if [[ -n "$package" ]]; then
            echo "$package" >> "$temp_pkg_file"
            counter=$((counter + 1))
        fi
    done
    
    # Создаем скрипт
    cat > "$SCRIPTS_DIR/$script_name.sh" << EOF
#!/bin/bash

# Установочный скрипт: $script_name
# Создан: $(date)
# Описание: Автоматически устанавливает необходимые пакеты

# Обновляем информацию о репозиториях
echo "Обновление информации о репозиториях..."
apt-get update

# Устанавливаем пакеты
echo "Установка пакетов..."
EOF
    
    # Добавляем каждый пакет в скрипт
    while read package; do
        echo "apt-get install -y $package" >> "$SCRIPTS_DIR/$script_name.sh"
    done < "$temp_pkg_file"
    
    # Добавляем завершающие строки
    cat >> "$SCRIPTS_DIR/$script_name.sh" << EOF

echo "Установка завершена!"
exit 0
EOF
    
    # Делаем скрипт исполняемым
    chmod +x "$SCRIPTS_DIR/$script_name.sh"
    
    # Удаляем временный файл
    rm "$temp_pkg_file"
    
    echo ""
    echo "Скрипт $script_name.sh успешно создан в директории $SCRIPTS_DIR"
    read -p "Нажмите Enter, чтобы продолжить..."
}

# Функция для извлечения пакетов из скрипта
extract_packages() {
    local script_path="$1"
    
    # Извлекаем только строки с apt-get install
    grep "apt-get install -y" "$script_path" | sed 's/apt-get install -y //'
}

# Функция для редактирования существующего скрипта
edit_existing_script() {
    clear_screen
    show_header
    
    echo "Редактирование существующего скрипта"
    echo "----------------------------------"
    
    # Получаем список доступных скриптов
    scripts=($(ls "$SCRIPTS_DIR"/*.sh 2>/dev/null))
    
    if [ ${#scripts[@]} -eq 0 ]; then
        echo "Скрипты не найдены. Сначала создайте скрипт."
        read -p "Нажмите Enter, чтобы продолжить..."
        return
    fi
    
    echo "Доступные скрипты:"
    echo ""
    
    for i in "${!scripts[@]}"; do
        echo "$((i+1))) $(basename "${scripts[$i]}")"
    done
    
    echo ""
    read -p "Выберите скрипт для редактирования (1-${#scripts[@]}): " script_choice
    
    # Проверяем, что выбор корректный
    if [[ ! "$script_choice" =~ ^[0-9]+$ ]] || [ "$script_choice" -lt 1 ] || [ "$script_choice" -gt ${#scripts[@]} ]; then
        echo "Некорректный выбор!"
        read -p "Нажмите Enter, чтобы продолжить..."
        return
    fi
    
    selected_script="${scripts[$((script_choice-1))]}"
    script_basename=$(basename "$selected_script")
    
    clear_screen
    show_header
    
    echo "Редактирование скрипта: $script_basename"
    echo "-----------------------------------"
    
    # Создаем временный файл для хранения пакетов
    temp_pkg_file=$(mktemp)
    extract_packages "$selected_script" > "$temp_pkg_file"
    
    # Выводим список пакетов
    echo "Текущие пакеты в скрипте:"
    echo ""
    
    packages=()
    while read -r package; do
        packages+=("$package")
    done < "$temp_pkg_file"
    
    for i in "${!packages[@]}"; do
        echo "$((i+1))) ${packages[$i]}"
    done
    
    echo ""
    echo "Что вы хотите сделать?"
    echo "1) Добавить пакет"
    echo "2) Удалить пакет"
    echo "3) Заменить пакет"
    echo "4) Вернуться в главное меню"
    
    read -p "Ваш выбор (1-4): " edit_choice
    
    case "$edit_choice" in
        1) # Добавить пакет
            read -p "Введите имя пакета для добавления: " new_package
            packages+=("$new_package")
            ;;
        2) # Удалить пакет
            if [ ${#packages[@]} -eq 0 ]; then
                echo "Нет пакетов для удаления!"
                read -p "Нажмите Enter, чтобы продолжить..."
                return
            fi
            
            read -p "Введите номер пакета для удаления (1-${#packages[@]}): " del_idx
            
            if [[ ! "$del_idx" =~ ^[0-9]+$ ]] || [ "$del_idx" -lt 1 ] || [ "$del_idx" -gt ${#packages[@]} ]; then
                echo "Некорректный выбор!"
                read -p "Нажмите Enter, чтобы продолжить..."
                return
            fi
            
            unset "packages[$((del_idx-1))]"
            # Перестраиваем массив после удаления элемента
            packages=("${packages[@]}")
            ;;
        3) # Заменить пакет
            if [ ${#packages[@]} -eq 0 ]; then
                echo "Нет пакетов для замены!"
                read -p "Нажмите Enter, чтобы продолжить..."
                return
            fi
            
            read -p "Введите номер пакета для замены (1-${#packages[@]}): " rep_idx
            
            if [[ ! "$rep_idx" =~ ^[0-9]+$ ]] || [ "$rep_idx" -lt 1 ] || [ "$rep_idx" -gt ${#packages[@]} ]; then
                echo "Некорректный выбор!"
                read -p "Нажмите Enter, чтобы продолжить..."
                return
            fi
            
            read -p "Введите новое имя пакета: " new_package
            packages[$((rep_idx-1))]="$new_package"
            ;;
        4) # Возврат в главное меню
            rm "$temp_pkg_file"
            return
            ;;
        *)
            echo "Некорректный выбор!"
            read -p "Нажмите Enter, чтобы продолжить..."
            rm "$temp_pkg_file"
            return
            ;;
    esac
    
    # Обновляем скрипт с новым списком пакетов
    cat > "$selected_script" << EOF
#!/bin/bash

# Установочный скрипт: $script_basename
# Изменен: $(date)
# Описание: Автоматически устанавливает необходимые пакеты

# Обновляем информацию о репозиториях
echo "Обновление информации о репозиториях..."
apt-get update

# Устанавливаем пакеты
echo "Установка пакетов..."
EOF
    
    # Добавляем каждый пакет в скрипт
    for package in "${packages[@]}"; do
        echo "apt-get install -y $package" >> "$selected_script"
    done
    
    # Добавляем завершающие строки
    cat >> "$selected_script" << EOF

echo "Установка завершена!"
exit 0
EOF
    
    echo ""
    echo "Скрипт $script_basename успешно обновлен!"
    read -p "Нажмите Enter, чтобы продолжить..."
    
    # Удаляем временный файл
    rm "$temp_pkg_file"
}

# Главный цикл
while true; do
    clear_screen
    show_header
    
    echo "Главное меню:"
    echo "1) Создать установочный скрипт"
    echo "2) Изменить установочный скрипт"
    echo "3) Выход"
    echo ""
    
    read -p "Выберите действие (1-3): " choice
    
    case "$choice" in
        1)
            create_new_script
            ;;
        2)
            edit_existing_script
            ;;
        3)
            clear_screen
            echo "Спасибо за использование конструктора установочных скриптов!"
            exit 0
            ;;
        *)
            echo "Некорректный выбор. Пожалуйста, выберите 1, 2 или 3."
            read -p "Нажмите Enter, чтобы продолжить..."
            ;;
    esac
done