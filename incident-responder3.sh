#!/bin/bash

LOG="/tmp/incident_responder.log"
ANALISTA=""
HOST=$(hostname)

pause() { read -p "Presiona ENTER para continuar..."; }

log() { echo "$(date '+%F %T') | $1" >> "$LOG"; }

header() {
clear
cat <<EOF
INCIDENT RESPONDER - Linux
Diagnóstico y Respuesta a Incidentes
Host: $HOST
Analista: $ANALISTA
Fecha: $(date)
=================================================
EOF
}

# =============================
# REGISTRO DE ANALISTA
# =============================
clear
read -p "Ingresa tu nombre (Analista): " ANALISTA
log "Inicio de sesión del analista: $ANALISTA"

# =============================
# ESCANEO GENERAL + ANÁLISIS
# =============================
scan_general() {
  header
  echo "🔍 ESCANEO GENERAL DEL SISTEMA"
  echo "----------------------------------------------"

  echo "1) Uptime y carga:"
  uptime
  echo ""

  echo "2) Memoria:"
  free -h
  echo ""

  echo "3) Disco raíz:"
  df -h /
  echo ""

  echo "4) Red:"
  ip a | grep inet
  echo ""

  log "Escaneo general ejecutado"

  # 🔎 Análisis posterior
  analizar_causa_probable

  pause
}

# ============================
# ANALISADOR DE CAUSA
# ============================
analizar_causa_probable() {
  echo ""
  echo "📌 ANÁLISIS DE CAUSA PROBABLE"
  echo "----------------------------------------------"

  CAUSA=""
  TECNICA=""
  INTERNA=""
  OPCION=""

  # 1️⃣ Disco lleno
  USO_DISCO=$(df / | awk 'NR==2 {gsub("%",""); print $5}')
  if [ "$USO_DISCO" -ge 90 ]; then
    CAUSA="DISCO LLENO"
    TECNICA="El filesystem raíz supera el 90% de uso."
    INTERNA="El sistema no puede escribir archivos y los servicios fallan."
    OPCION="1) Disco lleno"
  fi

  # 2️⃣ Memoria / OOM
  if dmesg 2>/dev/null | grep -qi oom; then
    CAUSA="MEMORIA AGOTADA (OOM)"
    TECNICA="El kernel activó el OOM Killer."
    INTERNA="Un proceso consumió toda la memoria disponible."
    OPCION="3) Memoria agotada (OOM)"
  fi

  # 3️⃣ CPU saturada
  LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | awk '{print int($1)}')
  CPU_CORES=$(nproc 2>/dev/null || echo 1)
  if [ "$LOAD" -ge "$CPU_CORES" ]; then
    CAUSA="CPU SATURADA"
    TECNICA="El load average supera el número de núcleos."
    INTERNA="Procesos están compitiendo por CPU."
    OPCION="4) CPU al 100%"
  fi

  # 4️⃣ Servicios caídos
  if systemctl --failed 2>/dev/null | grep -q failed; then
    CAUSA="SERVICIO CRÍTICO CAÍDO"
    TECNICA="systemd reporta servicios fallidos."
    INTERNA="Un servicio esencial no está operativo."
    OPCION="2) Servicio crítico caído"
  fi

  # 5️⃣ Red / DNS
  if ! ping -c 1 8.8.8.8 &>/dev/null; then
    CAUSA="PROBLEMA DE RED"
    TECNICA="No hay conectividad IP."
    INTERNA="La red está caída o mal configurada."
    OPCION="5) Red / DNS"
  elif ! ping -c 1 google.com &>/dev/null; then
    CAUSA="DNS CAÍDO"
    TECNICA="Falla la resolución de nombres."
    INTERNA="El sistema no traduce dominios a IP."
    OPCION="5) Red / DNS"
  fi

  if [ -n "$CAUSA" ]; then
    echo "➡️ CAUSA MÁS PROBABLE: $CAUSA"
    echo ""
    echo "🔬 DESCRIPCIÓN TÉCNICA:"
    echo "$TECNICA"
    echo ""
    echo "🧑‍🏫 EXPLICACIÓN INTERNA:"
    echo "$INTERNA"
    echo ""
    echo "🔧 RECOMENDACIÓN:"
    echo "Revisar opción: $OPCION"
    log "Causa probable detectada: $CAUSA"
  else
    echo "✔ No se detectó una causa crítica inmediata."
    log "No se detectó causa crítica"
  fi
}
# =============================
# DISCO LLENO
# =============================
check_disk() {
header
USO=$(df / | awk 'NR==2 {print $5}')
echo "🟥 DISCO"
echo "Uso actual: $USO"
echo
echo "🔧 Recomendaciones:"
echo "du -sh /* 2>/dev/null | sort -h"
echo "Eliminar logs, archivos temporales"
log "Chequeo de disco ejecutado"
pause
}

