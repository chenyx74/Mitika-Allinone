#!bin/bash

###########################################################read me ########################################################################
#This script used for install keystone that is identity service of openstack,before this,please install mariadb and rabbitmq firstly.In kilo,
#there is no openstack-keystone service again ,Apache service httpd is responsible for keystone start up,it named as wsgi-keytsone.The access
#user is keystone and the password is KEYSTONE_DBPASS for mariadb,the access user and passwd all are openstack
#this script writen by shan jin xiao at 2015/11/11
#shanjinxiao@cmbchina.com
############################################################################################################################################33

#keystone form mitaka have some changes,exp:it use API v3 and there is term called domain when create project
# service and user.


########################################################function define########################################################
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
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/keystone.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/keystone.log

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
if [ -f  /etc/openstack-kilo_tag/install_mariadb_rabbitmq.tag ]
then 
	log_info "mariadb have installed ."
else
	echo -e "\033[41;37m you should install mariadb first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-kilo_tag/config_keystone.tag ]
then 
	echo -e "\033[41;37m etc/openstack-kilo_tag/config_keystone.tag \033[0m"
	log_info "you had install keystone,there is no need install again."	
	exit
fi

if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info " we will use local yum repo and that's all ready"
else 
	echo "please make local yum repo"
	exit
fi


#create databases
function  fn_create_keystone_database () {
mysql -uroot -proot -e "CREATE DATABASE keystone;" &&  mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'KEYSTONE_DBPASS';" && mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'KEYSTONE_DBPASS';"   
fn_log "create keystone databases successful!"

}
mysql -uroot -proot -e "show databases ;" >tmp 
DATABASEKEYSTONE=`cat tmp | grep keystone`
rm -rf tmp 
if [ ${DATABASEKEYSTONE}x = keystonex ]
then
	log_info "keystone database had installed."
else
	fn_create_keystone_database
fi

######################################install keystone packages#######################################################################
yum clean all && yum install openstack-keystone httpd mod_wsgi python-openstackclient memcached python-memcached -y
fn_log "yum clean all && yum install openstack-keystone httpd mod_wsgi python-openstackclient memcached python-memcached -y"

#start memcached.service
systemctl enable memcached.service &&  systemctl start memcached.service 
fn_log "systemctl enable memcached.service &&  systemctl start memcached.service"
yum clean all && yum install -y openstack-utils
fn_log "yum clean all && yum install -y openstack-utils"

##############################################keystone.conf config############################################################################
[ -f /etc/keystone/keystone.conf_bak ]  || cp -a /etc/keystone/keystone.conf /etc/keystone/keystone.conf_bak
fn_log "[ -f /etc/keystone/keystone.conf_bak ]  || cp -a /etc/keystone/keystone.conf /etc/keystone/keystone.conf_bak"
ADMIN_TOKEN=$(openssl rand -hex 10)
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN 
fn_log "openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN "
                                                      
openstack-config --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:KEYSTONE_DBPASS@${HOSTNAME}/keystone  
fn_log "openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:KEYSTONE_DBPASS@${HOSTNAME}/keystone "


openstack-config --set /etc/keystone/keystone.conf token provider fernet 
fn_log "openstack-config --set /etc/keystone/keystone.conf token provider fernet "

su -s /bin/sh -c "keystone-manage db_sync" keystone 
fn_log "su -s /bin/sh -c "keystone-manage db_sync" keystone "

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
fn_log "keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone "
####################################################################keystone.conf finish###################################################

############################################config apache tomcat#########################################################################
[ -f /etc/httpd/conf/httpd.conf_bak  ] || cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf_bak
fn_log "[ -f /etc/httpd/conf/httpd.conf_bak  ] || cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf_bak"

sed  -i  "s/#ServerName www.example.com:80/ServerName ${HOSTNAME}/" /etc/httpd/conf/httpd.conf
fn_log "sed  -i  's/#ServerName www.example.com:80/ServerName $HOSTNAME/' /etc/httpd/conf/httpd.conf"

