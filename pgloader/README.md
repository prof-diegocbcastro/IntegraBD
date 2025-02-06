# 🗂️ Informações sobre o PGLoader

## 🔤 Tratamento de Bancos de Dados com Codificação UTF-16LE

Alguns bancos de dados estão em codificação **UTF-16LE**. Para identificar a codificação do banco de dados, siga estes passos:

1. Abra o banco de dados usando **DBeaver**.
2. Execute o seguinte comando:
   ```sql
   PRAGMA encoding;
   ```

### ⚙️ Definindo a Codificação do Banco de Dados

O SQLite não permite alterar a codificação diretamente após a criação do banco. Portanto, é necessário criar um novo banco com a codificação desejada.

#### 🔨 Passos para Criar um Novo Banco com Codificação UTF-8

1. Instale o SQLite se ainda não estiver instalado:
   ```bash
   sudo apt install sqlite3
   ```
2. Gere um dump do banco de dados atual:
   ```bash
   sqlite3 base.sqlite .dump > dump.sql
   ```
3. Crie um novo banco com codificação UTF-8 e carregue o dump:
   ```bash
   sqlite3 nova_base.sqlite < dump.sql
   ```

### 🧰 Comandos Adicionais

- Verificar a integridade do banco de dados:
  ```bash
  sqlite3 base.sqlite "PRAGMA integrity_check;"
  ```
- Listar todas as tabelas do banco de dados:
  ```bash
  sqlite3 base.sqlite "SELECT name FROM sqlite_master WHERE type='table';"
  ```

[🔙 Voltar](../README.md)
