#!bin/bash

#####################################################read me################################################################################################
#This scripts was used for install neutron and it will verify all function installed,this scripts will create net,subnet,router for admin and demo user,while 
#a admin-instance using cirros image
#this scripts was enhanced by shan jin xiao at 2015/11/17
#shanjinxiao@cmbchina.com
###########################################################################################################################################################


NAMEHOST=`hostname`
HOSTNAME=`hostname`
#log function
NAMEHOST=$HOSTNAME
function log_info ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/neutron.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/neutron.log

}

function fn_log ()  {
if [  $? -eq 0  ]
then
	log_info "$@ sucessed."
	echo -e "\033[32m $@ sucessed. \033[0m"
else
	log_error "$@ failed."
	echo -e "\033[41;37m $@ failed. \033[0m"
	exit
fi
}
if [ -f  /etc/openstack-kilo_tag/install_cinder.tag ]
then 
	log_info "cinder have installed ."
else
	echo -e "\033[41;37m you should install cinder first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-kilo_tag/install_neutron.tag ]
then 
	echo -e "\033[41;37m you haved install neutron \033[0m"
	log_info "you haved install neutron."	
	exit
fi
#create neutron databases 
function  fn_create_neutron_database () {
mysql -uroot -proot -e "CREATE DATABASE neutron;" &&  mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'NEUTRON_DBPASS';" && mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'NEUTRON_DBPASS';" 
fn_log "create  database neutron"
}
mysql -uroot -proot -e "show databases ;" >test 
DATABASENEUTRON=`cat test | grep neutron`
rm -rf test 
if [ ${DATABASENEUTRON}x = neutronx ]
then
	log_info "neutron database had installed."
else
	fn_create_neutron_database
fi

#unset http_proxy https_proxy ftp_proxy no_proxy 

source /root/adminrc
USER_NEUTRON=`openstack user list | grep neutron | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_NEUTRON}x = neutronx ]
then
	log_info "openstack user had created  neutron"
else
	openstack user create --domain default neutron  --password neutron
	fn_log "openstack user create --domain default neutron  --password neutron"
	openstack role add --project service --user neutron admin
	fn_log "openstack role add --project service --user neutron admin"
fi

SERVICE_NEUTRON=`openstack service list | grep neutron | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_NEUTRON}x = neutronx ]
then 
	log_info "openstack service create neutron."
else
	openstack service create --name neutron --description "OpenStack Networking" network
	fn_log "openstack service create --name neutron --description "OpenStack Networking" network"
fi

ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep network  |grep internal | wc -l`
ENDPOINT_LIST_provider=`openstack endpoint list | grep network   |grep provider | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep network   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 0  ]  && [ ${ENDPOINT_LIST_provider}  -eq  0   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 0  ]
then
	openstack endpoint create --region RegionOne   network public http://${NAMEHOST}:9696  &&   openstack endpoint create --region RegionOne   network internal http://${NAMEHOST}:9696 &&   openstack endpoint create --region RegionOne   network admin http://${NAMEHOST}:9696
	fn_log "openstack endpoint create --region RegionOne   network provider http://${NAMEHOST}:9696  &&   openstack endpoint create --region RegionOne   network internal http://${NAMEHOST}:9696 &&   openstack endpoint create --region RegionOne   network admin http://${NAMEHOST}:9696"
else	
	log_info "openstack endpoint create neutron."
fi



if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info " we will use local yum repo and that's all ready"
else 
	echo "please make local yum repo"
	exit
fi


yum clean all && yum install openstack-neutron openstack-neutron-ml2   openstack-neutron-linuxbridge ebtables -y
fn_log "yum clean all && yum install openstack-neutron openstack-neutron-ml2 python-neutronclient  which  -y"

[ -f /etc/neutron/neutron.conf_bak ] || cp -a  /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak 

openstack-config --set  /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT core_plugin  ml2 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT service_plugins  router 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips  True 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes  True 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes  True 
# openstack-config --set  /etc/neutron/neutron.conf DEFAULT nova_url  http://${NAMEHOST}:8774/v2 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone

openstack-config --set  /etc/neutron/neutron.conf database connection   mysql+pymysql://neutron:NEUTRON_DBPASS@${NAMEHOST}/neutron 

openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host  ${NAMEHOST}
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack 
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  openstack 
 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://${NAMEHOST}:5000 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://${NAMEHOST}:35357 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken memcached_servers  ${NAMEHOST}:11211 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_type  password  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_name  default  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_name  default 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  service 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  neutron

