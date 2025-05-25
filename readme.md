# Zabbix Network Monitoring Project

This project implements network monitoring of a home environment using Zabbix and Wireshark. The goal is to monitor key network characteristics like performance and stability while applying networking concepts through tool configuration.

## Network Environment

The monitored network consists of:

- **Notebook (Zabbix Server)**
  - OS: Fedora Linux 41 
  - IP: 192.168.0.44 (DHCP)
  - Hardware: Dell Latitude 4000, Intel Core i5, 16GB RAM

- **CentOS7 VM (Zabbix Agent)**
  - OS: CentOS 7
  - IP: 192.168.0.83 (DHCP), 10.0.2.15 (NAT)
  - Role: Monitored host

- **Smartphone (Unmonitored)**
  - OS: Android 14
  - IP: 192.168.0.4 (DHCP)
  - Hardware: Samsung Galaxy S21fe

- **Router**
  - Model: Arris TG1692A
  - IP: 192.168.0.1
  - Role: Internet gateway

## Installation

### Prerequisites

```bash
# Install Docker and Docker Compose
sudo dnf install docker docker-compose

# Clone Zabbix docker repository
git clone https://github.com/zabbix/zabbix-docker.git
```

### Deploying Zabbix Server

```bash
# Start Zabbix containers
cd zabbix-docker
sudo docker compose -f ./docker-compose_v3_alpine_mysql_latest.yaml up -d
```

Access the web interface at: http://server-ip/zabbix
- Default login: Admin
- Default password: zabbix

### Installing Zabbix Agent

```bash
# Add Zabbix repository
rpm -Uvh https://repo.zabbix.com/zabbix/6.4/rhel/7/x86_64/zabbix-release-6.4-1.el7.noarch.rpm

# Install agent
yum install -y zabbix-agent

# Configure agent
vi /etc/zabbix/zabbix_agentd.conf
# Set Server=<zabbix-server-ip>
# Set Hostname=<agent-hostname>

# Open firewall port
firewall-cmd --permanent --add-port=10050/tcp
firewall-cmd --reload

# Start agent
systemctl start zabbix-agent
systemctl enable zabbix-agent
```

## Monitored Metrics

The following metrics are monitored according to the SLA:

- Network uptime (>95% monthly)
- CPU usage 
- Internal connectivity
- Network traffic
- Disk usage/IO
- Memory usage

## Tools Used

- **Zabbix**: Main monitoring platform
- **Wireshark**: Network packet analysis
- **Docker**: Container deployment
- **VirtualBox/Vagrant**: VM management

## Project Structure

```
.
├── zabbix-docker/           # Zabbix container configurations
├── compose.yaml            # Main docker-compose file
├── .env                    # Environment variables
└── README.md              # This file
```

## Contributing

This is an academic project for the Network Administration and Management course at UFSC (Federal University of Santa Catarina).

## Author

Abmael Batista da Silva
Systems Information Student - UFSC
April 2025

## License

This project is licensed under standard terms for academic work at UFSC.

