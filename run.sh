#!/bin/bash

mkdir -m 777 -p ./barman/data ./barman/server ./temboard ./nifi/drivers

configure(){
    wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.30/mysql-connector-java-8.0.30.jar -P ./nifi/drivers && \
    wget https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/23.2.0.0/ojdbc8-23.2.0.0.jar -P ./nifi/drivers && \
    wget https://jdbc.postgresql.org/download/postgresql-42.6.0.jar -P ./nifi/drivers && \
    wget https://repo1.maven.org/maven2/org/apache/nifi/nifi-kite-nar/1.15.3/nifi-kite-nar-1.15.3.nar -P ./nifi/drivers && \
    wget https://truststore.pki.rds.amazonaws.com/sa-east-1/sa-east-1-bundle.pem -P ./nifi/drivers && \
    wget https://jdbcsql.sourceforge.net/sqljdbc4.jar -P ./nifi/drivers && \
    chmod 777 ./nifi/drivers/*;
}

build(){
    docker compose --compatibility -p "postgresql-barman" build --no-cache --memory 2g --progress=plain;
}

up(){
    docker compose --compatibility -p "postgresql-barman" up -d;
}

stop(){
    docker compose --compatibility -p "postgresql-barman" stop;
}

drop(){
    docker compose --compatibility -p "postgresql-barman" down;
}

restart(){
    docker compose --compatibility -p "postgresql-barman" down && docker compose --compatibility -p "postgresql-barman" up -d;
}

drop_hard(){
    docker compose --compatibility -p "postgresql-barman" down --remove-orphans --volumes --rmi 'all'
    docker builder prune --all --force;
    sudo rm -rf ./barman/server;
    sudo rm -rf ./temboard/*;
    sudo rm -rf ./nifi/*;
}

$1
