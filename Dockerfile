#
# Base para o Postgres com SSH
#
FROM postgres:15.10-bullseye AS base

ENV TZ="America/Bahia"
ENV POSTGRES_PASSWORD="postgres"
ENV BARMAN_PASSWORD="barman"

RUN mkdir -p /home/barman && \
    groupadd -g 1010 barman && \
    useradd -d /home/barman -s /bin/bash -u 1010 -g barman barman && \
    echo "barman:${BARMAN_PASSWORD}" | chpasswd && \
    echo "postgres:${POSTGRES_PASSWORD}" | chpasswd && \
    passwd -d root

RUN apt-get update -y && \
    apt-get install -y \
    barman-cli \
    barman-cli-cloud \
    openssh-server && \
    rm -rf /var/lib/apt/lists/*

RUN chown -R postgres:postgres /var/lib/postgresql

RUN chown -R barman:barman /home/barman

RUN mkdir -p /var/run/sshd

RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config

RUN echo "PermitTTY yes" >> /etc/ssh/sshd_config







#
# Postgres com SSH
#
FROM base AS postgres    

WORKDIR /var/lib/postgresql

USER postgres 

RUN mkdir -p /var/lib/postgresql/.ssh /var/lib/postgresql/data/pgdata

RUN ssh-keygen -t rsa -b 4096 -f /var/lib/postgresql/.ssh/id_rsa -N ""

USER root

RUN cat > /docker-entrypoint-initdb.d/init.sh <<EOF
#!/bin/bash
set -e

# Criar usuário barman para replicar
psql -U \$POSTGRES_USER -c "CREATE USER barman WITH REPLICATION PASSWORD 'barman';"

# Adicionar no pg_hba
echo "host replication barman 100.100.0.20/32 scram-sha-256" >> /var/lib/postgresql/data/pgdata/pg_hba.conf
# echo "host replication barman barman md5" >> /var/lib/postgresql/data/pgdata/pg_hba.conf

# Recarregar configurações
psql -c "SELECT pg_reload_conf();"

EOF

RUN chmod +x /docker-entrypoint-initdb.d/init.sh

RUN cat > /var/lib/postgresql/docker-entrypoint.sh <<EOF
#!/bin/bash
set -e

# Run SSH
# /usr/sbin/sshd
su - root -c "/usr/sbin/sshd"

# Run Postgres
/usr/local/bin/docker-entrypoint.sh postgres "\$@" &

# Permissoes
sleep 10
for db in \$(psql -U \$POSTGRES_USER -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;"); do
    psql -U \$POSTGRES_USER -d "\$db" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
    psql -U \$POSTGRES_USER -d "\$db" -c "GRANT EXECUTE ON FUNCTION pg_backup_start(text, boolean) to barman;"
    psql -U \$POSTGRES_USER -d "\$db" -c "GRANT EXECUTE ON FUNCTION pg_backup_stop(boolean) to barman;"
    psql -U \$POSTGRES_USER -d "\$db" -c "GRANT EXECUTE ON FUNCTION pg_switch_wal() to barman;"
    psql -U \$POSTGRES_USER -d "\$db" -c "GRANT EXECUTE ON FUNCTION pg_create_restore_point(text) to barman;"
    psql -U \$POSTGRES_USER -d "\$db" -c "GRANT pg_read_all_settings TO barman;"
    psql -U \$POSTGRES_USER -d "\$db" -c "GRANT pg_read_all_stats TO barman;"
    psql -U \$POSTGRES_USER -d "\$db" -c "GRANT pg_checkpoint TO barman;"
done
# 
sleep infinity

EOF

RUN chmod +x /var/lib/postgresql/docker-entrypoint.sh && \
    chown -R postgres:postgres /var/lib/postgresql

ENTRYPOINT [ "/var/lib/postgresql/docker-entrypoint.sh" ]






#
# Barman
#
FROM base AS barman

WORKDIR /var/lib/barman

RUN apt-get update -y && \
apt-get install -y \
barman && \
rm -rf /var/lib/apt/lists/*

USER barman

RUN mkdir -p /home/barman/.ssh

RUN ssh-keygen -t rsa -b 4096 -f /home/barman/.ssh/id_rsa -N ""

USER root

RUN cat > /home/barman/docker-entrypoint.sh <<EOF
#!/bin/bash
set -e

# Run SSH
# /usr/sbin/sshd
su - root -c "/usr/sbin/sshd"

# Esperar pelo postgres do container principal
sleep 30

# Run Barman
# su - barman -c "/usr/bin/barman cron"
/usr/bin/barman cron
sleep 5
/usr/bin/barman switch-wal --force --archive all

# Logs
tail -f /var/log/barman/barman.log

EOF

RUN chmod +x /home/barman/docker-entrypoint.sh

RUN chown -R barman:barman /home/barman /var/lib/barman && \
    chown barman:barman /etc/barman.conf

ENTRYPOINT [ "/home/barman/docker-entrypoint.sh" ]







#
# Temboard
#
FROM python:3.13.1-alpine3.21 AS temboard

ENV TZ="America/Bahia"
ENV TEMBOAR_SERVER_VERSION="9.0.1"

WORKDIR /home/temboard

RUN addgroup -g 1000 -S temboard \
    && adduser -h /home/temboard -u 1001 -G temboard -D temboard \
    && chown -R temboard:temboard /home/temboard

RUN apk update \
    && apk add --no-cache \
    openssl \
    bash \
    sudo \
    postgresql15-client \
    && passwd -d root

RUN pip install temboard==$TEMBOAR_SERVER_VERSION psycopg2-binary

RUN cat > /home/temboard/entrypoint.sh <<EOF
#!/bin/bash 
set -e

# temboard entrypoint
# Configure temboard
bash /usr/local/share/temboard/auto_configure.sh

# Migrate temboard database
export PGPASSWORD=\${TEMBOARD_PASSWORD}
[ ! -f databaseMigrated ] && bash /usr/local/share/temboard/create_repository.sh && touch databaseMigrated

# Run temboard
sudo -iu temboard temboard -c /etc/temboard/temboard.conf


EOF

RUN chmod +x /home/temboard/entrypoint.sh \
    && chown -R temboard:temboard /home/temboard

USER root





#
# NIFI
#
FROM apache/nifi:1.26.0 AS nifi

USER root

WORKDIR /opt/nifi/nifi-current

RUN apt-get update -y && apt-get install -y wget

RUN mkdir -p /opt/nifi/nifi-current/jdbc

RUN echo "java.arg.8=-Duser.timezone=America/Bahia" >> /opt/nifi/nifi-current/conf/bootstrap.conf

CMD [ "/opt/nifi/nifi-current/bin/nifi.sh", "run" ]
