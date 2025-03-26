#!/bin/bash
#
# Script to install development tools (Git, Node.js, Python3, npm, Ansible) on Debian
# Run as root (sudo)

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root (sudo)!"
    exit 1
fi

echo "Начинаем установку инструментов разработки (Git, Node.js, Python3, npm, Ansible)..."

# Update package lists
echo "Обновление списка пакетов..."
apt-get update

# Install Git
echo "Установка Git..."
apt-get install -y git

# Check Git installation
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    echo "✅ Git успешно установлен: $GIT_VERSION"
else
    echo "❌ Ошибка: Git не установлен!"
fi

# Install Python3 and pip
echo "Установка Python3 и pip..."
apt-get install -y python3 python3-pip

# Check Python installation
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "✅ Python3 успешно установлен: $PYTHON_VERSION"
else
    echo "❌ Ошибка: Python3 не установлен!"
fi

# Install Node.js and npm using NodeSource repository
echo "Установка Node.js и npm..."
# Add NodeSource repository (latest LTS version)
if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
    echo "Добавление репозитория NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
fi

# Install Node.js (npm will be installed as a dependency)
apt-get install -y nodejs

# Check Node.js and npm installation
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo "✅ Node.js успешно установлен: $NODE_VERSION"
else
    echo "❌ Ошибка: Node.js не установлен!"
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    echo "✅ npm успешно установлен: $NPM_VERSION"
else
    echo "❌ Ошибка: npm не установлен!"
fi

# Install Ansible
echo "Установка Ansible..."
apt-get install -y ansible

# Check Ansible installation
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n 1)
    echo "✅ Ansible успешно установлен: $ANSIBLE_VERSION"
else
    # Try installing via pip if apt install fails
    echo "Установка Ansible через pip..."
    pip3 install ansible
    
    if command -v ansible &> /dev/null; then
        ANSIBLE_VERSION=$(ansible --version | head -n 1)
        echo "✅ Ansible успешно установлен через pip: $ANSIBLE_VERSION"
    else
        echo "❌ Ошибка: Ansible не установлен!"
    fi
fi

# Install development tools
echo "Установка дополнительных инструментов разработки..."
apt-get install -y build-essential

echo "Установка завершена!"
echo ""
echo "Установленные версии:"
echo "--------------------"
[ -x "$(command -v git)" ] && echo "Git: $(git --version)"
[ -x "$(command -v python3)" ] && echo "Python: $(python3 --version)"
[ -x "$(command -v pip3)" ] && echo "pip: $(pip3 --version | awk '{print $2}')"
[ -x "$(command -v node)" ] && echo "Node.js: $(node --version)"
[ -x "$(command -v npm)" ] && echo "npm: $(npm --version)"
[ -x "$(command -v ansible)" ] && echo "Ansible: $(ansible --version | head -n 1 | awk '{print $2}')"