#!/bin/bash

#############################################
# INCIDENT RESPONDER - Linux (PRO)
#############################################

LOG="/tmp/incident_responder.log"
ANALISTA=""
HOST=$(hostname)
MODE="JUNIOR"

#############################################
# COLORES ANSI
#############################################
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
WHITE="\e[97m"
BOLD="\e[1m"
RESET="\e[0m"

#############################################
# FUNCIONES BASE
#############################################
pause() { read -p "Presiona ENTER para continuar..."; }

log() { echo "$(date '+%F %T') | $1" >> "$LOG"; }

#############################################
# COLOR SEGÚN SEVERIDAD
#############################################
color_severidad() {
  case "$SEVERIDAD" in
    CRÍTICA) echo -e "${BOLD}${RED}" ;;
    ALTA)    echo -e "${BOLD}${YELLOW}" ;;
    MEDIA)   echo -e "${BOLD}${CYAN}" ;;
    BAJA)    echo -e "${BOLD}${GREEN}" ;;
    *)       echo -e "${WHITE}" ;;
  esac
}

#############################################
# HEADER
#############################################
header() {
  clear
  echo -e "${BOLD}${CYAN}INCIDENT RESPONDER - Linux${RESET}"
  echo -e "${WHITE}Diagnóstico y Respuesta a Incidentes${RESET}"
  echo -e "Host: $HOST"
  echo -e "Analista: $ANALISTA"
  echo -e "Modo: $MODE"
  echo -e "Fecha: $(date)"
  echo -e "${CYAN}=================================================${RESET}"
}

#############################################
# REGISTRO DE ANALISTA
#############################################
clear
read -p "Ingresa tu nombre (Analista): " ANALISTA
log "Inicio de sesión del analista: $ANALISTA"

#############################################
# SELECCIÓN DE MODO
#############################################
clear
echo "Selecciona modo de operación:"
echo "1) Junior (guiado / explicativo)"
echo "2) Senior (técnico / directo)"
read -p "Opción: " MODE_OPT

if [ "$MODE_OPT" = "2" ]; then
  MODE="SENIOR"
fi

log "Modo seleccionado: $MODE"

#############################################
# ESCANEO GENERAL
#############################################
scan_general() {
  header
  echo -e "${BOLD}${CYAN}🔍 ESCANEO GENERAL DEL SISTEMA${RESET}"
  echo "----------------------------------------------"

  echo -e "${BOLD}1) Uptime y carga:${RESET}"
  uptime
  echo ""

  echo -e "${BOLD}2) Memoria:${RESET}"
  free -h
  echo ""

  echo -e "${BOLD}3) Disco raíz:${RESET}"
  df -h /
  echo ""

  echo -e "${BOLD}4) Red:${RESET}"
  ip a | grep inet
  echo ""

  log "Escaneo general ejecutado"

  analizar_causa_probable
  resumen_ejecutivo

  pause
}

