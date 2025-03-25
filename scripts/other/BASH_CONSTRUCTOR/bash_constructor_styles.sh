#!/bin/bash

# Файл с визуальными элементами и константами для конструктора скриптов

# Цвета для улучшения визуализации
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export PURPLE='\033[0;35m'
export WHITE='\033[1;37m'
export NC='\033[0m'

# Визуальные элементы
export HORIZONTAL_LINE="────────────────────────────────────────────────────"
export BOX_TOP="╭──────────────────────────────────────────────────╮"
export BOX_BOTTOM="╰──────────────────────────────────────────────────╯"
export BOX_SIDE="│"

# Маркеры для использования в скриптах, созданных конструктором
export SCRIPT_START_MARKER="## BSCRIPT_START:"
export SCRIPT_END_MARKER="## BSCRIPT_END:"
export METADATA_MARKER="## BSCRIPT_META"

# Функция для отображения заголовка
display_header() {
    local title="$1"
    clear
    echo -e "${BLUE}${BOX_TOP}${NC}"
    echo -e "${BLUE}${BOX_SIDE}${NC} ${CYAN}${title}${NC}"
    echo -e "${BLUE}${BOX_BOTTOM}${NC}"
    echo ""
}

# Функция для отображения уведомления
display_notification() {
    local message="$1"
    local color="$2"
    
    echo -e "${color}${message}${NC}"
}

# Функция для отображения успешной операции
display_success() {
    local message="$1"
    echo -e "\n${GREEN}✓ ${message}${NC}"
    echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
}

# Функция для отображения ошибки
display_error() {
    local message="$1"
    echo -e "\n${RED}✗ ${message}${NC}"
    echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
}

# Функция для отображения информации
display_info() {
    local message="$1"
    echo -e "\n${YELLOW}ℹ ${message}${NC}"
}

# Функция для запроса подтверждения (да/нет)
confirm_action() {
    local prompt="$1"
    local response
    
    while true; do
        echo -e "${YELLOW}${prompt} ${WHITE}(д/н)${NC}: "
        read -r response
        case "$response" in
            [Дд]|[Yy]) return 0 ;;
            [Нн]|[Nn]) return 1 ;;
            *) echo -e "${RED}Пожалуйста, введите 'д' для да или 'н' для нет.${NC}" ;;
        esac
    done
}

# Функция для отображения меню выбора
display_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    echo -e "${CYAN}${title}${NC}"
    echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
    
    for i in "${!options[@]}"; do
        echo -e "${WHITE}$((i+1)).${NC} ${options[i]}"
    done
    
    echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
}

# Функция для отображения прогресса
display_progress() {
    local message="$1"
    local symbol="⚙"
    echo -ne "${YELLOW}${symbol} ${message}... ${NC}"
}

# Функция завершения прогресса
complete_progress() {
    local success=$1
    local success_message="$2"
    local error_message="$3"
    
    if [[ $success -eq 0 ]]; then
        echo -e "${GREEN}✓ ${success_message}${NC}"
    else
        echo -e "${RED}✗ ${error_message}${NC}"
    fi
}

# Функция для отображения справки
display_help() {
    echo -e "${CYAN}Справка по использованию:${NC}"
    echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
    echo -e "Конструктор Bash Скриптов позволяет легко создавать композитные скрипты,"
    echo -e "объединяя несколько существующих скриптов в один исполняемый файл."
    echo -e "\n${WHITE}Основные возможности:${NC}"
    echo -e "• Создание нового композитного скрипта"
    echo -e "• Редактирование существующего композитного скрипта"
    echo -e "• Просмотр информации о скрипте"
    echo -e "\n${WHITE}Советы:${NC}"
    echo -e "• Все скрипты должны быть исполняемыми (.sh)"
    echo -e "• Вы можете изменять порядок, добавлять или удалять скрипты"
    echo -e "• Метаданные хранятся внутри самого скрипта для удобства управления"
    echo -e "${BLUE}${HORIZONTAL_LINE}${NC}"
}

# Функция анимации загрузки
display_loading() {
    local message="$1"
    local duration=${2:-2}  # Длительность в секундах, по умолчанию 2
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    
    for (( i=0; i<duration*10; i++ )); do
        local char="${chars:i%10:1}"
        echo -ne "\r${CYAN}${char} ${message}...${NC}"
        sleep 0.1
    done
    echo -ne "\r${GREEN}✓ ${message} завершено!${NC}\n"
}

# Функция для ожидания нажатия клавиши
wait_for_keypress() {
    local message="${1:-Нажмите любую клавишу для продолжения...}"
    echo -e "\n${YELLOW}${message}${NC}"
    read -n 1 -s
}