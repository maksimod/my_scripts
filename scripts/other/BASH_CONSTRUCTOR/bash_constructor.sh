#!/bin/bash

# Конструктор Bash Скриптов - Улучшенная версия
# Автор: Профессиональный DevOps разработчик
# Дата: 25.03.2025

# Определение пути к скрипту и директории стилей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
STYLES_PATH="$SCRIPT_DIR/bash_constructor_styles.sh"

# Установка рабочей директории в родительскую
WORKING_DIR="$PARENT_DIR"

# Подключение файла со стилями
if [[ -f "$STYLES_PATH" ]]; then
    source "$STYLES_PATH"
else
    echo "Ошибка: Файл стилей не найден в $STYLES_PATH"
    exit 1
fi

# Функция для проверки валидности имени скрипта
validate_script_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        display_error "Имя скрипта должно содержать только буквы, цифры, подчеркивания и дефисы."
        return 1
    fi
    return 0
}

# Функция для отображения списка скриптов с нумерацией
display_scripts() {
    local scripts=("$@")
    if [[ ${#scripts[@]} -eq 0 ]]; then
        display_info "Нет выбранных скриптов."
        return
    fi
    
    echo -e "${CYAN}Текущие скрипты в последовательности:${NC}"
    echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
    for i in "${!scripts[@]}"; do
        echo -e "${WHITE}$((i+1)).${NC} ${scripts[i]}"
    done
    echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
}

# Функция для получения всех доступных скриптов
get_available_scripts() {
    local exclude_pattern="$SCRIPT_DIR"
    find "$WORKING_DIR" -maxdepth 1 -name "*.sh" | while read -r script; do
        # Пропускаем скрипты из директории конструктора
        if [[ "$script" != "$exclude_pattern"* && -f "$script" ]]; then
            echo "$script"
        fi
    done
}

# Функция для извлечения метаданных из скрипта
extract_metadata_from_script() {
    local script_path="$1"
    local scripts=()
    
    if [[ ! -f "$script_path" ]]; then
        display_error "Скрипт $script_path не найден!"
        return 1
    fi
    
    # Проверяем, был ли скрипт создан нашим конструктором
    if ! grep -q "$METADATA_MARKER" "$script_path"; then
        display_error "Скрипт $script_path не был создан конструктором скриптов."
        return 1
    fi
    
    # Извлекаем список скриптов
    while IFS= read -r line; do
        if [[ "$line" =~ $SCRIPT_START_MARKER(.+) ]]; then
            scripts+=("${BASH_REMATCH[1]}")
        fi
    done < "$script_path"
    
    printf '%s\n' "${scripts[@]}"
    return 0
}

# Функция для проверки, является ли скрипт композитным
is_composite_script() {
    local script_path="$1"
    
    if [[ ! -f "$script_path" ]]; then
        return 1
    fi
    
    if grep -q "$METADATA_MARKER" "$script_path"; then
        return 0
    else
        return 1
    fi
}

# Функция для создания композитного скрипта с метаданными
create_composer_script() {
    local scripts=("$@")
    
    if [[ ${#scripts[@]} -eq 0 ]]; then
        display_error "Не выбрано ни одного скрипта для создания композитного скрипта."
        return 1
    fi
    
    # Запрос имени итогового скрипта
    while true; do
        echo -e "${CYAN}Введите имя итогового объединенного скрипта ${WHITE}(без расширения)${NC}: "
        read -r final_script_name
        
        if validate_script_name "$final_script_name"; then
            break
        fi
    done
    
    # Сохраняем в родительской директории
    local output_script="$WORKING_DIR/${final_script_name}.sh"
    
    # Проверка на существование файла
    if [[ -f "$output_script" ]]; then
        if ! confirm_action "Файл $output_script уже существует. Перезаписать?"; then
            display_info "Операция отменена."
            return 1
        fi
    fi
    
    display_progress "Создание композитного скрипта"
    
    # Создание итогового скрипта
    cat << EOF > "$output_script"
#!/bin/bash

# Автоматически сгенерированный композитный скрипт
# Дата создания: $(date)
# $METADATA_MARKER

# Настройка цветов
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функция для отображения заголовка скрипта
display_script_header() {
    echo -e "\${BLUE}================================================\${NC}"
    echo -e "\${GREEN}Выполнение скрипта: \$1\${NC}"
    echo -e "\${BLUE}================================================\${NC}"
}

EOF
    
    # Добавление скриптов в порядке, указанном пользователем
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            echo "$SCRIPT_START_MARKER$script" >> "$output_script"
            echo "display_script_header \"$script\"" >> "$output_script"
            echo "" >> "$output_script"
            
            # Копирование содержимого скрипта, исключая первую строку шебанга
            tail -n +2 "$script" >> "$output_script"
            
            echo "" >> "$output_script"
            echo "$SCRIPT_END_MARKER$script" >> "$output_script"
            echo "" >> "$output_script"
        else
            display_error "Скрипт $script не найден!"
        fi
    done
    
    # Установка прав на выполнение
    chmod +x "$output_script"
    
    complete_progress 0 "Создан композитный скрипт: $output_script" "Ошибка при создании скрипта"
    return 0
}

# Функция для поиска композитных скриптов в текущей директории
find_composite_scripts() {
    local composite_scripts=()
    
    for script in "$WORKING_DIR"/*.sh; do
        if [[ -f "$script" ]] && grep -q "$METADATA_MARKER" "$script"; then
            composite_scripts+=("$script")
        fi
    done
    
    printf '%s\n' "${composite_scripts[@]}"
}

# Функция для удаления дубликатов из массива
remove_duplicates() {
    local -n array="$1"
    local -A seen
    local -a unique_array
    
    for item in "${array[@]}"; do
        if [[ -z "${seen[$item]}" ]]; then
            seen[$item]=1
            unique_array+=("$item")
        fi
    done
    
    array=("${unique_array[@]}")
}

# Функция для редактирования композитного скрипта
edit_composer_script() {
    local script_to_edit="$1"
    local tmp_file
    
    # Если скрипт не указан, предлагаем выбрать из списка
    if [[ -z "$script_to_edit" ]]; then
        mapfile -t available_scripts < <(find_composite_scripts)
        
        if [[ ${#available_scripts[@]} -eq 0 ]]; then
            display_error "Не найдено композитных скриптов для редактирования."
            return 1
        fi
        
        display_header "Редактирование композитного скрипта"
        display_menu "Доступные композитные скрипты:" "${available_scripts[@]}"
        
        while true; do
            echo -e "${CYAN}Выберите скрипт для редактирования ${WHITE}(1-${#available_scripts[@]})${NC}: "
            read -r script_num
            
            if [[ "$script_num" =~ ^[0-9]+$ ]] && 
               [[ "$script_num" -ge 1 ]] && 
               [[ "$script_num" -le "${#available_scripts[@]}" ]]; then
                script_to_edit="${available_scripts[$((script_num-1))]}"
                break
            else
                display_error "Некорректный выбор. Попробуйте снова."
            fi
        done
    fi
    
    # Проверка, является ли выбранный скрипт композитным
    if ! is_composite_script "$script_to_edit"; then
        display_error "Скрипт $script_to_edit не является композитным скриптом или не найден."
        return 1
    fi
    
    # Извлечение текущих скриптов
    mapfile -t current_scripts < <(extract_metadata_from_script "$script_to_edit")
    
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Создание временного файла
    tmp_file=$(mktemp)
    
    while true; do
        display_header "Редактирование скрипта: $script_to_edit"
        display_scripts "${current_scripts[@]}"
        
        display_menu "Выберите действие:" \
            "Удалить скрипт" \
            "Вставить скрипт" \
            "Заменить скрипт" \
            "Изменить порядок скриптов" \
            "Сохранить изменения" \
            "Отменить редактирование"
        
        echo -e "${CYAN}Выберите действие ${WHITE}(1-6)${NC}: "
        read -r edit_choice
        
        case "$edit_choice" in
            1)  # Удаление скрипта
                if [[ ${#current_scripts[@]} -eq 0 ]]; then
                    display_error "Нет скриптов для удаления."
                    wait_for_keypress
                    continue
                fi
                
                echo -e "${CYAN}Введите номер скрипта для удаления ${WHITE}(1-${#current_scripts[@]})${NC}: "
                read -r delete_num
                
                if [[ "$delete_num" =~ ^[0-9]+$ ]] && 
                   [[ "$delete_num" -ge 1 ]] && 
                   [[ "$delete_num" -le "${#current_scripts[@]}" ]]; then
                    removed_script="${current_scripts[$((delete_num-1))]}"
                    unset "current_scripts[$((delete_num-1))]"
                    current_scripts=("${current_scripts[@]}")
                    display_success "Скрипт $removed_script удален."
                else
                    display_error "Некорректный номер скрипта."
                fi
                ;;
            
            2)  # Вставка скрипта
                # Отображение доступных скриптов для вставки
                echo -e "${CYAN}Доступные скрипты:${NC}"
                echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
                
                # Получение списка всех .sh файлов, кроме самого конструктора
                declare -a filtered_scripts
                for script in "$WORKING_DIR"/*.sh; do
                    # Пропускаем скрипты из директории конструктора
                    if [[ "$script" == "$SCRIPT_DIR"* ]]; then
                        continue
                    fi
                    
                    # Проверяем, не является ли скрипт композитным
                    if ! is_composite_script "$script"; then
                        filtered_scripts+=("$script")
                    fi
                done
                
                # Удаляем дубликаты
                remove_duplicates filtered_scripts
                
                # Если нет доступных скриптов, сообщаем об этом
                if [[ ${#filtered_scripts[@]} -eq 0 ]]; then
                    echo -e "${YELLOW}Нет доступных скриптов для вставки.${NC}"
                    wait_for_keypress
                    continue
                fi
                
                # Выводим отфильтрованные скрипты
                for i in "${!filtered_scripts[@]}"; do
                    echo -e "${WHITE}$((i+1)).${NC} ${filtered_scripts[i]}"
                done
                
                echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
                echo -e "${CYAN}Введите номер скрипта для вставки ${WHITE}(1-${#filtered_scripts[@]})${NC}: "
                read -r insert_script_num
                
                if [[ "$insert_script_num" =~ ^[0-9]+$ ]] && 
                   [[ "$insert_script_num" -ge 1 ]] && 
                   [[ "$insert_script_num" -le "${#filtered_scripts[@]}" ]]; then
                    insert_script="${filtered_scripts[$((insert_script_num-1))]}"
                    
                    # Проверка, не является ли выбранный скрипт композитным
                    if is_composite_script "$insert_script"; then
                        display_error "Нельзя вставить композитный скрипт в другой композитный скрипт."
                        wait_for_keypress
                        continue
                    fi
                    
                    if [[ ! -f "$insert_script" ]]; then
                        display_error "Скрипт $insert_script не найден."
                        wait_for_keypress
                        continue
                    fi
                    
                    if [[ ${#current_scripts[@]} -eq 0 ]]; then
                        # Если список пуст, просто добавляем
                        current_scripts=("$insert_script")
                        display_success "Скрипт $insert_script добавлен."
                    else
                        # Запрос позиции для вставки
                        echo -e "${CYAN}Введите позицию для вставки ${WHITE}(0-${#current_scripts[@]}, 0 - в начало)${NC}: "
                        read -r insert_pos
                        
                        if [[ "$insert_pos" =~ ^[0-9]+$ ]] && 
                           [[ "$insert_pos" -ge 0 ]] && 
                           [[ "$insert_pos" -le "${#current_scripts[@]}" ]]; then
                            # Вставка скрипта в указанную позицию
                            current_scripts=("${current_scripts[@]:0:$insert_pos}" "$insert_script" "${current_scripts[@]:$insert_pos}")
                            display_success "Скрипт $insert_script вставлен в позицию $insert_pos."
                        else
                            display_error "Некорректная позиция для вставки."
                        fi
                    fi
                else
                    display_error "Некорректный номер скрипта."
                fi
                ;;
            
            3)  # Замена скрипта
                if [[ ${#current_scripts[@]} -eq 0 ]]; then
                    display_error "Нет скриптов для замены."
                    wait_for_keypress
                    continue
                fi
                
                echo -e "${CYAN}Введите номер скрипта для замены ${WHITE}(1-${#current_scripts[@]})${NC}: "
                read -r replace_num
                
                if [[ "$replace_num" =~ ^[0-9]+$ ]] && 
                   [[ "$replace_num" -ge 1 ]] && 
                   [[ "$replace_num" -le "${#current_scripts[@]}" ]]; then
                    # Получение списка всех .sh файлов, кроме самого конструктора
                    declare -a filtered_scripts
                    for script in "$WORKING_DIR"/*.sh; do
                        # Пропускаем скрипты из директории конструктора
                        if [[ "$script" == "$SCRIPT_DIR"* ]]; then
                            continue
                        fi
                        
                        # Проверяем, не является ли скрипт композитным
                        if ! is_composite_script "$script"; then
                            filtered_scripts+=("$script")
                        fi
                    done
                    
                    # Удаляем дубликаты
                    remove_duplicates filtered_scripts
                    
                    # Если нет доступных скриптов, сообщаем об этом
                    if [[ ${#filtered_scripts[@]} -eq 0 ]]; then
                        echo -e "${YELLOW}Нет доступных скриптов для замены.${NC}"
                        wait_for_keypress
                        continue
                    fi
                    
                    # Выводим отфильтрованные скрипты
                    for i in "${!filtered_scripts[@]}"; do
                        echo -e "${WHITE}$((i+1)).${NC} ${filtered_scripts[i]}"
                    done
                    
                    echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
                    echo -e "${CYAN}Введите номер нового скрипта ${WHITE}(1-${#filtered_scripts[@]})${NC}: "
                    read -r new_script_num
                    
                    if [[ "$new_script_num" =~ ^[0-9]+$ ]] && 
                       [[ "$new_script_num" -ge 1 ]] && 
                       [[ "$new_script_num" -le "${#filtered_scripts[@]}" ]]; then
                        replace_script="${filtered_scripts[$((new_script_num-1))]}"
                        
                        # Проверка, не является ли выбранный скрипт композитным
                        if is_composite_script "$replace_script"; then
                            display_error "Нельзя заменить на композитный скрипт."
                            wait_for_keypress
                            continue
                        fi
                        
                        if [[ -f "$replace_script" ]]; then
                            old_script="${current_scripts[$((replace_num-1))]}"
                            current_scripts[$((replace_num-1))]="$replace_script"
                            display_success "Скрипт $old_script заменен на $replace_script."
                        else
                            display_error "Скрипт $replace_script не найден."
                        fi
                    else
                        display_error "Некорректный номер нового скрипта."
                    fi
                else
                    display_error "Некорректный номер скрипта для замены."
                fi
                ;;
            
            4)  # Изменение порядка скриптов
                if [[ ${#current_scripts[@]} -lt 2 ]]; then
                    display_error "Недостаточно скриптов для изменения порядка."
                    wait_for_keypress
                    continue
                fi
                
                echo -e "${CYAN}Введите номер скрипта для перемещения ${WHITE}(1-${#current_scripts[@]})${NC}: "
                read -r move_num
                
                if [[ "$move_num" =~ ^[0-9]+$ ]] && 
                   [[ "$move_num" -ge 1 ]] && 
                   [[ "$move_num" -le "${#current_scripts[@]}" ]]; then
                    echo -e "${CYAN}Введите новую позицию ${WHITE}(1-${#current_scripts[@]})${NC}: "
                    read -r new_pos
                    
                    if [[ "$new_pos" =~ ^[0-9]+$ ]] && 
                       [[ "$new_pos" -ge 1 ]] && 
                       [[ "$new_pos" -le "${#current_scripts[@]}" ]] && 
                       [[ "$new_pos" -ne "$move_num" ]]; then
                        # Сохраняем скрипт для перемещения
                        moving_script="${current_scripts[$((move_num-1))]}"
                        
                        # Удаляем скрипт из текущей позиции
                        unset "current_scripts[$((move_num-1))]"
                        current_scripts=("${current_scripts[@]}")
                        
                        # Вставляем скрипт в новую позицию
                        new_pos_adjusted=$((new_pos-1))
                        current_scripts=("${current_scripts[@]:0:$new_pos_adjusted}" "$moving_script" "${current_scripts[@]:$new_pos_adjusted}")
                        
                        display_success "Скрипт $moving_script перемещен с позиции $move_num на позицию $new_pos."
                    else
                        display_error "Некорректная новая позиция."
                    fi
                else
                    display_error "Некорректный номер скрипта для перемещения."
                fi
                ;;
            
            5)  # Сохранение изменений
                if [[ ${#current_scripts[@]} -eq 0 ]]; then
                    display_error "Нет скриптов для сохранения. Композитный скрипт должен содержать хотя бы один скрипт."
                    wait_for_keypress
                    continue
                fi
                
                display_progress "Пересоздание композитного скрипта"
                # Получаем имя файла без расширения
                script_name="${script_to_edit%.sh}"
                script_basename="$(basename "$script_name")"
                
                # Переименовываем текущий скрипт в бэкап, если пользователь согласен
                if [[ -f "$script_to_edit" ]]; then
                    # Бэкап сохраняем в папке конструктора
                    backup_file="$SCRIPT_DIR/${script_basename}.bak"
                    if confirm_action "Создать резервную копию текущего скрипта как $backup_file?"; then
                        cp "$script_to_edit" "$backup_file"
                        display_info "Создана резервная копия: $backup_file"
                    fi
                fi
                
                # Пересоздаем скрипт с текущим набором скриптов
                if create_composer_script "${current_scripts[@]}"; then
                    # Переименовываем созданный скрипт в исходное имя
                    mv "$WORKING_DIR/${script_basename}.sh" "$tmp_file"
                    mv "$tmp_file" "$script_to_edit"
                    chmod +x "$script_to_edit"
                    
                    display_success "Скрипт $script_to_edit успешно обновлен."
                    break
                else
                    display_error "Ошибка при обновлении скрипта."
                fi
                ;;
            
            6)  # Отмена редактирования
                if confirm_action "Вы уверены, что хотите отменить все изменения?"; then
                    display_info "Редактирование отменено."
                    rm -f "$tmp_file"
                    return 1
                fi
                ;;
            
            *)
                display_error "Некорректный выбор. Попробуйте снова."
                ;;
        esac
        
        wait_for_keypress
    done
    
    # Очистка
    rm -f "$tmp_file"
    return 0
}

# Функция для просмотра информации о скрипте
view_script_info() {
    display_header "Просмотр информации о скрипте"
    
    # Получаем список композитных скриптов
    mapfile -t composite_scripts < <(find_composite_scripts)
    
    if [[ ${#composite_scripts[@]} -eq 0 ]]; then
        display_error "Не найдено композитных скриптов."
        return 1
    fi
    
    display_menu "Доступные композитные скрипты:" "${composite_scripts[@]}"
    
    echo -e "${CYAN}Выберите скрипт для просмотра ${WHITE}(1-${#composite_scripts[@]})${NC}: "
    read -r script_num
    
    if [[ "$script_num" =~ ^[0-9]+$ ]] && 
       [[ "$script_num" -ge 1 ]] && 
       [[ "$script_num" -le "${#composite_scripts[@]}" ]]; then
        script_to_view="${composite_scripts[$((script_num-1))]}"
        
        display_header "Информация о скрипте: $script_to_view"
        
        # Извлечение и отображение метаданных
        mapfile -t scripts_in_composite < <(extract_metadata_from_script "$script_to_view")
        
        echo -e "${CYAN}Дата создания:${NC}"
        grep -m 1 "Дата создания:" "$script_to_view" | sed 's/# Дата создания: //'
        
        echo -e "\n${CYAN}Количество включенных скриптов:${NC} ${#scripts_in_composite[@]}"
        
        echo -e "\n${CYAN}Список включенных скриптов:${NC}"
        echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
        for i in "${!scripts_in_composite[@]}"; do
            echo -e "${WHITE}$((i+1)).${NC} ${scripts_in_composite[i]}"
        done
        echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
        
        # Размер файла
        size=$(stat -c %s "$script_to_view")
        human_size=$(numfmt --to=iec --suffix=B "$size")
        echo -e "\n${CYAN}Размер файла:${NC} $human_size ($size байт)"
        
        # Права доступа
        permissions=$(stat -c %A "$script_to_view")
        echo -e "${CYAN}Права доступа:${NC} $permissions"
    else
        display_error "Некорректный номер скрипта."
    fi
}

# Функция для быстрого просмотра скрипта
quick_view_script() {
    display_header "Быстрый просмотр скрипта"
    
    # Получаем список всех скриптов
    available_scripts=("$WORKING_DIR"/*.sh)
    
    display_menu "Доступные скрипты:" "${available_scripts[@]}"
    
    echo -e "${CYAN}Выберите скрипт для просмотра ${WHITE}(1-${#available_scripts[@]})${NC}: "
    read -r script_num
    
    if [[ "$script_num" =~ ^[0-9]+$ ]] && 
       [[ "$script_num" -ge 1 ]] && 
       [[ "$script_num" -le "${#available_scripts[@]}" ]]; then
        script_to_view="${available_scripts[$((script_num-1))]}"
        
        display_header "Содержимое скрипта: $script_to_view"
        
        # Проверка наличия программы для подсветки синтаксиса
        if command -v bat &> /dev/null; then
            bat --style=plain --language=bash "$script_to_view"
        elif command -v highlight &> /dev/null; then
            highlight -O ansi "$script_to_view"
        else
            # Простой просмотр с номерами строк
            nl -ba "$script_to_view"
        fi
    else
        display_error "Некорректный номер скрипта."
    fi
}

# Основная функция меню
main_menu() {
    while true; do
        display_header "Конструктор Bash Скриптов v2.0"
        
        display_menu "Выберите действие:" \
            "Создать новый композитный скрипт" \
            "Редактировать существующий композитный скрипт" \
            "Просмотреть информацию о скрипте" \
            "Быстрый просмотр скрипта" \
            "Справка" \
            "Выход"
        
        echo -e "${CYAN}Введите номер опции ${WHITE}(1-6)${NC}: "
        read -r menu_choice
        
        case "$menu_choice" in
            1)  # Создание нового скрипта
                display_header "Создание нового композитного скрипта"
                
                # Получаем список всех скриптов, которые не являются композитными и не являются самим конструктором
                declare -a available_scripts
                for script in "$WORKING_DIR"/*.sh; do
                    # Пропускаем скрипты из директории конструктора
                    if [[ "$script" == "$SCRIPT_DIR"* ]]; then
                        continue
                    fi
                    
                    if [[ -f "$script" ]] && ! is_composite_script "$script"; then
                        available_scripts+=("$script")
                    fi
                done
                
                # Удаляем дубликаты
                remove_duplicates available_scripts
                
                if [[ ${#available_scripts[@]} -eq 0 ]]; then
                    display_error "Нет доступных скриптов для создания композитного скрипта."
                    wait_for_keypress
                    continue
                fi
                
                selected_scripts=()
                
                while true; do
                    display_header "Выбор скриптов для композитного скрипта"
                    display_scripts "${selected_scripts[@]}"
                    
                    display_menu "Доступные скрипты:" "${available_scripts[@]}"
                    echo -e "${YELLOW}Введите номер скрипта для добавления, 'г' для завершения выбора, 'о' для отмены:${NC} "
                    read -r choice
                    
                    if [[ "$choice" =~ ^[Гг]$ ]]; then
                        break
                    fi
                    
                    if [[ "$choice" =~ ^[Оо]$ ]]; then
                        display_info "Операция отменена."
                        selected_scripts=()
                        break
                    fi
                    
                    if [[ "$choice" =~ ^[0-9]+$ ]] && 
                       [[ "$choice" -ge 1 ]] && 
                       [[ "$choice" -le "${#available_scripts[@]}" ]]; then
                        selected_script="${available_scripts[$((choice-1))]}"
                        
                        # Проверяем, не добавлен ли скрипт уже
                        if [[ " ${selected_scripts[*]} " == *" $selected_script "* ]]; then
                            display_error "Скрипт $selected_script уже добавлен!"
                        else
                            selected_scripts+=("$selected_script")
                            display_success "Добавлен скрипт: $selected_script"
                        fi
                    else
                        display_error "Некорректный выбор. Попробуйте снова."
                    fi
                done
                
                if [[ ${#selected_scripts[@]} -gt 0 ]]; then
                    create_composer_script "${selected_scripts[@]}"
                fi
                ;;
            
            2)  # Редактирование существующего скрипта
                edit_composer_script
                ;;
            
            3)  # Просмотр информации о скрипте
                view_script_info
                ;;
                
            4)  # Быстрый просмотр скрипта
                quick_view_script
                ;;
                
            5)  # Справка
                display_help
                ;;
                
            6)  # Выход
                display_loading "Завершение работы" 1
                exit 0
                ;;
            
            *)
                display_error "Некорректный выбор. Попробуйте снова."
                ;;
        esac
        
        wait_for_keypress
    done
}

# Проверка наличия хотя бы одного подходящего скрипта в директории
has_valid_scripts=false
for script in "$WORKING_DIR"/*.sh; do
    if [[ -f "$script" && "$script" != "$(basename "${BASH_SOURCE[0]}")" && "$script" != "bash_constructor_styles.sh" ]]; then
        has_valid_scripts=true
        break
    fi
done

if ! $has_valid_scripts; then
    display_error "В текущей директории не найдено подходящих bash-скриптов (.sh)."
    echo -e "${YELLOW}Убедитесь, что в директории есть скрипты, отличные от конструктора.${NC}"
    exit 1
fi

# Вывод приветствия
display_loading "Запуск Конструктора Bash Скриптов" 1

# Запуск основной функции меню
main_menu