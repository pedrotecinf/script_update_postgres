# Scripts de Atualização PostgreSQL Docker 🐘🔄

Este repositório contém scripts para automatizar o processo de atualização de containers PostgreSQL no Docker, oferecendo duas versões com diferentes níveis de funcionalidades e robustez.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Requisitos](#requisitos)
- [Comparação entre Versões](#comparação-entre-versões)
- [Script V1 (update_postgres.sh)](#script-v1-update_postgressh)
- [Script V2 (update_postgres_v2.sh)](#script-v2-update_postgres_v2sh)
- [Guia de Uso](#guia-de-uso)
- [Boas Práticas](#boas-práticas)
- [Resolução de Problemas](#resolução-de-problemas)

## 🎯 Visão Geral

Os scripts automatizam o processo de atualização do PostgreSQL em ambientes Docker, incluindo:
- Backup do banco de dados existente
- Criação de novo volume
- Migração dos dados
- Suporte a Docker Swarm
- Verificações de segurança e integridade

## 🔧 Requisitos

- Docker instalado e em execução
- Acesso ao container PostgreSQL
- Permissões de administrador no banco de dados
- Espaço em disco suficiente para backup
- Bash shell

## 📊 Comparação entre Versões

| Funcionalidade                     | V1  | V2  |
|-----------------------------------|-----|-----|
| Backup básico                      | ✅  | ✅  |
| Restauração de dados              | ✅  | ✅  |
| Suporte a Docker Swarm            | ✅  | ✅  |
| Menu interativo                    | ❌  | ✅  |
| Verificação de espaço em disco    | ❌  | ✅  |
| Validação de versão PostgreSQL    | ❌  | ✅  |
| Verificação de integridade        | ❌  | ✅  |
| Barra de progresso                | ❌  | ✅  |
| Logs detalhados                   | ❌  | ✅  |
| Suporte multi-arquitetura         | ❌  | ✅  |
| Relatório de mudanças             | ❌  | ✅  |

## 🚀 Script V1 (update_postgres.sh)

### Características
- Script básico e direto
- Processo de atualização simplificado
- Feedback básico das operações
- Ideal para ambientes de desenvolvimento

### Fluxo de Execução
1. Lista containers em execução
2. Solicita ID do container
3. Realiza backup
4. Cria novo volume
5. Restaura dados
6. Fornece instruções de atualização

### Uso Básico
```bash
chmod +x update_postgres.sh
./update_postgres.sh
```

## 🌟 Script V2 (update_postgres_v2.sh)

### Novas Características
- Interface interativa aprimorada
- Validações extensivas de segurança
- Sistema de logging detalhado
- Suporte a múltiplas arquiteturas
- Relatórios de mudança
- Barra de progresso visual
- Verificações de integridade

### Recursos Avançados

#### 🔍 Validações
- Verificação de espaço em disco
- Validação de versão PostgreSQL
- Verificação de container
- Teste de conexão
- Verificação de integridade do backup

#### 📊 Interface
- Menu numerado para seleção
- Barra de progresso em operações
- Feedback colorido
- Logs detalhados

#### 📝 Documentação
- Logs com timestamp
- Relatório de mudanças
- Comparação de configurações
- Documentação das alterações

#### 🔒 Segurança
- Verificações de integridade
- Validações de entrada
- Tratamento de erros
- Limpeza automática

### Uso Avançado
```bash
chmod +x update_postgres_v2.sh
./update_postgres_v2.sh
```

## 📖 Guia de Uso

1. **Preparação**
   ```bash
   # Clone o repositório
   git clone [URL_DO_REPOSITORIO]
   cd [NOME_DO_DIRETORIO]
   
   # Torne os scripts executáveis
   chmod +x update_postgres.sh update_postgres_v2.sh
   ```

2. **Execução**
   - Para versão básica:
     ```bash
     ./update_postgres.sh
     ```
   - Para versão avançada:
     ```bash
     ./update_postgres_v2.sh
     ```

3. **Siga as Instruções Interativas**
   - Selecione o container
   - Forneça credenciais
   - Especifique a versão desejada
   - Acompanhe o progresso

4. **Após a Conclusão**
   - Verifique os logs (V2)
   - Revise o relatório de mudanças (V2)
   - Siga as instruções finais

## ⚡ Boas Práticas

1. **Antes da Atualização**
   - Realize backup adicional de segurança
   - Verifique espaço em disco
   - Teste em ambiente de desenvolvimento
   - Documente configurações atuais

2. **Durante a Atualização**
   - Não interrompa o processo
   - Monitore os logs
   - Mantenha backup seguro

3. **Após a Atualização**
   - Verifique integridade dos dados
   - Teste funcionalidades críticas
   - Mantenha backups por período seguro
   - Documente mudanças realizadas

## 🔍 Resolução de Problemas

### Problemas Comuns

1. **Erro de Permissão**
   ```bash
   chmod +x update_postgres.sh
   chmod +x update_postgres_v2.sh
   ```

2. **Espaço Insuficiente**
   - Libere espaço em disco
   - Ajuste REQUIRED_SPACE_MULTIPLIER em V2

3. **Falha na Conexão**
   - Verifique credenciais
   - Confirme status do container
   - Verifique configurações de rede

4. **Erro no Backup**
   - Verifique permissões
   - Confirme espaço disponível
   - Verifique logs para detalhes

### Logs e Diagnóstico (V2)
- Consulte arquivo de log para detalhes
- Verifique relatório de mudanças
- Analise saída do console

## 🤝 Contribuição

Contribuições são bem-vindas! Por favor:
1. Faça fork do repositório
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📜 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.