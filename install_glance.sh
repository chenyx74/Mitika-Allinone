#!bin/bash
###############################################read me#################################################################################################
#This script used for install glance service,glance's function is store images.As so far,all image is stored to /var/lib/glance/images,you can config ceph
#as glance backend to store images!The access user is keystone and the password is GLANCE_DBPASS for mariadb,the access user and passwd all are openstack
#This script was enhanced by shan jin xiao at 2015/11/12
#shanjinxiao@cmbchina.com
##########################################################################################################################################################


#log function
NAMEHOST=`hostname`
HOSTNAME=`hostname`
function log_info ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/glance.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/glance.log

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
if [ -f  /etc/openstack-kilo_tag/config_keystone.tag ]
then 
	log_info "mkeystone have installed ."
else
	echo -e "\033[41;37m you should install keystone first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-kilo_tag/install_glance.tag ]
then 
	echo -e "\033[41;37m you haved install glance \033[0m"
	log_info "you haved install glance."	
	exit
fi

#create glance databases 
function  fn_create_glance_database () {
mysql -uroot -proot -e "CREATE DATABASE glance;" &&  mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'GLANCE_DBPASS';" && mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'GLANCE_DBPASS';" 
fn_log "create glance databases"
}
mysql -uroot -proot -e "show databases ;" >test 
DATABASEGLANCE=`cat test | grep glance`
rm -rf test 
if [ ${DATABASEGLANCE}x = glancex ]
then
	log_info "glance database had installed."
else
	fn_create_glance_database
fi

#unset http_proxy https_proxy ftp_proxy no_proxy 
source /root/adminrc 

#create user glance
USER_GLANCE=`openstack user list | grep glance | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_GLANCE}x = glancex ]
then
	log_info "openstack user had created  glance"
else
	openstack user create  --domain default glance  --password glance
	fn_log "openstack user create  --domain default glance  --password glance"
	openstack role add --project service --user glance admin
	fn_log "openstack role add --project service --user glance admin"
fi

#create service glance
SERVICE_IMAGE=`openstack service list | grep glance | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_IMAGE}x = glancex ]
then 
	log_info "openstack service create glance."
else
	openstack service create --name glance --description "OpenStack Image service" image
	fn_log "openstack service create --name glance --description "OpenStack Image service" image"
fi

#create endpoint api
ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep image  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep image   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep image   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]

then
	log_info "openstack endpoint create glance."
else
	openstack endpoint create --region RegionOne   image public http://${NAMEHOST}:9292  &&   openstack endpoint create --region RegionOne   image internal http://${NAMEHOST}:9292 &&   openstack endpoint create --region RegionOne   image admin http://${NAMEHOST}:9292
	fn_log "openstack endpoint create --region RegionOne   image public http://${NAMEHOST}:9292  &&   openstack endpoint create --region RegionOne   image internal http://${NAMEHOST}:9292 &&   openstack endpoint create --region RegionOne   image admin http://${NAMEHOST}:9292"
fi


if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info " we will use local yum repo and that's all ready"
else 
	echo "please make local yum repository"
	exit
fi

yum clean all && yum install openstack-glance  -y
fn_log "yum clean all && yum install openstack-glance -y"
#unset http_proxy https_proxy ftp_proxy no_proxy 

#########################################################config glance-api.conf#######################################################
[ -f /etc/glance/glance-api.conf_bak ] || cp -a /etc/glance/glance-api.conf /etc/glance/glance-api.conf_bak
openstack-config --set  /etc/glance/glance-api.conf database connection  mysql+pymysql://glance:GLANCE_DBPASS@${HOSTNAME}/glance 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_type   password 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_domain_name  default 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken user_domain_name   default 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken username  glance 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken password  glance
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_name  service
openstack-config --set  /etc/glance/glance-api.conf paste_deploy flavor  keystone
openstack-config --set  /etc/glance/glance-api.conf glance_store stores  file,http
openstack-config --set  /etc/glance/glance-api.conf glance_store default_store  file
openstack-config --set  /etc/glance/glance-api.conf glance_store filesystem_store_datadir  /var/lib/glance/images/ 
# openstack-config --set  /etc/glance/glance-api.conf DEFAULT notification_driver  noop 
# openstack-config --set  /etc/glance/glance-api.conf DEFAULT verbose  True 
# openstack-config --set  /etc/glance/glance-api.conf DEFAULT debug  True 
fn_log "openstack-config --set  /etc/glance/glance-api.conf database connection  mysql://glance:GLANCE_DBPASS@${HOSTNAME}/glance && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_plugin  password && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_domain_id  default && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken user_domain_id  default && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken username  glance && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken password  GLANCE_DBPASS && openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_name  service  && openstack-config --set  /etc/glance/glance-api.conf paste_deploy flavor  keystone && openstack-config --set  /etc/glance/glance-api.conf glance_store default_store  file && openstack-config --set  /etc/glance/glance-api.conf glance_store filesystem_store_datadir  /var/lib/glance/images/ && openstack-config --set  /etc/glance/glance-api.conf DEFAULT notification_driver  noop && openstack-config --set  /etc/glance/glance-api.conf DEFAULT verbose  True "

