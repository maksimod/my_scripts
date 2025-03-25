#!/bin/bash

# Цвета для улучшения визуализации
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Файл для хранения метаданных композитного скрипта
METADATA_FILE=".bash_constructor_metadata"

# Функция для проверки валидности имени скрипта
validate_script_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Ошибка: Имя скрипта должно содержать только буквы, цифры, подчеркивания и дефисы.${NC}"
        return 1
    fi
    return 0
}

# Функция для отображения списка скриптов с нумерацией
display_scripts() {
    local scripts=("$@")
    echo -e "${BLUE}Текущие скрипты в последовательности:${NC}"
    for i in "${!scripts[@]}"; do
        echo "$((i+1)). ${scripts[i]}"
    done
}

# Функция для создания композитного скрипта с метаданными
create_composer_script() {
    local scripts=("$@")
    
    # Запрос имени итогового скрипта
    while true; do
        read -p "Введите имя итогового объединенного скрипта (без расширения): " final_script_name
        
        if validate_script_name "$final_script_name"; then
            break
        fi
    done
    
    local output_script="${final_script_name}.sh"
    
    # Создание итогового скрипта
    echo "#!/bin/bash" > "$output_script"
    echo "" >> "$output_script"
    echo "# Автоматически сгенерированный композитный скрипт" >> "$output_script"
    echo "# Дата создания: $(date)" >> "$output_script"
    echo "" >> "$output_script"
    
    # Сохранение метаданных
    printf '%s\n' "${scripts[@]}" > "$METADATA_FILE"
    
    # Добавление скриптов в порядке, указанном пользователем
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            echo "# Начало скрипта: $script" >> "$output_script"
            echo "echo -e \"${YELLOW}Выполнение скрипта: $script${NC}\"" >> "$output_script"
            echo "" >> "$output_script"
            
            # Копирование содержимого скрипта, исключая первую строку шебанга
            tail -n +2 "$script" >> "$output_script"
            
            echo "" >> "$output_script"
            echo "# Конец скрипта: $script" >> "$output_script"
            echo "" >> "$output_script"
        else
            echo -e "${RED}Внимание: Скрипт $script не найден!${NC}"
        fi
    done
    
    # Установка прав на выполнение
    chmod +x "$output_script"
    
    echo -e "${GREEN}Создан композитный скрипт: $output_script${NC}"
}