# =============================
# I/O SATURADO
# =============================
check_io() {
header
echo "🟥 SATURACIÓN I/O"
command -v iostat &>/dev/null && iostat -xz 1 3 || echo "iostat no disponible"
dmesg 2>/dev/null | grep -i "I/O error" || echo "Sin errores I/O visibles"
log "Chequeo I/O ejecutado"
pause
}

# =============================
# MEMORIA
# =============================
check_memory() {
header
echo "🟥 MEMORIA / OOM"
free -h
dmesg 2>/dev/null | grep -i oom || echo "No OOM detectado"
log "Chequeo memoria ejecutado"
pause
}

# =============================
# CPU
# =============================
check_cpu() {
header
echo "🟥 CPU / LOAD"
uptime
top -bn1 | head -n 5
log "Chequeo CPU ejecutado"
pause
}

# =============================
# RED / DNS
# =============================
check_network() {
header
echo "🟥 RED / DNS"
ping -c 2 8.8.8.8 &>/dev/null && echo "Conectividad OK" || echo "Falla de red"
command -v dig &>/dev/null && dig google.com +short || echo "dig no disponible"
log "Chequeo red ejecutado"
pause
}

# =============================
# KERNEL
# =============================
check_kernel() {
header
echo "🚨 KERNEL / PANIC"
dmesg 2>/dev/null | egrep -i "panic|lockup|BUG|Call Trace" || echo "Sin eventos críticos"
echo
echo "⚠ No intervenir sin evidencia."
log "Chequeo kernel ejecutado"
pause
}

# =============================
# FUGA DE RECURSOS
# =============================
check_fd() {
header
echo "🧟 FUGA DE RECURSOS"
ps aux | grep Z || echo "No hay zombies visibles"
command -v lsof &>/dev/null && lsof | wc -l || echo "lsof no disponible"
log "Chequeo FD ejecutado"
pause
}

# =============================
# FINALIZAR REPORTE
# =============================
final_report() {
header
echo "📄 REPORTE FINALIZADO"
echo "Ubicación del log: $LOG"
log "Reporte finalizado por el analista"
pause
}

# =============================
# MENÚ PRINCIPAL
# =============================
while true; do
header
echo "MENÚ PRINCIPAL"
echo "1) Escaneo general"
echo "2) Analizar disco lleno"
echo "3) Analizar saturación I/O"
echo "4) Analizar memoria / OOM"
echo "5) Analizar CPU"
echo "6) Analizar red / DNS"
echo "7) Analizar kernel / panic"
echo "8) Analizar fuga de recursos"
echo "9) Finalizar reporte"
echo "0) Salir"
echo
read -p "Selecciona opción: " op

case $op in
1) scan_general ;;
2) check_disk ;;
3) check_io ;;
4) check_memory ;;
5) check_cpu ;;
6) check_network ;;
7) check_kernel ;;
8) check_fd ;;
9) final_report ;;
0) log "Salida del sistema"; exit 0 ;;
*) echo "Opción inválida"; pause ;;
esac
done