#############################################
# ANALIZADOR DE CAUSA
#############################################
analizar_causa_probable() {

  CAUSA="NINGUNA"
  DESCRIPCION=""
  EXPLICACION=""
  SEVERIDAD="BAJA"
  IMPACTO="SIN IMPACTO"
  RECOMENDACION="Monitoreo"

  USO_DISCO=$(df / | awk 'NR==2 {gsub("%",""); print $5}')
  if [ "$USO_DISCO" -ge 90 ]; then
    CAUSA="DISCO LLENO"
    DESCRIPCION="El filesystem raíz supera el 90% de uso."
    EXPLICACION="El sistema no puede escribir archivos y los servicios comienzan a fallar."
    SEVERIDAD="ALTA"
    IMPACTO="Servicios detenidos o inestables"
    RECOMENDACION="Opción 2) Analizar disco lleno"
  fi

  if dmesg 2>/dev/null | grep -qi oom; then
    CAUSA="MEMORIA AGOTADA (OOM)"
    DESCRIPCION="El kernel activó el OOM Killer."
    EXPLICACION="Un proceso consumió toda la memoria disponible."
    SEVERIDAD="CRÍTICA"
    IMPACTO="Procesos finalizados por el kernel"
    RECOMENDACION="Opción 4) Analizar memoria"
  fi

  LOAD=$(uptime | awk -F'load average:' '{print int($2)}')
  CPU_CORES=$(nproc 2>/dev/null || echo 1)
  if [ "$LOAD" -ge "$CPU_CORES" ]; then
    CAUSA="CPU SATURADA"
    DESCRIPCION="El load average supera los núcleos disponibles."
    EXPLICACION="Demasiados procesos compiten por CPU."
    SEVERIDAD="MEDIA"
    IMPACTO="Lentitud general del sistema"
    RECOMENDACION="Opción 5) Analizar CPU"
  fi

  if systemctl --failed 2>/dev/null | grep -q failed; then
    CAUSA="SERVICIO CRÍTICO CAÍDO"
    DESCRIPCION="systemd reporta servicios fallidos."
    EXPLICACION="Un servicio esencial no está operativo."
    SEVERIDAD="ALTA"
    IMPACTO="Funcionalidad parcial o caída de aplicación"
    RECOMENDACION="Revisar servicios manualmente"
  fi

  if ! ping -c 1 8.8.8.8 &>/dev/null; then
    CAUSA="PROBLEMA DE RED"
    DESCRIPCION="No hay conectividad IP."
    EXPLICACION="La red está caída o mal configurada."
    SEVERIDAD="CRÍTICA"
    IMPACTO="Sistema aislado"
    RECOMENDACION="Opción 6) Analizar red / DNS"
  fi

  log "Análisis realizado: $CAUSA"
}

#############################################
# RESUMEN EJECUTIVO (COLORES AUTOMÁTICOS)
#############################################
resumen_ejecutivo() {
  COLOR=$(color_severidad)

  echo ""
  echo -e "${BOLD}${MAGENTA}🧾 RESUMEN EJECUTIVO${RESET}"
  echo "----------------------------------------------"
  echo -e "${COLOR}Causa probable : $CAUSA${RESET}"
  echo -e "${COLOR}Severidad      : $SEVERIDAD${RESET}"
  echo -e "${COLOR}Impacto        : $IMPACTO${RESET}"
  echo -e "${COLOR}Acción sugerida: $RECOMENDACION${RESET}"
  echo ""

  if [ "$MODE" = "JUNIOR" ]; then
    echo -e "${CYAN}🧑‍🏫 EXPLICACIÓN:${RESET}"
    echo "$EXPLICACION"
  else
    echo -e "${YELLOW}🔧 DETALLE TÉCNICO:${RESET}"
    echo "$DESCRIPCION"
  fi
}

#############################################
# INCIDENTES ESPECÍFICOS (SIN CAMBIOS)
#############################################
check_disk() { header; df -h /; echo; pause; }
check_io() { header; iostat -xz 1 3 2>/dev/null; pause; }
check_memory() { header; free -h; pause; }
check_cpu() { header; uptime; top -bn1 | head -n 5; pause; }
check_network() { header; ping -c 2 8.8.8.8 &>/dev/null && echo "Red OK" || echo "Falla de red"; pause; }
check_kernel() { header; dmesg | egrep -i "panic|lockup|BUG|Call Trace"; pause; }
check_fd() { header; ps aux | grep Z; pause; }

final_report() {
header
echo -e "${GREEN}📄 REPORTE FINALIZADO${RESET}"
echo "Log técnico: $LOG"
log "Reporte finalizado"
pause
}

#############################################
# MENÚ PRINCIPAL
#############################################
while true; do
header
echo "MENÚ PRINCIPAL"
echo "1) Escaneo general"
echo "2) Disco lleno"
echo "3) Saturación I/O"
echo "4) Memoria / OOM"
echo "5) CPU"
echo "6) Red / DNS"
echo "7) Kernel / Panic"
echo "8) Fuga de recursos"
echo "9) Finalizar reporte"
echo "0) Salir"
read -p "Opción: " op

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
0) log "Salida"; exit 0 ;;
*) echo "Opción inválida"; pause ;;
esac
done
