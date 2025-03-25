#!/bin/bash
#
# Script to set up Git credentials and clone the iqbanana_space_disk repository
# This script sets the Git username to "Maksimod" and email to "maksumonka@gmail.com"
# and then clones the repository into the current directory

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Настройка учетных данных Git и клонирование репозитория...${NC}"

# Check if Git is installed
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Git не установлен. Устанавливаем Git...${NC}"
    sudo apt-get update
    sudo apt-get install -y git
    
    if [ $? -ne 0 ]; then
        echo "Не удалось установить Git. Пожалуйста, установите Git вручную и запустите скрипт снова."
        exit 1
    fi
fi

# Set Git global configuration for username and email
echo -e "${BLUE}Настройка имени пользователя и почты для Git...${NC}"
git config --global user.name "Maksimod"
git config --global user.email "maksumonka@gmail.com"

# Check if config was set correctly
GIT_NAME=$(git config --global user.name)
GIT_EMAIL=$(git config --global user.email)

if [ "$GIT_NAME" = "Maksimod" ] && [ "$GIT_EMAIL" = "maksumonka@gmail.com" ]; then
    echo -e "${GREEN}Git настроен успешно:${NC}"
    echo -e "Имя: ${GREEN}$GIT_NAME${NC}"
    echo -e "Почта: ${GREEN}$GIT_EMAIL${NC}"
else
    echo "Не удалось настроить учетные данные Git."
    exit 1
fi

# Define repository URL
REPO_URL="https://github.com/maksimod/iqbanana_space_disk"
REPO_NAME="iqbanana_space_disk"

# Check if the repository directory already exists
if [ -d "$REPO_NAME" ]; then
    echo -e "${YELLOW}Папка '$REPO_NAME' уже существует. Проверяем, является ли она Git-репозиторием...${NC}"
    
    if [ -d "$REPO_NAME/.git" ]; then
        echo -e "${YELLOW}Репозиторий уже склонирован. Обновляем до последней версии...${NC}"
        cd "$REPO_NAME"
        git pull
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Репозиторий успешно обновлен.${NC}"
        else
            echo "Не удалось обновить репозиторий."
            exit 1
        fi
    else
        echo -e "${YELLOW}Папка '$REPO_NAME' существует, но не является Git-репозиторием.${NC}"
        echo -e "${YELLOW}Переименовываем существующую папку и клонируем репозиторий...${NC}"
        
        # Rename existing directory with timestamp
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        mv "$REPO_NAME" "${REPO_NAME}_backup_${TIMESTAMP}"
        
        # Clone the repository
        git clone "$REPO_URL"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Репозиторий успешно склонирован.${NC}"
            echo -e "${YELLOW}Предыдущая папка была переименована в '${REPO_NAME}_backup_${TIMESTAMP}'${NC}"
        else
            echo "Не удалось склонировать репозиторий."
            exit 1
        fi
    fi
else
    # Clone the repository since the directory doesn't exist
    echo -e "${BLUE}Клонирование репозитория $REPO_URL...${NC}"
    git clone "$REPO_URL"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Репозиторий успешно склонирован в папку $REPO_NAME${NC}"
    else
        echo "Не удалось склонировать репозиторий."
        exit 1
    fi
fi

echo -e "${GREEN}Все операции успешно выполнены!${NC}"
echo -e "${BLUE}Учетные данные Git настроены:${NC}"
echo -e "Имя: ${GREEN}$GIT_NAME${NC}"
echo -e "Почта: ${GREEN}$GIT_EMAIL${NC}"
echo -e "${BLUE}Репозиторий находится в папке:${NC} ${GREEN}$REPO_NAME${NC}"