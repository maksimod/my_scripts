#!/bin/bash
# emergency-diagnostics.sh - скрипт диагностики проблем загрузки системы
# Запускайте с правами root в аварийном режиме или с Live USB

# Функция для вывода информации в определенном формате
log_info() {
    echo -e "\e[1;34m[ИНФО]\e[0m $1"
}

log_warning() {
    echo -e "\e[1;33m[ПРЕДУПРЕЖДЕНИЕ]\e[0m $1"
}

log_error() {
    echo -e "\e[1;31m[ОШИБКА]\e[0m $1"
}

log_success() {
    echo -e "\e[1;32m[OK]\e[0m $1"
}

log_section() {
    echo -e "\n\e[1;36m==== $1 ====\e[0m"
}

# Проверяем, запущен ли скрипт с правами root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Скрипт должен быть запущен с правами root"
    exit 1
fi

# Создаем директорию для сохранения отчета
REPORT_DIR="/tmp/system-diagnostics-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/report.txt"

# Перенаправляем весь вывод в отчет и на экран
exec > >(tee -a "$REPORT_FILE")
exec 2>&1

log_info "Отчет также сохраняется в: $REPORT_FILE"

# Определяем, запущено ли это с Live USB или в аварийном режиме системы
LIVE_USB=false
if grep -q "boot=live" /proc/cmdline; then
    LIVE_USB=true
    log_info "Обнаружен запуск с Live USB"
    
    # Монтируем системный раздел, если запущено с Live USB
    log_section "Монтирование системного раздела"
    
    # Поиск корневого раздела
    ROOT_PART=""
    for part in $(lsblk -lno NAME,SIZE | grep -v "loop\|sr\|ram" | awk '{print $1}'); do
        if [ -b "/dev/$part" ]; then
            # Пробуем с блочным устройством
            mkdir -p /mnt/diag_root
            if mount "/dev/$part" /mnt/diag_root 2>/dev/null; then
                if [ -d "/mnt/diag_root/etc" ] && [ -d "/mnt/diag_root/boot" ]; then
                    ROOT_PART="/dev/$part"
                    log_success "Найден корневой раздел: $ROOT_PART"
                    break
                fi
                umount /mnt/diag_root
            fi
        fi
    done
    
    if [ -z "$ROOT_PART" ]; then
        log_error "Корневой раздел не найден! Укажите его вручную через параметр -r /dev/sdXY"
        exit 1
    fi
    
    # Настройка префикса для чтения файлов
    SYS_ROOT="/mnt/diag_root"
else
    log_info "Запущено на целевой системе"
    SYS_ROOT=""
fi

# Функция для чтения файла в системе с учетом режима запуска
read_sys_file() {
    local file="$1"
    if [ -f "$SYS_ROOT/$file" ]; then
        cat "$SYS_ROOT/$file"
    else
        echo "Файл не найден: $file"
    fi
}

# 1. Проверка состояния файловой системы
log_section "Проверка состояния файловой системы"

if [ "$LIVE_USB" = true ]; then
    # С Live USB проверим файловую систему
    log_info "Проверка файловой системы на корневом разделе $ROOT_PART"
    fsck -n "$ROOT_PART"
    if [ $? -eq 0 ]; then
        log_success "Файловая система в порядке"
    else
        log_error "Обнаружены проблемы с файловой системой! Требуется восстановление."
        log_info "Для восстановления используйте: fsck -y $ROOT_PART"
    fi
else
    # В аварийном режиме проверим, как была смонтирована ФС
    mount_info=$(mount | grep "on / ")
    log_info "Информация о монтировании корневой ФС: $mount_info"
    
    if echo "$mount_info" | grep -q "ro"; then
        log_warning "Корневая файловая система смонтирована в режиме 'только чтение'"
    fi
fi

# 2. Проверка fstab
log_section "Анализ fstab"
fstab_file="$SYS_ROOT/etc/fstab"

