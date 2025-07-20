#!/bin/bash

ZBX_DB_HOST="srvzbxdb"
ZBX_PROXYS_SERVER_HOST="srvzbxprx01,srvzbxprx02"
ZBX_PROXYS_SERVER_ACTIVE_HOST="srvzbxprx01;srvzbxprx02"
ZBX_DB_NAME="zabbix"
ZBX_DB_USER="zabbix"
ZBX_DB_PASS="zbx@db"
ZBX_SERVER_IP="srvzbxserver"
ZBX_WEB_IP="srvzbxweb"
SUBNET_ALLOW="192.168.15.0/24"

function install_zabbix_server() {
  echo ">>> Instalando Zabbix Server e Agent..."

  apt update
  wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
  dpkg -i /tmp/zabbix-release.deb
  apt update

  apt install -y zabbix-server-pgsql zabbix-sql-scripts zabbix-agent2 postgresql-client \
    zabbix-agent2-plugin-mongodb zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql

  echo ">>> Importando schema..."
  zcat /usr/share/zabbix/sql-scripts/postgresql/server.sql.gz | PGPASSWORD="$ZBX_DB_PASS" psql -h "$ZBX_DB_HOST" -U "$ZBX_DB_USER" -d "$ZBX_DB_NAME"

  sed -i "s|^# DBHost=.*|DBHost=$ZBX_DB_HOST|" /etc/zabbix/zabbix_server.conf
  sed -i "s|^# DBPassword=.*|DBPassword=$ZBX_DB_PASS|" /etc/zabbix/zabbix_server.conf

  sed -i "s/^LogFileSize=.*/LogFileSize=1/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^Hostname=.*/#Hostname=Zabbix server/" /etc/zabbix/zabbix_agent2.conf

  systemctl restart zabbix-server zabbix-agent2
  systemctl enable zabbix-server zabbix-agent2
  systemctl disable apache2

  echo ">>> Zabbix Server configurado."
}

function install_zabbix_db() {
  echo ">>> Instalando PostgreSQL e Zabbix Agent..."

  apt update
  wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
  dpkg -i /tmp/zabbix-release.deb
  apt update

  apt install -y postgresql postgresql-contrib zabbix-agent2 \
    zabbix-agent2-plugin-mongodb zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql

  PG_CONF="/etc/postgresql/16/main/postgresql.conf"
  PG_HBA="/etc/postgresql/16/main/pg_hba.conf"

  sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" "$PG_CONF"
  echo "host    all             all             $SUBNET_ALLOW            scram-sha-256" >> "$PG_HBA"

  systemctl restart postgresql
  systemctl enable postgresql

  sudo -u postgres psql <<EOF
CREATE USER $ZBX_DB_USER WITH PASSWORD '$ZBX_DB_PASS';
CREATE DATABASE $ZBX_DB_NAME OWNER $ZBX_DB_USER;
EOF

  sed -i "s/^LogFileSize=.*/LogFileSize=1/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^Server=.*/Server=$ZBX_PROXYS_SERVER_HOST/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^ServerActive=.*/ServerActive=$ZBX_PROXYS_SERVER_ACTIVE_HOST/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^Hostname=.*/#Hostname=/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s|^# HostMetadata=.*|HostMetadata=Linux|" /etc/zabbix/zabbix_agent2.conf

  systemctl restart zabbix-agent2
  systemctl enable zabbix-agent2

  echo ">>> PostgreSQL e Agent configurados."
}

function install_zabbix_web() {
  echo ">>> Instalando Zabbix Frontend e Agent..."

  apt update
  wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
  dpkg -i /tmp/zabbix-release.deb
  apt update

  apt install -y zabbix-frontend-php php8.3-pgsql zabbix-apache-conf zabbix-agent2 \
    zabbix-agent2-plugin-mongodb zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql

  sed -i "s/^LogFileSize=.*/LogFileSize=1/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^Server=.*/Server=$ZBX_PROXYS_SERVER_HOST/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^ServerActive=.*/ServerActive=$ZBX_PROXYS_SERVER_ACTIVE_HOST/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^Hostname=.*/#Hostname=/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s|^# HostMetadata=.*|HostMetadata=Linux|" /etc/zabbix/zabbix_agent2.conf

  systemctl restart zabbix-agent2 apache2
  systemctl enable zabbix-agent2 apache2

  echo ">>> Zabbix Frontend configurado em http://$ZBX_WEB_IP/zabbix"
}

function install_grafana() {
  echo ">>> Instalando Grafana..."

  apt update
  wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
  dpkg -i /tmp/zabbix-release.deb
  apt update

  apt install -y zabbix-agent2 zabbix-agent2-plugin-mongodb \
    zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql

  sed -i "s/^LogFileSize=.*/LogFileSize=1/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^Server=.*/Server=$ZBX_PROXYS_SERVER_HOST/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^ServerActive=.*/ServerActive=$ZBX_PROXYS_SERVER_ACTIVE_HOST/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^Hostname=.*/#Hostname=/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s|^# HostMetadata=.*|HostMetadata=Linux|" /etc/zabbix/zabbix_agent2.conf
  
  apt install -y adduser libfontconfig1 musl
  wget https://dl.grafana.com/enterprise/release/grafana-enterprise_12.0.2_amd64.deb -O /tmp/grafana.deb
  dpkg -i /tmp/grafana.deb

  grafana-cli plugins install alexanderzobnin-zabbix-app

  systemctl enable grafana-server
  systemctl restart grafana-server

  echo ">>> Grafana disponivel em http://<ip>:3000 (admin/admin)"
}

