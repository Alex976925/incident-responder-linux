#!/bin/bash

# ==============================
# INCIDENT RESPONSE TOOL
# Autor: Alexander
# ==============================

REPORT_DIR="$HOME/incident_reports"
mkdir -p "$REPORT_DIR"

clear
echo "=============================================="
echo "   INCIDENT RESPONSE - LINUX / UNIX TOOL"
echo "=============================================="
read -p "Nombre del operador: " OPERATOR
DATE=$(date "+%Y-%m-%d_%H-%M-%S")
REPORT="$REPORT_DIR/reporte_$DATE.txt"

echo "Operador: $OPERATOR" > "$REPORT"
echo "Fecha: $(date)" >> "$REPORT"
echo "==============================================" >> "$REPORT"

pause() { read -p "Presiona ENTER para continuar..."; }

log() {
  echo -e "$1"
  echo -e "$1" >> "$REPORT"
}

# ==============================
# ESCANEO INICIAL
# ==============================
scan_system() {
  log "\n🔍 ESCANEO INICIAL DEL SISTEMA"
  log "----------------------------------------------"

  log "\n1) Uptime y carga:"
  uptime | tee -a "$REPORT"

  log "\n2) CPU:"
  top -bn1 | head -5 | tee -a "$REPORT"

  log "\n3) Memoria:"
  free -h | tee -a "$REPORT"

  log "\n4) Disco:"
  df -h | tee -a "$REPORT"

  log "\n5) Procesos que más consumen:"
  ps aux --sort=-%cpu | head -6 | tee -a "$REPORT"

  log "\n6) Servicios fallando:"
  command -v systemctl >/dev/null && systemctl --failed || echo "Systemd no disponible" | tee -a "$REPORT"

  log "\n7) Errores críticos recientes:"
  command -v journalctl >/dev/null && journalctl -p 3 -n 10 || echo "journalctl no disponible" | tee -a "$REPORT"

  log "\n8) Red:"
  ip a | tee -a "$REPORT"
  ip route | tee -a "$REPORT"

  log "\n9) Puertos escuchando:"
  ss -tulnp 2>/dev/null || netstat -tulnp 2>/dev/null | tee -a "$REPORT"

  log "\n10) Cron jobs:"
  crontab -l 2>/dev/null || echo "No hay cron de usuario" | tee -a "$REPORT"
}
# =============================
# ANALIS + CAUSAS
# =============================
analizar_causas() {

  log "\n🧠 ANÁLISIS AUTOMÁTICO DE CAUSA PROBABLE"
  log "----------------------------------------------"

  CAUSA=""
  TECNICA=""
  INTERNA=""
  ACCION=""

  DISK_USE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  SWAP_USE=$(free | awk '/Swap/ { if ($2==0) print 0; else print int($3/$2*100) }')
  LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
  CORES=$(nproc)

  if [ "$DISK_USE" -ge 90 ]; then
    CAUSA="DISCO LLENO"
    TECNICA="El sistema de archivos raíz supera el 90% de uso."
    INTERNA="El servidor no puede guardar información ni trabajar correctamente."
    ACCION="Liberar espacio eliminando logs o archivos grandes."
  
  elif [ "$SWAP_USE" -ge 80 ]; then
    CAUSA="MEMORIA / SWAP SATURADA"
    TECNICA="La memoria RAM está agotada y el sistema usa swap excesivamente."
    INTERNA="El sistema se vuelve muy lento o se congela."
    ACCION="Identificar y detener procesos que consumen demasiada memoria."
  
  elif (( $(echo "$LOAD > $CORES" | bc -l) )); then
    CAUSA="CPU SOBRECARGADA"
    TECNICA="La carga del sistema supera la capacidad del CPU."
    INTERNA="El servidor está trabajando más de lo que puede."
    ACCION="Revisar procesos que consumen CPU."
  
  elif ! ping -c 1 8.8.8.8 &>/dev/null; then
    CAUSA="PROBLEMA DE RED"
    TECNICA="No hay conectividad externa desde el servidor."
    INTERNA="El servidor está aislado de la red."
    ACCION="Revisar interfaz de red y gateway."
  
  elif grep -R "Permission denied" /var/log &>/dev/null; then
    CAUSA="PROBLEMAS DE PERMISOS"
    TECNICA="Errores de permisos impiden la ejecución de procesos."
    INTERNA="El sistema no puede acceder a archivos necesarios."
    ACCION="Corregir permisos y propietarios."
  
  elif dmesg | grep -i "error" &>/dev/null; then
    CAUSA="ERRORES DEL SISTEMA / FILESYSTEM"
    TECNICA="El kernel reporta errores de lectura o escritura."
    INTERNA="Posible daño en el disco o sistema de archivos."
    ACCION="Revisar logs del kernel y programar fsck."
  
  else
    CAUSA="SERVICIOS DETENIDOS"
    TECNICA="No se detectó fallo de recursos, posible servicio caído."
    INTERNA="Una aplicación clave dejó de funcionar."
    ACCION="Revisar y reiniciar servicios."
  fi

  log "\n📌 CAUSA MÁS PROBABLE DETECTADA:"
  log "➡️ $CAUSA"

  log "\n🔬 DESCRIPCIÓN TÉCNICA:"
  log "$TECNICA"

  log "\n🧑‍🏫 EXPLICACIÓN INTERNA (PRINCIPIANTES):"
  log "$INTERNA"

  log "\n🔧 ACCIÓN INMEDIATA RECOMENDADA:"
  log "$ACCION"
}
# ==============================
# DIAGNÓSTICOS + SOLUCIONES
# ==============================
disk_full() {
  log "\n💥 DISCO LLENO"
  log "TÉCNICO: El filesystem supera el 90%, servicios pueden fallar."
  log "OPERATIVO: El sistema no puede escribir logs ni archivos temporales."

  df -h | tee -a "$REPORT"

  log "\n🔧 SOLUCIÓN:"
  log "Liberando logs antiguos..."
  journalctl --vacuum-time=7d 2>/dev/null
  truncate -s 0 /var/log/*.log 2>/dev/null

  log "Buscar archivos grandes:"
  du -sh /* 2>/dev/null | sort -h | tail
}

memory_swap() {
  log "\n💥 MEMORIA / SWAP SATURADA"
  log "TÉCNICO: El sistema está usando swap intensivamente."
  log "OPERATIVO: Lentitud extrema y procesos congelados."

  free -h | tee -a "$REPORT"

  log "\n🔧 SOLUCIÓN:"
  log "Identificando procesos pesados:"
  ps aux --sort=-%mem | head
}

high_cpu() {
  log "\n💥 CPU ALTA"
  log "TÉCNICO: Procesos consumiendo CPU excesiva."
  log "OPERATIVO: Servicios lentos o caídos."

  top -bn1 | head -10 | tee -a "$REPORT"
}

network_down() {
  log "\n💥 PROBLEMAS DE RED"
  log "TÉCNICO: Interfaces caídas o sin ruta."
  log "OPERATIVO: Sistema incomunicado."

  ip a | tee -a "$REPORT"
  ping -c 3 8.8.8.8 || log "Sin conectividad externa"
}

services_down() {
  log "\n💥 SERVICIOS CAÍDOS"
  log "TÉCNICO: Demonios detenidos."
  log "OPERATIVO: Aplicación fuera de servicio."

  command -v systemctl >/dev/null && systemctl --failed || log "No systemd"
}

permissions_issue() {
  log "\n💥 PERMISOS / OWNERSHIP"
  log "TÉCNICO: Permisos incorrectos bloquean ejecución."
  log "OPERATIVO: Errores inesperados."

  log "Buscar errores Permission denied en logs"
  grep -R "Permission denied" /var/log 2>/dev/null | head
}

fs_corruption() {
  log "\n💥 POSIBLE CORRUPCIÓN DE FS"
  log "TÉCNICO: Errores de lectura/escritura."
  log "OPERATIVO: Riesgo de pérdida de datos."

  dmesg | tail -20 | tee -a "$REPORT"
}

# ==============================
# MENÚ PRINCIPAL
# ==============================
while true; do
  clear
  echo "=============================================="
  echo " INCIDENT RESPONSE TOOL - OPERADOR: $OPERATOR"
  echo "=============================================="
  echo "1) Escaneo inicial del sistema"
  echo "2) Disco lleno"
  echo "3) Memoria / Swap"
  echo "4) CPU alta"
  echo "5) Red caída"
  echo "6) Servicios caídos"
  echo "7) Permisos incorrectos"
  echo "8) Corrupción de filesystem"
  echo "9) Finalizar reporte (sin cerrar sesión)"
  echo "0) Salir"
  read -p "Opción: " OPT

  case $OPT in
    1) scan_system; pause ;;
    2) disk_full; pause ;;
    3) memory_swap; pause ;;
    4) high_cpu; pause ;;
    5) network_down; pause ;;
    6) services_down; pause ;;
    7) permissions_issue; pause ;;
    8) fs_corruption; pause ;;
    9)
      log "\n=============================="
      log "REPORTE FINALIZADO"
      log "Operador: $OPERATOR"
      log "Fecha cierre: $(date)"
      log "=============================="
      pause
      ;;
    0) exit ;;
    *) echo "Opción inválida"; sleep 1 ;;
  esac
done