openstack-config --set  /etc/neutron/neutron.conf nova auth_url  http://${NAMEHOST}:35357  
openstack-config --set  /etc/neutron/neutron.conf nova auth_type  password  
openstack-config --set  /etc/neutron/neutron.conf nova project_domain_name  default 
openstack-config --set  /etc/neutron/neutron.conf nova user_domain_name  default  
openstack-config --set  /etc/neutron/neutron.conf nova region_name  RegionOne 
openstack-config --set  /etc/neutron/neutron.conf nova project_name  service
openstack-config --set  /etc/neutron/neutron.conf nova username  nova  
openstack-config --set  /etc/neutron/neutron.conf nova password nova 
openstack-config --set  /etc/neutron/neutron.conf oslo_concurrency lock_path  /var/lib/neutron/tmp
# openstack-config --set  /etc/neutron/neutron.conf nova auth_url  http://${NAMEHOST}:35357 
# openstack-config --set  /etc/neutron/neutron.conf nova auth_plugin  password 
# openstack-config --set  /etc/neutron/neutron.conf nova project_domain_id  default 
# openstack-config --set  /etc/neutron/neutron.conf nova user_domain_id  default 
# openstack-config --set  /etc/neutron/neutron.conf nova region_name  RegionOne 
# openstack-config --set  /etc/neutron/neutron.conf nova project_name  service 
# openstack-config --set  /etc/neutron/neutron.conf nova username  nova 
# openstack-config --set  /etc/neutron/neutron.conf nova password  nova
# openstack-config --set  /etc/neutron/neutron.conf DEFAULT verbose  True 
# openstack-config --set  /etc/neutron/neutron.conf DEFAULT debug  True



fn_log "config /etc/neutron/neutron.conf"
[ -f /etc/neutron/plugins/ml2/ml2_conf.ini_bak  ] || cp -a  /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini_bak
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers  flat,vlan,vxlan 
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers  linuxbridge,l2population 
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers  port_security 
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types  vxlan 
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks  provider
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges  1:1000 
openstack-config --set   /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True

# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers  flat,vlan,gre,vxlan 
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types  gre 
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers  openvswitch 
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges  1:1000 
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group  True 
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True 
# openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver 

fn_log "config /etc/neutron/plugins/ml2/ml2_conf.ini"

# rm -rf /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
# fn_log "ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini"

read -p "please choose your management IP NIC on controler node[default first NIC]:" NIC_NUM
if [ -z ${NIC_NUM} ]
then
	echo "use default the first NIC as your nova management IP"
	NIC_NUM=1 
fi
MANAGE_NIC_NAME=$(ip addr | grep ^`expr ${NIC_NUM} + 1`: |awk -F ":" '{print$2}')
MANAGE_NIC_IP=$(ifconfig ${MANAGE_NIC_NAME}  | grep netmask | awk -F " " '{print$2}')

read -p "please choose your neutron ext-net physical NIC[default first NIC]:" NIC_NUM
if [ -z ${NIC_NUM} ]
then
	echo "use default the first NIC as your nova management IP"
	NIC_NUM=1 
fi
EXT_NET_NIC_NAME=$(ip addr | grep ^`expr ${NIC_NUM} + 1`: |awk -F ":" '{print$2}')
EXT_NET_NIC_IP=$(ifconfig ${TUNNEL_NIC_NAME}  | grep netmask | awk -F " " '{print$2}')
echo "the ext_net nic name is: ${EXT_NET_NIC_NAME}"

[ -f  /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak ] || cp -a   /etc/neutron/plugins/ml2/linuxbridge_agent.ini   /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  linux_bridge physical_interface_mappings  provider:"${EXT_NET_NIC_NAME}"
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan  enable_vxlan  True 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan  local_ip  ${MANAGE_NIC_IP} 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini  vxlan l2_population  True 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  enable_security_group  True 
openstack-config --set   /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup  firewall_driver  neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
fn_log "config /etc/neutron/plugins/ml2/linuxbridge_agent.ini"

[ -f   /etc/neutron/l3_agent.ini_bak ] || cp -a    /etc/neutron/l3_agent.ini    /etc/neutron/l3_agent.ini_bak 
openstack-config --set  /etc/neutron/l3_agent.ini  DEFAULT     interface_driver  neutron.agent.linux.interface.BridgeInterfaceDriver 
openstack-config --set   /etc/neutron/l3_agent.ini  DEFAULT     external_network_bridge    
openstack-config --set  /etc/neutron/l3_agent.ini  DEFAULT     verbose  True  
fn_log "config /etc/neutron/l3_agent.ini "

[ -f   /etc/neutron/dhcp_agent.ini_bak ] || cp -a    /etc/neutron/dhcp_agent.ini    /etc/neutron/dhcp_agent.ini_bak 
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     interface_driver  neutron.agent.linux.interface.BridgeInterfaceDriver   
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     dhcp_driver  neutron.agent.linux.dhcp.Dnsmasq  
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     enable_isolated_metadata  True   
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     verbose  True   
fn_log "config /etc/neutron/dhcp_agent.ini "

openstack-config --set  /etc/nova/nova.conf  neutron url  http://${NAMEHOST}:9696
openstack-config --set  /etc/nova/nova.conf  neutron auth_url  http://${NAMEHOST}:35357
openstack-config --set  /etc/nova/nova.conf  neutron auth_type  password 
openstack-config --set  /etc/nova/nova.conf  neutron project_domain_name  default 
openstack-config --set  /etc/nova/nova.conf  neutron user_domain_name  default 
openstack-config --set  /etc/nova/nova.conf  neutron region_name  RegionOne 
openstack-config --set  /etc/nova/nova.conf  neutron project_name service
openstack-config --set  /etc/nova/nova.conf  neutron username  neutron 
openstack-config --set  /etc/nova/nova.conf  neutron password  neutron
openstack-config --set  /etc/nova/nova.conf  neutron service_metadata_proxy  True 
openstack-config --set  /etc/nova/nova.conf  neutron metadata_proxy_shared_secret  neutron_shared_secret 
fn_log "config /etc/nova/nova.conf"


echo "dhcp-option-force=26,1450" >/etc/neutron/dnsmasq-neutron.conf
fn_log "echo "dhcp-option-force=26,1450" >/etc/neutron/dnsmasq-neutron.conf"
[ -f /etc/neutron/metadata_agent.ini_bak-2 ] || cp -a  /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini_bak-2 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT nova_metadata_ip  ${NAMEHOST}   
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT metadata_proxy_shared_secret  neutron_shared_secret
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT verbose  True
fn_log "config /etc/neutron/metadata_agent.ini"

rm -rf /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
fn_log "rm -rf /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini"

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf   --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
fn_log "su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf   --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron"

systemctl restart openstack-nova-api.service
fn_log "systemctl restart openstack-nova-api.service"
systemctl enable neutron-server.service   neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service 
systemctl start neutron-server.service   neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service
fn_log "systemctl enable neutron-server.service   neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service &&  systemctl start neutron-server.service   neutron-linuxbridge-agent.service neutron-dhcp-agent.service   neutron-metadata-agent.service"
systemctl enable neutron-l3-agent.service && systemctl start neutron-l3-agent.service
fn_log "systemctl enable neutron-l3-agent.service && systemctl start neutron-l3-agent.service"

sleep 30




source /root/adminrc
neutron agent-list


source /root/demorc

KEYPAIR=`nova keypair-list | grep  mykey | awk -F " " '{print$2}'`
if [  ${KEYPAIR}x = mykeyx ]
then
	log_info "keypair had added."
else
	ssh-keygen -t dsa -f ~/.ssh/id_dsa -N ""
	fn_log "ssh-keygen -t dsa -f ~/.ssh/id_dsa -N """
	openstack keypair create --public-key ~/.ssh/id_dsa.pub mykey
	fn_log "openstack keypair create --public-key ~/.ssh/id_dsa.pub mykey"
fi

SECRULE=`nova secgroup-list-rules  default | grep 22 | awk -F " " '{print$4}'`
if [ x${SECRULE} = x22 ]
then 
	log_info "port 22 and icmp had add to secgroup."
else
	openstack security group rule create --proto icmp default 
	fn_log "openstack security group rule create --proto icmp default "
	openstack security group rule create --proto tcp --dst-port 22 default
	fn_log "openstack security group rule create --proto tcp --dst-port 22 default"
fi


#creae provider network,called ext-net also
source /root/adminrc
PUBLIC_NET_START=192.168.115.200
PUBLIC_NET_END=192.168.115.250
PUBLIC_NET_GW=192.168.115.254
NEUTRON_DNS=192.168.115.254
NEUTRON_PUBLIC_NET=192.168.115.0/24

PUBLIC_NET=`neutron net-list | grep provider |wc -l`
if [ ${PUBLIC_NET}  -eq 0 ]
then
	neutron net-create --shared --provider:physical_network provider   --provider:network_type flat provider
	fn_log "neutron net-create --shared --provider:physical_network provider   --provider:network_type flat provider"
