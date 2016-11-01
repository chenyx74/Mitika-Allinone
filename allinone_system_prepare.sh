#!bin/bash
#################################################read me##################################################################################################
#before installing openstack project,you need setting your system,this include setting yum repositiry,firewall,selinux,ssh,network and so on,if you plan to
#install openstack with allinone,you just need run #this scripts,otherwise,you need run this scripts on every node that will be installed part of openstack 
#service .example,compute node that need install nova-compute,storage node need install cinder-volume.This #installation will all use local repo including 
#rdo-epel,rdo-kilo,and ISO packages.before run this scripts,you need ftp rpm source to /data directory,the location of ISO packages is:/data/ISO;the rdo-epel 
#location #is :/data/rdo-openstack-epel;the rdo-kilo location is:/data/rdo-openstack-kilo/openstack-common and /data/rdo-openstack-kilo/openstack-kilo 
#this scripts was enhanced by shan jin xiao at 2015/11/10!
#shanjinxiao@cmbchina.com
################################################################################################################################################

############################################function define###########################################################
#log function
function log_info ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/presystem.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/presystem.log

}

function fn_log ()  {
if [  $? -eq 0  ]
then
	log_info "$@ successful."
	echo -e "\033[32m $@ successful. \033[0m"
else
	log_error "$@ failed."
	echo -e "\033[41;37m $@ failed. \033[0m"
	exit
fi
}



#set hostname
function set_hostname () {
hostnamectl set-hostname ${NAMEHOST}
fn_log "set hostname"
echo "${NIC_IP} ${NAMEHOST} " >>/etc/hosts
fn_log  "modify hosts"
}



#stop firewall
function stop_firewall(){
service firewalld stop 
fn_log "stop firewall"
chkconfig firewalld off 
fn_log "chkconfig firewalld off"

ping -c 4 ${NAMEHOST} 
fn_log "ping -c 4 ${NAMEHOST} "
}




#install ntp 
function install_ntp () {
yum clean all && yum install ntp net-tools  -y 
fn_log "yum clean all && yum install ntp -y"
#modify /etc/ntp.conf 
if [ -f /etc/ntp.conf  ]
then 
	cp -a /etc/ntp.conf /etc/ntp.conf_bak
	#sed -i 's/^restrict\ default\ nomodify\ notrap\ nopeer\ noquery/restrict\ default\ nomodify\ /' /etc/ntp.conf && sed -i "/^# Please\ consider\ joining\ the\ pool/iserver\ ${NAMEHOST}\ iburst  " /etc/ntp.conf
	#commont all ntp server dependency external time and set local time to ntp time server
	sed -e 's/^server/#server/' -e '$a server 127.127.1.0' -e '$a fudge 127.127.1.0 stratum'  -i /etc/ntp.conf
	fn_log "config /etc/ntp.conf"
fi 
#restart ntp 
systemctl enable ntpd.service && systemctl start ntpd.service  
fn_log "systemctl enable ntpd.service && systemctl start ntpd.service"
sleep 10
ntpq -c peers 
ntpq -c assoc
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_ntp.tag
}

#disabile selinux
function set_selinx () 
{
cp -a /etc/selinux/config /etc/selinux/config_bak
sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config
fn_log "sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config"
}