# Функция для редактирования композитного скрипта
edit_composer_script() {
    # Проверка существования метаданных
    if [[ ! -f "$METADATA_FILE" ]]; then
        echo -e "${RED}Ошибка: Нет существующего композитного скрипта для редактирования.${NC}"
        return 1
    fi
    
    # Чтение текущих скриптов
    mapfile -t current_scripts < "$METADATA_FILE"
    
    while true; do
        clear
        echo -e "${BLUE}===== Редактирование композитного скрипта =====${NC}"
        display_scripts "${current_scripts[@]}"
        
        echo -e "\nВыберите действие:"
        echo "1. Удалить скрипт"
        echo "2. Вставить скрипт"
        echo "3. Заменить скрипт"
        echo "4. Завершить редактирование"
        
        read -p "Введите номер опции: " edit_choice
        
        case "$edit_choice" in
            1)  # Удаление скрипта
                read -p "Введите номер скрипта для удаления: " delete_num
                if [[ "$delete_num" -ge 1 ]] && [[ "$delete_num" -le "${#current_scripts[@]}" ]]; then
                    unset "current_scripts[$((delete_num-1))]"
                    current_scripts=("${current_scripts[@]}")
                    echo -e "${GREEN}Скрипт удален.${NC}"
                else
                    echo -e "${RED}Некорректный номер скрипта.${NC}"
                fi
                ;;
            
            2)  # Вставка скрипта
                read -p "Введите номер позиции для вставки (после текущего скрипта): " insert_pos
                read -p "Введите имя скрипта для вставки: " insert_script
                
                if [[ -f "$insert_script" ]] && 
                   [[ "$insert_pos" -ge 0 ]] && 
                   [[ "$insert_pos" -le "${#current_scripts[@]}" ]]; then
                    current_scripts=("${current_scripts[@]:0:$insert_pos}" "$insert_script" "${current_scripts[@]:$insert_pos}")
                    echo -e "${GREEN}Скрипт вставлен.${NC}"
                else
                    echo -e "${RED}Ошибка: Некорректное имя скрипта или позиция.${NC}"
                fi
                ;;
            
            3)  # Замена скрипта
                read -p "Введите номер скрипта для замены: " replace_num
                read -p "Введите имя нового скрипта: " replace_script
                
                if [[ -f "$replace_script" ]] && 
                   [[ "$replace_num" -ge 1 ]] && 
                   [[ "$replace_num" -le "${#current_scripts[@]}" ]]; then
                    current_scripts[$((replace_num-1))]="$replace_script"
                    echo -e "${GREEN}Скрипт заменен.${NC}"
                else
                    echo -e "${RED}Ошибка: Некорректное имя скрипта или позиция.${NC}"
                fi
                ;;
            
            4)  # Завершение редактирования
                # Обновляем файл метаданных и пересоздаем композитный скрипт
                printf '%s\n' "${current_scripts[@]}" > "$METADATA_FILE"
                create_composer_script "${current_scripts[@]}"
                break
                ;;
            
            *)
                echo -e "${RED}Некорректный выбор. Попробуйте снова.${NC}"
                ;;
        esac
        
        read -p "Нажмите Enter для продолжения..." pause
    done
}

# Основная функция меню
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}=========== Конструктор Bash Скриптов ===========${NC}"
        echo "1. Создать новый композитный скрипт"
        echo "2. Редактировать существующий композитный скрипт"
        echo "3. Выход"
        
        read -p "Выберите действие (1-3): " menu_choice
        
        case "$menu_choice" in
            1)  # Создание нового скрипта
                clear
                selected_scripts=()
                while true; do
                    echo "Доступные bash-скрипты:"
                    scripts=(*.sh)
                    for i in "${!scripts[@]}"; do
                        echo "$((i+1)). ${scripts[i]}"
                    done
                    
                    read -p "Введите номер скрипта для добавления (или 'готово' для завершения): " choice
                    
                    if [[ "$choice" == "готово" || "$choice" == "g" ]]; then
                        break
                    fi
                    
                    if [[ "$choice" =~ ^[0-9]+$ ]] && 
                       [[ "$choice" -ge 1 ]] && 
                       [[ "$choice" -le "${#scripts[@]}" ]]; then
                        selected_script="${scripts[$((choice-1))]}"
                        
                        if [[ " ${selected_scripts[*]} " != *" $selected_script "* ]]; then
                            selected_scripts+=("$selected_script")
                            echo -e "${GREEN}Добавлен скрипт: $selected_script${NC}"
                        else
                            echo -e "${RED}Скрипт $selected_script уже добавлен!${NC}"
                        fi
                    else
                        echo -e "${RED}Некорректный выбор. Попробуйте снова.${NC}"
                    fi
                done
                
                if [[ ${#selected_scripts[@]} -gt 0 ]]; then
                    create_composer_script "${selected_scripts[@]}"
                else
                    echo -e "${YELLOW}Не выбрано ни одного скрипта.${NC}"
                fi
                ;;
            
            2)  # Редактирование существующего скрипта
                edit_composer_script
                ;;
            
            3)  # Выход
                echo -e "${YELLOW}Завершение работы...${NC}"
                exit 0
                ;;
            
            *)
                echo -e "${RED}Некорректный выбор. Попробуйте снова.${NC}"
                ;;
        esac
        
        read -p "Нажмите Enter для продолжения..." pause
    done
}

# Запуск основной функции меню
main_menu