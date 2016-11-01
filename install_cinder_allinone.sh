#!bin/bash
#####################################################read me########################################################################################
#This script used for install cinder,if you will,you can install all cinder service on controller node.Before run this script,please choose your disk
#by "fdisk -l" command,and wirte your disk to $pwd/lib/cinder_disk file,scripts will use your disks create cinder-volumes VG,and is default VG used for
#cinder backend.The mariadb user is cinder,and the password is CINDER_DBPASS.the keystone user is cinder and the password is cinder also.
#This script was enhanced by shan jin xiao at 2015/11/12
#shanjinxiao@cmbchina.com
#######################################################################################################################################################

#log function
NAMEHOST=`hostname`
HOSTNAME=`hostname`
function log_info ()
{
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/cinder.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/cinder.log

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
if [ -f  /etc/openstack-kilo_tag/install_nova.tag ]
then 
	log_info "nova have installed ."
else
	echo -e "\033[41;37m you should install nova first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-kilo_tag/install_cinder.tag ]
then 
	echo -e "\033[41;37m you had install cinder \033[0m"
	log_info "you had install cinder."	
	exit
fi

#create cinder databases 
function  fn_create_cinder_database () {
mysql -uroot -proot -e "CREATE DATABASE cinder;" &&  mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'CINDER_DBPASS';" && mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'CINDER_DBPASS';" 
fn_log "create cinder databases"
}
mysql -uroot -proot -e "show databases ;" >test 
DATABASECINDER=`cat test | grep cinder`
rm -rf test 
if [ ${DATABASECINDER}x = cinderx ]
then
	log_info "cinder database had installed."
else
	fn_create_cinder_database
fi
source /root/adminrc


USER_CINDER=`openstack user list | grep cinder | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_CINDER}x = cinderx ]
then
	log_info "openstack user had created  cinder"
else
	openstack user create  --domain default  cinder --password cinder
	fn_log "openstack user create  --domain default  cinder --password cinder"
	openstack role add --project service --user cinder admin
	fn_log "openstack role add --project service --user cinder admin"
fi

SERVICE_CINDER=`openstack service list | grep cinderv2 | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_CINDER}x = cinderv2x ]
then 
	log_info "openstack service create cinder and cinderv2."
else
	openstack service create --name cinder --description "OpenStack Block Storage" volume && openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
	fn_log "openstack service create --name cinder --description "OpenStack Block Storage" volume && openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2"
fi

ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep volume  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep volume   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep volume   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 0  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  0   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 0  ]
then
	openstack endpoint create --region RegionOne   volume public http://${NAMEHOST}:8776/v1/%\(tenant_id\)s 
	openstack endpoint create --region RegionOne   volume internal http://${NAMEHOST}:8776/v1/%\(tenant_id\)s  
    openstack endpoint create --region RegionOne   volume admin http://${NAMEHOST}:8776/v1/%\(tenant_id\)s
	fn_log "openstack endpoint create --region RegionOne   volume public http://${NAMEHOST}:8776/v1/%\(tenant_id\)s && openstack endpoint create --region RegionOne   volume internal http://${NAMEHOST}:8776/v1/%\(tenant_id\)s  && openstack endpoint create --region RegionOne   volume admin http://${NAMEHOST}:8776/v1/%\(tenant_id\)s"
else
	log_info "openstack endpoint create cinder."
fi

ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep volumev2  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep volumev2   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep volumev2   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 0 ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  0   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 0  ]
then
	openstack endpoint create --region RegionOne   volumev2 public http://${NAMEHOST}:8776/v2/%\(tenant_id\)s 
	openstack endpoint create --region RegionOne   volumev2 internal http://${NAMEHOST}:8776/v2/%\(tenant_id\)s 
	openstack endpoint create --region RegionOne   volumev2 admin http://${NAMEHOST}:8776/v2/%\(tenant_id\)s
	fn_log "openstack endpoint create --region RegionOne   volumev2 public http://${NAMEHOST}:8776/v2/%\(tenant_id\)s && openstack endpoint create --region RegionOne   volumev2 internal http://${NAMEHOST}:8776/v2/%\(tenant_id\)s && openstack endpoint create --region RegionOne   volumev2 admin http://${NAMEHOST}:8776/v2/%\(tenant_id\)s"
else
	log_info "openstack endpoint create cinderv2."
fi


if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info " we will use local yum repository and that's all ready!"
else 
	echo "please make local yum repository firstly!"
	exit
fi

