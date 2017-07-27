# Pre Chef Setup

* Change root user password

      passwd
* Get chefdk

      rpm -ivh https://packages.chef.io/files/stable/chefdk/2.0.28/el/7/chefdk-2.0.28-1.el7.x86_64.rpm
* Setup

      mkdir /root/repo
      mkdir -p /opt/chef/cookbooks
      yum install -y git
      git clone https://github.com/gene1wood/openvpn-port-forwarder /root/repo
      # create a /root/node.json file with any customizations
      /root/repo/run-chef.sh

# From the client

https://www.digitalocean.com/community/tutorials/how-to-setup-and-configure-an-openvpn-server-on-centos-7

Instructions on how to provision the client will be placed in a document on the server

    /etc/openvpn/next_steps.md
