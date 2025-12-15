#!/bin/bash

#############################################
# INCIDENT RESPONDER - Linux (PRO)
#############################################

LOG="/tmp/incident_responder.log"
ANALISTA=""
HOST=$(hostname)
MODE="JUNIOR"

pause() { read -p "Presiona ENTER para continuar..."; }

log() { echo "$(date '+%F %T') | $1" >> "$LOG"; }

#############################################
# HEADER
#############################################
header() {
clear
cat <<EOF
INCIDENT RESPONDER - Linux
Diagnóstico y Respuesta a Incidentes
Host: $HOST
Analista: $ANALISTA
Modo: $MODE
Fecha: $(date)
=================================================
EOF
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

  # DISCO LLENO
  USO_DISCO=$(df / | awk 'NR==2 {gsub("%",""); print $5}')
  if [ "$USO_DISCO" -ge 90 ]; then
    CAUSA="DISCO LLENO"
    DESCRIPCION="El filesystem raíz supera el 90% de uso."
    EXPLICACION="El sistema no puede escribir archivos y los servicios comienzan a fallar."
    SEVERIDAD="ALTA"
    IMPACTO="Servicios detenidos o inestables"
    RECOMENDACION="Opción 2) Analizar disco lleno"
  fi

  # MEMORIA / OOM
  if dmesg 2>/dev/null | grep -qi oom; then
    CAUSA="MEMORIA AGOTADA (OOM)"
    DESCRIPCION="El kernel activó el OOM Killer."
    EXPLICACION="Un proceso consumió toda la memoria disponible."
    SEVERIDAD="CRÍTICA"
    IMPACTO="Procesos finalizados por el kernel"
    RECOMENDACION="Opción 4) Analizar memoria"
  fi

  # CPU
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

  # SERVICIOS
  if systemctl --failed 2>/dev/null | grep -q failed; then
    CAUSA="SERVICIO CRÍTICO CAÍDO"
    DESCRIPCION="systemd reporta servicios fallidos."
    EXPLICACION="Un servicio esencial no está operativo."
    SEVERIDAD="ALTA"
    IMPACTO="Funcionalidad parcial o caída de aplicación"
    RECOMENDACION="Revisar servicios manualmente"
  fi

  # RED / DNS
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
# RESUMEN EJECUTIVO
#############################################
resumen_ejecutivo() {
  echo ""
  echo "🧾 RESUMEN EJECUTIVO"
  echo "----------------------------------------------"
  echo "Causa probable : $CAUSA"
  echo "Severidad      : $SEVERIDAD"
  echo "Impacto        : $IMPACTO"
  echo "Acción sugerida: $RECOMENDACION"
  echo ""

  if [ "$MODE" = "JUNIOR" ]; then
    echo "🧑‍🏫 EXPLICACIÓN:"
    echo "$EXPLICACION"
  else
    echo "🔧 DETALLE TÉCNICO:"
    echo "$DESCRIPCION"
  fi
}

#############################################
# INCIDENTES ESPECÍFICOS
#############################################
check_disk() {
header
df -h /
echo
echo "Sugerencias:"
echo "du -sh /* 2>/dev/null | sort -h"
log "Chequeo disco"
pause
}

check_io() {
header
command -v iostat &>/dev/null && iostat -xz 1 3 || echo "iostat no disponible"
dmesg 2>/dev/null | grep -i "I/O error" || echo "Sin errores visibles"
log "Chequeo I/O"
pause
}

check_memory() {
header
free -h
dmesg 2>/dev/null | grep -i oom || echo "No OOM detectado"
log "Chequeo memoria"
pause
}

check_cpu() {
header
uptime
top -bn1 | head -n 5
log "Chequeo CPU"
pause
}

check_network() {
header
ping -c 2 8.8.8.8 &>/dev/null && echo "Red OK" || echo "Falla de red"
log "Chequeo red"
pause
}

check_kernel() {
header
dmesg 2>/dev/null | egrep -i "panic|lockup|BUG|Call Trace" || echo "Sin eventos críticos"
log "Chequeo kernel"
pause
}

check_fd() {
header
ps aux | grep Z || echo "No hay zombies"
command -v lsof &>/dev/null && lsof | wc -l || echo "lsof no disponible"
log "Chequeo FD"
pause
}

final_report() {
header
echo "📄 REPORTE FINALIZADO"
echo "Log: $LOG"
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