RESULT_HTTP=`cat /etc/httpd/conf/httpd.conf | grep $HOSTNAME | awk -F " " '{print$2}'`
if [ ${RESULT_HTTP} = ${HOSTNAME}  ]
then
	log_info "http servername is ${HOSTNAME} "
else
	log_error "http servername is null"
	exit 1
fi

##########################config wsgi-keystone,in kilo ,openstack-keystone will not be start#########################################
rm -rf /etc/httpd/conf.d/wsgi-keystone.conf  && cp -a $PWD/lib/wsgi-keystone.conf  /etc/httpd/conf.d/wsgi-keystone.conf 
fn_log "cp -a $PWD/lib/wsgi-keystone.conf  /etc/httpd/conf.d/wsgi-keystone.conf "

systemctl enable httpd.service && systemctl start httpd.service 
fn_log "systemctl enable httpd.service && systemctl start httpd.service "
#unset http_proxy https_proxy ftp_proxy no_proxy 

export OS_TOKEN=$ADMIN_TOKEN
export OS_URL=http://$HOSTNAME:35357/v3
export OS_IDENTITY_API_VERSION=3
sleep 10

#create service
SERVICE_NAME=`openstack service list | grep keystone |awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${SERVICE_NAME}x  = keystonex ]
then 
	log_info "openstack service have create"
else
	openstack service create --name keystone --description "OpenStack Identity" identity
    fn_log "openstack service create --name keystone --description "OpenStack Identity" identity"
fi

#create endpoint api
ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep keystone  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep keystone   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep keystone   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]
then
	log_info "openstack endpoint had created."
else
	openstack endpoint create --region RegionOne   identity public http://${NAMEHOST}:5000/v3 && openstack endpoint create --region RegionOne   identity internal http://${NAMEHOST}:5000/v3 && openstack endpoint create --region RegionOne   identity admin http://${NAMEHOST}:35357/v3
	fn_log "openstack endpoint create --region RegionOne   identity public http://${NAMEHOST}:5000/v3 && openstack endpoint create --region RegionOne   identity internal http://${NAMEHOST}:5000/v3 && openstack endpoint create --region RegionOne   identity admin http://${NAMEHOST}:35357/v3"
fi

#create domain
DEFAULT_DOMAIN=`openstack domain list | grep default | awk -F " " '{print$4}'`
if [  ${DEFAULT_DOMAIN}x  = defaultx ]
then
	log_info "default domain had created."
else
	openstack domain create --description "Default Domain" default
	fn_log "openstack domain create --description "Default Domain" default"
fi

#create admin project
PROJECT_ADMIN=`openstack project list | grep admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${PROJECT_ADMIN}x = adminx ]
then
	log_info "openstack project admin create."
else
	openstack project create --domain default   --description "Admin Project" admin
	fn_log "openstack project create --domain default   --description "Admin Project" admin"
fi

#create user admin
USER_LIST=`openstack user list | grep  admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`

if [ ${USER_LIST}x = adminx ]
then
	log_info "openstack user had  created  admin"
else
	openstack user create --domain default  admin --password admin
	fn_log "openstack user create --domain default  admin --password admin"
fi




ROLE_ADMIN=`openstack role list | grep admin | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${ROLE_ADMIN}x = adminx ]
then 
	log_info "openstack role had created admin"
else
	openstack role create admin
	fn_log "openstack role create admin"
	openstack role add --project admin --user admin admin
	fn_log "openstack role add --project admin --user admin admin"
fi


PROJECT_SERVICE=`openstack project list |grep service | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${PROJECT_SERVICE}x = servicex ]
then
	log_info "openstack project had created service. "
else
	openstack project create --domain default   --description "Service Project" service
	fn_log "openstack project create --domain default   --description "Service Project" service"
fi


