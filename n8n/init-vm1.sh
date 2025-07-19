#!/bin/bash

# Script para instalación automática de Docker, Nginx y Certbot
# Versión mejorada con mejor manejo de errores y logging

set -euo pipefail  # Modo estricto: salir en error, variables no definidas, fallos en pipes

# Configuración
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/tmp/${SCRIPT_NAME%.*}.log"
readonly PROJECT_DIR="${HOME}/app"

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Función de logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        INFO)  echo -e "${GREEN}[INFO]${NC} $message" | tee -a "$LOG_FILE" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$LOG_FILE" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE" ;;
        STEP)  echo -e "${BLUE}#### $message ####${NC}" | tee -a "$LOG_FILE" ;;
    esac
}

# Función para verificar si el comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar distribución Ubuntu
check_ubuntu() {
    if ! grep -qi ubuntu /etc/os-release; then
        log ERROR "Este script está diseñado para Ubuntu. Distribución actual: $(lsb_release -si 2>/dev/null || echo 'Desconocida')"
        exit 1
    fi
}

# Función para actualizar el sistema
update_system() {
    log STEP "Actualizando el sistema"
    
    if sudo apt-get update && sudo apt-get upgrade -y; then
        log INFO "Sistema actualizado correctamente"
    else
        log ERROR "Fallo al actualizar el sistema"
        exit 1
    fi
}

# Función para desinstalar paquetes conflictivos de Docker
remove_conflicting_packages() {
    log STEP "Eliminando paquetes conflictivos de Docker"
    
    local packages=(docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc)
    local removed_any=false
    
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$pkg "; then
            log INFO "Eliminando paquete conflictivo: $pkg"
            sudo apt-get remove -y "$pkg" || log WARN "No se pudo eliminar $pkg (puede que no esté instalado)"
            removed_any=true
        fi
    done
    
    if ! $removed_any; then
        log INFO "No se encontraron paquetes conflictivos de Docker"
    fi
}

# Función para configurar el repositorio de Docker
setup_docker_repository() {
    log STEP "Configurando repositorio de Docker"
    
    # Instalar dependencias
    log INFO "Instalando dependencias necesarias"
    sudo apt-get install -y ca-certificates curl
    
    # Crear directorio para keyrings
    log INFO "Configurando directorio de claves"
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Descargar clave GPG de Docker
    log INFO "Descargando clave GPG oficial de Docker"
    if sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; then
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        log INFO "Clave GPG de Docker configurada correctamente"
    else
        log ERROR "Error al descargar la clave GPG de Docker"
        exit 1
    fi
    
    # Agregar repositorio a sources.list
    log INFO "Agregando repositorio de Docker a las fuentes APT"
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Actualizar índices de paquetes
    if sudo apt-get update; then
        log INFO "Repositorio de Docker configurado correctamente"
    else
        log ERROR "Error al actualizar después de agregar el repositorio de Docker"
        exit 1
    fi
}

# Función para instalar Docker
install_docker() {
    log STEP "Instalando paquetes de Docker"
    
    local docker_packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    
    if sudo apt-get install -y "${docker_packages[@]}"; then
        log INFO "Docker instalado correctamente"
        
        # Verificar instalación
        if command_exists docker; then
            local docker_version=$(docker --version)
            log INFO "Versión de Docker instalada: $docker_version"
        fi
    else
        log ERROR "Error al instalar Docker"
        exit 1
    fi
}

# Función para configurar usuario en grupo docker
setup_docker_user() {
    log STEP "Configurando usuario en el grupo docker"
    
    if sudo usermod -aG docker "$USER"; then
        log INFO "Usuario $USER agregado al grupo docker"
        log WARN "Necesitarás cerrar sesión y volver a iniciarla para que los cambios surtan efecto"
    else
        log ERROR "Error al agregar usuario al grupo docker"
        exit 1
    fi
}

# Función para instalar Nginx y Certbot
install_nginx_certbot() {
    log STEP "Instalando Nginx y Certbot"
    
    if sudo apt-get install -y nginx certbot python3-certbot-nginx; then
        log INFO "Nginx y Certbot instalados correctamente"
        
        # Verificar instalaciones
        if command_exists nginx; then
            local nginx_version=$(nginx -v 2>&1)
            log INFO "Versión de Nginx: $nginx_version"
        fi
        
        if command_exists certbot; then
            local certbot_version=$(certbot --version 2>&1)
            log INFO "Versión de Certbot: $certbot_version"
        fi
    else
        log ERROR "Error al instalar Nginx y Certbot"
        exit 1
    fi
}

# Función para habilitar servicios
enable_services() {
    log STEP "Habilitando servicios"
    
    if sudo systemctl enable nginx; then
        log INFO "Servicio Nginx habilitado"
        
        # Verificar estado del servicio
        if sudo systemctl is-active --quiet nginx; then
            log INFO "Nginx está ejecutándose"
        else
            log INFO "Iniciando servicio Nginx"
            sudo systemctl start nginx
        fi
    else
        log ERROR "Error al habilitar Nginx"
        exit 1
    fi
}

# Función para crear directorio del proyecto
create_project_directory() {
    log STEP "Creando directorio del proyecto"
    
    if mkdir -p "$PROJECT_DIR"; then
        log INFO "Directorio creado: $PROJECT_DIR"
        log INFO "Permisos del directorio: $(ls -ld "$PROJECT_DIR")"
    else
        log ERROR "Error al crear directorio $PROJECT_DIR"
        exit 1
    fi
}

# Función para mostrar resumen final
show_summary() {
    log STEP "Resumen de la instalación"
    
    echo
    log INFO "Instalación completada exitosamente"
    log INFO "Componentes instalados:"
    log INFO "  - Docker CE con plugins"
    log INFO "  - Nginx"
    log INFO "  - Certbot"
    log INFO ""
    log INFO "Directorio del proyecto: $PROJECT_DIR"
    log INFO "Log de instalación: $LOG_FILE"
    log INFO ""
    log WARN "IMPORTANTE: Para usar Docker sin sudo, cierra sesión y vuelve a iniciarla"
    log INFO ""
    log INFO "Para verificar las instalaciones:"
    log INFO "  - Docker: docker --version"
    log INFO "  - Nginx: nginx -v"
    log INFO "  - Certbot: certbot --version"
}

# Función principal
main() {
    log INFO "Iniciando script de instalación: $SCRIPT_NAME"
    log INFO "Log guardado en: $LOG_FILE"
    
    # Verificar si es Ubuntu
    check_ubuntu
    
    # Verificar permisos de sudo
    if ! sudo -n true 2>/dev/null; then
        log INFO "Este script requiere permisos de sudo"
    fi
    
    # Ejecutar funciones de instalación
    update_system
    remove_conflicting_packages
    setup_docker_repository
    install_docker
    setup_docker_user
    install_nginx_certbot
    enable_services
    create_project_directory
    show_summary
    
    log INFO "Script completado exitosamente"
}

# Manejo de señales para limpieza
cleanup() {
    log INFO "Script interrumpido. Realizando limpieza..."
    exit 1
}

trap cleanup SIGINT SIGTERM

# Ejecutar función principal solo si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi