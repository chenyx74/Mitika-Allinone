#!bin/bash
####################################################################read me #############################################################################
#This script used for install nova,if you will ,you can install all nova service on controler node.The mariadb user is nova,and the password is NOVA_DBPASS.
#the keystone user is nova and the password is nova also.
#This script enhanced by shan jin xiao at 2015/11/12
#shanjinxiao@cmbchina.com
#############################################################################################################################################################

#log function
NAMEHOST=`hostname`
HOSTNAME=`hostname`
function log_info ()
{
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/nova.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/nova.log

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
if [ -f  /etc/openstack-kilo_tag/install_glance.tag ]
then 
	log_info "glance have installed ."
else
	echo -e "\033[41;37m you should install glance first. \033[0m"
	exit
fi


if [ -f  /etc/openstack-kilo_tag/install_nova.tag ]
then 
	echo -e "\033[41;37m you haved install nova \033[0m"
	log_info "you haved install nova."	
	exit
fi
#unset http_proxy https_proxy ftp_proxy no_proxy 
#create nova databases 
function  fn_create_nova_database () {
mysql -uroot -proot -e "CREATE DATABASE nova;" 
mysql -uroot -proot -e "CREATE DATABASE nova_api;" 
mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';" && mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';" 
mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';" && mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';" 

fn_log "create nova databases"
}
mysql -uroot -proot -e "show databases ;" >test 
DATABASENOVA=`cat test | grep nova`
rm -rf test 
if [ ${DATABASENOVA}x = novax ]
then
	log_info "nova database had installed."
else
	fn_create_nova_database
fi


source /root/adminrc 

#create user nova
USER_NOVA=`openstack user list | grep nova | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_NOVA}x = novax ]
then
	log_info "openstack user had created  nova"
else
	openstack user create --domain default  nova --password nova
	fn_log "openstack user create  nova  --password nova"
	openstack role add --project service --user nova admin
	fn_log "openstack role add --project service --user nova admin"
fi


#create service nova
SERVICE_NOVA=`openstack service list | grep nova | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_NOVA}x = novax ]
then 
	log_info "openstack service create nova."
else
	openstack service create --name nova --description "OpenStack Compute" compute
	fn_log "openstack service create --name nova --description "OpenStack Compute" compute"
fi

#create endpoint api
ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep compute  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep compute   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep compute   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]
then
	log_info "openstack endpoint create nova."
else
	openstack endpoint create --region RegionOne   compute public http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   compute internal http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   compute admin http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s
	fn_log "openstack endpoint create --region RegionOne   compute public http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   compute internal http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   compute admin http://${HOSTNAME}:8774/v2.1/%\(tenant_id\)s"
fi




if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info " we will use local yum repository and that's all ready!"
else 
	echo "please make local yum repository firstly!"
	exit
fi

yum clean all && yum install openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler  -y
fn_log "yum clean all && yum install openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler python-novaclient -y"
#unset http_proxy https_proxy ftp_proxy no_proxy 

read -p "please choose your nova-controler node management NIC number[default first NIC]:" NIC_NUM
if [ -z ${NIC_NUM} ]
then
	echo "use default the first NIC as your nova management IP"
	NIC_NUM=1
fi
NIC_NAME=$(ip addr | grep ^`expr ${NIC_NUM} + 1`: |awk -F ":" '{print$2}')
NIC_IP=$(ifconfig ${NIC_NAME}  | grep netmask | awk -F " " '{print$2}')


[ -f /etc/nova/nova.conf_bak ]  || cp -a /etc/nova/nova.conf /etc/nova/nova.conf_bak

openstack-config --set  /etc/nova/nova.conf DEFAULT enabled_apis  osapi_compute,metadata  
openstack-config --set  /etc/nova/nova.conf DEFAULT rpc_backend  rabbit 
openstack-config --set  /etc/nova/nova.conf DEFAULT my_ip ${NIC_IP}
openstack-config --set  /etc/nova/nova.conf DEFAULT use_neutron True  
openstack-config --set  /etc/nova/nova.conf DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver
 
openstack-config --set  /etc/nova/nova.conf vnc vncserver_listen  ${NIC_IP} 
openstack-config --set  /etc/nova/nova.conf vnc vncserver_proxyclient_address  ${NIC_IP} 

openstack-config --set  /etc/nova/nova.conf api_database connection   mysql+pymysql://nova:NOVA_DBPASS@${NAMEHOST}/nova_api 
openstack-config --set  /etc/nova/nova.conf database connection   mysql+pymysql://nova:NOVA_DBPASS@${NAMEHOST}/nova

openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host  ${NAMEHOST}
openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid  openstack   
openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password  openstack 
openstack-config --set  /etc/nova/nova.conf DEFAULT auth_strategy  keystone 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_uri  http://${NAMEHOST}:5000 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_url  http://${NAMEHOST}:35357 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken memcached_servers   ${HOSTNAME}:11211 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_type   password 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_domain_name   default 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken user_domain_name   default 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_name  service 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken username  nova 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken password  nova 

openstack-config --set  /etc/nova/nova.conf glance api_servers  http://${HOSTNAME}:9292
openstack-config --set  /etc/nova/nova.conf oslo_concurrency lock_path  /var/lib/nova/tmp 


