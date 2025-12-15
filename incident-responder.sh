#!/bin/bash

########################################
# INCIDENT RESPONDER - Linux SRE Tool
# Diagnóstico + Soluciones guiadas
########################################

LOGFILE="/tmp/incident_responder.log"

pause() {
  read -p "Presiona ENTER para continuar..."
}

header() {
  clear
  echo "=============================================="
  echo " INCIDENT RESPONDER - Linux"
  echo " Diagnóstico y mitigación de incidentes"
  echo " Host: $(hostname)"
  echo " Fecha: $(date)"
  echo "=============================================="
}

log() {
  echo "$(date) - $1" >> "$LOGFILE"
}

########################################
# 1️⃣ ESCANEO COMPLETO DEL SISTEMA
########################################
scan_system() {
  header
  echo "🔍 ESCANEO INICIAL DEL SISTEMA"
  echo "----------------------------------------------"

  echo "1) Uptime y carga:"
  uptime
  echo ""

  echo "2) CPU:"
  top -bn1 | grep "Cpu(s)"
  echo ""

  echo "3) Memoria:"
  free -h
  echo ""

  echo "4) Disco:"
  df -h
  echo ""

  echo "5) Procesos que más consumen:"
  ps aux --sort=-%cpu | head -n 6
  echo ""

  echo "6) Servicios fallando:"
  systemctl --failed
  echo ""

  echo "7) Errores críticos recientes:"
  journalctl -p 3 -n 10 --no-pager
  echo ""

  echo "8) Red:"
  ip a | grep inet
  ip route
  echo ""

  echo "9) Puertos escuchando:"
  ss -tulnp | head -n 10
  echo ""

  echo "10) Cron jobs:"
  crontab -l 2>/dev/null || echo "No hay cron de usuario"
  echo ""

  log "Escaneo del sistema ejecutado"
  pause
}

########################################
# 2️⃣ INCIDENTES + SOLUCIONES
########################################

disk_issue() {
  header
  echo "🟥 DISCO LLENO"
  df -h
  echo ""
  echo "Diagnóstico:"
  echo "du -sh /* 2>/dev/null | sort -h"
  echo ""
  echo "Solución sugerida:"
  echo "journalctl --vacuum-time=7d"
  echo "truncate -s 0 /var/log/*.log"
  pause
}

service_issue() {
  header
  echo "🟥 SERVICIO CAÍDO"
  systemctl --failed
  echo ""
  echo "Diagnóstico:"
  echo "systemctl status <servicio>"
  echo "journalctl -u <servicio>"
  echo ""
  echo "Solución:"
  echo "systemctl restart <servicio>"
  pause
}

oom_issue() {
  header
  echo "🟥 MEMORIA AGOTADA (OOM)"
  free -h
  dmesg | grep -i oom
  echo ""
  echo "Soluciones:"
  echo "- Reiniciar servicio pesado"
  echo "- Agregar swap"
  echo "fallocate -l 2G /swapfile && mkswap /swapfile && swapon /swapfile"
  pause
}

cpu_issue() {
  header
  echo "🟥 CPU AL 100%"
  top
  echo ""
  echo "Solución:"
  echo "kill -9 <PID> (solo si es seguro)"
  pause
}

network_issue() {
  header
  echo "🟥 RED / DNS"
  ping -c 3 8.8.8.8
  ping -c 3 google.com
  cat /etc/resolv.conf
  echo ""
  echo "Soluciones:"
  echo "systemctl restart NetworkManager"
  pause
}

ssl_issue() {
  header
  echo "🟥 CERTIFICADO SSL"
  echo "Diagnóstico:"
  echo "openssl x509 -enddate -noout -in cert.pem"
  echo ""
  echo "Solución:"
  echo "certbot renew"
  pause
}

cron_issue() {
  header
  echo "🟥 CRON / AUTOMATIZACIONES"
  crontab -l
  echo ""
  echo "Logs:"
  grep CRON /var/log/syslog | tail
  pause
}

########################################
# 3️⃣ MENÚ DE INCIDENTES
########################################
incident_menu() {
  header
  echo "Selecciona posible causa del incidente:"
  echo "1) Disco lleno"
  echo "2) Servicio crítico caído"
  echo "3) Memoria agotada (OOM)"
  echo "4) CPU al 100%"
  echo "5) Red / DNS"
  echo "6) SSL vencido"
  echo "7) Cron / procesos automáticos"
  echo "0) Volver"
  echo ""
  read -p "Opción: " opt

  case $opt in
    1) disk_issue ;;
    2) service_issue ;;
    3) oom_issue ;;
    4) cpu_issue ;;
    5) network_issue ;;
    6) ssl_issue ;;
    7) cron_issue ;;
    0) return ;;
    *) echo "Opción inválida"; pause ;;
  esac
}

########################################
# 4️⃣ MENÚ PRINCIPAL
########################################
main_menu() {
  while true; do
    header
    echo "MENÚ PRINCIPAL"
    echo "1) Analizar sistema (diagnóstico)"
    echo "2) Analizar incidente + soluciones"
    echo "0) Salir"
    echo ""
    read -p "Selecciona opción: " choice

    case $choice in
      1) scan_system ;;
      2) incident_menu ;;
      0) echo "Saliendo..."; exit 0 ;;
      *) echo "Opción inválida"; pause ;;
    esac
  done
}

main_menu