PROJECT_DEMO=`openstack project list |grep demo | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${PROJECT_DEMO}x = demox ]
then
	log_info "openstack project had created demo "
else
	openstack project create --domain default   --description "Demo Project" demo
	fn_log "openstack project create --domain default   --description "Demo Project" demo"
fi


USER_DEMO=` openstack user list |grep demo |awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_DEMO}x  =  demox ]
then
	log_info "openstack user had created  demo "
else
	openstack user create --domain default  demo  --password demo
	fn_log "openstack user create  demo  --password demo"
fi

ROLE_LIST=`openstack role list | grep user  |awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${ROLE_LIST}x = userx ]
then
	log_info "openstack role had  created user."
else
	openstack role create user
	fn_log "openstack role create user"
	openstack role add --project demo --user demo user
	fn_log "openstack role add --project demo --user demo user"
fi


unset OS_TOKEN OS_URL


openstack --os-auth-url http://$HOSTNAME:35357/v3  --os-project-domain-name default --os-user-domain-name default   --os-project-name admin --os-username admin token issue --os-password admin
fn_log "openstack --os-auth-url http://$HOSTNAME:35357/v3  --os-project-domain-name default --os-user-domain-name default   --os-project-name admin --os-username admin token issue --os-password admin "



openstack --os-auth-url http://$HOSTNAME:5000/v3   --os-project-domain-name default --os-user-domain-name default   --os-project-name demo --os-username demo token issue --os-password demo
fn_log "openstack --os-auth-url http://$HOSTNAME:5000/v3   --os-project-domain-name default --os-user-domain-name default   --os-project-name demo --os-username demo token issue --os-password demo"


# openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password token issue --os-password admin
# fn_log "openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password token issue --os-password admin"


# openstack --os-auth-url http://$HOSTNAME:35357 --os-project-domain-id default --os-user-domain-id default --os-project-name admin --os-username admin --os-auth-type password token issue --os-password admin
# fn_log "openstack --os-auth-url http://$HOSTNAME:35357 --os-project-domain-id default --os-user-domain-id default --os-project-name admin --os-username admin --os-auth-type password token issue --os-password admin"




# openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password project list  --os-password admin
# fn_log "openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password project list  --os-password admin"





# openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password user list --os-password admin
# fn_log "openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password user list --os-password admin"






# openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password role list --os-password admin
# fn_log "openstack --os-auth-url http://$HOSTNAME:35357 --os-project-name admin --os-username admin --os-auth-type password role list --os-password admin"



# openstack --os-auth-url http://$HOSTNAME:5000 --os-project-domain-id default --os-user-domain-id default --os-project-name demo --os-username demo --os-auth-type password token issue  --os-password demo
# fn_log "openstack --os-auth-url http://$HOSTNAME:5000 --os-project-domain-id default --os-user-domain-id default --os-project-name demo --os-username demo --os-auth-type password token issue  --os-password demo"



# openstack --os-auth-url http://$HOSTNAME:5000 --os-project-domain-id default --os-user-domain-id default --os-project-name demo --os-username demo --os-auth-type password user list --os-password demo
# if [  $? -eq 0  ]
# then
# 	log_error "keystone installation and verify nocomplete"
# 	echo "\033[32m there is some issue beacuse user demo can not run "user list" normally \033[0m"
# 	exit
# else
# 	log_info "keystone installation and verify complete successful!"
# 	echo -e "\033[32m keystone installation and verify complete successful! \033[0m"
	
# fi


[ -f /root/adminrc ] || cp -a $PWD/lib/adminrc  /root/adminrc 
fn_log "[ -f /root/adminrc ] || cp -a $PWD/lib/adminrc  /root/adminrc  "


[ -f /root/demorc  ]  || cp -a $PWD/lib/demorc  /root/demorc 
fn_log "cp -a $PWD/lib/demorc  /root/demorc  "
source /root/adminrc
openstack token issue
fn_log "openstack token issue"



echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ### keystone installation complete sucessful!### \033[0m"
echo -e "\033[32m ################################################ \033[0m"

if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/config_keystone.tag
