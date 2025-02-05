# Realizando nossa rotina de backup

# Configuração geral

> Estamos utilizando o modo streaming para executar o projeto.

### Comando de rotina

- Entrar no container do barman
```bash
   docker exec -u barman -it pg-barman bash
```
#### Deve estar dentro do container

- Garantir a inicialização do barman
```bash
   barman cron
```

- Verificar se esta tudo `OK` com os servers gerenciados pelo Barman
```bash
   barman check all
```

- Realizar o backup
```bash
   barman backup all
```

#### Restore

- Para que seja possível executar o restore, deve parar o postgres para que seja possível mudar a pasta pgdata (pasta onde ficam os arquivos do nosso banco). Como estamos utilizando a imagem oficial do postgres e ao parar o mesmo o container também era parada, tivemos que modificar nosso entrypoint adicionando um sleep infinity para o container não morrer junto. Na máquina do Barman execute os seguintes comandos

```bash
docker exec -u barman -it postgres.cluster
```

- Use o pg_ctl para parar o postgres
> su postgres -c '/usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data/pgdata stop'

- Após a pausa do postgres, modifique o nome da pasta pgdata, o barman irá criar outra pasta nova

```bash
cd /var/lib/postgresql/data
mv pgdata pgdata_old
```

- Saio do conteiner do postgres e volte para o container do barman
```bash
docker exec -U barman -it barman bash
```

- Listar o backups
```bash
Barman list-backups all
```

- Listar as informações do container
```bash
barman show-backup postgres.cluster #Id_do_backup
```

- Criei o ponto de restauração
```bash
barman recover postgres #ID_DO_BACKUP 
/var/lib/postgresql/data/pgdata --target-time 
#'timestamp de finalização do backup escolhido' 
--remote-ssh-command 'ssh -p 222 root@postgres' 
--target-action 'promote'
```

- Volte do container do postgres
```bash
docker exec -u barman -it postgres.cluster
cd /var/lib/postgresql/data
chown postgres:postgres -R pgdata
```

- Utilize um nano ou vi para editar o arquivo postgresql.auto.conf dentro do pgdata
    - trocar o comando restore-command do arquivo postgresql.auto.conf para <b>barman-wal-restore --port 222 -P -U root barman postgres %f %p

- Reinicie o postgresql
```bash
su postgres -c '/usr/lib/postgresql/14/bin/pg_ctl -D /var/lib/postgresql/data/pgdata start'
```