#make local yum repository
function make_openstack_yumrepo () {
#cd /etc/yum.repos.d && rm -rf CentOS-Base.repo.bk &&  mv CentOS-Base.repo CentOS-Base.repo.bk   && wget http://mirrors.163.com/.help/CentOS7-Base-163.repo  
#remove all repo dependency external repository and just use local yum repo
if [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
then
	echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/make_yumrepo.tag
	return
fi

if [ -d /etc/yum.repos.d/bak ] 
then
	rm -rf /etc/yum.repos.d/bak
fi
cd /etc/yum.repos.d&&rm -rf *
fn_log "cd /etc/yum.repos.d && rm -rf * "

#make ISO packges yum repo
touch /etc/yum.repos.d/centos7-iso.repo&&echo "[centos7-iso]">>*.repo
sed -i '$aname=centos7-iso\nbaseurl=file:///data/ISO\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/centos7-iso.repo&&yum clean all&&yum makecache
#yum clean all && yum install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm -y
#make rdo-epel yum repo

rpm -aq|grep createrepo
if [ $? != 0 ] 
then
	yum install -y createrepo
fi
cd /data/rdo-openstack-epel && createrepo --update --baseurl=`pwd` `pwd`
cd /data/rdo-openstack-kilo/openstack-common && createrepo --update --baseurl=`pwd` `pwd`
cd /data/rdo-openstack-kilo/openstack-kilo && createrepo --update --baseurl=`pwd` `pwd`
touch /etc/yum.repos.d/rdo-epel.repo&&echo "[rdo-epel]">>/etc/yum.repos.d/rdo-epel.repo
touch /etc/yum.repos.d/openstack-common.repo&&echo "[openstack-common]">>/etc/yum.repos.d/openstack-common.repo
touch /etc/yum.repos.d/openstack-kilo.repo&&echo "[openstack-kilo]">>/etc/yum.repos.d/openstack-kilo.repo
sed -i '$aname=extra packages enterprise linux\nbaseurl=file:///data/rdo-openstack-epel\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/rdo-epel.repo
sed -i '$aname=openstack common packages\nbaseurl=file:///data/rdo-openstack-kilo/openstack-common\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/openstack-common.repo
sed -i '$aname=openstack kilo packages\nbaseurl=file:///data/rdo-openstack-kilo/openstack-kilo\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/openstack-kilo.repo
yum clean all&&yum makecache

echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/make_yumrepo.tag
cd $CUR_PATH
fn_log "yum repository initial complete successful!"
#yum clean all && yum install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm -y
#fn_log "yum clean all && yum install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm -y"
}

#whether need config your system or not
function If_config_system(){
	read -p "you confirm that you want to re-config[yes/no]:" INPUT
	if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
	then
		exit
		elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
		then
			echo "will re-config system!"
			rm -rf /etc/openstack-kilo_tag/*
		else
			If_config_system
		fi
}
#################################################function define finish#############################################

################################################main code body#######################################################

#if your system has been cofigurated,there is no need config again,we exit this config scripts
if [ -f  /etc/openstack-kilo_tag/presystem.tag ]
then 
	echo -e "\033[41;37m your system donot need config because it was configurated \033[0m"
	log_info "your system donot need config because it was configurated."	
	If_config_system		
fi

#set hostname
read -p "please input hostname for system [default:controller] :" install_number
CUR_PATH=$PWD
if  [ -z ${install_number}  ]
then 
    echo "controller" >$PWD/hostname
    NAMEHOST=controller
else
	echo "${install_number}" >$PWD/hostname
fi
#create dir to locate config label
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi

#make local yum repository
if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info "there is no need make yum repository!"
else 
	#make_openstack_yumrepo
	echo `date "+%Y-%m-%d %H:%M:%S"`>>/etc/openstack-kilo_tag/make_yumrepo.tag
	echo  "the yumrepo already create manually! skip this!"
fi

NAMEHOST=`cat $PWD/hostname`
#the first eth nic IP will be as openstack cluster management ip
read -p "please choose your NIC num as management IP[default first NIC]:" NIC_NUM
if [ -z ${NIC_NUM} ]
then
	echo "use default the first NIC as your management IP"
	NIC_NUM=1
fi
NIC_NAME=$(ip addr | grep ^`expr ${NIC_NUM} + 1`: |awk -F ":" '{print$2}')
NIC_IP=$(ifconfig ${NIC_NAME}  | grep netmask | awk -F " " '{print$2}')

HOSTS_STATUS=`cat /etc/hosts | grep $NIC_IP`

if [  -z  "${HOSTS_STATUS}"  ]
then
	set_hostname
else
	log_info "hostname had seted"
fi
cat /etc/hosts|grep `hostname`
if [ $? -eq 0 ]
then
	log_info "removing old hostname:${NAMEHOST} entry in hosts"
	sed -i '/'''$NAMEHOST'''/d' /etc/hosts
	set_hostname
fi

#set NTP server
if  [ -f /etc/openstack-kilo_tag/install_ntp.tag ]
then
	log_info "ntp had installed."
else
	install_ntp
fi

#stop selinux
STATUS_SELINUX=`cat /etc/selinux/config | grep ^SELINUX= | awk -F "=" '{print$2}'`
if [  ${STATUS_SELINUX} = enforcing ]
then 
	set_selinx
else 
	log_info "selinux is disabled."
fi

#stop firewalld
service firewalld status|grep -i running
if [ $? -eq 0 ] 
then
	stop_firewall
else
	log_info "firewalled has been stoped"
fi

#finish
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/presystem.tag
echo -e "\033[32m ############################################ \033[0m"
echo -e "\033[32m ##   prepare  system complete successful!#### \033[0m"
echo -e "\033[32m ############################################ \033[0m"

echo -e "\033[41;37m begin to reboot system to enforce kernel \033[0m"
log_info "begin to reboot system to enforce kernel."
sleep 10 

reboot







