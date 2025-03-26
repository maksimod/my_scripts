#!/bin/bash

# Минимальный скрипт мониторинга системы
# Фокус на стабильность и отсутствие синтаксических ошибок

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Переменные для меню
SELECTED=0
TOTAL_OPTIONS=2
EXIT_REQUESTED=0

# Функция для получения списка дисков
get_disks() {
    lsblk -d -o NAME | grep -v "loop\|sr\|fd" | tail -n +2
}

# Функция для получения модели диска
get_disk_model() {
    local disk="$1"
    local model=""
    
    # Используем smartctl для получения модели
    model=$(smartctl -i /dev/"$disk" 2>/dev/null | grep -E "Device Model|Product|Model Number" | head -1 | cut -d ":" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    
    if [ -z "$model" ]; then
        model="Неизвестно"
    fi
    
    echo "$model"
}

# Функция для получения температуры диска
get_disk_temp() {
    local disk="$1"
    local temp=""
    
    # Используем smartctl для получения температуры
    temp=$(smartctl -A /dev/"$disk" 2>/dev/null | grep -i "194 Temperature" | awk '{print $10}')
    
    if [ -z "$temp" ]; then
        echo "Н/Д"
    else
        echo "$temp"
    fi
}

# Функция для определения здоровья диска
get_disk_health() {
    local disk="$1"
    local health=""
    local health_status=""
    
    # Получаем статус SMART
    local smart_status=$(smartctl -H /dev/"$disk" 2>/dev/null | grep -i "SMART overall-health" | awk -F": " '{print $2}')
    
    if [ -z "$smart_status" ]; then
        health="Н/Д"
        health_status="Неизвестно"
    elif [ "$smart_status" = "PASSED" ]; then
        # Проверяем наличие переназначенных секторов
        local reallocated=$(smartctl -A /dev/"$disk" 2>/dev/null | grep "Reallocated_Sector" | awk '{print $10}')
        local pending=$(smartctl -A /dev/"$disk" 2>/dev/null | grep "Current_Pending_Sector" | awk '{print $10}')
        
        if [ -z "$reallocated" ] || [ "$reallocated" = "0" ]; then
            if [ -z "$pending" ] || [ "$pending" = "0" ]; then
                health="100"
                health_status="Отлично"
            else
                health="80"
                health_status="Хорошо (ожидающие сектора)"
            fi
        else
            health="70"
            health_status="Нормально (переназначенные сектора)"
        fi
    else
        health="50"
        health_status="Проблема"
    fi
    
    echo "$health|$health_status"
}

# Функция для получения загрузки CPU
get_cpu_usage() {
    # Получаем загрузку CPU через top
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print int(100 - $1)}'
}

