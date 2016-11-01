Name:		cv-zabbix-checks	
Version:	0.4
Release:	1%{?dist}
Summary:	Zabbix checks by CLusterVision

Group:		CV	
License:	GPLv3.0
URL:		http://github.com/krumstein/trinityX
Source0:	cv-zabbix-checks-0.4.tar.gz

BuildArch:	noarch
BuildRoot:	%{_tmppath}/%{name}-buildroot
Requires:	zabbix-agent
%description
ClusterVision Zabbix checks

%prep
%setup -q


%build

%install
install -m 0755 -o zabbix -g zabbix -d $RPM_BUILD_ROOT/var/lib/zabbix
install -m 0755 -o zabbix -g zabbix -d $RPM_BUILD_ROOT/var/lib/zabbix/userparameters
install -m 0755 -o zabbix -g zabbix  userparameters/smartctl-disks-discovery.pl userparameters/drbd   userparameters/ipmitool   userparameters/pacemaker   userparameters/perc   userparameters/smcli $RPM_BUILD_ROOT/var/lib/zabbix/userparameters/

install -m 0755 -d $RPM_BUILD_ROOT/etc/zabbix/zabbix_agentd.d/
install -m 0644 -o zabbix -g zabbix zabbix_agentd.d/userparameter_smartctl.conf zabbix_agentd.d/userparameter_drbd.conf   zabbix_agentd.d/userparameter_ipmi.conf   zabbix_agentd.d/userparameter_pacemaker.conf   zabbix_agentd.d/userparameter_perc.conf   zabbix_agentd.d/userparameter_smcli.conf  $RPM_BUILD_ROOT/etc/zabbix/zabbix_agentd.d/

install -m 0755 -d $RPM_BUILD_ROOT/etc/sudoers.d/
install -m 0644 sudoers-zabbix $RPM_BUILD_ROOT/etc/sudoers.d/zabbix

install -m 0755 -d $RPM_BUILD_ROOT/usr/lib/zabbix/templates/
install -m 0644 templates/smartctl.xml templates/apc_inrow_cooling.xml templates/drbd.xml templates/ipmitool.xml templates/pacemaker.xml templates/perc.xml templates/powervault.xml templates/slurm.xml templates/smcli.xml  $RPM_BUILD_ROOT/usr/lib/zabbix/templates/

install -m 0755 templates/import.sh $RPM_BUILD_ROOT/usr/lib/zabbix/templates/

install -m 0755 -d $RPM_BUILD_ROOT/usr/lib/zabbix/externalscripts/
install -m 0755 externalscripts/check_md_status  externalscripts/slurm $RPM_BUILD_ROOT/usr/lib/zabbix/externalscripts/
mkdir $RPM_BUILD_ROOT/tmp
touch $RPM_BUILD_ROOT/tmp/ipmitool.cache

%clean
rm -rf $RPM_BUILD_ROOT

%files
%dir /var/lib/zabbix/userparameters
/var/lib/zabbix/userparameters/drbd  
/var/lib/zabbix/userparameters/ipmitool  
/var/lib/zabbix/userparameters/pacemaker  
/var/lib/zabbix/userparameters/perc  
/var/lib/zabbix/userparameters/smcli
/var/lib/zabbix/userparameters/smartctl-disks-discovery.pl

/etc/zabbix/zabbix_agentd.d/userparameter_drbd.conf 
/etc/zabbix/zabbix_agentd.d/userparameter_ipmi.conf
/etc/zabbix/zabbix_agentd.d/userparameter_pacemaker.conf
/etc/zabbix/zabbix_agentd.d/userparameter_perc.conf
/etc/zabbix/zabbix_agentd.d/userparameter_smcli.conf
/etc/zabbix/zabbix_agentd.d/userparameter_smartctl.conf

/etc/sudoers.d/zabbix
/usr/lib/zabbix/externalscripts/check_md_status  
/usr/lib/zabbix/externalscripts/slurm
/tmp/ipmitool.cache
/usr/lib/zabbix/templates/apc_inrow_cooling.xml
/usr/lib/zabbix/templates/drbd.xml
/usr/lib/zabbix/templates/import.sh
/usr/lib/zabbix/templates/ipmitool.xml
/usr/lib/zabbix/templates/pacemaker.xml
/usr/lib/zabbix/templates/perc.xml
/usr/lib/zabbix/templates/powervault.xml
/usr/lib/zabbix/templates/slurm.xml
/usr/lib/zabbix/templates/smcli.xml
/usr/lib/zabbix/templates/smartctl.xml

%doc



%changelog
* Fri Oct 28 2016 Vladimir Krumshtein <vladimir.krumstein@clustervision.com> 0.1
- Initial RPM release 
* Fri Oct 28 2016 Vladimir Krumshtein <vladimir.krumstein@clustervision.com> 0.2
- Added external checks
