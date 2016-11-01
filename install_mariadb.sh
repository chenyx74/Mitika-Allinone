#!bin/bash

##########################################################read me##########################################################################
#This script be used for install openstack-selinux and mariadb and rabbitmq-server,mariadb is the database of openstack backend except for 
#ceilometer(it use mogodb),#rabbitmq is the message queue the mariadb's default user is root and password is root,the rabbitmq's default user 
#is openstack and the passsword is openstack.  
#This scripts was enhanced by shan jin xiao at 2015/11/11(single day)!
#shanjinxiao@cmbchina.com
#################################################################################################################################################

####################################################function define###############################################################################
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
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/mariadb_rabbitmq.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/mariadb_rabbitmq.log

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

function fn_install_mariadb () {
yum clean all && yum install python-openstackclient openstack-selinux -y && yum install mariadb mariadb-server python2-PyMySQL -y
fn_log "yum clean all && yum install openstack-selinux mariadb mariadb-server python2-PyMySQL-y"

rm -rf /etc/my.cnf.d/mariadb_openstack.cnf &&  cp -a $PWD/lib/mariadb_openstack.cnf /etc/my.cnf.d/mariadb_openstack.cnf
fn_log "cp -a $PWD/lib/mariadb_openstack.cnf /etc/my.cnf.d/mariadb_openstack.cnf"
echo " " >>/etc/my.cnf.d/mariadb_openstack.cnf
echo "bind-address = ${NIC_IP}" >>/etc/my.cnf.d/mariadb_openstack.cnf

#start mariadb
systemctl enable mariadb.service &&  systemctl start mariadb.service 
fn_log "systemctl enable mariadb.service &&  systemctl start mariadb.service"
mysql_secure_installation <<EOF

y
root
root
y
y
y
y
EOF
fn_log "mysql_secure_installation"
}

function fn_install_rabbit () {
 yum install rabbitmq-server -y
fn_log "yum clean all && yum install rabbitmq-server -y"

#start rabbitmq-server.service
systemctl enable rabbitmq-server.service &&  systemctl start rabbitmq-server.service 
fn_log "systemctl enable rabbitmq-server.service &&  systemctl start rabbitmq-server.service"

rabbitmqctl add_user openstack openstack
fn_log "rabbitmqctl add_user openstack openstack"
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
fn_log "rabbitmqctl set_permissions openstack ".*" ".*" ".*""
}

function fn_test_rabbit () {
RABBIT_STATUS=`rabbitmqctl list_users | grep openstack | awk -F " " '{print$1}'`
if [ ${RABBIT_STATUS}x  = openstackx ]
then 
	log_info "rabbit had installed successful."
else
	fn_install_rabbit
fi
}
##########################################################function define finish###############################################################

#####################################################main code ################################################################################
if [ -f  /etc/openstack-kilo_tag/presystem.tag ]
then 
	log_info "config system have installed ."
else
	echo -e "\033[41;37m you should config system first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-kilo_tag/install_mariadb_rabbitmq.tag ]
then 
	echo -e "\033[41;37m you haved config Basic environment,there is no need re-config \033[0m"
	log_info "you had installed mariadb."	
	exit
fi

if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info " we use local yum repo and that is all ready."
else 
	echo "\033[41;37m please make local yum repo firstly \033[0m"
	exit
fi

#the first eth nic IP will be as openstack cluster management ip
read -p "please choose your NIC num as mariadb bind[default first NIC]:" NIC_NUM
if [ -z ${NIC_NUM} ]
then
	echo "use default the first NIC as your management IP"
	NIC_NUM=1
fi
NIC_NAME=$(ip addr | grep ^`expr ${NIC_NUM} + 1`: |awk -F ":" '{print$2}')
NIC_IP=$(ifconfig ${NIC_NAME}  | grep netmask | awk -F " " '{print$2}')

MARIADB_STATUS=`service mariadb status | grep Active | awk -F "("  '{print$2}' | awk -F ")"  '{print$1}'`
if [ "${MARIADB_STATUS}"  = running ]
then
	log_info "mairadb had installation successful."
else
	fn_install_mariadb
fi

if [ -f /usr/sbin/rabbitmqctl  ]
then
	log_info "rabbit had installed."
else
	fn_test_rabbit
fi

if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_mariadb_rabbitmq.tag

echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###   install mariadb and rabbitmq sucessed.#### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
