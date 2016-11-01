#!bin/bash
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
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/dashboard.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/dashboard.log

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
if [ -f  /etc/openstack-kilo_tag/install_neutron.tag ]
then 
	log_info "neutron have installed ."
else
	echo -e "\033[41;37m you should install neutron first. \033[0m"
	exit
fi
if [ -f  /etc/openstack-kilo_tag/install_dashboard.tag ]
then 
	echo -e "\033[41;37m you haved install dashboard \033[0m"
	log_info "you haved install dashboard."	
	exit
fi


if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info " we will use local yum repository and that's all ready!"
else 
	echo "please make local yum repository firstly!"
	exit
fi

yum clean all &&  yum install openstack-dashboard -y
fn_log "yum clean all &&  yum install openstack-dashboard -y"
KEY_DASHBOARD=`cat /etc/openstack-dashboard/local_settings | grep SECRET_KEY | grep "=" |awk -F "'" '{print$2}'`
rm -rf /etc/openstack-dashboard/local_settings 
cp -a    $PWD/lib/local_settings /etc/openstack-dashboard/local_settings 
fn_log "cp -a $PWD/lib/local_settings /etc/openstack-dashboard/local_settings"
# unset http_proxy https_proxy ftp_proxy no_proxy  

sed -i "s/a0ec3ee55c1b5d28f378/${KEY_DASHBOARD}/g" /etc/openstack-dashboard/local_settings 
fn_log "sed -i "s/d7b47b003701d52cea8d/${KEY_DASHBOARD}/g" /etc/openstack-dashboard/local_settings"
sed -i  "s/controller/${HOSTNAME}/g"  /etc/openstack-dashboard/local_settings
fn_log "sed -i  "s/controller/${HOSTNAME}/g"  /etc/openstack-dashboard/local_settings"

systemctl enable httpd.service memcached.service &&  systemctl restart httpd.service memcached.service 
fn_log "systemctl enable httpd.service memcached.service &&  systemctl restart httpd.service memcached.service "

systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl restart libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl restart libvirtd.service openstack-nova-compute.service "



echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         install openstack dashboard     #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_dashboard.tag




	