#!/bin/bash

# AutoArrangeDisplays - Analyser
# Guarda la configuración actual de monitores usando displayplacer
# Uso: ./analyser.sh save <nombre_config> [ip]
#      ./analyser.sh list
#      ./analyser.sh delete <nombre_config>

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

# Crear data.txt si no existe
if [[ ! -f "$DATA_FILE" ]]; then
    echo "[]" > "$DATA_FILE"
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

# Obtener configuración actual de displayplacer
get_current_config() {
    "$DISPLAYPLACER" list 2>/dev/null || echo ""
}

# Guardar configuración
save_config() {
    local config_name="$1"
    local custom_ip="${2:-}"
    
    if [[ -z "$config_name" ]]; then
        echo "❌ Error: Debes proporcionar un nombre para la configuración"
        echo "Uso: $0 save <nombre_config> [ip]"
        exit 1
    fi
    
    local current_config
    current_config=$(get_current_config)
    
    if [[ -z "$current_config" ]]; then
        echo "❌ Error: No se pudo obtener la configuración de monitores"
        exit 1
    fi
    
    local ip="${custom_ip:-$(get_local_ip)}"
    local timestamp=$(date +%s)
    
    echo "📸 Capturando configuración de monitores..."
    echo "   Nombre: $config_name"
    echo "   IP: $ip"
    echo "   Timestamp: $timestamp"
    
    # Leer el archivo JSON actual
    local json_data
    json_data=$(cat "$DATA_FILE")
    
    # Usar jq para agregar la nueva configuración
    if command -v jq &> /dev/null; then
        json_data=$(echo "$json_data" | jq \
            --arg name "$config_name" \
            --arg ip "$ip" \
            --arg config "$current_config" \
            --arg timestamp "$timestamp" \
            'map(select(.name != $name)) + [{
                name: $name,
                ip: $ip,
                config: $config,
                timestamp: $timestamp,
                created: now | todate
            }]')
    else
        # Fallback sin jq (manual JSON construction)
        json_data=$(python3 << 'EOF'
import json
import sys
from datetime import datetime

data = json.loads(sys.stdin.read())
config_name = sys.argv[1]
ip = sys.argv[2]
current_config = sys.argv[3]
timestamp = sys.argv[4]

# Remover configuración existente con el mismo nombre
data = [c for c in data if c['name'] != config_name]

# Agregar nueva configuración
data.append({
    'name': config_name,
    'ip': ip,
    'config': current_config,
    'timestamp': int(timestamp),
    'created': datetime.now().isoformat()
})

print(json.dumps(data, indent=2))
EOF
"$config_name" "$ip" "$current_config" "$timestamp" < "$DATA_FILE")
    fi
    
    echo "$json_data" > "$DATA_FILE"
    echo "✅ Configuración guardada exitosamente en $DATA_FILE"
}

# Listar configuraciones
list_configs() {
    if [[ ! -s "$DATA_FILE" ]] || [[ "$(cat "$DATA_FILE")" == "[]" ]]; then
        echo "📭 No hay configuraciones guardadas"
        return
    fi
    
    echo "📋 Configuraciones guardadas:"
    echo "================================"
    
    if command -v jq &> /dev/null; then
        jq -r '.[] | "\(.name) | IP: \(.ip) | Guardado: \(.created)"' "$DATA_FILE"
    else
        python3 << 'EOF'
import json
with open(sys.argv[1]) as f:
    data = json.load(f)
    for config in data:
        print(f"{config['name']} | IP: {config['ip']} | Guardado: {config['created']}")
EOF
"$DATA_FILE"
    fi
}

# Eliminar configuración
delete_config() {
    local config_name="$1"
    
    if [[ -z "$config_name" ]]; then
        echo "❌ Error: Debes proporcionar el nombre de la configuración a eliminar"
        exit 1
    fi
    
    if command -v jq &> /dev/null; then
        local json_data
        json_data=$(jq --arg name "$config_name" 'map(select(.name != $name))' "$DATA_FILE")
        echo "$json_data" > "$DATA_FILE"
    else
        python3 << 'EOF'
import json
import sys

config_name = sys.argv[1]
with open(sys.argv[2]) as f:
    data = json.load(f)

data = [c for c in data if c['name'] != config_name]

with open(sys.argv[2], 'w') as f:
    json.dump(data, f, indent=2)
EOF
"$config_name" "$DATA_FILE"
    fi
    
    echo "✅ Configuración '$config_name' eliminada"
}

# Main
case "${1:-}" in
    save)
        save_config "$2" "${3:-}"
        ;;
    list)
        list_configs
        ;;
    delete)
        delete_config "$2"
        ;;
    *)
        echo "AutoArrangeDisplays - Analyser"
        echo ""
        echo "Uso:"
        echo "  $0 save <nombre_config> [ip]    - Guardar configuración actual"
        echo "  $0 list                         - Listar configuraciones guardadas"
        echo "  $0 delete <nombre_config>       - Eliminar una configuración"
        echo ""
        echo "Ejemplos:"
        echo "  $0 save home"
        echo "  $0 save office 192.168.1.100"
        echo "  $0 list"
        echo "  $0 delete home"
        exit 1
        ;;
esac