fn_log "openstack-config --set  /etc/nova/nova.conf database connection  mysql://nova:NOVA_DBPASS@${NAMEHOST}/nova && openstack-config --set  /etc/nova/nova.conf DEFAULT rpc_backend  rabbit &&  openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host  ${NAMEHOST} && openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid  openstack   && openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password  openstack && openstack-config --set  /etc/nova/nova.conf DEFAULT auth_strategy  keystone && openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_uri  http://${NAMEHOST}:5000 && openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_url  http://${NAMEHOST}:35357 && openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_plugin  password && openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_domain_id  default && openstack-config --set  /etc/nova/nova.conf keystone_authtoken user_domain_id  default &&  openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_name  service && openstack-config --set  /etc/nova/nova.conf keystone_authtoken username  nova && openstack-config --set  /etc/nova/nova.conf keystone_authtoken password  nova && openstack-config --set  /etc/nova/nova.conf DEFAULT my_ip ${NIC_IP} && openstack-config --set  /etc/nova/nova.conf DEFAULT vncserver_listen  ${NIC_IP} && openstack-config --set  /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address  ${NIC_IP} && openstack-config --set  /etc/nova/nova.conf DEFAULT verbose  True && openstack-config --set  /etc/nova/nova.conf glance host  ${NAMEHOST} && openstack-config --set  /etc/nova/nova.conf oslo_concurrency lock_path  /var/lib/nova/tmp && openstack-config --set  /etc/nova/nova.conf DEFAULT vnc_enabled  True && openstack-config --set  /etc/nova/nova.conf  DEFAULT   vncserver_listen  0.0.0.0"

su -s /bin/sh -c "nova-manage api_db sync" nova
fn_log "su -s /bin/sh -c "nova-manage api_db sync" nova"
su -s /bin/sh -c "nova-manage db sync" nova
fn_log "su -s /bin/sh -c "nova-manage db sync" nova"

systemctl start  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service  && systemctl enable  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service  
fn_log "systemctl start  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service  && systemctl enable  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service  "


if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info " we will use local yum repo and that's all ready"
else 
	echo "please make local yum repo"
	exit
fi


function If_install-nova-compute(){
	read -p "Are you sure you want install nova-compute on controler node?[yes/no]:" INPUT
	if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
	then
		exit
	elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
	then
		echo "will install nova-compute on controler node"
		yum clean all && yum install openstack-nova-compute  -y
		fn_log "yum clean all && yum install openstack-nova-compute sysfsutils -y"
	else
		If_install-nova-compute
	fi
}
If_install-nova-compute

#unset http_proxy https_proxy ftp_proxy no_proxy 
read -p "please choose your nova-compute nvc listen NIC number[default same as management NIC]:" NIC_NUM
if [ -z ${NIC_NUM} ]
then
	echo "use default the first NIC as your nova management IP"
	NIC_NUM=${NIC_NUM} 
fi
NIC_NAME=$(ip addr | grep ^`expr ${NIC_NUM} + 1`: |awk -F ":" '{print$2}')
NIC_IP=$(ifconfig ${NIC_NAME}  | grep netmask | awk -F " " '{print$2}')

openstack-config --set  /etc/nova/nova.conf vnc vncserver_listen  0.0.0.0  
openstack-config --set  /etc/nova/nova.conf vnc enabled  True  
openstack-config --set  /etc/nova/nova.conf vnc novncproxy_base_url  http://${NIC_IP}:6080/vnc_auto.html
fn_log "openstack-config --set  /etc/nova/nova.conf DEFAULT vnc_enabled  True && openstack-config --set  /etc/nova/nova.conf DEFAULT novncproxy_base_url  http://${NIC_IP}:6080/vnc_auto.html"




HARDWARE=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ ${HARDWARE}  -eq 0 ]
then 
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu 
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
else
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  kvm
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
fi

systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service "


source /root/adminrc
openstack compute service list
fn_log "openstack compute service list"

# nova service-list 
# NOVA_STATUS=`nova service-list | awk -F "|" '{print$7}'  | grep -v State | grep -v ^$ | grep down`
# if [  -z ${NOVA_STATUS} ]
# then
# 	echo "nova status is ok"
# 	log_info  "nova status is ok"
# 	echo -e "\033[32m nova status is ok \033[0m"
# else
# 	echo "nova status is down"
# 	log_error "nova status is down."
# 	exit
# fi
# nova endpoints

# fn_log "nova endpoints"
# nova image-list
# fn_log "nova image-list"
# NOVA_IMAGE_STATUS=` nova image-list  | grep cirros-0.3.4-x86_64  | awk -F "|"  '{print$4}'`
# if [ ${NOVA_IMAGE_STATUS}  = ACTIVE ]
# then
# 	log_info  "nova image status is ok"
# 	echo -e "\033[32m nova image status is ok \033[0m"
# else
# 	echo "nova image status is error."
# 	log_error "nova image status is error."
# 	exit
# fi
# chkconfig openstack-nova-consoleauth  on  && service  openstack-nova-consoleauth start
# fn_log "chkconfig openstack-nova-consoleauth  on  && service  openstack-nova-consoleauth start"


fn_log "systemctl restart  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service"
echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         install nova sucessed           #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_nova.tag




