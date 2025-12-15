#!/bin/bash

LOG="/tmp/incident_responder.log"
REPORT=""
ANALISTA=""
HOST=$(hostname)
CAUSA_GLOBAL="NO DETERMINADA"
SEVERIDAD="N/A"
IMPACTO="N/A"

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
REPORT="/tmp/incident_report_$(date +%Y%m%d_%H%M)_${ANALISTA// /_}.txt"
log "Inicio de sesión del analista: $ANALISTA"

# =============================
# ESCANEO GENERAL + ANÁLISIS
# =============================
scan_general() {
header
echo "🔍 ESCANEO GENERAL DEL SISTEMA"
echo "----------------------------------------------"

uptime
free -h
df -h /
ip a | grep inet

log "Escaneo general ejecutado"
analizar_causa_probable
pause
}

# ============================
# ANALISADOR DE CAUSA
# ============================
analizar_causa_probable() {

CAUSA_GLOBAL="NO DETERMINADA"
SEVERIDAD="BAJA"
IMPACTO="LIMITADO"

USO_DISCO=$(df / | awk 'NR==2 {gsub("%",""); print $5}')

if [ "$USO_DISCO" -ge 90 ]; then
  CAUSA_GLOBAL="DISCO LLENO"
  SEVERIDAD="ALTA"
  IMPACTO="Servicios / Sistema"
fi

if dmesg 2>/dev/null | grep -qi oom; then
  CAUSA_GLOBAL="MEMORIA AGOTADA (OOM)"
  SEVERIDAD="CRÍTICA"
  IMPACTO="Sistema completo"
fi

LOAD=$(uptime | awk -F'load average:' '{print int($2)}')
CPU_CORES=$(nproc 2>/dev/null || echo 1)

if [ "$LOAD" -ge "$CPU_CORES" ]; then
  CAUSA_GLOBAL="CPU SATURADA"
  SEVERIDAD="MEDIA"
  IMPACTO="Rendimiento"
fi

if systemctl --failed 2>/dev/null | grep -q failed; then
  CAUSA_GLOBAL="SERVICIO CRÍTICO CAÍDO"
  SEVERIDAD="ALTA"
  IMPACTO="Servicio"
fi

echo ""
echo "📌 CAUSA MÁS PROBABLE: $CAUSA_GLOBAL"
echo "🔥 SEVERIDAD: $SEVERIDAD"
echo "📉 IMPACTO: $IMPACTO"

log "Causa detectada: $CAUSA_GLOBAL | Severidad: $SEVERIDAD | Impacto: $IMPACTO"
}

# =============================
# GENERAR INFORME LEGIBLE
# =============================
generate_report() {
header
echo "🧾 GENERANDO INFORME LEGIBLE..."

cat <<EOF > "$REPORT"
INFORME DE INCIDENTE - LINUX

Analista: $ANALISTA
Host: $HOST
Fecha: $(date)

----------------------------------------
CAUSA PROBABLE:
$CAUSA_GLOBAL

SEVERIDAD:
$SEVERIDAD

IMPACTO:
$IMPACTO

----------------------------------------
DESCRIPCIÓN:
Durante el análisis del sistema se identificó una condición que puede afectar la estabilidad
y operación normal del entorno.

RECOMENDACIÓN GENERAL:
Aplicar acciones correctivas según la causa detectada y documentar resolución.

----------------------------------------
LOG TÉCNICO ADJUNTO:
$LOG
EOF

log "Informe legible generado: $REPORT"
echo "✔ Informe creado en: $REPORT"
pause
}

# =============================
# EXPORTAR INFORME
# =============================
export_report() {
header
DESTINO="$HOME/incident_reports"
mkdir -p "$DESTINO"
cp "$REPORT" "$DESTINO"

log "Informe exportado a $DESTINO"
echo "📤 Informe exportado a: $DESTINO"
pause
}

# =============================
# FINALIZAR REPORTE
# =============================
final_report() {
header
echo "📄 REPORTE FINALIZADO"
echo "Log técnico: $LOG"
echo "Informe legible: $REPORT"
log "Reporte finalizado por el analista"
pause
}

# =============================
# MENÚ PRINCIPAL
# =============================
while true; do
header
echo "MENÚ PRINCIPAL"
echo "1) Escaneo general del sistema"
echo "2) Generar informe legible"
echo "3) Exportar informe"
echo "4) Finalizar reporte"
echo "0) Salir"
echo
read -p "Selecciona opción: " op

case $op in
1) scan_general ;;
2) generate_report ;;
3) export_report ;;
4) final_report ;;
0) log "Salida del sistema"; exit 0 ;;
*) echo "Opción inválida"; pause ;;
esac
done