yum clean all &&  yum install openstack-cinder -y
fn_log "yum clean all &&  yum install openstack-cinder python-cinderclient python-oslo-db -y"
[ -f /etc/cinder/cinder.conf.bak ]|| cp -a /etc/cinder/cinder.conf /etc/cinder/cinder.conf.bak
# cp /usr/share/cinder/cinder-dist.conf /etc/cinder/cinder.conf && chown -R cinder:cinder /etc/cinder/cinder.conf

fn_log "cp /usr/share/cinder/cinder-dist.conf /etc/cinder/cinder.conf && chown -R cinder:cinder /etc/cinder/cinder.conf"

read -p "please choose your cinder management NIC number[default first NIC]:" NIC_NUM
if [ -z ${NIC_NUM} ]
then
	echo "use default the first NIC as your cinder management IP"
	NIC_NUM=1
fi
NIC_NAME=$(ip addr | grep ^`expr ${NIC_NUM} + 1`: |awk -F ":" '{print$2}')
NIC_IP=$(ifconfig ${NIC_NAME}  | grep netmask | awk -F " " '{print$2}')




 
openstack-config --set /etc/cinder/cinder.conf  DEFAULT rpc_backend  rabbit 
openstack-config --set /etc/cinder/cinder.conf  DEFAULT my_ip  ${NIC_IP}
openstack-config --set /etc/cinder/cinder.conf  DEFAULT auth_strategy  keystone
openstack-config --set /etc/cinder/cinder.conf  database connection  mysql+pymysql://cinder:CINDER_DBPASS@${NAMEHOST}/cinder
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_host  ${NAMEHOST} 
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_userid  openstack 
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_password  openstack 
 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_uri  http://${NAMEHOST}:5000 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_url  http://${NAMEHOST}:35357 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken memcached_servers  ${NAMEHOST}:11211 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_type   password 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_domain_name   default 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken user_domain_name   default 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_name  service 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken username  cinder 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken password  cinder 
 
openstack-config --set /etc/cinder/cinder.conf  oslo_concurrency lock_path  /var/lock/cinder 
# openstack-config --set /etc/cinder/cinder.conf  DEFAULT verbose  True 
# openstack-config --set /etc/cinder/cinder.conf  DEFAULT debug  True 
fn_log "openstack-config --set /etc/cinder/cinder.conf  database connection  mysql://cinder:CINDER_DBPASS@${NAMEHOST}/cinder && openstack-config --set /etc/cinder/cinder.conf  DEFAULT rpc_backend  rabbit &&  openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_host  ${NAMEHOST} && openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_userid  openstack && openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_password  openstack && openstack-config --set /etc/cinder/cinder.conf  DEFAULT auth_strategy  keystone && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_uri  http://${NAMEHOST}:5000 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_url  http://${NAMEHOST}:35357 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_plugin  password && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_domain_id  default && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken user_domain_id  default && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_name  service && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken username  cinder && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken password  cinder &&  openstack-config --set /etc/cinder/cinder.conf  DEFAULT my_ip  ${NIC_IP} && openstack-config --set /etc/cinder/cinder.conf  oslo_concurrency lock_path  /var/lock/cinder && openstack-config --set /etc/cinder/cinder.conf  DEFAULT verbose  True "


su -s /bin/sh -c "cinder-manage db sync" cinder 
fn_log "su -s /bin/sh -c "cinder-manage db sync" cinder"

openstack-config --set /etc/nova/nova.conf  cinder os_region_name  RegionOne
fn_log "openstack-config --set /etc/nova/nova.conf  cinder os_region_name  RegionOne"
systemctl restart openstack-nova-api.service
fn_log "systemctl restart openstack-nova-api.service"

systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service  && systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service   
fn_log "systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service  && systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service   "


if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info " we will use local yum repository and that's all ready!"
else 
	echo "please make local yum repository firstly!"
	exit
fi


function If_install-cinder-volume(){
	read -p "Are you sure you want install cinder-volume  on controler node?[yes/no]:" INPUT
	if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
	then
		exit
	elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
	then
		echo "will install cinder-volume  on controler node"
		yum clean all &&  yum install lvm2 -y &&  systemctl enable lvm2-lvmetad.service  &&  systemctl start lvm2-lvmetad.service
		fn_log "yum clean all &&  yum install qemu  lvm2 -y && systemctl enable lvm2-lvmetad.service  &&  systemctl start lvm2-lvmetad.service"
	else
		If_install-cinder-volume
	fi
}

If_install-cinder-volume


CINDER_DISK=`cat  $PWD/lib/cinder_disk | grep ^CINDER_DISK | awk -F "=" '{print$2}'`