[ -f /etc/glance/glance-registry.conf_bak ] || cp -a /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf_bak
openstack-config --set  /etc/glance/glance-registry.conf database connection  mysql+pymysql://glance:GLANCE_DBPASS@${HOSTNAME}/glance 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken memcached_servers  ${HOSTNAME}:11211 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken auth_type   password 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_domain_name  default 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken user_domain_name   default 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken username  glance 
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken password  glance
openstack-config --set  /etc/glance/glance-api.conf keystone_authtoken project_name  service
openstack-config --set  /etc/glance/glance-api.conf paste_deploy flavor  keystone
openstack-config --set  /etc/glance/glance-registry.conf DEFAULT verbose  True 
openstack-config --set  /etc/glance/glance-registry.conf DEFAULT debug  True 
fn_log "openstack-config --set  /etc/glance/glance-registry.conf database connection  mysql://glance:GLANCE_DBPASS@${HOSTNAME}/glance && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken auth_plugin  password && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_domain_id  default && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken user_domain_id  default && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken project_name  service && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken username  glance && openstack-config --set  /etc/glance/glance-registry.conf keystone_authtoken password GLANCE_DBPASS &&  openstack-config --set  /etc/glance/glance-registry.conf paste_deploy flavor  keystone && openstack-config --set  /etc/glance/glance-registry.conf DEFAULT notification_driver  noop && openstack-config --set  /etc/glance/glance-registry.conf DEFAULT verbose  True "

su -s /bin/sh -c "glance-manage db_sync" glance 
fn_log "su -s /bin/sh -c "glance-manage db_sync" glance"
################################################################glance config finish#################################################################

systemctl enable openstack-glance-api.service openstack-glance-registry.service &&  systemctl start openstack-glance-api.service openstack-glance-registry.service 
fn_log "systemctl enable openstack-glance-api.service openstack-glance-registry.service &&  systemctl start openstack-glance-api.service openstack-glance-registry.service "
sleep 10

function fn_add_imageAPIv2_to_source () {
echo " " >>  /root/adminrc && \
echo " " >>  /root/demorc && \
echo "export OS_IMAGE_API_VERSION=2" | tee -a /root/adminrc  /root/demorc
fn_log ""export OS_IMAGE_API_VERSION=2" |  tee -a /root/adminrc  /root/demorc"
}
VERSION_IMAGE=`cat /root/adminrc | grep OS_IMAGE_API_VERSION | awk -F " " '{print$2}' | awk -F "=" '{print$1}'`
if [ ${VERSION_IMAGE}x = OS_IMAGE_API_VERSIONx  ]
then
	log_info "adminrc have add OS_IMAGE_API_VERSION."
else
	fn_add_imageAPIv2_to_source
fi


function fn_create_image () {
source /root/adminrc  && \
cp -a $PWD/lib/cirros-0.3.4-x86_64-disk.img /tmp/  && \
glance image-create --name "cirros-0.3.4-x86_64" --file /tmp/cirros-0.3.4-x86_64-disk.img  \
--disk-format qcow2 --container-format bare --visibility public --progress

fn_log "create image"

glance image-list
fn_log "glance image-list"
}
GLANCE_ID=`glance image-list | grep cirros-0.3.4-x86_64  | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${GLANCE_ID}x = cirros-0.3.4-x86_64x ]
then
	log_info "glance image cirros-0.3.4-x86_64 had create."
else
	fn_create_image
fi


echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###        install glance sucessed         #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"


if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_glance.tag

