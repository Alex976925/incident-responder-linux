#!/bin/bash

########################################
# INCIDENT RESPONDER - Linux SRE Tool
# Diagnóstico + Análisis + Soluciones
# Idioma: Español
########################################

LOGFILE="/tmp/incident_report_$(date +%F_%H%M%S).log"
ANALISTA=""

########################################
# UTILIDADES
########################################
pause() {
  read -p "Presiona ENTER para continuar..."
}

log() {
  echo "$(date '+%F %T') | $1" | tee -a "$LOGFILE"
}

header() {
  clear
  echo "=============================================="
  echo " INCIDENT RESPONDER - Linux"
  echo " Diagnóstico y Respuesta a Incidentes"
  echo " Host: $(hostname)"
  echo " Analista: $ANALISTA"
  echo " Fecha: $(date)"
  echo "=============================================="
  echo ""
}

########################################
# REGISTRO DE ANALISTA
########################################
registro_analista() {
  clear
  read -p "Ingresa tu nombre completo (Analista): " ANALISTA
  echo ""
  log "Inicio de sesión del analista: $ANALISTA"
}

########################################
# ESCANEO DEL SISTEMA
########################################
scan_system() {
  header
  log "Inicio de escaneo del sistema"

  echo "🔍 ESCANEO INICIAL DEL SISTEMA"
  echo "----------------------------------------------"

  echo "1) Uptime y carga:"
  uptime | tee -a "$LOGFILE"
  echo ""

  echo "2) CPU:"
  top -bn1 | grep "Cpu(s)" | tee -a "$LOGFILE"
  echo ""

  echo "3) Memoria:"
  free -h | tee -a "$LOGFILE"
  echo ""

  echo "4) Disco:"
  df -h | tee -a "$LOGFILE"
  echo ""

  echo "5) Procesos que más consumen CPU:"
  ps aux --sort=-%cpu | head -n 6 | tee -a "$LOGFILE"
  echo ""

  echo "6) Servicios fallando:"
  systemctl --failed 2>/dev/null | tee -a "$LOGFILE" || echo "No systemd"
  echo ""

  echo "7) Errores críticos recientes:"
  journalctl -p 3 -n 10 --no-pager 2>/dev/null | tee -a "$LOGFILE"
  echo ""

  echo "8) Red:"
  ip a | grep inet | tee -a "$LOGFILE"
  ip route | tee -a "$LOGFILE"
  echo ""

  echo "9) Puertos escuchando:"
  ss -tulnp 2>/dev/null | head -n 10 | tee -a "$LOGFILE"
  echo ""

  echo "10) Cron jobs:"
  crontab -l 2>/dev/null | tee -a "$LOGFILE" || echo "No hay cron de usuario"
  echo ""

  log "Escaneo del sistema finalizado"
  pause
}

