#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para exibir mensagens de erro e sair
error_exit() {
    echo -e "${RED}Erro: $1${NC}" >&2
    exit 1
}

# Função para exibir mensagens de sucesso
success_message() {
    echo -e "${GREEN}$1${NC}"
}

# Função para exibir mensagens de aviso
warning_message() {
    echo -e "${YELLOW}$1${NC}"
}

# Verificar se o Docker está instalado e em execução
if ! command -v docker &> /dev/null; then
    error_exit "Docker não está instalado. Por favor, instale o Docker primeiro."
fi

# Listar containers em execução
echo "Listando containers Docker em execução..."
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"

# Solicitar ID do container
read -p "Digite o ID do container PostgreSQL que deseja atualizar: " CONTAINER_ID

# Verificar se o container existe
if ! docker ps | grep -q $CONTAINER_ID; then
    error_exit "Container não encontrado!"
fi

# Solicitar informações do usuário
read -p "Digite o nome do usuário PostgreSQL (default: postgres): " PG_USER
PG_USER=${PG_USER:-postgres}

# Solicitar senha
read -s -p "Digite a senha do PostgreSQL: " POSTGRES_PASSWORD
echo

# Solicitar a versão desejada do PostgreSQL
read -p "Digite a versão do PostgreSQL para atualização (ex: 16): " PG_VERSION

# Nome do arquivo de backup
BACKUP_FILE="postgres_backup_$(date +%Y%m%d_%H%M%S).sql"
VOLUME_NAME="postgres_data_${PG_VERSION}"
TEMP_CONTAINER="postgres${PG_VERSION}_temp"

# Criar backup
warning_message "Criando backup do banco de dados..."
if ! docker exec -t $CONTAINER_ID pg_dumpall -U $PG_USER > $BACKUP_FILE; then
    error_exit "Falha ao criar backup!"
fi
success_message "Backup criado com sucesso: $BACKUP_FILE"

# Verificar serviços Docker
if docker service ls &> /dev/null; then
    warning_message "Listando serviços Docker..."
    docker service ls
    read -p "Digite o nome do serviço PostgreSQL (deixe em branco se não estiver usando Docker Swarm): " SERVICE_NAME
    
    if [ ! -z "$SERVICE_NAME" ]; then
        warning_message "Parando serviço $SERVICE_NAME..."
        docker service scale $SERVICE_NAME=0
    fi
fi

# Criar novo volume
warning_message "Criando novo volume Docker..."
if ! docker volume create $VOLUME_NAME; then
    error_exit "Falha ao criar volume!"
fi
success_message "Volume criado com sucesso!"

# Iniciar container temporário
warning_message "Iniciando container temporário com PostgreSQL ${PG_VERSION}..."
if ! docker run --name $TEMP_CONTAINER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    -v $VOLUME_NAME:/var/lib/postgresql/data \
    -d postgres:$PG_VERSION; then
    error_exit "Falha ao iniciar container temporário!"
fi
success_message "Container temporário iniciado com sucesso!"

# Aguardar inicialização do PostgreSQL
warning_message "Aguardando inicialização do PostgreSQL..."
sleep 10

# Restaurar backup
warning_message "Restaurando backup para o novo container..."
if ! cat $BACKUP_FILE | docker exec -i $TEMP_CONTAINER psql -U $PG_USER; then
    error_exit "Falha ao restaurar backup!"
fi
success_message "Backup restaurado com sucesso!"

# Parar e remover container temporário
warning_message "Limpando recursos temporários..."
docker stop $TEMP_CONTAINER
docker rm $TEMP_CONTAINER

# Instruções finais
success_message "\nAtualização preparada com sucesso!"
echo -e "\nPróximos passos:"
echo "1. O volume '$VOLUME_NAME' está pronto para uso"
echo "2. Backup salvo em: $BACKUP_FILE"
echo "3. Atualize seu container/serviço para usar:"
echo "   - Nova versão do PostgreSQL: $PG_VERSION"
echo "   - Novo volume: $VOLUME_NAME"

if [ ! -z "$SERVICE_NAME" ]; then
    echo -e "\nPara atualizar o serviço, execute:"
    echo "docker service update --image postgres:$PG_VERSION --mount-add type=volume,source=$VOLUME_NAME,target=/var/lib/postgresql/data $SERVICE_NAME"
fi

success_message "\nProcesso de atualização concluído!"