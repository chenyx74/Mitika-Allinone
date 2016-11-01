#!/bin/bash
##############################function define#################################################
function log_info ()
{
if [ ! -d /var/log/openstack-kilo  ]
then
	mkdir -p /var/log/openstack-kilo 
fi

DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/allinone_main.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo  ]
then
	mkdir -p /var/log/openstack-kilo 
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/allinone_main.log

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


function fn_install_openstack ()
{
cat << EOF
1) config allinone basic system environment.
2) install mariadb and rabbitmq-server.
3) install keystone.
4) install glance.
5) install nova.
6) install cinder.
7) install neutron.
8) install dashboard.
0) quit
EOF

read -p "please input your choice for install [0-8]:" install_number
expr ${install_number}+0 >/dev/null
if [ $? -eq 0 ]
then
	log_info "input number is : ${install_number}"
else
	echo "please input one right number[0-8]"
	log_info "input is string,please input number as tips above."
	fn_install_openstack
fi
if  [ -z ${install_number}  ]
then 
    echo "please input one right number[0-8]"
	fn_install_openstack
	################################################system prepare###################	
elif [ ${install_number}  -eq 1 ]
then
	log_info "begin to prepare system env"
	echo "begin to prepare system env"
	/bin/bash $PWD/etc/allinone_system_prepare.sh
	log_info "/bin/bash $PWD/etc/allinone_system_prepare.sh."
	echo "prepare system configuration complete successful!"
	log_info  "prepare system configuration complete successful!"
	fn_install_openstack
##################################prepare complete#########################################

		###############################install&config mariadb#############################		
elif  [ ${install_number}  -eq 2 ]
then
	log_info "begin to install mariadb"
	echo "begin to install mariadb"
	/bin/bash $PWD/etc/install_mariadb.sh
	log_info "/bin/bash $PWD/etc/install_mariadb.sh."
	echo "mariadb configuration complete successful!"
	log_info "mariadb configuration complete successful!"
	fn_install_openstack
	
	####################################mariadb configuration complete ###############
elif  [ ${install_number}  -eq 3 ]
then
	log_info "begin to install keystone"
	echo "begin to install keystone"
	/bin/bash $PWD/etc/install-keystone.sh
	log_info "/bin/bash $PWD/etc/install-keystone.sh."
	echo "keystone configuration complete successful!"
	log_info  "keystone configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 4 ]
then
	log_info "begin to install glance"
	echo "begin to install glance"
	/bin/bash $PWD/etc/install_glance.sh
	log_info "/bin/bash $PWD/etc/install_glance.sh."
	echo "glance configuration complete successful!"
	log_info "glance configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 5 ]
then
	log_info "begin to install nova_allinone"
	echo "begin to install nova_allinone"
	/bin/bash $PWD/etc/install_nova_allinone.sh  
	log_info "/bin/bash $PWD/etc/install_nova_allinone.sh."
	echo "nova configuration complete successful!"
	log_info "nova configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 6 ]
then
	log_info "begin to install cinder_allinone"
	echo "begin to install cinder_allinone"
	/bin/bash $PWD/etc/install_cinder_allinone.sh
	log_info "/bin/bash $PWD/etc/install_cinder_allinone.sh."
	echo "cinder configuration complete successful!"
	log_info "cinder configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 7 ]
then
	log_info "begin to install neutron_allinone"
	echo "begin to install neutron_allinone"
	fn_install_neutron
	log_info "/bin/bash $PWD/etc/install_neutron_allinone.sh."
	echo "neutron configuration complete successful!"
	log_info "neutron configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 8 ]
then
	log_info "begin to install dashboard"
	echo "begin to install dashboard"
	/bin/bash ${INSTALL_PATH}/etc/install_dashboard.sh
	log_info "/bin/bash $PWD/etc/install_dashboard.sh."
	echo "dashboard configuration complete successful!"
	log_info "dashboard configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 0 ]
then 
     log_info "installation exit by user"
	 exit 
else 
     echo "please input one right number[0-8]"
	 fn_install_openstack
fi
}

function fn_install_neutron () {
cat << EOF
1) install neutron for one NIC
2) install neutron for two NICs
0) quit
EOF
read -p "please input one number for install :" install_number
expr ${install_number}+0 >/dev/null
if [ $? -eq 0 ]
then
	log_info "input is number."
else
	echo "please input one right number[0-2]"
	log_info "input is string."
	fn_install_neutron
fi
if  [ -z ${install_number}  ]
then 
    echo "please input one right number[0-2]"
	fn_install_neutron
elif [ ${install_number}  -eq 1 ]
then
	/bin/bash $PWD/etc/install_neutron_one.sh
	log_info "/bin/bash $PWD/etc/install_neutron_one.sh"
	fn_install_neutron
elif [ ${install_number}  -eq 2 ]
then
	/bin/bash $PWD/etc/install_neutron_allinone.sh
	log_info "/bin/bash $PWD/etc/install_neutron_allinone.sh"
	fn_install_neutron	
elif  [ ${install_number}  -eq 0 ]
then 
     log_info "exit intall."
	fn_install_openstack
else 
     echo "please input one right number[0-2]"
	 fn_install_neutron
fi
 fn_install_openstack
}
#################################function define finish#######################3

INSTALL_PATH=$PWD
USER_N=`whoami`

if  [ ${USER_N}  = root ]
then 
	log_info "execute by root. "
else
	log_error "execute by ${USER_N}"
	echo -e "\033[41;37m you must execute this scritp by root. \033[0m"
	exit
fi

fn_install_openstack