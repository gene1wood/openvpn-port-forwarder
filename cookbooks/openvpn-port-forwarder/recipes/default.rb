#
# Cookbook:: openvpn-port-forwarder
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

directory '/root/.ssh' do
  mode '0600'
end

file '/root/.ssh/authorized_keys' do
  content node['ssh_public_key']
end

package 'epel-release'

package 'base OS packages' do
  package_name %w[
    net-tools
    openvpn
    easy-rsa
    iptables-services
    policycoreutils-python
  ]
end

# https://www.digitalocean.com/community/tutorials/how-to-setup-and-configure-an-openvpn-server-on-centos-7
# https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-16-04

service 'sshd'

template '/etc/ssh/sshd_config' do
  source name[1..-1] + ".erb"
  variables({
                :port => node['sshd']['port']
            })
  notifies :reload, 'service[sshd]', :delayed
end

execute 'semanage sshd port' do
  command "/usr/sbin/semanage port --add --type ssh_port_t --proto tcp #{node['sshd']['port']}"
  not_if "/usr/sbin/semanage port --list --locallist | egrep '^ssh_port_t\s+tcp\s+#{node['sshd']['port']}$'"
end

# Setup a CA

directory '/etc/openvpn/easy-rsa'

for filename in %w[
  build-ca
  build-dh
  build-inter
  build-key
  build-key-pass
  build-key-pkcs12
  build-key-server
  build-req
  build-req-pass
  clean-all
  inherit-inter
  list-crl
  pkitool
  revoke-full
  sign-req
  whichopensslcnf
  openssl-1.0.0.cnf
] do
  link "/etc/openvpn/easy-rsa/#{filename}" do
    to "/usr/share/easy-rsa/2.0/#{filename}"
  end
end

directory '/etc/openvpn/easy-rsa/keys'

template '/etc/openvpn/easy-rsa/vars' do
  source name[1..-1] + ".erb"
end

link '/etc/openvpn/easy-rsa/openssl.cnf' do
  to '/usr/share/easy-rsa/2.0/openssl-1.0.0.cnf'
end

file '/etc/openvpn/easy-rsa/keys/index.txt' do
  not_if { ::File.exist?('/etc/openvpn/easy-rsa/keys/index.txt') }
end
file '/etc/openvpn/easy-rsa/keys/serial' do
  content '01'
  not_if { ::File.exist?('/etc/openvpn/easy-rsa/keys/serial') }
end

bash 'build_ca' do
  cwd '/etc/openvpn/easy-rsa'
  code <<-EOH
    source /etc/openvpn/easy-rsa/vars
    /etc/openvpn/easy-rsa/pkitool --initca ca
  EOH
  creates '/etc/openvpn/easy-rsa/keys/ca.key'
end

link '/etc/openvpn/ca.crt' do
  to '/etc/openvpn/easy-rsa/keys/ca.crt'
end

bash 'build_key_server' do
  cwd '/etc/openvpn/easy-rsa'
  code <<-EOH
    source /etc/openvpn/easy-rsa/vars
    /etc/openvpn/easy-rsa/pkitool --server server
  EOH
  creates '/etc/openvpn/easy-rsa/keys/server.key'
end

link '/etc/openvpn/server.crt' do
  to '/etc/openvpn/easy-rsa/keys/server.crt'
end

link '/etc/openvpn/server.key' do
  to '/etc/openvpn/easy-rsa/keys/server.key'
end

bash 'build_dh' do
  cwd '/etc/openvpn/easy-rsa'
  code <<-EOH
    source /etc/openvpn/easy-rsa/vars
    /etc/openvpn/easy-rsa/build-dh
  EOH
  creates '/etc/openvpn/easy-rsa/keys/dh2048.pem'
end

link '/etc/openvpn/dh2048.pem' do
  to '/etc/openvpn/easy-rsa/keys/dh2048.pem'
end

execute 'build_ta' do
  command '/usr/sbin/openvpn --genkey --secret /etc/openvpn/ta.key'
  creates '/etc/openvpn/ta.key'
end

# Openvpn server

template '/etc/openvpn/server.conf' do
  source name[1..-1] + ".erb"
  mode '0644'
end

# Create openvpn clients

bash 'build_client' do
  cwd '/etc/openvpn/easy-rsa'
  code <<-EOH
    source /etc/openvpn/easy-rsa/vars
    /etc/openvpn/easy-rsa/pkitool #{node['openvpn']['client_name']}
  EOH
  creates "/etc/openvpn/easy-rsa/keys/#{node['openvpn']['client_name']}.key"
end

directory '/etc/openvpn/ccd'

file "/etc/openvpn/ccd/#{node['openvpn']['client_name']}" do
  content "ifconfig-push #{node['openvpn']['client_ip']} #{node['openvpn']['client_gateway']}"
end

file "/etc/openvpn/ipp.txt" do
  content "#{node['openvpn']['client_name']},#{node['openvpn']['client_ip']}"
end

# Firewall and routing

systemd_unit 'firewalld' do
  action [:mask]
end

service 'iptables' do
  action [:enable]
end

service 'firewalld' do
  action [:stop]
end

service 'iptables' do
  action [:start]
end

template '/etc/sysconfig/iptables' do
  source name[1..-1] + ".erb"
  variables({
                :sshd_port_under => node['sshd']['port'] - 1,
                :sshd_port_over => node['sshd']['port'] + 1
            })
  notifies :reload, 'service[iptables]', :delayed
end

execute "sysctl --system" do
  action :nothing
end

file '/etc/sysctl.d/30-enable-ip-forwarding.conf' do
  content 'net.ipv4.ip_forward = 1'
  notifies :run, 'execute[sysctl --system]', :immediately
end

systemd_unit 'openvpn@server' do
  action [:enable, :start]
end

template '/etc/openvpn/client.ovpn' do
  source name[1..-1] + ".erb"
end

template '/etc/openvpn/next_steps.md' do
  source name[1..-1] + ".erb"
end