if [ -f "$fstab_file" ]; then
    log_info "Содержимое fstab:"
    cat "$fstab_file"
    
    # Анализ на наличие сетевых ФС
    if grep -q "nfs\|cifs\|sshfs" "$fstab_file"; then
        log_warning "Обнаружены сетевые файловые системы в fstab"
    fi
    
    # Проверка автомонтирования
    auto_entries=$(grep -v "^#" "$fstab_file" | grep -v "noauto" | wc -l)
    log_info "Количество автоматически монтируемых устройств: $auto_entries"
    
    # Проверка наличия _netdev для сетевых устройств
    network_without_netdev=$(grep -E "nfs|cifs|sshfs" "$fstab_file" | grep -v "_netdev" | wc -l)
    if [ $network_without_netdev -gt 0 ]; then
        log_error "Сетевые устройства без опции _netdev: $network_without_netdev (возможная причина сбоя)"
    fi
    
    # Проверка наличия строк с синтаксическими ошибками
    broken_lines=0
    while IFS= read -r line; do
        if [[ ! "$line" =~ ^# ]] && [[ -n "$line" ]]; then
            fields=$(echo "$line" | awk '{print NF}')
            if [ $fields -ne 6 ]; then
                log_error "Возможная ошибка синтаксиса в строке: $line (неверное количество полей: $fields)"
                broken_lines=$((broken_lines+1))
            fi
        fi
    done < "$fstab_file"
    
    if [ $broken_lines -gt 0 ]; then
        log_error "Обнаружено $broken_lines строк с возможными ошибками синтаксиса"
    else
        log_success "Синтаксис fstab выглядит правильным"
    fi
else
    log_error "Файл fstab не найден!"
fi

# 3. Анализ журналов загрузки
log_section "Анализ журналов загрузки"

# Проверка последних сообщений в journalctl
if [ "$LIVE_USB" = false ]; then
    log_info "Последние 100 строк журнала системы:"
    journalctl -b -p err -n 100
    
    log_info "Ошибки mountall и systemd-mount:"
    journalctl -b | grep -E "mountall|systemd-mount" | grep -i error
    
    log_info "Ошибки монтирования:"
    journalctl -b | grep -i "mount\|fstab" | grep -i "fail\|error"
else
    # С Live USB проверим журналы из файлов
    if [ -d "$SYS_ROOT/var/log" ]; then
        log_info "Поиск ошибок в системных журналах:"
        grep -i "error\|fail\|emergency" "$SYS_ROOT/var/log/syslog" "$SYS_ROOT/var/log/kern.log" 2>/dev/null | tail -n 100
    else
        log_warning "Каталог журналов не найден"
    fi
fi

# 4. Проверка состояния системных сервисов
log_section "Состояние системных сервисов"

if [ "$LIVE_USB" = false ]; then
    log_info "Статус всех сервисов:"
    systemctl list-units --state=failed
    
    log_info "Состояние загрузки системы:"
    systemctl is-system-running
    
    log_info "Результат проверки загрузчика:"
    grub-fstest
else
    log_info "Проверка служб невозможна при запуске с Live USB"
fi

# 5. Проверка файловых систем и дисков
log_section "Информация о дисках и разделах"

log_info "Список блочных устройств:"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,UUID

log_info "Проверка S.M.A.R.T. на дисках (если доступно):"
for disk in $(lsblk -nd -o NAME); do
    if [ -b "/dev/$disk" ]; then
        if command -v smartctl &> /dev/null; then
            log_info "SMART для /dev/$disk:"
            smartctl -H "/dev/$disk" || true
        else
            log_warning "smartctl не установлен, проверка SMART недоступна"
            break
        fi
    fi
done

# 6. Проверка конфигурации загрузчика
log_section "Анализ конфигурации загрузчика"

grub_cfg="$SYS_ROOT/boot/grub/grub.cfg"
if [ -f "$grub_cfg" ]; then
    log_info "Проверка конфигурации GRUB:"
    if grep -q "error\|syntax" "$grub_cfg"; then
        log_error "Найдены сообщения об ошибках в конфигурации GRUB:"
        grep -n "error\|syntax" "$grub_cfg"
    else
        log_success "Ошибок в файле конфигурации GRUB не обнаружено"
    fi
    
    # Проверка параметров загрузки
    log_info "Параметры загрузки ядра:"
    grep "linux\|kernel" "$grub_cfg" | grep -v "echo" | head -n 5
else
    log_warning "Файл конфигурации GRUB не найден"
fi

# 7. Проверка проблем в systemd
log_section "Диагностика systemd"

if [ "$LIVE_USB" = false ]; then
    log_info "Устройства, которые не удалось смонтировать:"
    systemctl --failed --type=mount
    
    log_info "Проблемные target-ы:"
    systemctl --failed --type=target
else
    log_info "Проверка systemd невозможна при запуске с Live USB"
fi

# 8. Информация о системе
log_section "Общая информация о системе"

if [ -f "$SYS_ROOT/etc/os-release" ]; then
    log_info "Версия ОС:"
    cat "$SYS_ROOT/etc/os-release"
fi

log_info "Информация о процессоре:"
cat /proc/cpuinfo | grep "model name" | head -n 1

log_info "Информация о памяти:"
free -h

log_info "Версия ядра:"
uname -a

# 9. Проверка прав доступа к критическим файлам
log_section "Проверка прав доступа к системным файлам"

critical_files=(
    "/etc/fstab"
    "/etc/passwd"
    "/etc/shadow"
    "/etc/sudoers"
    "/boot/grub/grub.cfg"
    "/boot/vmlinuz-*"
    "/boot/initrd.img-*"
)

for file in "${critical_files[@]}"; do
    for actual_file in $SYS_ROOT/$file; do
        if [ -f "$actual_file" ]; then
            file_perms=$(stat -c "%a %U:%G" "$actual_file")
            file_base=$(basename "$actual_file")
            log_info "Права к $file_base: $file_perms"
            
            # Проверка на небезопасные права
            if [[ "$actual_file" =~ shadow ]] && [[ ! "$file_perms" =~ ^[0-7]00 ]]; then
                log_error "Небезопасные права доступа для $file_base"
            elif [[ "$actual_file" =~ sudoers ]] && [[ ! "$file_perms" =~ ^440 ]]; then
                log_error "Небезопасные права доступа для $file_base"
            fi
        fi
    done
done

# 10. Проверка свободного места
log_section "Проверка свободного места на дисках"

if [ "$LIVE_USB" = false ]; then
    df -h
    
    # Проверка inode
    log_info "Использование inode:"
    df -i
    
    # Проверка заполненности /boot
    boot_usage=$(df -h | grep "/boot" | awk '{print $5}' | sed 's/%//')
    if [ ! -z "$boot_usage" ] && [ $boot_usage -gt 90 ]; then
        log_error "Раздел /boot заполнен на $boot_usage%! Это может вызывать проблемы с загрузкой."
    fi
else
    df -h /mnt/diag_root
fi

# 11. Заключение и рекомендации
log_section "ЗАКЛЮЧЕНИЕ И РЕКОМЕНДАЦИИ"

log_info "Основные проверки завершены. Результаты сохранены в: $REPORT_FILE"

# Если скрипт запущен с Live USB, отмонтируем системный раздел
if [ "$LIVE_USB" = true ] && [ -n "$ROOT_PART" ]; then
    log_info "Отмонтирование системного раздела..."
    umount /mnt/diag_root || true
fi

# Проверка наличия критических ошибок и формулирование рекомендаций
MOUNT_ERRORS=false
FS_ERRORS=false
GRUB_ERRORS=false
SPACE_ISSUES=false
SYSTEMD_ERRORS=false

# Проверка ошибок монтирования
if grep -q "mount\|fstab" "$REPORT_FILE" | grep -q "fail\|error"; then
    MOUNT_ERRORS=true
fi

# Проверка ошибок ФС
if grep -q "Обнаружены проблемы с файловой системой" "$REPORT_FILE"; then
    FS_ERRORS=true
fi

# Проверка ошибок GRUB
if grep -q "ошибк.*в.*GRUB" "$REPORT_FILE"; then
    GRUB_ERRORS=true
fi

# Проверка проблем с местом
if grep -q "заполнен на [9][0-9]%" "$REPORT_FILE"; then
    SPACE_ISSUES=true
fi

# Проверка ошибок systemd
if grep -q "failed.*systemd\|systemd.*failed" "$REPORT_FILE"; then
    SYSTEMD_ERRORS=true
fi

# Вывод рекомендаций
echo ""
echo "============================================="
echo "            ДИАГНОСТИЧЕСКИЕ ВЫВОДЫ          "
echo "============================================="
echo ""

if [ "$MOUNT_ERRORS" = true ]; then
    echo "ПРОБЛЕМА: Обнаружены ошибки монтирования"
    echo "РЕШЕНИЕ: "
    echo "  1. Временно удалите из fstab все сетевые диски или добавьте опцию 'noauto,x-systemd.automount'"
    echo "  2. Проверьте доступность всех указанных устройств"
    echo "  3. Добавьте опцию '_netdev' для всех сетевых устройств"
    echo ""
fi

if [ "$FS_ERRORS" = true ]; then
    echo "ПРОБЛЕМА: Обнаружены проблемы с файловой системой"
    echo "РЕШЕНИЕ: "
    echo "  1. Выполните полную проверку: fsck -y /dev/[раздел]"
    echo "  2. При необходимости загрузитесь с Live USB для проверки"
    echo ""
fi

if [ "$GRUB_ERRORS" = true ]; then
    echo "ПРОБЛЕМА: Обнаружены ошибки в конфигурации GRUB"
    echo "РЕШЕНИЕ: "
    echo "  1. Проверьте синтаксис в /etc/default/grub"
    echo "  2. Выполните update-grub для пересоздания конфигурации"
    echo ""
fi

if [ "$SPACE_ISSUES" = true ]; then
    echo "ПРОБЛЕМА: Недостаточно места на диске"
    echo "РЕШЕНИЕ: "
    echo "  1. Удалите старые ядра: apt autoremove"
    echo "  2. Очистите журналы системы: journalctl --vacuum-time=2d"
    echo "  3. Очистите кэш apt: apt clean"
    echo ""
fi

if [ "$SYSTEMD_ERRORS" = true ]; then
    echo "ПРОБЛЕМА: Ошибки в systemd"
    echo "РЕШЕНИЕ: "
    echo "  1. Проверьте проблемные юниты: systemctl --failed"
    echo "  2. Для отключения проблемного юнита: systemctl disable [unit]"
    echo ""
fi

echo "РЕКОМЕНДАЦИИ ПО ЗАЩИТЕ ОТ ПОЛОМОК:"
echo "  1. Создайте резервную копию рабочего fstab"
echo "     cp /etc/fstab /etc/fstab.working"
echo ""
echo "  2. Создайте минимальную версию fstab (только корневой раздел):"
echo "     echo \"/dev/sda1 / ext4 defaults,errors=remount-ro 0 1\" > /etc/fstab.minimal"
echo ""
echo "  3. Добавьте параметр systemd для автоматического восстановления:"
echo "     В /etc/default/grub добавьте в GRUB_CMDLINE_LINUX:"
echo "     systemd.restore_state=0"
echo ""
echo "  4. Для сетевых дисков всегда используйте:"
echo "     noauto,x-systemd.automount,_netdev,soft,timeo=15"
echo ""
echo "  5. Добавьте запасной пункт загрузки в GRUB:"
echo "     cp /boot/grub/grub.cfg /boot/grub/grub.cfg.backup"
echo "     update-grub"
echo ""

echo "============================================="
echo "Полная диагностика сохранена в: $REPORT_FILE"
echo "============================================="

exit 0