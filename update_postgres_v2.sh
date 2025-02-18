#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
LOG_FILE="postgres_update_$(date +%Y%m%d_%H%M%S).log"
REQUIRED_SPACE_MULTIPLIER=2.5 # Espaço necessário = tamanho do banco * multiplicador
MIN_POSTGRES_VERSION=9.6
MAX_POSTGRES_VERSION=16
PROGRESS_BAR_WIDTH=50
POSTGRES_READY_TIMEOUT=30  # Tempo máximo de espera em segundos

# Função para cleanup
cleanup() {
    local temp_container=$1
    log "INFO" "Realizando limpeza..."
    docker stop $temp_container >/dev/null 2>&1 || true
    docker rm $temp_container >/dev/null 2>&1 || true
}

# Função para logging
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "INFO") echo -e "${BLUE}[INFO]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
    esac
}

# Função para exibir barra de progresso
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percentage=$((current * 100 / total))
    local filled=$((percentage * PROGRESS_BAR_WIDTH / 100))
    local empty=$((PROGRESS_BAR_WIDTH - filled))
    
    printf "\r${message} [${GREEN}"
    printf "=%.0s" $(seq 1 $filled)
    printf "${NC}"
    printf " %.0s" $(seq 1 $empty)
    printf "] ${percentage}%%"
}

# Função para verificar espaço em disco
check_disk_space() {
    local container_id=$1
    local db_size=$(docker exec $container_id psql -U $PG_USER -t -c "SELECT pg_database_size('postgres')")
    local required_space=$((db_size * REQUIRED_SPACE_MULTIPLIER))
    local available_space=$(df . | awk 'NR==2 {print $4}')
    
    if [ $available_space -lt $required_space ]; then
        log "ERROR" "Espaço em disco insuficiente. Necessário: $(($required_space/1024/1024))MB, Disponível: $(($available_space/1024))MB"
        return 1
    fi
    return 0
}

# Função para validar versão do PostgreSQL
validate_postgres_version() {
    local version=$1
    if ! [[ $version =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        log "ERROR" "Formato de versão inválido. Use formato: XX ou XX.X"
        return 1
    fi
    
    local major_version=$(echo $version | cut -d. -f1)
    if [ $major_version -lt $MIN_POSTGRES_VERSION ] || [ $major_version -gt $MAX_POSTGRES_VERSION ]; then
        log "ERROR" "Versão $version não suportada. Use versão entre $MIN_POSTGRES_VERSION e $MAX_POSTGRES_VERSION"
        return 1
    fi
    return 0
}

# Função para verificar se o container é PostgreSQL
verify_postgres_container() {
    local container_id=$1
    if ! docker exec $container_id psql --version >/dev/null 2>&1; then
        log "ERROR" "O container selecionado não parece ser um container PostgreSQL válido"
        return 1
    fi
    return 0
}

# Função para testar conexão com o banco
test_database_connection() {
    local container_id=$1
    local user=$2
    local timeout=$3
    local waited=0
    
    while [ $waited -lt $timeout ]; do
        if docker exec $container_id pg_isready -U $user >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
        show_progress $waited $timeout "Aguardando conexão com o banco"
    done
    
    log "ERROR" "Timeout ao tentar conectar ao banco de dados"
    return 1
}

# Função para verificar integridade do backup
verify_backup_integrity() {
    local backup_file=$1
    
    log "INFO" "Verificando integridade do backup..."
    
    # Verifica se o arquivo não está vazio
    if [ ! -s "$backup_file" ]; then
        log "ERROR" "Arquivo de backup vazio"
        return 1
    fi
    
    # Verifica se o arquivo contém comandos SQL válidos
    if ! grep -q "^CREATE DATABASE" "$backup_file" || ! grep -q "^CREATE TABLE" "$backup_file"; then
        log "ERROR" "Backup parece não conter estrutura válida do PostgreSQL"
        return 1
    fi
    
    return 0
}

# Função para gerar relatório de mudanças
generate_change_report() {
    local old_version=$1
    local new_version=$2
    local report_file="postgres_update_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Relatório de Atualização PostgreSQL"
        echo "=================================="
        echo "Data: $(date)"
        echo "Versão Anterior: $old_version"
        echo "Nova Versão: $new_version"
        echo ""
        echo "Mudanças de Configuração:"
        echo "------------------------"
        # Comparar configurações
        diff <(docker exec $CONTAINER_ID psql -U $PG_USER -c "SHOW ALL") \
             <(docker exec $TEMP_CONTAINER psql -U $PG_USER -c "SHOW ALL") \
        || true
        
        echo ""
        echo "Verificações de Compatibilidade:"
        echo "------------------------------"
        # Verificar mudanças de tipos de dados
        docker exec $TEMP_CONTAINER psql -U $PG_USER -c "SELECT version();"
        
    } > "$report_file"
    
    log "SUCCESS" "Relatório de mudanças gerado: $report_file"
}

# Função para monitorar progresso do backup
monitor_backup_progress() {
    local container_id=$1
    local backup_file=$2
    local total_size=$(docker exec $container_id psql -U $PG_USER -t -c "SELECT pg_database_size('postgres')")
    
    while true; do
        local current_size=0
        if [ -f "$backup_file" ]; then
            current_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null)
        fi
        show_progress $current_size $total_size "Progresso do backup"
        sleep 1
        
        # Verifica se o backup ainda está em andamento
        if ! ps aux | grep -q "[p]g_dumpall.*$container_id"; then
            break
        fi
    done
    echo # Nova linha após a barra de progresso
}

# Verificar se o Docker está instalado e em execução
if ! command -v docker &> /dev/null; then
    log "ERROR" "Docker não está instalado"
    exit 1
fi