#########################################create cinder-volumes VG and cofig just scan choosed disk#############################
function fn_create_cinder_volumes () {
if [  -z  ${CINDER_DISK} ]
then 
	log_info "there is not disk for cinder."
else
	pvcreate ${CINDER_DISK}  && vgcreate cinder-volumes ${CINDER_DISK}
	fn_log "pvcreate ${CINDER_DISK}  && vgcreate cinder-volumes ${CINDER_DISK}"
fi

}

VOLUNE_NAME=`vgs | grep cinder-volumes | awk -F " " '{print$1}'`
if [ ${VOLUNE_NAME}x = cinder-volumesx ]
then
	log_info "cinder-volumes had created."
else
	fn_create_cinder_volumes
fi

########################################just scan your choose disks omit other disks########################################
filter=" "
filter_end="\"r/.*/\""
for var in ${CINDER_DISK}
do
tmp=$(echo $var |cut -d / -f 3)
filter=${filter}\"a/${tmp}/\",
done
filter="[${filter}${filter_end} ]"
sed -i "/^devices/a filter = ${filter}" /etc/lvm/lvm.conf
fn_log "config /etc/lvm/lvm.conf filter=${filter} on devices section"
#################################################################################################################
		
yum clean all &&  yum install openstack-cinder targetcli  -y
fn_log "yum clean all &&  yum install openstack-cinder targetcli python-oslo-db python-oslo-log  MySQL-python  -y"

openstack-config --set /etc/cinder/cinder.conf  lvm volume_driver  cinder.volume.drivers.lvm.LVMVolumeDriver  
openstack-config --set /etc/cinder/cinder.conf  lvm volume_group  cinder-volumes  
openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_protocol  iscsi  
openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_helper  lioadm  
openstack-config --set /etc/cinder/cinder.conf  DEFAULT glance_host  ${NAMEHOST}  
openstack-config --set /etc/cinder/cinder.conf  DEFAULT enabled_backends  lvm
openstack-config --set /etc/cinder/cinder.conf  DEFAULT glance_api_servers  http://${NAMEHOST}:9292
# openstack-config --set /etc/cinder/cinder.conf  DEFAULT verbose True
# openstack-config --set /etc/cinder/cinder.conf  DEFAULT debug True
fn_log "openstack-config --set /etc/cinder/cinder.conf  lvm volume_driver  cinder.volume.drivers.lvm.LVMVolumeDriver  && openstack-config --set /etc/cinder/cinder.conf  lvm volume_group  cinder-volumes  && openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_protocol  iscsi  && openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_helper  lioadm  && openstack-config --set /etc/cinder/cinder.conf  DEFAULT glance_host  ${NAMEHOST}  && openstack-config --set /etc/cinder/cinder.conf  DEFAULT enabled_backends  lvm"

systemctl enable openstack-cinder-volume.service target.service &&  systemctl start openstack-cinder-volume.service target.service 
fn_log "systemctl enable openstack-cinder-volume.service target.service &&  systemctl start openstack-cinder-volume.service target.service "


# VERSION_VOLUME=`cat /root/adminrc | grep OS_VOLUME_API_VERSION | awk -F " " '{print$2}' | awk -F "=" '{print$1}'`
# if [ ${VERSION_VOLUME}x = OS_VOLUME_API_VERSIONx  ]
# then
# 	log_info "adminrc have add VERSION_VOLUME."
# else
# 	echo " " >>/root/adminrc  && echo " " >>/root/demorc  && echo "export OS_VOLUME_API_VERSION=2" | tee -a /root/adminrc /root/demorc 
# 	fn_log "echo " " >>/root/adminrc  && echo " " >>/root/demorc  && echo "export OS_VOLUME_API_VERSION=2" | tee -a /root/adminrc /root/demorc "
# fi

sleep 30
source /root/adminrc && cinder service-list
CINDER_STATUS=`source /root/adminrc && cinder service-list | awk -F "|" '{print$6}' | grep -v State  | grep -v ^$ | grep -i down`

if [  -z  ${CINDER_STATUS} ]
then
	log_info "cinder status is ok."
	echo -e "\033[32m cinder status is ok \033[0m"
else
	log_error "cinder status is down."
	echo -e "\033[41;37m cinder status is down. \033[0m"
	exit
fi
# [ -d  /var/lock/cinder  ] ||  mkdir /var/lock/cinder && chown cinder:cinder /var/lock/cinder  -R
# echo " " >>/etc/rc.d/rc.local 
# echo "[ -d  /var/lock/cinder  ] ||  mkdir /var/lock/cinder " >>/etc/rc.d/rc.local 
# echo "chown cinder:cinder /var/lock/cinder  -R" >>/etc/rc.d/rc.local 
# chmod +x /etc/rc.d/rc.local


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         install cinder sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_cinder.tag