function install_proxy_agent2() {
  echo ">>> Instalando Zabbix Proxy e Agent2..."

  apt update
  wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
  dpkg -i /tmp/zabbix-release.deb
  apt update

  apt install -y zabbix-proxy-sqlite3 zabbix-sql-scripts zabbix-agent2 \
    zabbix-agent2-plugin-mongodb zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql

  echo ">>> Criando banco de dados SQLite..."
  mkdir /var/lib/zabbix/ | 
  chmod 777 /var/lib/zabbix/
  gzip /usr/share/zabbix/sql-scripts/sqlite3/proxy.sql
  zcat /usr/share/zabbix/sql-scripts/sqlite3/proxy.sql.gz | sqlite3 /var/lib/zabbix/zabbix_proxy.db
  chown zabbix:zabbix /var/lib/zabbix/zabbix_proxy.db

  echo ">>> Configurando arquivos..."
  sed -i "s/^Server=.*/Server=$ZBX_SERVER_IP/" /etc/zabbix/zabbix_proxy.conf
  sed -i "s|^DBName=.*|DBName=/var/lib/zabbix/zabbix_proxy.db|" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/^Hostname=.*/#Hostname=/" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/^LogFileSize=.*/LogFileSize=1/" /etc/zabbix/zabbix_proxy.conf
  
  sed -i "s/^LogFileSize=.*/LogFileSize=1/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^Hostname=.*/#Hostname=/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s|^# HostMetadata=.*|HostMetadata=Linux|" /etc/zabbix/zabbix_agent2.conf

  systemctl restart zabbix-agent2 zabbix-proxy
  systemctl enable zabbix-agent2 zabbix-proxy

  echo ">>> Zabbix Proxy e Zabbix Agent2 configurados!"
}

function config_ip() {
# Rodar como root
if [ "$EUID" -ne 0 ]; then
  echo "Execute este script como root, script dedicado para o Ubuntu"
  exit 1
fi

# Solicita IP e Gateway
read -p "Digite o novo IP (ex: 192.168.15.100 ou 192.168.15.100/24): " IP_INPUT
read -p "Digite o Gateway (ex: 192.168.15.1): " GATEWAY

# Adiciona /24 se mascara nao informada
if [[ "$IP_INPUT" != */* ]]; then
  IP="$IP_INPUT/24"
else
  IP="$IP_INPUT"
fi

NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE=$(ls $NETPLAN_DIR | grep -E '\.ya?ml$' | head -1)

if [ -z "$NETPLAN_FILE" ]; then
  echo "Arquivo Netplan nao encontrado em $NETPLAN_DIR"
  exit 1
fi

NETPLAN_PATH="$NETPLAN_DIR/$NETPLAN_FILE"

# Detectar interface (primeira interface dentro da chave ethernets)
INTERFACE=$(awk '/ethernets:/ {getline; print $1}' $NETPLAN_PATH | sed 's/://')

if [ -z "$INTERFACE" ]; then
  echo "Nao foi possivel detectar a interface no arquivo $NETPLAN_PATH"
  exit 1
fi

echo "Interface detectada: $INTERFACE"
echo "Atualizando $NETPLAN_PATH..."

# Remove configuracao dhcp4 e adiciona IP estatico
awk -v iface="$INTERFACE" -v ip="$IP" -v gw="$GATEWAY" '
  BEGIN {in_iface=0}
  {
    if ($0 ~ iface":") { print; in_iface=1; next }
    if (in_iface && $1 ~ /dhcp4:/) {
      print "      dhcp4: no"
      print "      addresses: [" ip "]"
      print "      gateway4: " gw
      print "      nameservers:"
      print "        addresses: [8.8.8.8, 1.1.1.1]"
      in_iface=0
      next
    }
    print
  }
' $NETPLAN_PATH > $NETPLAN_PATH.tmp && mv $NETPLAN_PATH.tmp $NETPLAN_PATH

echo "Configuracao atualizada no arquivo Netplan."

echo "A nova configuracao sera aplicada somente apos o reboot do servidor."
echo "Para aplicar agora, rode manualmente: sudo netplan apply"
}

function config_etchosts() {
# Adiciona entradas do ambiente Zabbix no /etc/hosts

echo "" >> /etc/hosts
echo "# Entradas Zabbix" >> /etc/hosts
echo "192.168.15.100 srvzbxdb" >> /etc/hosts
echo "192.168.15.101 srvzbxserver" >> /etc/hosts
echo "192.168.15.102 srvzbxweb" >> /etc/hosts
echo "192.168.15.103 srvzbxprx01" >> /etc/hosts
echo "192.168.15.104 srvzbxprx02" >> /etc/hosts
echo "192.168.15.105 srvgrafana" >> /etc/hosts

echo "Entradas adicionadas no /etc/hosts!"
}

function main_menu() {
  clear
  echo "=== Instalacao Zabbix 7.x ==="
  echo "1) Instalar Zabbix Server"
  echo "2) Instalar Banco de Dados (PostgreSQL)"
  echo "3) Instalar Zabbix Frontend (WEB)"
  echo "4) Instalar Zabbix Proxy e Agent2 (Proxy)"
  echo "5) Instalar Grafana (opcional)"
  echo "6) Configura IP (opcional)"
  echo "7) Configura ETChosts (opcional)"
  echo "0) Sair"
  echo "============================="
  read -p "Escolha uma opcao: " choice

  case "$choice" in
    1) install_zabbix_server ;;
    2) install_zabbix_db ;;
    3) install_zabbix_web ;;
    4) install_proxy_agent2 ;;
    5) install_grafana ;;
    6) config_ip ;;
    7) config_etchosts ;;
    0) exit 0 ;;
    *) echo "Opcao invalida." ;;
  esac
}

main_menu