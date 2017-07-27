#!/bin/bash

JSON_ATTRIBUTES="/root/node.json"

if test ! -e "$JSON_ATTRIBUTES"; then
  echo "missing $JSON_ATTRIBUTES"
  echo "proceeding with no customizations"
  CHEF_CLIENT_ARGS=""
else
  CHEF_CLIENT_ARGS="--json-attributes $JSON_ATTRIBUTES"
fi

if ! rpm -q chefdk >/dev/null; then
  echo "missing chefdk. Exiting"
  exit 1
fi

BERKSHELF_PATH=/root/.berkshelf berks install --berksfile=/root/repo/cookbooks/openvpn-port-forwarder/Berksfile
BERKSHELF_PATH=/root/.berkshelf berks vendor --berksfile=/root/repo/cookbooks/openvpn-port-forwarder/Berksfile /opt/chef/cookbooks
ln -s /root/repo/cookbooks/openvpn-port-forwarder /opt/chef/cookbooks/openvpn-port-forwarder
(cd /opt/chef/cookbooks && chef-client -z --log_level warn -r openvpn-port-forwarder $CHEF_CLIENT_ARGS $*)