# Функция мониторинга системы
monitor_system() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             МОНИТОРИНГ СИСТЕМЫ В РЕАЛЬНОМ ВРЕМЕНИ          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GRAY}Для выхода нажмите Ctrl+C${NC}\n"
    
    # Счетчик времени
    SECONDS=0
    
    # Обработка сигнала Ctrl+C
    trap "return 0" INT TERM
    
    while true; do
        # Получение текущего времени
        current_time=$(date "+%H:%M:%S")
        uptime_seconds=$SECONDS
        uptime_formatted=$(printf "%02d:%02d:%02d" $((uptime_seconds/3600)) $((uptime_seconds%3600/60)) $((uptime_seconds%60)))
        
        # Очистка экрана с сохранением заголовка
        tput cup 4 0
        tput ed
        
        echo -e "${BLUE}Время: ${GREEN}$current_time${BLUE} | Время работы: ${GREEN}$uptime_formatted${NC}\n"
        
        # CPU информация
        cpu_usage=$(get_cpu_usage)
        
        echo -e "${PURPLE}═══ ПРОЦЕССОР ════════════════════════════════════════════${NC}"
        
        # Цветовая индикация
        if [ "$cpu_usage" -lt 50 ]; then
            cpu_color=$GREEN
        elif [ "$cpu_usage" -lt 80 ]; then
            cpu_color=$YELLOW
        else
            cpu_color=$RED
        fi
        
        echo -e "${YELLOW}Общая загрузка ЦП: ${cpu_color}${cpu_usage}%${NC}"
        
        # CPU температура
        if command -v sensors >/dev/null 2>&1; then
            cpu_temp=$(sensors | grep -i 'Core\|Package\|Tdie' | grep ':' | sed 's/[+°C]//g')
            
            if [ ! -z "$cpu_temp" ]; then
                echo -e "${YELLOW}Температура ЦП:${NC}"
                echo "$cpu_temp" | while read line; do
                    temp=$(echo $line | awk '{print $3}' | cut -d'.' -f1)
                    sensor_name=$(echo $line | awk '{print $1 " " $2}')
                    
                    # Цветовая индикация
                    if [ "$temp" -lt 50 ]; then
                        color=$GREEN
                    elif [ "$temp" -lt 70 ]; then
                        color=$YELLOW
                    else
                        color=$RED
                    fi
                    
                    printf "  %-20s: %s%3d°C%s\n" "$sensor_name" "$color" "$temp" "$NC"
                done
            else
                echo -e "${RED}Данные о температуре процессора недоступны${NC}"
            fi
        else
            echo -e "${RED}Данные о температуре процессора недоступны${NC}"
        fi
        echo ""
        
        # Память
        memory_info=$(free -h | grep Mem)
        memory_total=$(echo $memory_info | awk '{print $2}')
        memory_used=$(echo $memory_info | awk '{print $3}')
        memory_percentage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
        
        echo -e "${PURPLE}═══ ПАМЯТЬ ═══════════════════════════════════════════════${NC}"
        if [ "$memory_percentage" -lt 50 ]; then
            memory_color=$GREEN
        elif [ "$memory_percentage" -lt 80 ]; then
            memory_color=$YELLOW
        else
            memory_color=$RED
        fi
        echo -e "${YELLOW}Использование памяти: ${memory_color}$memory_used${YELLOW} из ${GREEN}$memory_total ${memory_color}(${memory_percentage}%)${NC}"
        echo ""
        
        # Диски
        echo -e "${PURPLE}═══ ДИСКИ ════════════════════════════════════════════════${NC}"
        
        disks=$(get_disks)
        
        if [ -z "$disks" ]; then
            echo -e "${RED}Не обнаружено физических дисков${NC}"
        else
            echo "$disks" | while read disk; do
                disk_model=$(get_disk_model "$disk")
                disk_temp=$(get_disk_temp "$disk")
                disk_health_data=$(get_disk_health "$disk")
                disk_health_num=$(echo "$disk_health_data" | cut -d'|' -f1)
                disk_health_info=$(echo "$disk_health_data" | cut -d'|' -f2)
                
                echo -e "${YELLOW}/dev/$disk ${BLUE}(${disk_model})${YELLOW}:"
                
                # Вывод здоровья диска
                if [ "$disk_health_num" != "Н/Д" ]; then
                    if [ "$disk_health_num" -ge 90 ]; then
                        health_color=$GREEN
                    elif [ "$disk_health_num" -ge 70 ]; then
                        health_color=$YELLOW
                    else
                        health_color=$RED
                    fi
                    echo -e "  Здоровье: ${health_color}${disk_health_num}% ${NC}(${disk_health_info})"
                else
                    echo -e "  Здоровье: ${GRAY}Н/Д${NC}"
                fi
                
                # Вывод температуры
                if [ "$disk_temp" != "Н/Д" ]; then
                    if [ "$disk_temp" -lt 35 ]; then
                        disk_temp_color=$GREEN
                    elif [ "$disk_temp" -lt 50 ]; then
                        disk_temp_color=$YELLOW
                    else
                        disk_temp_color=$RED
                    fi
                    echo -e "  Температура: ${disk_temp_color}${disk_temp}°C${NC}"
                else
                    echo -e "  Температура: ${GRAY}Н/Д${NC}"
                fi
            done
        fi
        
        # Пауза
        sleep 2
    done
}

