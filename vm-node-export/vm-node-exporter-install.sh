#!/bin/bash

# Determine the distribution of the host
if [[ -e /etc/os-release ]]; then
  . /etc/os-release
  if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
    # Update the host
    sudo apt-get update && sudo apt-get upgrade -y

    # Check if curl is installed, and install it if it's not
    if ! command -v curl > /dev/null 2>&1; then
      echo "Installing curl..."
      sudo apt-get install -y curl
    fi
  else
    echo "Unsupported distribution. Exiting script."
    exit 1
  fi
else
  echo "Operating system release file not found. Exiting script."
  exit 1
fi

# Check if the prometheus user exists, and create it if it doesn't
if ! id prometheus > /dev/null 2>&1; then
  echo "Creating prometheus user..."
  sudo useradd --no-create-home --shell /bin/false prometheus
fi

# Download the latest release of Node Exporter for amd64 from GitHub
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4)

# Remove the old version file, if it exists
sudo rm -f /usr/local/bin/node_exporter-v*

# Create a file without an extension that has the version in its name
sudo touch "/usr/local/bin/node_exporter"

sudo wget $DOWNLOAD_URL -O /tmp/node_exporter.tar.gz

# Extract the Node Exporter binary
sudo tar xzf /tmp/node_exporter.tar.gz --strip-components=1 -C /tmp

# Copy the Node Exporter binary
sudo mv /tmp/node_exporter /usr/local/bin/node_exporter

# Set the owner of the Node Exporter binary to prometheus:prometheus
sudo chown prometheus:prometheus /usr/local/bin/node_exporter

# Create a systemd service for Node Exporter
cat <<EOFS | sudo tee /etc/systemd/system/node_exporter.service
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
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

echo "Prometheus Node Exporter installed on the host."
