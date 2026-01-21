#!/bin/bash

# AutoArrangeDisplays - Runner
# Restaura la configuración de monitores según la IP actual
# Uso: ./runner.sh [--apply] [--ip <ip>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_FILE="${SCRIPT_DIR}/data.txt"
DISPLAYPLACER="${SCRIPT_DIR}/displayplacer"

# Verificar que displayplacer existe
if [[ ! -f "$DISPLAYPLACER" ]]; then
    echo "❌ Error: displayplacer no encontrado en $DISPLAYPLACER"
    echo "Descárgalo de: https://github.com/jakehilborn/displayplacer/releases"
    exit 1
fi

# Verificar que data.txt existe
if [[ ! -f "$DATA_FILE" ]]; then
    echo "❌ Error: $DATA_FILE no encontrado"
    echo "Primero corre: ./analyser.sh save <nombre_config>"
    exit 1
fi

# Obtener la IP local
get_local_ip() {
    local ip
    # Intenta obtener la IP primaria
    ip=$(ifconfig 2>/dev/null | grep -A 1 "en0" | grep "inet " | awk '{print $2}' | head -1)
    
    if [[ -z "$ip" ]]; then
        # Fallback a en1 (para laptops con wireless)
        ip=$(ifconfig 2>/dev/null | grep -A 1 "en1" | grep "inet " | awk '{print $2}' | head -1)
    fi
    
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    echo "${ip:-unknown}"
}

# Aplicar configuración
apply_config() {
    local config_command="$1"
    
    if [[ -z "$config_command" ]]; then
        echo "❌ Error: No hay configuración para aplicar"
        return 1
    fi
    
    echo "🔧 Aplicando configuración de monitores..."
    
    if "$DISPLAYPLACER" "$config_command" 2>/dev/null; then
        echo "✅ Configuración aplicada exitosamente"
        return 0
    else
        echo "❌ Error al aplicar la configuración"
        return 1
    fi
}

# Restaurar según IP
restore_by_ip() {
    local current_ip="${1:-}"
    
    if [[ -z "$current_ip" ]]; then
        current_ip=$(get_local_ip)
    fi
    
    echo "🌐 IP actual: $current_ip"
    
    # Verificar si data.txt está vacío
    if [[ ! -s "$DATA_FILE" ]] || [[ "$(cat "$DATA_FILE")" == "[]" ]]; then
        echo "❌ No hay configuraciones guardadas en $DATA_FILE"
        exit 1
    fi
    
    # Buscar configuración para la IP actual
    local config_command
    local config_name
    
    if command -v jq &> /dev/null; then
        config_command=$(jq -r ".[] | select(.ip == \"$current_ip\") | .config" "$DATA_FILE" | head -1)
        config_name=$(jq -r ".[] | select(.ip == \"$current_ip\") | .name" "$DATA_FILE" | head -1)
    else
        # Fallback sin jq
        local match
        match=$(python3 << 'EOF'
import json
import sys

current_ip = sys.argv[1]

with open(sys.argv[2]) as f:
    data = json.load(f)
    
for config in data:
    if config['ip'] == current_ip:
        print(json.dumps({'name': config['name'], 'config': config['config']}))
        break
EOF
"$current_ip" "$DATA_FILE")
        
        if [[ -n "$match" ]]; then
            config_name=$(echo "$match" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('name',''))")
            config_command=$(echo "$match" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('config',''))")
        fi
    fi
    
    if [[ -z "$config_command" ]] || [[ "$config_command" == "null" ]]; then
        echo "❌ No hay configuración guardada para la IP: $current_ip"
        echo ""
        echo "Configuraciones disponibles:"
        list_configs
        exit 1
    fi
    
    echo "📍 Encontrada configuración: $config_name"
    apply_config "$config_command"
}

# Listar configuraciones
list_configs() {
    echo "📋 Configuraciones disponibles:"
    echo "================================"
    
    if command -v jq &> /dev/null; then
        jq -r '.[] | "\(.name) | IP: \(.ip)"' "$DATA_FILE"
    else
        python3 << 'EOF'
import json
import sys

with open(sys.argv[1]) as f:
    data = json.load(f)
    for config in data:
        print(f"{config['name']} | IP: {config['ip']}")
EOF
"$DATA_FILE"
    fi
}

# Aplicar configuración específica por nombre
apply_by_name() {
    local config_name="$1"
    
    echo "📌 Buscando configuración: $config_name"
    
    local config_command
    
    if command -v jq &> /dev/null; then
        config_command=$(jq -r ".[] | select(.name == \"$config_name\") | .config" "$DATA_FILE" | head -1)
    else
        config_command=$(python3 << 'EOF'
import json
import sys

config_name = sys.argv[1]

with open(sys.argv[2]) as f:
    data = json.load(f)
    
for config in data:
    if config['name'] == config_name:
        print(config['config'])
        break
EOF
"$config_name" "$DATA_FILE")
    fi
    
    if [[ -z "$config_command" ]] || [[ "$config_command" == "null" ]]; then
        echo "❌ Configuración no encontrada: $config_name"
        echo ""
        list_configs
        exit 1
    fi
    
    apply_config "$config_command"
}

# Main
case "${1:-}" in
    --apply)
        restore_by_ip "${2:-}"
        ;;
    --ip)
        restore_by_ip "$2"
        ;;
    --name)
        apply_by_name "$2"
        ;;
    --list)
        list_configs
        ;;
    *)
        current_ip=$(get_local_ip)
        echo "AutoArrangeDisplays - Runner"
        echo ""
        echo "IP actual: $current_ip"
        echo ""
        echo "Uso:"
        echo "  $0                    - Restaurar automáticamente según IP"
        echo "  $0 --apply            - Restaurar según IP actual (explícito)"
        echo "  $0 --ip <ip>          - Restaurar según IP específica"
        echo "  $0 --name <nombre>    - Restaurar por nombre de configuración"
        echo "  $0 --list             - Listar todas las configuraciones"
        echo ""
        
        # Intentar restaurar automáticamente
        if [[ "$(cat "$DATA_FILE")" != "[]" ]]; then
            echo "Intentando restaurar automáticamente..."
            echo ""
            restore_by_ip "$current_ip" || true
        else
            list_configs
        fi
        ;;
esac