# Функция проверки здоровья дисков
check_disks() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  ПРОВЕРКА ЗДОРОВЬЯ ДИСКОВ                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GRAY}Сканирование дисков... Это может занять несколько секунд.${NC}\n"
    
    disks=$(get_disks)
    
    if [ -z "$disks" ]; then
        echo -e "${RED}Не обнаружено физических дисков${NC}"
        echo -e "${GRAY}Нажмите Enter для возврата в меню...${NC}"
        read
        return
    fi
    
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}   ДИСК     │     МОДЕЛЬ     │  СОСТОЯНИЕ  │  ЗДОРОВЬЕ  │  ТЕМП.  ${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
    
    echo "$disks" | while read disk; do
        disk_model=$(get_disk_model "$disk")
        disk_model="${disk_model:0:14}" # Ограничиваем для вывода
        
        disk_temp=$(get_disk_temp "$disk")
        disk_health_data=$(get_disk_health "$disk")
        disk_health_num=$(echo "$disk_health_data" | cut -d'|' -f1)
        disk_health_info=$(echo "$disk_health_data" | cut -d'|' -f2)
        
        # Определяем состояние диска
        if [ "$disk_health_num" = "Н/Д" ]; then
            disk_status="Неизвестно"
            status_color=$GRAY
        elif [ "$disk_health_num" -ge 90 ]; then
            disk_status="Отлично"
            status_color=$GREEN
        elif [ "$disk_health_num" -ge 70 ]; then
            disk_status="Хорошо"
            status_color=$GREEN
        else
            disk_status="Проблема"
            status_color=$RED
        fi
        
        # Определяем цвет для здоровья
        if [ "$disk_health_num" = "Н/Д" ]; then
            health_color=$GRAY
            health_display="Н/Д"
        else
            if [ "$disk_health_num" -ge 90 ]; then
                health_color=$GREEN
            elif [ "$disk_health_num" -ge 70 ]; then
                health_color=$YELLOW
            else
                health_color=$RED
            fi
            health_display="${disk_health_num}%"
        fi
        
        # Определяем цвет для температуры
        if [ "$disk_temp" != "Н/Д" ]; then
            if [ "$disk_temp" -lt 35 ]; then
                temp_color=$GREEN
            elif [ "$disk_temp" -lt 50 ]; then
                temp_color=$YELLOW
            else
                temp_color=$RED
            fi
            disk_temp="${disk_temp}°C"
        else
            temp_color=$GRAY
            disk_temp="Н/Д"
        fi
        
        # Вывод информации
        printf " ${BOLD}%-10s${NC} │ %-14s │ ${status_color}%-11s${NC} │ ${health_color}%-10s${NC} │ ${temp_color}%-7s${NC}\n" \
            "$disk" "$disk_model" "$disk_status" "$health_display" "$disk_temp"
    done
    
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Детальная информация о дисках:${NC}"
    
    echo "$disks" | while read disk; do
        echo -e "\n${CYAN}=== Информация о диске /dev/$disk ===${NC}"
        
        if command -v smartctl >/dev/null 2>&1; then
            smartctl -a /dev/"$disk" 2>/dev/null
        else
            echo "${GRAY}Нет доступных инструментов для диагностики${NC}"
        fi
    done
    
    echo -e "\n${GRAY}Нажмите Enter для возврата в меню...${NC}"
    read
}

# Функция отображения меню
show_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          СИСТЕМА МОНИТОРИНГА ЗДОРОВЬЯ КОМПЬЮТЕРА           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GRAY}Используйте стрелки ↑ ↓ для выбора и Enter для подтверждения${NC}\n"
    
    MENU_OPTIONS=("Мониторинг в реальном времени" "Проверка здоровья дисков")
    
    for i in $(seq 0 $((TOTAL_OPTIONS - 1))); do
        if [ $i -eq $SELECTED ]; then
            echo -e "${GREEN}> ${BOLD}$(($i + 1)). ${MENU_OPTIONS[$i]}${NC}"
        else
            echo -e "  $(($i + 1)). ${MENU_OPTIONS[$i]}"
        fi
    done
    
    # Пункт выхода
    if [ $SELECTED -eq $TOTAL_OPTIONS ]; then
        echo -e "${GREEN}> ${BOLD}$(($TOTAL_OPTIONS + 1)). Выход${NC}"
    else
        echo -e "  $(($TOTAL_OPTIONS + 1)). Выход"
    fi
}

# Основная функция
main() {
    # Проверка на root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Этот скрипт должен быть запущен с правами root!${NC}"
        echo "Выполните: sudo bash $0"
        exit 1
    fi
    
    # Проверка наличия необходимых утилит
    if ! command -v smartctl >/dev/null 2>&1; then
        echo -e "${YELLOW}Утилита smartctl не найдена. Рекомендуется установить пакет smartmontools.${NC}"
        echo -e "${YELLOW}Выполните: apt-get install smartmontools${NC}"
        echo -e "${GRAY}Нажмите Enter для продолжения...${NC}"
        read
    fi
    
    # Цикл меню
    while [ $EXIT_REQUESTED -eq 0 ]; do
        show_menu
        
        # Обработка ввода
        read -rsn1 key
        
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            
            if [[ $key == "[A" ]]; then  # Стрелка вверх
                if [ $SELECTED -gt 0 ]; then
                    SELECTED=$((SELECTED - 1))
                else
                    SELECTED=$TOTAL_OPTIONS
                fi
            elif [[ $key == "[B" ]]; then  # Стрелка вниз
                if [ $SELECTED -lt $TOTAL_OPTIONS ]; then
                    SELECTED=$((SELECTED + 1))
                else
                    SELECTED=0
                fi
            fi
        elif [[ $key == "" ]]; then  # Enter
            if [ $SELECTED -eq 0 ]; then
                monitor_system
            elif [ $SELECTED -eq 1 ]; then
                check_disks
            elif [ $SELECTED -eq $TOTAL_OPTIONS ]; then
                EXIT_REQUESTED=1
            fi
        fi
    done
    
    clear
    echo -e "${GREEN}Спасибо за использование системы мониторинга!${NC}"
    exit 0
}

# Запуск
main