else
	log_info "provider net is exist."
fi

SUB_PUBLIC_NET=`neutron subnet-list | grep provider |wc -l `
if [ ${SUB_PUBLIC_NET}  -eq 0 ]
then
	neutron subnet-create --name provider  --allocation-pool start=${PUBLIC_NET_START},end=${PUBLIC_NET_END} --dns-nameserver ${NEUTRON_DNS} --gateway ${PUBLIC_NET_GW}  provider ${NEUTRON_PUBLIC_NET}
	fn_log "neutron subnet-create --name provider   --allocation-pool start=${PUBLIC_NET_START},end=${PUBLIC_NET_END}   --dns-nameserver ${NEUTRON_DNS} --gateway ${PUBLIC_NET_GW}    provider ${NEUTRON_PUBLIC_NET}"
else
	log_info "sub_public is exist."
fi


#create selfservice network ,called private network also
source /root/demorc
PRIVATE_NET_DNS=192.168.115.254
PRIVATE_NET_GW=192.168.1.1
NEUTRON_PRIVATE_NET=192.168.1.0/24

PRIVATE_NET=`neutron net-list | grep selfservice |wc -l`
if [ ${PRIVATE_NET}  -eq 0 ]
then
	neutron net-create selfservice
	fn_log "neutron net-create selfservice"
else
	log_info "selfservice net is exist."
fi

#create selfservice subnet
SUB_PRIVATE_NET=`neutron subnet-list | grep selfservice |wc -l`
if [ ${SUB_PRIVATE_NET}  -eq 0 ]
then
	neutron subnet-create --name selfservice   --dns-nameserver ${PRIVATE_NET_DNS} --gateway ${PRIVATE_NET_GW}  selfservice ${NEUTRON_PRIVATE_NET}
	fn_log "neutron subnet-create --name selfservice   --dns-nameserver ${PRIVATE_NET_DNS}--gateway ${PRIVATE_NET_GW}  selfservice ${NEUTRON_PRIVATE_NET}"
else
	log_info "selfservice subnet is exist."
fi

source /root/adminrc
ROUTE_VALUE=`neutron net-show provider | grep router:external | awk -F " "  '{print$4}'`
if [ ${ROUTE_VALUE}x  = Truex  ]
then
	log_info "the value had changed."
else
	neutron net-update provider --router:external
	fn_log "neutron net-update provider --router:external"
fi

#bing selfservice to provider by router
source /root/demorc
ROUTE_NU=`neutron router-list | grep router | wc -l`
if [ ${ROUTE_NU}  -eq 0 ]
then
	neutron router-create router
	fn_log "neutron router-create router"
	neutron router-interface-add router selfservice
	fn_log "neutron router-interface-add router selfservice"
	neutron router-gateway-set router provider
	fn_log "neutron router-gateway-set router provider"
else
	log_info "router had created."
fi

source /root/adminrc
ip netns
fn_log "ip netns"
neutron net-list
neutron subnet-list
neutron router-port-list router
fn_log "neutron router-port-list router"


#restart all relative service
systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl restart libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service "
systemctl restart neutron-dhcp-agent  neutron-l3-agent  neutron-linuxbridge-agent  neutron-metadata-agent neutron-server
fn_log "systemctl restart neutron-dhcp-agent  neutron-l3-agent  neutron-linuxbridge-agent  neutron-metadata-agent neutron-server"
systemctl restart  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
fn_log "systemctl restart  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service"


# nova list |grep admin-instance1
# if [ $? -eq 0 ]
# then
# echo "instance admin-instance1 already created!"
# else
# echo "*****************create instance with admin user************************************"
# net_id=$(neutron net-list|grep admin-net|awk -F "|" '{print $2}'|awk '{print $1}')
# image=$(nova image-list|grep cirros|awk -F "|" '{print $3}'|awk '{print $1}')
# flavor=1
# sg=default
# key=admin-key
# name=admin-instance1

# nova boot --image ${image} --flavor ${flavor} --nic net-id=${net_id} --security-group ${sg} --key-name ${key} ${name}
# fn_log "nova boot instance"
# nova list
# echo"*******************create instance finish******************************************"
# fi
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_neutron.tag
echo -e "\033[32m ################################# \033[0m"
echo -e "\033[32m ##  install neutron sucessed.#### \033[0m"
echo -e "\033[32m ################################# \033[0m"

















