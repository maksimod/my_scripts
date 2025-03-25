#!/bin/bash

# System Health Monitor
# Интерактивный монитор состояния компьютера с выбором функций

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Переменные для управления меню
SELECTED=0
TOTAL_OPTIONS=2
EXIT_REQUESTED=0

# Функция для отображения анимации загрузки
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Функция для проверки и установки зависимостей
check_dependencies() {
    local packages=("$@")
    local packages_to_install=()
    
    echo -e "${BLUE}${BOLD}Проверка необходимых компонентов...${NC}"
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q $pkg; then
            packages_to_install+=("$pkg")
        fi
    done
    
    if [ ${#packages_to_install[@]} -ne 0 ]; then
        echo -e "${YELLOW}Необходимо установить следующие пакеты: ${packages_to_install[*]}${NC}"
        echo -e "${BLUE}Установка начнется через 3 секунды...${NC}"
        for i in {3..1}; do
            echo -ne "${YELLOW}$i...${NC} "
            sleep 1
        done
        echo ""
        
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                  Установка компонентов                     ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
        
        for pkg in "${packages_to_install[@]}"; do
            echo -ne "${GREEN}Установка ${BOLD}$pkg${NC}${GREEN}...${NC} "
            apt-get install -y $pkg >/dev/null 2>&1 &
            show_spinner $!
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}[УСПЕШНО]${NC}"
            else
                echo -e "${RED}[ОШИБКА]${NC}"
                echo -e "${RED}Не удалось установить $pkg. Пожалуйста, установите его вручную.${NC}"
                read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..."
            fi
        done
        
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                  Установка завершена                       ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
        sleep 1
    else
        echo -e "${GREEN}Все необходимые компоненты уже установлены.${NC}"
        sleep 1
    fi
}

# Функция для проверки наличия утилит мониторинга температуры
check_temp_monitor_tools() {
    check_dependencies "lm-sensors" "hddtemp" "sysstat" "nvme-cli" "inxi" "htop"
    
    # Настраиваем sensors, если еще не настроен
    if ! [ -f /etc/sensors3.conf ] || ! sensors >/dev/null 2>&1; then
        echo -e "${YELLOW}Настраиваем датчики температуры...${NC}"
        yes | sensors-detect >/dev/null 2>&1
    fi
    
    # Убедимся, что демон hddtemp работает
    if ! systemctl is-active --quiet hddtemp; then
        echo -e "${YELLOW}Запускаем сервис мониторинга температуры HDD...${NC}"
        systemctl enable --now hddtemp >/dev/null 2>&1
    fi
}

# Функция для проверки наличия утилит мониторинга здоровья дисков
check_disk_health_tools() {
    check_dependencies "smartmontools" "nvme-cli" "hdparm" "grep" "awk" "util-linux"
    
    # Убедимся, что smartd демон работает
    if ! systemctl is-active --quiet smartd; then
        echo -e "${YELLOW}Запускаем сервис мониторинга S.M.A.R.T...${NC}"
        systemctl enable --now smartd >/dev/null 2>&1
    fi
}

# Функция для мониторинга температуры и нагрузки
monitor_temp_load() {
    check_temp_monitor_tools
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             МОНИТОРИНГ ТЕМПЕРАТУРЫ И НАГРУЗКИ              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GRAY}Для выхода нажмите Ctrl+C${NC}\n"
    
    SECONDS=0
    
    trap 'return 0' INT
    
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
        cpu_temp=$(sensors | grep -i 'Core\|Package\|Tdie' | grep ':' | awk '{print $1 " " $2 " " $3}' | sed 's/[+°C]//g')
        cpu_load=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
        
        echo -e "${PURPLE}═══ ПРОЦЕССОР ════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}Общая загрузка ЦП: ${RED}$cpu_load${NC}"
        
        if [ ! -z "$cpu_temp" ]; then
            echo -e "${YELLOW}Температура ЦП:${NC}"
            while IFS= read -r line; do
                temp=$(echo $line | awk '{print $3}' | cut -d'.' -f1)
                sensor_name=$(echo $line | awk '{print $1 " " $2}')
                
                # Цветовая индикация в зависимости от температуры
                if [ $temp -lt 50 ]; then
                    color=$GREEN
                elif [ $temp -lt 70 ]; then
                    color=$YELLOW
                else
                    color=$RED
                fi
                
                printf "  %-20s: %s%3d°C%s\n" "$sensor_name" "$color" "$temp" "$NC"
            done <<< "$cpu_temp"
        else
            echo -e "${RED}Данные о температуре процессора недоступны${NC}"
        fi
        echo ""
        
        # Загрузка памяти
        memory_info=$(free -h | grep Mem)
        memory_total=$(echo $memory_info | awk '{print $2}')
        memory_used=$(echo $memory_info | awk '{print $3}')
        memory_percentage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
        
        echo -e "${PURPLE}═══ ПАМЯТЬ ═══════════════════════════════════════════════${NC}"
        if [ $memory_percentage -lt 50 ]; then
            memory_color=$GREEN
        elif [ $memory_percentage -lt 80 ]; then
            memory_color=$YELLOW
        else
            memory_color=$RED
        fi
        echo -e "${YELLOW}Использование памяти: ${memory_color}$memory_used${YELLOW} из ${GREEN}$memory_total ${memory_color}(${memory_percentage}%)${NC}"
        echo ""
        
        # GPU информация (если есть)
        gpu_info=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader 2>/dev/null)
        
        if [ ! -z "$gpu_info" ]; then
            echo -e "${PURPLE}═══ ГРАФИЧЕСКИЙ ПРОЦЕССОР ═════════════════════════════════${NC}"
            gpu_temp=$(echo $gpu_info | awk -F', ' '{print $1}')
            gpu_util=$(echo $gpu_info | awk -F', ' '{print $2}' | awk '{print $1}')
            
            # Цветовая индикация для GPU
            if [ $gpu_temp -lt 50 ]; then
                gpu_temp_color=$GREEN
            elif [ $gpu_temp -lt 75 ]; then
                gpu_temp_color=$YELLOW
            else
                gpu_temp_color=$RED
            fi
            
            if [ $gpu_util -lt 50 ]; then
                gpu_util_color=$GREEN
            elif [ $gpu_util -lt 80 ]; then
                gpu_util_color=$YELLOW
            else
                gpu_util_color=$RED
            fi
            
            echo -e "${YELLOW}Температура GPU: ${gpu_temp_color}${gpu_temp}°C${NC}"
            echo -e "${YELLOW}Использование GPU: ${gpu_util_color}${gpu_util}%${NC}"
            echo ""
        fi
        
        # HDD/SSD температура
        echo -e "${PURPLE}═══ ДИСКИ ════════════════════════════════════════════════${NC}"
        
        # Получаем список дисков
        disks=$(lsblk -d -o NAME -n | grep -v "loop\|sr")
        
        if [ -z "$disks" ]; then
            echo -e "${RED}Не обнаружено физических дисков${NC}"
        else
            for disk in $disks; do
                # Смотрим тип диска (NVMe или SATA/HDD)
                if [[ $disk == nvme* ]]; then
                    # NVMe диск
                    nvme_temp=$(nvme smart-log /dev/$disk 2>/dev/null | grep "temperature" | awk '{print $3}')
                    disk_model=$(nvme list | grep $disk | awk '{print $3 " " $4 " " $5}')
                    
                    if [ ! -z "$nvme_temp" ]; then
                        if [ $nvme_temp -lt 40 ]; then
                            disk_temp_color=$GREEN
                        elif [ $nvme_temp -lt 60 ]; then
                            disk_temp_color=$YELLOW
                        else
                            disk_temp_color=$RED
                        fi
                        
                        echo -e "${YELLOW}$disk (${BLUE}$disk_model${YELLOW}): Температура: ${disk_temp_color}${nvme_temp}°C${NC}"
                    else
                        echo -e "${YELLOW}$disk (${BLUE}$disk_model${YELLOW}): ${RED}Температура недоступна${NC}"
                    fi
                else
                    # SATA/HDD диск
                    disk_temp=$(hddtemp /dev/$disk 2>/dev/null | awk -F': ' '{print $3}' | awk '{print $1}')
                    disk_model=$(smartctl -i /dev/$disk 2>/dev/null | grep "Device Model" | awk -F': ' '{print $2}')
                    
                    if [ -z "$disk_model" ]; then
                        disk_model=$(hdparm -I /dev/$disk 2>/dev/null | grep "Model Number" | awk -F': ' '{print $2}')
                    fi
                    
                    # Получаем загрузку диска
                    disk_util=$(iostat -d -x /dev/$disk 1 2 | tail -2 | head -1 | awk '{print $14}')
                    
                    # Цветовое кодирование
                    if [ ! -z "$disk_temp" ]; then
                        disk_temp_number=$(echo $disk_temp | tr -d '°C')
                        
                        if [ $disk_temp_number -lt 35 ]; then
                            disk_temp_color=$GREEN
                        elif [ $disk_temp_number -lt 50 ]; then
                            disk_temp_color=$YELLOW
                        else
                            disk_temp_color=$RED
                        fi
                        
                        echo -e "${YELLOW}$disk (${BLUE}$disk_model${YELLOW}): Температура: ${disk_temp_color}${disk_temp}${NC}, Загрузка: ${CYAN}${disk_util}%${NC}"
                    else
                        echo -e "${YELLOW}$disk (${BLUE}$disk_model${YELLOW}): ${RED}Температура недоступна${NC}, Загрузка: ${CYAN}${disk_util}%${NC}"
                    fi
                fi
            done
        fi
        
        # Пауза перед обновлением
        sleep 2
    done
}