# Listar containers em execução com menu interativo
log "INFO" "Buscando containers PostgreSQL..."
declare -a containers
while IFS= read -r line; do
    containers+=("$line")
done < <(docker ps --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}" | grep "postgres")

if [ ${#containers[@]} -eq 0 ]; then
    log "ERROR" "Nenhum container PostgreSQL encontrado"
    exit 1
fi

echo -e "\n${BLUE}Containers PostgreSQL disponíveis:${NC}"
for i in "${!containers[@]}"; do
    IFS='|' read -r id name image status <<< "${containers[$i]}"
    echo "[$((i+1))] $name ($id) - $image - $status"
done

# Seleção do container
while true; do
    read -p "Selecione o número do container PostgreSQL (1-${#containers[@]}): " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#containers[@]}" ]; then
        IFS='|' read -r CONTAINER_ID CONTAINER_NAME IMAGE STATUS <<< "${containers[$((selection-1))]}"
        break
    fi
    log "WARNING" "Seleção inválida"
done

# Solicitar informações do usuário
read -p "Digite o nome do usuário PostgreSQL (default: postgres): " PG_USER
PG_USER=${PG_USER:-postgres}

# Solicitar senha
read -s -p "Digite a senha do PostgreSQL: " POSTGRES_PASSWORD
echo

# Solicitar a versão desejada do PostgreSQL
while true; do
    read -p "Digite a versão do PostgreSQL para atualização (ex: 16): " PG_VERSION
    if validate_postgres_version "$PG_VERSION"; then
        break
    fi
done

# Verificar container PostgreSQL
if ! verify_postgres_container "$CONTAINER_ID"; then
    exit 1
fi

# Testar conexão com o banco
if ! test_database_connection "$CONTAINER_ID" "$PG_USER" 5; then
    exit 1
fi

# Verificar espaço em disco
if ! check_disk_space "$CONTAINER_ID"; then
    exit 1
fi

# Nome do arquivo de backup
BACKUP_FILE="postgres_backup_$(date +%Y%m%d_%H%M%S).sql"
VOLUME_NAME="postgres_data_${PG_VERSION}"
TEMP_CONTAINER="postgres${PG_VERSION}_temp"

# Criar backup com monitoramento de progresso
log "INFO" "Iniciando backup do banco de dados..."
docker exec -t $CONTAINER_ID pg_dumpall -U $PG_USER > $BACKUP_FILE &
monitor_backup_progress "$CONTAINER_ID" "$BACKUP_FILE"

if [ ! -s "$BACKUP_FILE" ]; then
    log "ERROR" "Falha ao criar backup"
    exit 1
fi

# Verificar integridade do backup
if ! verify_backup_integrity "$BACKUP_FILE"; then
    log "ERROR" "Falha na verificação de integridade do backup"
    exit 1
fi

log "SUCCESS" "Backup criado com sucesso: $BACKUP_FILE"

# Verificar serviços Docker
if docker service ls &> /dev/null; then
    log "INFO" "Listando serviços Docker..."
    docker service ls
    read -p "Digite o nome do serviço PostgreSQL (deixe em branco se não estiver usando Docker Swarm): " SERVICE_NAME
    
    if [ ! -z "$SERVICE_NAME" ]; then
        log "INFO" "Parando serviço $SERVICE_NAME..."
        docker service scale $SERVICE_NAME=0
    fi
fi

# Criar novo volume
log "INFO" "Criando novo volume Docker..."
if ! docker volume create $VOLUME_NAME; then
    log "ERROR" "Falha ao criar volume"
    exit 1
fi

# Iniciar container temporário
log "INFO" "Iniciando container temporário com PostgreSQL ${PG_VERSION}..."
if ! docker run --name $TEMP_CONTAINER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    -v $VOLUME_NAME:/var/lib/postgresql/data \
    -d postgres:$PG_VERSION; then
    log "ERROR" "Falha ao iniciar container temporário"
    cleanup $TEMP_CONTAINER
    exit 1
fi

# Aguardar inicialização do PostgreSQL e testar conexão
if ! test_database_connection "$TEMP_CONTAINER" "$PG_USER" $POSTGRES_READY_TIMEOUT; then
    cleanup $TEMP_CONTAINER
    exit 1
fi

# Restaurar backup
log "INFO" "Restaurando backup para o novo container..."
if ! cat $BACKUP_FILE | docker exec -i $TEMP_CONTAINER psql -U $PG_USER; then
    log "ERROR" "Falha ao restaurar backup"
    cleanup $TEMP_CONTAINER
    exit 1
fi

# Gerar relatório de mudanças
OLD_VERSION=$(docker exec $CONTAINER_ID psql -V | grep -oP '\d+\.\d+')
generate_change_report "$OLD_VERSION" "$PG_VERSION"

# Parar e remover container temporário
log "INFO" "Limpando recursos temporários..."
cleanup $TEMP_CONTAINER

# Instruções finais
log "SUCCESS" "Atualização preparada com sucesso!"
echo -e "\nPróximos passos:"
echo "1. O volume '$VOLUME_NAME' está pronto para uso"
echo "2. Backup salvo em: $BACKUP_FILE"
echo "3. Logs salvos em: $LOG_FILE"
echo "4. Atualize seu container/serviço para usar:"
echo "   - Nova versão do PostgreSQL: $PG_VERSION"
echo "   - Novo volume: $VOLUME_NAME"

if [ ! -z "$SERVICE_NAME" ]; then
    echo -e "\nPara atualizar o serviço, execute:"
    echo "docker service update --image postgres:$PG_VERSION --mount-add type=volume,source=$VOLUME_NAME,target=/var/lib/postgresql/data $SERVICE_NAME"
fi

log "SUCCESS" "Processo de atualização concluído!"