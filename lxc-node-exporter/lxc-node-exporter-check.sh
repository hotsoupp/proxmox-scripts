#!/bin/bash

# Get a list of all LXC containers
containers=$(pct list | awk '{print $1}' | sed -n '2,$p')

echo "Checking Node Exporter version for all LXC containers..."

# Loop through all LXC containers
for container in $containers
do
  echo "Checking container $container..."

  # Check if Node Exporter is already installed in the container
  if pct exec $container -- stat -c '%A' /usr/local/bin/node_exporter 2>/dev/null | grep -q 'x'; then
    # Get the installed version from the container
    INSTALLED_VERSION=$(pct exec $container -- ls /usr/local/bin | grep -oP "node_exporter-\Kv[0-9.]+")

    echo "Node Exporter is installed in container $container (version $INSTALLED_VERSION)."
  else
    echo "Node Exporter is not installed in container $container."
  fi
done