# Функция для проверки здоровья дисков
check_disk_health() {
    check_disk_health_tools
    
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  ПРОВЕРКА ЗДОРОВЬЯ ДИСКОВ                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GRAY}Сканирование дисков... Это может занять несколько секунд.${NC}\n"
    
    # Получаем список дисков
    disks=$(lsblk -d -o NAME -n | grep -v "loop\|sr")
    
    if [ -z "$disks" ]; then
        echo -e "${RED}Не обнаружено физических дисков${NC}"
        echo -e "${GRAY}Нажмите Enter для возврата в меню...${NC}"
        read
        return
    fi
    
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}   ДИСК     │     МОДЕЛЬ     │  СОСТОЯНИЕ  │  ЗДОРОВЬЕ  │  ТЕМП.  ${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
    
    for disk in $disks; do
        disk_model="Неизвестно"
        disk_health="Н/Д"
        disk_status="Неизвестно"
        disk_temp="Н/Д"
        
        # Определяем тип диска (NVMe или SATA/HDD)
        if [[ $disk == nvme* ]]; then
            # NVMe диск
            disk_model=$(nvme list | grep $disk | awk '{print $3 " " $4}')
            nvme_smart=$(nvme smart-log /dev/$disk 2>/dev/null)
            
            if [ ! -z "$nvme_smart" ]; then
                # Проверяем критические предупреждения
                critical_warnings=$(echo "$nvme_smart" | grep "critical_warning" | awk '{print $3}')
                percent_used=$(echo "$nvme_smart" | grep "percentage_used" | awk '{print $3}')
                disk_temp=$(echo "$nvme_smart" | grep "temperature" | awk '{print $3}')
                
                # Если нет значения percentage_used, проверяем media_errors и num_err_log_entries
                if [ -z "$percent_used" ]; then
                    media_errors=$(echo "$nvme_smart" | grep "media_errors" | awk '{print $3}')
                    error_logs=$(echo "$nvme_smart" | grep "num_err_log_entries" | awk '{print $3}')
                    
                    if [ "$media_errors" == "0" ] && [ "$error_logs" == "0" ]; then
                        disk_health="100%"
                        health_color=$GREEN
                    else
                        if [ "$media_errors" -gt 0 ]; then
                            disk_health="Ошибки: $media_errors"
                            health_color=$RED
                        else
                            disk_health="Ошибки журнала: $error_logs"
                            health_color=$YELLOW
                        fi
                    fi
                else
                    # Инвертируем значение (100 - percent_used)
                    disk_health=$((100 - percent_used))"%"
                    
                    if [ $disk_health -ge 90 ]; then
                        health_color=$GREEN
                    elif [ $disk_health -ge 70 ]; then
                        health_color=$YELLOW
                    else
                        health_color=$RED
                    fi
                fi
                
                if [ "$critical_warnings" == "0" ]; then
                    disk_status="Хорошо"
                    status_color=$GREEN
                else
                    disk_status="Предупреждение"
                    status_color=$RED
                fi
            fi
        else
            # SATA/HDD диск
            smart_info=$(smartctl -a /dev/$disk 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                disk_model=$(echo "$smart_info" | grep "Device Model" | awk -F': ' '{print $2}')
                
                if [ -z "$disk_model" ]; then
                    disk_model=$(echo "$smart_info" | grep "Product" | awk -F': ' '{print $2}')
                fi
                
                if [ -z "$disk_model" ]; then
                    disk_model=$(hdparm -I /dev/$disk 2>/dev/null | grep "Model Number" | awk -F': ' '{print $2}')
                fi
                
                # Проверяем состояние SMART
                smart_status=$(echo "$smart_info" | grep -i "SMART overall-health" | awk -F': ' '{print $2}')
                
                if [ -z "$smart_status" ]; then
                    smart_status=$(echo "$smart_info" | grep -i "SMART Health Status" | awk -F': ' '{print $2}')
                fi
                
                # Получаем температуру
                disk_temp=$(echo "$smart_info" | grep -i "Temperature" | head -1 | awk '{print $(NF-1)}')
                
                if [ -z "$disk_temp" ]; then
                    disk_temp=$(hddtemp /dev/$disk 2>/dev/null | awk -F': ' '{print $3}' | awk '{print $1}' | tr -d '°C')
                fi
                
                if [ ! -z "$smart_status" ]; then
                    if [[ $smart_status == *"PASSED"* || $smart_status == *"OK"* ]]; then
                        disk_status="Хорошо"
                        status_color=$GREEN
                    else
                        disk_status="Проблема"
                        status_color=$RED
                    fi
                fi
                
                # Получаем значение Reallocated_Sector_Ct (5) и Current_Pending_Sector (197)
                reallocated=$(echo "$smart_info" | grep -i "Reallocated_Sector_Ct" | awk '{print $10}')
                pending=$(echo "$smart_info" | grep -i "Current_Pending_Sector" | awk '{print $10}')
                
                # Если не можем получить эти значения, ищем общую оценку "health"
                if [ -z "$reallocated" ] || [ -z "$pending" ]; then
                    # Ищем процент "lifetime" или "health"
                    health_percent=$(echo "$smart_info" | grep -i "remaining life" | grep -o '[0-9]\+%' | tr -d '%')
                    
                    if [ -z "$health_percent" ]; then
                        health_percent=$(echo "$smart_info" | grep -i "health" | grep -o '[0-9]\+%' | tr -d '%')
                    fi
                    
                    if [ ! -z "$health_percent" ]; then
                        disk_health="${health_percent}%"
                        
                        if [ $health_percent -ge 90 ]; then
                            health_color=$GREEN
                        elif [ $health_percent -ge 70 ]; then
                            health_color=$YELLOW
                        else
                            health_color=$RED
                        fi
                    else
                        disk_health="Хорошо"
                        health_color=$GREEN
                    fi
                else
                    # Если есть переназначенные сектора или ожидающие переназначения, рассчитываем здоровье
                    if [ "$reallocated" != "0" ] || [ "$pending" != "0" ]; then
                        # Приблизительная оценка здоровья
                        if [ "$reallocated" != "0" ] && [ "$pending" == "0" ]; then
                            disk_health="95%"
                            health_color=$GREEN
                        elif [ "$reallocated" != "0" ] && [ "$pending" != "0" ]; then
                            disk_health="75%"
                            health_color=$YELLOW
                        elif [ "$pending" != "0" ]; then
                            disk_health="60%"
                            health_color=$RED
                        fi
                    else
                        disk_health="100%"
                        health_color=$GREEN
                    fi
                fi
            fi
        fi
        
        # Цветовое кодирование для температуры
        if [ "$disk_temp" != "Н/Д" ]; then
            if [ $disk_temp -lt 35 ]; then
                temp_color=$GREEN
            elif [ $disk_temp -lt 50 ]; then
                temp_color=$YELLOW
            else
                temp_color=$RED
            fi
            disk_temp="${disk_temp}°C"
        else
            temp_color=$GRAY
        fi
        
        # Если статус не определен, используем цвет по умолчанию
        if [ -z "$status_color" ]; then
            status_color=$GRAY
        fi
        
        if [ -z "$health_color" ]; then
            health_color=$GRAY
        fi
        
        # Выводим информацию о диске
        printf " ${BOLD}%-10s${NC} │ %-14s │ ${status_color}%-11s${NC} │ ${health_color}%-10s${NC} │ ${temp_color}%-7s${NC}\n" \
            "$disk" "${disk_model:0:14}" "$disk_status" "$disk_health" "$disk_temp"
    done
    
    echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Подробная информация о здоровье дисков (рекомендуется сохранить):${NC}"
    
    for disk in $disks; do
        echo -e "\n${CYAN}=== Детальная информация о диске /dev/$disk ===${NC}"
        
        if [[ $disk == nvme* ]]; then
            nvme smart-log /dev/$disk 2>/dev/null
        else
            smartctl -a /dev/$disk 2>/dev/null
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
    
    for i in $(seq 0 $((TOTAL_OPTIONS - 1))); do
        if [ $i -eq $SELECTED ]; then
            echo -e "${GREEN}> ${BOLD}$(($i + 1)). ${MENU_OPTIONS[$i]}${NC}"
        else
            echo -e "  $(($i + 1)). ${MENU_OPTIONS[$i]}"
        fi
    done
    
    # Добавляем пункт выхода
    if [ $SELECTED -eq $TOTAL_OPTIONS ]; then
        echo -e "${GREEN}> ${BOLD}$(($TOTAL_OPTIONS + 1)). Выход${NC}"
    else
        echo -e "  $(($TOTAL_OPTIONS + 1)). Выход"
    fi
}

# Главная функция
main() {
    # Проверяем, запущен ли скрипт от имени root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Этот скрипт должен быть запущен с правами root!${NC}"
        echo "Выполните: sudo bash $0"
        exit 1
    fi
    
    # Инициализация меню
    MENU_OPTIONS=("Температура и нагрузка компонентов" "Проверка здоровья дисков")
    
    # Отображение меню и обработка выбора
    while [ $EXIT_REQUESTED -eq 0 ]; do
        show_menu
        
        # Перехват нажатий клавиш
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
                monitor_temp_load
            elif [ $SELECTED -eq 1 ]; then
                check_disk_health
            elif [ $SELECTED -eq $TOTAL_OPTIONS ]; then
                EXIT_REQUESTED=1
            fi
        fi
    done
    
    clear
    echo -e "${GREEN}Спасибо за использование системы мониторинга!${NC}"
    exit 0
}

# Запуск главной функции
main