#!/bin/bash
#
# Script to completely disable hibernation and sleep on Debian-based systems
# Run as root (sudo)

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root (sudo)!"
    exit 1
fi

echo "Начинаем отключение гибернации и спящего режима..."

# 1. Mask all sleep/hibernate systemd targets
echo "Маскирование целей systemd для спящего режима и гибернации..."
systemctl mask sleep.target
systemctl mask suspend.target
systemctl mask hibernate.target
systemctl mask hybrid-sleep.target

# 2. Configure systemd-logind
echo "Настройка systemd-logind для игнорирования событий сна..."
mkdir -p /etc/systemd/logind.conf.d/
cat > /etc/systemd/logind.conf.d/10-disable-sleep.conf << EOF
[Login]
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
IdleAction=ignore
EOF

# 3. Modify kernel parameters in GRUB
echo "Настройка параметров ядра через GRUB..."
if [ -f /etc/default/grub ]; then
    # Backup original grub config
    cp /etc/default/grub /etc/default/grub.bak
    
    # Update GRUB parameters to disable sleep/hibernate at kernel level
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nohlt acpi_sleep=0 acpi_osi=Linux"/' /etc/default/grub
    
    # Update GRUB
    update-grub
else
    echo "ПРЕДУПРЕЖДЕНИЕ: Файл /etc/default/grub не найден. Пропускаем настройку GRUB."
fi

# 4. Create a service to disable sleep via sysfs
echo "Создание systemd-сервиса для отключения спящего режима..."
cat > /etc/systemd/system/disable-sleep.service << EOF
[Unit]
Description=Disable Sleep and Hibernation
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c "if [ -f /sys/power/pm_async ]; then echo 0 > /sys/power/pm_async; fi; if [ -f /sys/power/autosleep ]; then echo 0 > /sys/power/autosleep; fi; if [ -f /sys/power/disk ]; then echo off > /sys/power/disk; fi"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl enable disable-sleep.service
systemctl start disable-sleep.service

# 5. Set up rc.local for systems that still use it
echo "Создание резервного метода через rc.local..."
cat > /etc/rc.local << EOF
#!/bin/sh -e
# Disable sleep/suspend/hibernate
if [ -f /sys/power/pm_async ]; then echo 0 > /sys/power/pm_async; fi
if [ -f /sys/power/autosleep ]; then echo 0 > /sys/power/autosleep; fi
if [ -f /sys/power/disk ]; then echo off > /sys/power/disk; fi
exit 0
EOF

chmod +x /etc/rc.local

# 6. Disable graphical power management (if X11 is installed)
if [ -d /etc/X11/xorg.conf.d ]; then
    echo "Отключение энергосбережения в X11..."
    mkdir -p /etc/X11/xorg.conf.d/
    cat > /etc/X11/xorg.conf.d/10-no-dpms.conf << EOF
Section "ServerFlags"
  Option "BlankTime" "0"
  Option "StandbyTime" "0"
  Option "SuspendTime" "0"
  Option "OffTime" "0"
EndSection
EOF
fi

# 7. Install acpid if not already installed
if ! dpkg -l | grep -q acpid; then
    echo "Установка acpid для лучшего управления энергопотреблением..."
    apt-get update
    apt-get install -y acpid
fi

# Apply immediate settings
echo "Применение немедленных настроек..."
if [ -f /sys/power/pm_async ]; then echo 0 > /sys/power/pm_async; fi
if [ -f /sys/power/autosleep ]; then echo 0 > /sys/power/autosleep; fi
if [ -f /sys/power/disk ]; then echo off > /sys/power/disk; fi

echo "Готово! Гибернация и спящий режим отключены."
echo "Для применения всех изменений рекомендуется перезагрузить систему."