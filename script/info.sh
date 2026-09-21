#!/bin/sh

# ============================================================
# Alpine Linux - Información de Hardware y Software
# ============================================================

VERSION="2.0"

# ============================================================
# FUNCIONES
# ============================================================

title() {
    printf "\n============================================================\n"
    printf "%s\n" "$1"
    printf "============================================================\n"
}

info() {
    printf "%-25s: %s\n" "$1" "$2"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================
# SISTEMA OPERATIVO
# ============================================================

title "SISTEMA OPERATIVO"

if [ -f /etc/alpine-release ]; then
    info "Alpine Linux" "$(cat /etc/alpine-release)"
fi

info "Kernel" "$(uname -r)"
info "Arquitectura" "$(uname -m)"
info "Hostname" "$(hostname)"
info "Kernel completo" "$(uname -a)"

if [ -f /etc/os-release ]; then
    . /etc/os-release

    info "Distribución" "${PRETTY_NAME:-Desconocida}"
    info "ID" "${ID:-Desconocido}"
    info "Versión" "${VERSION_ID:-Desconocida}"
fi

# ============================================================
# CPU
# ============================================================

title "PROCESADOR (CPU)"

if [ -f /proc/cpuinfo ]; then

    MODEL=$(awk -F': ' '
        /model name/ {
            print $2
            exit
        }
        /Hardware/ {
            print $2
            exit
        }
    ' /proc/cpuinfo)

    if command_exists nproc; then
        CORES=$(nproc)
    else
        CORES=$(grep -c '^processor' /proc/cpuinfo)
    fi

    info "Modelo" "${MODEL:-No disponible}"
    info "CPU lógicas" "${CORES:-No disponible}"

    if command_exists lscpu; then
        echo
        echo "--- Información detallada ---"

        lscpu 2>/dev/null | grep -E \
        'Architecture|CPU\(s\)|Model name|Core|Socket|Thread|MHz|Vendor ID|Virtualization|Hypervisor' |
        sed 's/^/  /'
    fi

    echo
    echo "--- CPUs detectadas en /proc/cpuinfo ---"

    grep '^processor' /proc/cpuinfo 2>/dev/null |
    wc -l |
    awk '{print "  CPUs lógicas: " $1}'

fi

# ============================================================
# MEMORIA RAM
# ============================================================

title "MEMORIA RAM"

if [ -f /proc/meminfo ]; then

    TOTAL=$(awk '/MemTotal/ {
        printf "%.2f GB", $2/1024/1024
    }' /proc/meminfo)

    AVAILABLE=$(awk '/MemAvailable/ {
        printf "%.2f GB", $2/1024/1024
    }' /proc/meminfo)

    USED=$(awk '
        /MemTotal/ {total=$2}
        /MemAvailable/ {available=$2}
        END {
            printf "%.2f GB", (total-available)/1024/1024
        }
    ' /proc/meminfo)

    info "RAM total" "$TOTAL"
    info "RAM usada aprox." "$USED"
    info "RAM disponible" "$AVAILABLE"
fi

if command_exists free; then
    echo
    echo "--- Estado de memoria ---"
    free -h
fi

# ============================================================
# SWAP
# ============================================================

title "MEMORIA SWAP"

if command_exists free; then
    free -h | awk '
        NR==1 {print}
        /^Swap:/ {print}
    '
else
    echo "Comando free no disponible."
fi

# ============================================================
# ALMACENAMIENTO
# ============================================================

title "ALMACENAMIENTO"

if command_exists lsblk; then

    echo "--- Discos y particiones ---"

    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL 2>/dev/null

else

    echo "lsblk no está instalado."
    echo "Puedes instalarlo con:"
    echo "  apk add util-linux"

    echo
    echo "--- Dispositivos detectados en /sys/block ---"

    for disk in /sys/block/*; do
        if [ -e "$disk" ]; then
            NAME=$(basename "$disk")

            SIZE=$(cat "$disk/size" 2>/dev/null)

            if [ -n "$SIZE" ]; then
                SIZE_MB=$((SIZE / 2048))
                echo "  $NAME : ${SIZE_MB} MB"
            else
                echo "  $NAME"
            fi
        fi
    done

fi

echo
echo "--- Espacio de archivos ---"

df -h 2>/dev/null

# ============================================================
# PCI / HARDWARE
# ============================================================

title "DISPOSITIVOS PCI"

if command_exists lspci; then

    lspci 2>/dev/null

else

    echo "lspci no está instalado."
    echo "Puedes instalarlo con:"
    echo "  apk add pciutils"

fi

# ============================================================
# USB
# ============================================================

title "DISPOSITIVOS USB"

if command_exists lsusb; then

    lsusb 2>/dev/null

else

    echo "lsusb no está instalado."
    echo "Puedes instalarlo con:"
    echo "  apk add usbutils"

fi

# ============================================================
# RED
# ============================================================

title "RED"

if command_exists ip; then

    echo "--- Interfaces ---"

    ip -br addr 2>/dev/null

    echo
    echo "--- Enlaces ---"

    ip -br link 2>/dev/null

    echo
    echo "--- Rutas ---"

    ip route 2>/dev/null

else

    echo "El comando ip no está disponible."

fi

# ============================================================
# INFORMACIÓN DE ETH0
# ============================================================

if command_exists ip; then

    echo
    echo "--- Información de eth0 ---"

    if ip addr show eth0 >/dev/null 2>&1; then

        ip addr show eth0 2>/dev/null |
        grep -E 'inet |ether ' |
        sed 's/^/  /'

    else

        echo "  eth0 no está disponible."

    fi

fi

# ============================================================
# DNS
# ============================================================

title "CONFIGURACIÓN DNS"

if [ -f /etc/resolv.conf ]; then

    cat /etc/resolv.conf

else

    echo "/etc/resolv.conf no existe."

fi

# ============================================================
# SOFTWARE INSTALADO
# ============================================================

title "SOFTWARE"

if command_exists apk; then

    info "Gestor de paquetes" "apk"

    echo
    echo "--- Paquetes instalados ---"

    apk info 2>/dev/null

    echo
    echo "--- Cantidad de paquetes ---"

    COUNT=$(apk info 2>/dev/null | wc -l)

    info "Paquetes" "$COUNT"

else

    echo "apk no está disponible."

fi

# ============================================================
# SERVICIOS
# ============================================================

title "SERVICIOS"

if command_exists rc-status; then

    rc-status 2>/dev/null

else

    echo "OpenRC no disponible."

fi

# ============================================================
# PROCESOS
# ============================================================

title "PROCESOS"

if command_exists ps; then

    ps aux 2>/dev/null

else

    echo "ps no está disponible."

fi

# ============================================================
# UPTIME
# ============================================================

title "TIEMPO DE ACTIVIDAD"

if [ -f /proc/uptime ]; then

    # IMPORTANTE:
    # /proc/uptime devuelve decimales.
    # int() elimina la parte decimal para que
    # la aritmética de /bin/sh funcione correctamente.

    UPTIME=$(awk '{print int($1)}' /proc/uptime)

    DAYS=$((UPTIME / 86400))
    HOURS=$(((UPTIME % 86400) / 3600))
    MINUTES=$(((UPTIME % 3600) / 60))
    SECONDS=$((UPTIME % 60))

    info "Uptime" "${DAYS}d ${HOURS}h ${MINUTES}m ${SECONDS}s"

else

    echo "No se pudo obtener el uptime."

fi

# ============================================================
# VIRTUALIZACIÓN
# ============================================================

title "VIRTUALIZACIÓN"

if command_exists systemd-detect-virt; then

    VIRT=$(systemd-detect-virt 2>/dev/null)

    if [ -n "$VIRT" ]; then
        info "Virtualización" "$VIRT"
    else
        info "Virtualización" "No detectada"
    fi

elif [ -d /sys/hypervisor ]; then

    info "Virtualización" "Posible máquina virtual"

elif grep -qi hypervisor /proc/cpuinfo 2>/dev/null; then

    info "Virtualización" "Hypervisor detectado"

else

    info "Virtualización" "No detectada mediante comprobaciones básicas"

fi

# ============================================================
# DETECCIÓN DE VIRTUALBOX
# ============================================================

title "VIRTUALBOX"

if command_exists lsusb; then

    VBOX_USB=$(lsusb 2>/dev/null | grep -i "VirtualBox")

    if [ -n "$VBOX_USB" ]; then

        echo "VirtualBox detectado mediante USB:"
        echo "$VBOX_USB"

    else

        echo "No se detectó VirtualBox mediante USB."

    fi

else

    echo "lsusb no está disponible."

fi

# ============================================================
# GPU
# ============================================================

title "GPU / GRÁFICOS"

if command_exists lspci; then

    GPU=$(lspci 2>/dev/null |
        grep -Ei 'VGA compatible controller|3D controller|Display controller')

    if [ -n "$GPU" ]; then
        echo "$GPU"
    else
        echo "No se detectó GPU mediante PCI."
    fi

else

    echo "lspci no está instalado."
    echo "Instala pciutils para detectar la GPU:"
    echo "  apk add pciutils"

fi

# ============================================================
# BATERÍA
# ============================================================

title "BATERÍA"

BATTERY_FOUND=0

for BAT in /sys/class/power_supply/BAT*; do

    if [ -d "$BAT" ]; then

        BATTERY_FOUND=1

        NAME=$(basename "$BAT")

        STATUS=$(cat "$BAT/status" 2>/dev/null)
        CAPACITY=$(cat "$BAT/capacity" 2>/dev/null)

        info "$NAME estado" "${STATUS:-Desconocido}"
        info "$NAME carga" "${CAPACITY:-Desconocida}%"

    fi

done

if [ "$BATTERY_FOUND" -eq 0 ]; then
    echo "No se detectó batería."

fi

# ============================================================
# TEMPERATURA
# ============================================================

title "TEMPERATURA"

if [ -d /sys/class/thermal ]; then

    FOUND_TEMP=0

    for ZONE in /sys/class/thermal/thermal_zone*; do

        if [ -f "$ZONE/temp" ]; then

            FOUND_TEMP=1

            TYPE=$(cat "$ZONE/type" 2>/dev/null)
            TEMP=$(cat "$ZONE/temp" 2>/dev/null)

            if [ -n "$TEMP" ]; then

                TEMP_C=$(awk "BEGIN {
                    printf \"%.1f\", $TEMP/1000
                }")

                info "${TYPE:-Zona térmica}" "${TEMP_C} °C"

            fi

        fi

    done

    if [ "$FOUND_TEMP" -eq 0 ]; then
        echo "No se encontraron sensores térmicos."

    fi

else

    echo "No existe /sys/class/thermal."

fi

# ============================================================
# VARIABLES DE ENTORNO
# ============================================================

title "VARIABLES DE ENTORNO RELEVANTES"

printf "SHELL     : %s\n" "${SHELL:-No definido}"
printf "USER      : %s\n" "${USER:-No definido}"
printf "HOME      : %s\n" "${HOME:-No definido}"
printf "PATH      : %s\n" "${PATH:-No definido}"
printf "DISPLAY   : %s\n" "${DISPLAY:-No definido}"
printf "XDG_SESSION_TYPE : %s\n" "${XDG_SESSION_TYPE:-No definido}"
printf "DESKTOP_SESSION  : %s\n" "${DESKTOP_SESSION:-No definido}"

# ============================================================
# FECHA Y HORA
# ============================================================

title "FECHA Y HORA"

if command_exists date; then
    date
fi

# ============================================================
# RESUMEN
# ============================================================

title "RESUMEN"

if [ -f /etc/alpine-release ]; then
    info "Sistema" "Alpine Linux $(cat /etc/alpine-release)"
fi

info "Kernel" "$(uname -r)"
info "Arquitectura" "$(uname -m)"

if command_exists nproc; then
    info "CPU lógicas" "$(nproc)"
fi

if [ -f /proc/meminfo ]; then
    RAM_SUMMARY=$(awk '/MemTotal/ {
        printf "%.2f GB", $2/1024/1024
    }' /proc/meminfo)

    info "RAM" "$RAM_SUMMARY"
fi

if [ -f /proc/uptime ]; then

    UPTIME=$(awk '{print int($1)}' /proc/uptime)

    DAYS=$((UPTIME / 86400))
    HOURS=$(((UPTIME % 86400) / 3600))
    MINUTES=$(((UPTIME % 3600) / 60))

    info "Uptime" "${DAYS}d ${HOURS}h ${MINUTES}m"

fi

# ============================================================
# FIN
# ============================================================

title "FIN DEL INFORME"

echo "Informe generado: $(date)"
echo "Alpine Linux Hardware/Software Collector v$VERSION"