########################################
# ANÁLISIS AUTOMÁTICO DE CAUSA
########################################
analizar_causa() {
  header
  log "Inicio de análisis automático de causa"

  DISK_USE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  SWAP_USE=$(free | awk '/Swap/ { if ($2==0) print 0; else print int($3/$2*100) }')
  LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
  CORES=$(nproc)

  CAUSA=""
  TECNICA=""
  INTERNA=""
  SOLUCION=""

  if [ "$DISK_USE" -ge 90 ]; then
    CAUSA="DISCO LLENO"
    TECNICA="El filesystem raíz supera el 90% de uso."
    INTERNA="El sistema no puede escribir archivos y los servicios fallan."
    SOLUCION="Liberar espacio eliminando logs y archivos innecesarios."

  elif [ "$SWAP_USE" -ge 80 ]; then
    CAUSA="MEMORIA / SWAP SATURADA"
    TECNICA="La RAM está agotada y el sistema depende excesivamente del swap."
    INTERNA="El servidor se vuelve lento o se congela."
    SOLUCION="Identificar procesos pesados y agregar swap."

  elif (( $(echo "$LOAD > $CORES" | bc -l) )); then
    CAUSA="CPU SOBRECARGADA"
    TECNICA="La carga del sistema supera el número de núcleos."
    INTERNA="Hay demasiados procesos ejecutándose al mismo tiempo."
    SOLUCION="Identificar y limitar procesos que consumen CPU."

  elif ! ping -c 1 8.8.8.8 &>/dev/null; then
    CAUSA="PROBLEMA DE RED"
    TECNICA="El sistema no tiene conectividad externa."
    INTERNA="El servidor está aislado de la red."
    SOLUCION="Revisar red, DNS y gateway."

  elif dmesg | grep -i "oom" &>/dev/null; then
    CAUSA="OOM KILLER"
    TECNICA="El kernel terminó procesos por falta de memoria."
    INTERNA="El sistema se quedó sin RAM."
    SOLUCION="Aumentar memoria o swap."

  elif dmesg | grep -i "error" &>/dev/null; then
    CAUSA="ERROR DE SISTEMA / FILESYSTEM"
    TECNICA="El kernel reporta errores de disco o filesystem."
    INTERNA="Puede haber daño en el disco."
    SOLUCION="Revisar logs y programar fsck."

  else
    CAUSA="SERVICIO CRÍTICO DETENIDO"
    TECNICA="No hay fallos de recursos, probable servicio caído."
    INTERNA="Una aplicación dejó de responder."
    SOLUCION="Revisar y reiniciar servicios."
  fi

  echo "📌 CAUSA MÁS PROBABLE DETECTADA"
  echo "----------------------------------------------"
  echo "➡️ $CAUSA"
  echo ""
  echo "🔬 DESCRIPCIÓN TÉCNICA:"
  echo "$TECNICA"
  echo ""
  echo "🧑‍🏫 EXPLICACIÓN INTERNA:"
  echo "$INTERNA"
  echo ""
  echo "🔧 ACCIÓN RECOMENDADA:"
  echo "$SOLUCION"
  echo ""

  log "Causa detectada: $CAUSA"
  pause
}

########################################
# SOLUCIONES GUIADAS
########################################
disk_issue() {
  header
  log "Aplicando solución de disco lleno"
  df -h
  echo ""
  echo "Liberando logs antiguos..."
  journalctl --vacuum-time=7d
  pause
}

memory_issue() {
  header
  log "Aplicando solución de memoria"
  free -h
  echo ""
  echo "Creando swap temporal de 2GB"
  fallocate -l 2G /swapfile && chmod 600 /swapfile
  mkswap /swapfile && swapon /swapfile
  pause
}

cpu_issue() {
  header
  top
  echo ""
  echo "Identifica el PID a terminar manualmente si es seguro."
  pause
}

network_issue() {
  header
  ping -c 3 8.8.8.8
  cat /etc/resolv.conf
  pause
}

service_issue() {
  header
  systemctl --failed
  pause
}

########################################
# MENÚ SOLUCIONES
########################################
solution_menu() {
  header
  echo "Selecciona acción correctiva:"
  echo "1) Disco lleno"
  echo "2) Memoria / Swap"
  echo "3) CPU"
  echo "4) Red"
  echo "5) Servicios"
  echo "0) Volver"
  read -p "Opción: " opt

  case $opt in
    1) disk_issue ;;
    2) memory_issue ;;
    3) cpu_issue ;;
    4) network_issue ;;
    5) service_issue ;;
    0) return ;;
  esac
}

########################################
# FINALIZAR REPORTE
########################################
finalizar_reporte() {
  header
  log "Reporte finalizado por el analista"
  echo "📄 REPORTE FINALIZADO"
  echo "Archivo generado:"
  echo "$LOGFILE"
  pause
}

########################################
# MENÚ PRINCIPAL
########################################
main_menu() {
  while true; do
    header
    echo "MENÚ PRINCIPAL"
    echo "1) Escaneo inicial del sistema"
    echo "2) Análisis automático de causa"
    echo "3) Aplicar soluciones"
    echo "4) Finalizar reporte (no cerrar sesión)"
    echo "0) Salir"
    read -p "Selecciona opción: " choice

    case $choice in
      1) scan_system ;;
      2) analizar_causa ;;
      3) solution_menu ;;
      4) finalizar_reporte ;;
      0) exit 0 ;;
    esac
  done
}

########################################
# INICIO
########################################
registro_analista
main_menu
