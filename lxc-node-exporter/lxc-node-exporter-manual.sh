#!/bin/bash

# Prompt the user for the container ID
read -p "Enter the container ID: " container

echo "Updating and checking prerequisites on container $container..."

# Check if Node Exporter is already installed in the container
if pct exec $container -- stat -c '%A' /usr/local/bin/node_exporter 2>/dev/null | grep -q 'x'; then
  echo "Node Exporter is already installed. Do you want to replace it with the latest version? (Y/N)"
  read -r yn
  case $yn in
    [Yy]* ) ;;
    [Nn]* ) exit;;
    * ) echo "Please answer Y or N."; exit;;
  esac
fi

# Execute multiple commands within a single pct invocation using a heredoc
pct exec $container /bin/bash <<EOF
# Determine whether the container is running Debian or Ubuntu
. /etc/os-release
if [[ "\$ID" == "debian" || "\$ID" == "ubuntu" ]]; then
  # Update the container
  apt-get update && apt-get upgrade -y

  # Check if curl is installed, and install it if it's not
  if ! command -v curl > /dev/null 2>&1; then
    echo "Installing curl..."
    apt-get install -y curl
  fi
else
  echo "Unsupported distribution. Exiting."
  exit 1
fi

# Check if the prometheus user exists, and create it if it doesn't
if ! id prometheus > /dev/null 2>&1; then
  echo "Creating prometheus user..."
  useradd --no-create-home --shell /bin/false prometheus
fi

# Download the latest release of Node Exporter for amd64 from GitHub
DOWNLOAD_URL=\$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4)
wget \$DOWNLOAD_URL -O /tmp/node_exporter.tar.gz

# Extract the Node Exporter binary
tar xzf /tmp/node_exporter.tar.gz --strip-components=1 -C /tmp

# Copy the Node Exporter binary
mv /tmp/node_exporter /usr/local/bin/node_exporter

# Set the owner of the Node Exporter binary to prometheus:prometheus
chown prometheus:prometheus /usr/local/bin/node_exporter

# Create a systemd service for Node Exporter
cat <<EOFS > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOFS

# Reload systemd and start Node Exporter
systemctl daemon-reload
systemctl restart node_exporter
systemctl enable node_exporter

echo "Prometheus Node Exporter installed or updated."
EOF

echo "Container $container has been updated."