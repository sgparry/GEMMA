#!/bin/bash

#!header:begin
# This file is part of GEMMA - http://pyspace.org/GEMMA
#
# GEMMA is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GEMMA is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GEMMA.  If not, see <http://www.gnu.org/licenses/>.

# Copyright (C) 2015 Stephen Parry

# Moodle is a registered trademark of the Moodle Trust.
# GEMMA is in no way maintained or endorsed by the Moodle Trust.

#!header:end

# Library of functions for Moodle Maintenance Scripts

let RANDOM=${SECONDS}+$$

set -e

function add_trap()
{
	local traps
	eval traps=($(trap -p $2))
	traps="${traps[2]}"
	trap "${traps}${traps:+; }$1" $2
}

add_trap err_exit ERR

function check_root() {
	if [[ $EUID -ne 0 ]]; then
		echo "This script must be run as root" 1>&2
		exit 1
	fi
}

function args_parse_version() {
	version=(${1//\./ })
	baseversion=${version[0]}${version[1]}
	if [ ${version[-1]} == x ]; then
		archive=moodle-latest-${baseversion}.tgz
	else
		archive=moodle-$1.tgz
	fi
}

function args_parse_site_address() {
	sitedomain=${1%%/*}
	sitepath=${1#*/}
	if [ "$sitepath" = "$1" ]; then
		sitepath=
	fi
}

function args_parse_ssl_opts() {
	if [ "$1" == "nossl" ]; then
		ssl=0
	elif [ "$1" == "ssl" ]; then
		ssl=1
	fi
}

function env_set_main_dirs() {
	sitedir=${wwwroot}/${sitedomain}/${htdocs}
	datadir=${dataroot}/${sitedomain}
	assetsdir=${assetsroot}/${sitedomain}
	if ! [ "${sitepath}" = "" ]; then
		sitedir=${sitedir}/${sitepath}
		datadir=${datadir}/${sitepath}
		assetsdir=${assetsdir}/${sitepath}
	fi
}

function env_set_backup_dirs() {
	if [ "$1" = "" ]; then
		backupdate=`date +%Y%m%d`
	else
		backupdate=$1
	fi
	sitebakdir=${sitedir}.${backupdate}
	databakdir=${datadir}.${backupdate}
	if [ "$dbname" != "" ]; then
		dbbakdir=${dbbackuproot}/${dbname}.${backupdate}
	fi
}

function env_print_main_dirs() {
	if [ "$archive" != "" ]; then
		echo "archive    = stable${baseversion}/${archive}"
	fi
	echo "sitedomain = ${sitedomain}"
	echo "sitepath   = ${sitepath}"
	echo "sitedir    = ${sitedir}"
	echo "datadir    = ${datadir}"
	echo "assetsdir  = ${assetsdir}"
}

function env_print_backup_dirs() {
	if [ "$dbname" != "" ]; then
		echo "dbname     = ${dbname}"
		echo "dbdir      = ${dbdir}"
	fi
	echo "sitebakdir = ${sitebakdir}"
	echo "databakdir = ${databakdir}"
	if [ "$dbname" != "" ]; then
		echo "dbbakdir   = ${dbbakdir}"
	fi
}


function env_calc_new_db_names()
{
	echo "Generating new database and user names..."
	if [ "${newdbname}" == "" ]; then
		newdbname=${sitedomain//./_}
		if ! [ "${sitepath}" = "" ]; then
			newdbname=${newdbname}_${sitepath//[^A-Za-z0-9_]/}
		fi
	fi
	if [ "${newdbuser}" == "" ]; then
		newdbuser=${newdbname}
		local i=0 arr
		arr=(${newdbuser//_/ })
		i=${#arr[*]}
		while [ ${#newdbuser} -gt 16 -a $i -gt 0 ]; do
			let i--
			arr[i]=${arr[i]:0:1}
			newdbuser=${arr[*]}
			newdbuser=${newdbuser// /_}
		done
		while [ ${#newdbuser} -gt 16 -a ${#arr[*]} -gt 1 ]; do
			arr[-2]=${arr[-2]}${arr[-1]}
			unset arr[-1]
			newdbuser=${arr[*]}
			newdbuser=${newdbuser// /_}
		done
		newdbuser=${newdbuser:0:16}
	fi
	if [ "${newdbpass}" == "" ]; then
		newdbpass=
		arr=(a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 0 1 2 3 4 5 6 7 8 9 . _ - : , !)
		for (( i=0 ; i < 40 ; i++ )) ; do
			newdbpass="${newdbpass}${arr[RANDOM % ${#arr[*]}]}"
		done
	fi
}

function env_get_ip()
{
	newip=$(resolveip -s ${sitedomain}) || newip=\*
}

function ui_prompt_db_root_creds_to_file()
{
	local rootdbuser rootdbpass
	root_creds_file=~/.$$-gemma-creds-root
	echo '[client]' > ${root_creds_file}
	add_trap fs_creds_cleanup 0
	chmod 600 ${root_creds_file}
	read -p "Enter database root user name: " rootdbuser
	echo user = ${rootdbuser} >> ${root_creds_file}
	unset rootdbuser
	read -p "Enter database root password: " -s rootdbpass
	echo ""
	echo password = ${rootdbpass} >> ${root_creds_file}
	unset rootdbpass
}

function mdl_config_get_db_name() {
	dbname=$(sudo -u ${a2user} ${php} -r 'define('\''CLI_SCRIPT'\'',true); require('\'${sitedir}/config.php\''); print($CFG->dbname);')
}

function mdl_extract_db_creds_to_file()
{
	mdl_creds_file=~/.$$-gemma-creds-mdl
	echo '[client]'>${mdl_creds_file}
	add_trap fs_creds_cleanup 0
	chmod 600 ${mdl_creds_file}
	echo user = $(sudo -u ${a2user} ${php} -r 'define('\''CLI_SCRIPT'\'',true); require('\'${sitedir}/config.php\''); print($CFG->dbuser);') >> ${mdl_creds_file}
	echo password = $(sudo -u ${a2user} ${php} -r 'define('\''CLI_SCRIPT'\'',true); require('\'${sitedir}/config.php\''); print($CFG->dbpass);') >> ${mdl_creds_file}
}

function mdl_endisable_maint_mode() {
	pushd ${sitedir} 2>&1 1>/dev/null
	sudo -u ${a2user} ${php} ${sitedir}/admin/cli/maintenance.php --$1
	popd 2>&1 1>/dev/null
}

function mdl_upgrade() {
	echo "Running Moodle upgrade..."
	echo "========================="
	pushd ${sitedir} 2>&1 1>/dev/null
	if [ "$1"=="unattended" ]; then
		args=--non-interactive
	else
		args=
	fi
	sudo -u ${a2user} ${php} ${sitedir}/admin/cli/upgrade.php $args
	popd 2>&1 1>/dev/null
}

function mdl_install() {
	echo "Running Moodle install..."
	echo "========================="
	pushd ${sitedir} 2>&1 1>/dev/null
	local wwwrooturl
	if [ "$ssl" == "0" ]; then
		wwwrooturl="http"
	else
		wwwrooturl="https"
	fi
	wwwrooturl="${wwwrooturl}://${sitedomain}"
	if [ "${sitepath}" != "" ]; then
		wwwrooturl="${wwwrooturl}/${sitepath}"
	fi
	fs_get_octal_from_perms
	sudo -u ${a2user} ${php} ${sitedir}/admin/cli/install.php --chmod=${datadiroctal} --wwwroot=${wwwrooturl} --dataroot=${datadir}/moodledata --dbname="${newdbname}" --dbuser="${newdbuser}" --dbpass="${newdbpass}"
	popd 2>&1 1>/dev/null
}

function mdl_get_plugin_update_list() {
	echo "Getting Moodle plugin update list..."
	echo "===================================="
	pushd ${sitedir} 2>&1 1>/dev/null
	update_list="$(sudo -u ${a2user} ${php} <<'EOF'
<?php
	define('CLI_SCRIPT',true);
	require_once('./config.php');
	require_once($CFG->libdir . '/adminlib.php');
	require_once($CFG->libdir . '/filelib.php');
	$pluginman = core_plugin_manager::instance();
	$checker = \core\update\checker::instance();
	$checker->fetch();
	$plugininfo = $pluginman->get_plugins();
	foreach($plugininfo as $type => $plugins)
	{
		foreach($plugins as $name => $plugin)
		{
			if($plugin->component != 'core')
			{
				$available_updates = $checker->get_update_info($plugin->component);
				if(!is_null($available_updates))
				{
					$versionsofar = $plugin->versiondisk;
					if(is_null($versionsofar))
						$versionsofar=0;
					$currversion=$versionsofar;
					foreach($available_updates as $available_update)
					{
						if($available_update->version > $versionsofar)
						{
							$versionsofar=$available_update->version;
							$update = '--package=' . $available_update->download.'|--typeroot='. $plugin->typerootdir .'|--name='.$name.
								'|--md5='. $available_update->downloadmd5."\n";
						}
					}
					if($versionsofar > $currversion)
						print($update);
				}
			}
		}
	}
EOF
	)"
	popd 2>&1 1>/dev/null
}

function mdl_deploy_plugin_updates()
{
	echo "Deploying Moodle plugin updates..."
	echo "=================================="
	pushd ${sitedir} 2>&1 1>/dev/null
	echo "$update_list"
	for a in $update_list; do echo ${a//|/ }; sudo -u ${a2user} ${php} mdeploy.php --upgrade ${a//|/ }; done
	popd 2>&1 1>/dev/null
}

function a2_get_ver()
{
	local IFS="."
	apachever=($(a2query -v))
}

function a2_create_site_config()
{
	echo "Creating Apache2 site config..."
	if ! [ -e ${a2sitesavaildir}/$sitedomain.conf ]; then
		env_get_ip
		if [ "${ssl}" == "1" ]; then
			if ! [ -e ${certdir}/${sitedomain}.cert ]; then
				echo "ERROR! cannot find certificate: ${certdir}/${sitedomain}.cert"
				exit -1
			fi
			if ! [ -e ${privkeydir}/${sitedomain}.key ]; then
				echo "ERROR! cannot find private key file: ${privkeydir}/${sitedomain}.key"
				exit -1
			fi
			cat > ${a2sitesavaildir}/${sitedomain}.conf <<-EOF
				<VirtualHost ${newip}:443>
				DocumentRoot ${wwwroot}/${sitedomain}/${htdocs}
				ServerName ${sitedomain}
				SSLEngine on
				SSLCertificateFile ${certdir}/${sitedomain}.cert
				SSLCertificateKeyFile ${privkeydir}/${sitedomain}.key
			EOF
			if [ -e ${certdir}/${sitedomain}.chain.cert ]; then
				echo SSLCertificateChainFile ${certdir}/${sitedomain}.chain.cert>>${a2sitesavaildir}/${sitedomain}.conf
			fi
			cat >> ${a2sitesavaildir}/${sitedomain}.conf <<-EOF
				Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
				</VirtualHost>
			EOF
		fi

		cat >> ${a2sitesavaildir}/${sitedomain}.conf <<-EOF
			<VirtualHost ${newip}:80>
			DocumentRoot ${wwwroot}/${sitedomain}/${htdocs}
		EOF
		if [ "${ssl}" == "1" ]; then
			cat >> ${a2sitesavaildir}/${sitedomain}.conf <<-EOF
				RedirectPermanent / https://${sitedomain}:443/
				<Directory "${wwwroot}/${sitedomain}/${htdocs}">
				allow from none
				</Directory>
			EOF
		fi
		cat >> ${a2sitesavaildir}/${sitedomain}.conf <<-EOF
			</VirtualHost>
		EOF
	fi
}

function a2_check_site_config()
{
	echo "Checking Apache2 config..."
	apache2ctl configtest
}

function a2_enable_site_config()
{
	echo "Enabling Apache2 site..."
	a2ensite ${sitedomain}
	apache2ctl restart
}

function a2_add_path_dir_config()
{
	local port
	if [ "$ssl" == "0" ]; then
		port='80'
	elif [ "$ssl" == "1" ]; then
		port='443'
	fi
	sed -i -f - ${a2sitesavaildir}/${sitedomain}.conf <<-EOF
		/<VirtualHost[^:]*:${port}/,/<\/VirtualHost>/ {
		/<\/VirtualHost>/i<Directory "${sitedir}">\n\
allow from all\n\
Options -Indexes\n\
</Directory>
		}
	EOF
}

function a2fs_create_site_root_dir()
{
	if ! [ -d ${wwwroot}/${sitedomain} ]; then
		echo "Creating Apache2 site upper root directory..."
		mkdir ${wwwroot}/${sitedomain}
		chown root:${a2group} ${wwwroot}/${sitedomain}
		chmod u+rwX,g+rX-w,o-rwx ${wwwroot}/${sitedomain}
	fi
	if [ "${sitepath}" != "" ] && ! [ -d ${wwwroot}/${sitedomain}/${htdocs} ]; then
		echo "Creating Apache2 site lower root directory..."
		mkdir ${wwwroot}/${sitedomain}/${htdocs}
		chown root:${a2group} ${wwwroot}/${sitedomain}/${htdocs}
		chmod u+rXw,g+rX-w,o-rwx ${wwwroot}/${sitedomain}/${htdocs}
	fi
}

function a2fs_create_path_parent_dir()
{
	if [[ "${sitepath}" =~ .+/.+ ]]; then
		echo "Creating Apache2 site intermediary directories..."
		local p d
		local -a dirs
		p=$(dirname ${sitepath})
		dirs=()
		while [ "$p" != "." ]; do
			dirs=($p ${dirs[*]})
			p=$(dirname $p)
		done
		for p in ${dirs[*]}; do
			d=${wwwroot}/${sitedomain}/${htdocs}/$p
			if ! [ -d $d ]; then
				mkdir $d
				chown root:${a2group} $d
				chmod u+rwX,g+rX-w,o-rwx $d
			fi
		done
	fi
}

function a2fs_install_site_files()
{
	echo "Instating new site files..."
	if [ "${sitepath}"=="" -a -d "${sitedir}" ]; then
		rmdir ${sitedir}
	fi
	mv ${tempdir}/$$/moodle ${sitedir}/
}

function a2fs_restore_config()
{
	echo "Re-instating config..."
	cp -p ${sitebakdir}/config.php ${sitedir}/
}

function a2fs_install_custom_assets()
{
	echo "Re-instating custom assets..."
	if ( ! [ -d $assetsdir/+all+ ] ) && ( ! [ -d $assetsdir/+path+ ] ); then
		echo "No custom assets to install"
	else
		if [ -d $assetsdir/+all+ ]; then
			for a in $assetsdir/+all+/*; do
				name=$(basename $a)
				find ${sitedir}/ -type f -name $name -exec cp -p $a '{}' \;
			done
		fi
		if [ -d $assetsdir/+path+ ]; then
			cp -rfp $assetsdir/+path+/* ${sitedir}
		fi
	fi
}

function a2fs_lock_unlock_write_permissions()
{
  local sitemod
  if [ "$1"=="unlocked" || "$1"=="unlock" ]; then
		echo "Unlocking write permissions on Apache2 dir"
    sitemods=${sitemodsunlocked}
  else
		echo "Locking write permissions on Apache2 dir"
    sitemods=${sitemodslocked}
  fi
	chown -R ${siteowner} ${sitedir}/
	chmod -R ${sitemods} ${sitedir}/
}

function mdlfs_create_data_root_dir()
{
	if [ -d ${dataroot}/${sitedomain} ]; then
		echo "Creating Moodle data root directory..."
		mkdir ${dataroot}/${sitedomain}
		chown root:${a2group} ${dataroot}/${sitedomain}
		chmod u+rwX,g+rX-w,o-rwx ${dataroot}/${sitedomain}
	fi
}

function mdlfs_create_data_path_dir()
{
	if ! [ -d ${datadir} ]; then
		echo "Creating Moodle data path directory..."
		mkdir -p ${datadir}
		chown root:${a2group} ${datadir}
		chmod u+rXw,g+rX-w,o-rwx ${datadir}
	fi
	if ! [ -d ${datadir}/moodledata ]; then
		mkdir -p ${datadir}/moodledata
		chown root:${a2group} ${datadir}/moodledata
		chmod u+rXw,g+rXw,o-rwx ${datadir}/moodledata
	fi
}

function err_exit()
{
	if [ "${ignore_errs}" == "" ]; then
		echo "Fatal error - exiting"
		exit -1;
	fi
}

function fs_creds_cleanup()
{
	echo "Cleaning up creds..."
	rm -f ~/.$$-*
}

function fs_tmp_cleanup()
{
	echo "Cleaning up temp files..."
	rm -rf ${tempdir}/$$
}

function fs_check_main_dirs() {
	if ! [ -d ${dbdir} ]; then
		echo Database files missing from ${dbdir}
		exit -1
	fi

	if ! [ -d ${sitedir} ]; then
		echo "\"${sitedir}\": not a vaild Moodle site dir"
		exit -1
	fi
	if ! [ -d ${datadir}/moodledata ]; then
		echo "\"${datadir}\": not a vaild Moodle data dir"
		exit -1
	fi
}

function fs_check_site_and_data_backup_dirs() {
	if [ -e ${sitebakdir} ] || [ -e ${databakdir} ]; then
		echo "Backup already exists for today; roll back or rename the existing backup before proceeding"
		exit -1
	fi
}

function fs_check_db_backup_dir() {
	if [ -e ${dbbakdir} ]; then
		echo "Backup already exists for today; roll back or rename the existing backup before proceeding"
		exit -1
	fi
}

function fs_fetch_and_extract_archive() {
	echo ""
	echo "FETCHING and EXTRACTING MOODLE SOFTWARE ARCHIVE..."
	echo "=================================================="
	archivedir=${tempdir}/$$/
	[ -e ${archivedir}/moodle ] && rm -rf ${archivedir}/moodle 
	mkdir -p ${archivedir}
	add_trap fs_tmp_cleanup 0
	[ -e ${archivedir}/${archive} ] && rm ${archivedir}/${archive}
	wget http://downloads.sourceforge.net/project/moodle/Moodle/stable${baseversion}/${archive} -P ${archivedir}
	echo "Extracting files..."
	(tar xvzf ${archivedir}/${archive} -C ${archivedir} | awk '/^.*\/$/{printf "."}' )
	rm ${archivedir}/${archive}
	echo "done"
}

function fs_get_octal_from_perms()
{
	mkdir ${tempdir}/$$/test
	chown ${dataowner} ${tempdir}/$$/test
	chmod ${datamods} ${tempdir}/$$/test
	if [ "${datasetgid}" == "1" ]; then
		chmod g+s ${tempdir}/$$/test
	fi
	datadiroctal=$(stat -c "%a" ${tempdir}/$$/test)
	rm -rf ${tempdir}/$$/test
}

function fs_correct_permissions()
{
  local sitemods
  if [ "$1"=="unlocked" -o "$1"=="unlock" ]; then
    sitemods=${sitemodsunlocked}
  else
    sitemods=${sitemodslocked}
  fi
	echo "Correcting ownership and permissons..."
	chown -R ${siteowner} ${sitedir}/
	chmod -R ${sitemods} ${sitedir}/
	chown -R ${dataowner} ${datadir}/
	chmod -R ${datamods} ${datadir}/
	if [ "${datasetgid}" == "1" ]; then
		find ${datadir}/ -type d -exec chmod g+s '{}' \;
	fi
}

function mysql_get_ver()
{
	local IFS="."
	mysqlver=($(mysql --defaults-extra-file="${mdl_creds_file}" -N -s -r -e "SELECT @@VERSION;" ))
}

function mysql_check_root_creds()
{
	echo "Checking MySQL login details..."
	mysql --defaults-extra-file="${root_creds_file}" -N -s -r -e "SELECT 'OK';" || {
		echo "Credentials failed."
		exit -1
	}
}

function mysql_create_raw_db()
{
	local createdbname=$1
	local sql="CREATE DATABASE /* IF NOT EXISTS */ \`${createdbname}\` CHARACTER SET=utf8 COLLATE=utf8_unicode_ci;"
	mysql --defaults-extra-file=${root_creds_file} -e "$sql"
}

function mysql_create_empty_db()
{
	echo "Creating empty database and users..."
	mysql_create_raw_db ${newdbname}
	local sql="GRANT RELOAD, REPLICATION CLIENT ON *.* TO '${newdbuser}'@'localhost' IDENTIFIED BY '${newdbpass}', '${newdbuser}'@'127.0.0.1' IDENTIFIED BY '${newdbpass}';\
	GRANT ALL PRIVILEGES ON \`${newdbname}\`.* TO '${newdbuser}'@'localhost', '${newdbuser}'@'127.0.0.1' WITH GRANT OPTION"
	mysql --defaults-extra-file=${root_creds_file} -e "$sql"
}

function mysql_backup_db()
{
	
	echo "Backing up database files"
	mkdir -p ${dbbackuproot}
	if [ "$xtrabackup" == "auto" -a \( ${mysqlver[0]} -gt 5 -o \( ${mysqlver[0]} -eq 5 -a ${mysqlver[1]} -gt 5 \) \) -o \( "$xtrabackup" != "0" -a "$xtrabackup" != "" \) ]; then
		if ! [ ${mysqlver[0]} -gt 5 -o \( ${mysqlver[0]} -eq 5 -a ${mysqlver[1]} -gt 5 \) ]; then
			echo "Xtrabackup only supported for MySQL 5.6 and above"
			exit -1
		fi
		echo innobackupex --defaults-extra-file=${mdl_creds_file} --databases="${dbname}" --no-timestamp ${xtrabackupflags} --backup ${dbbakdir}
		innobackupex --defaults-extra-file=${mdl_creds_file} --databases="${dbname}" --no-timestamp ${xtrabackupflags} --backup ${dbbakdir}
		mysqldump --defaults-extra-file=${mdl_creds_file} --no-data ${dbname} > ${dbbakdir}/"${dbname}".sql
		mysql --defaults-extra-file=${mdl_creds_file} -N -s -r "${dbname}" <<-'EOF'  > ${dbbakdir}/"${dbname}".DISCARD.sql
			SELECT CONCAT('ALTER TABLE `',table_name,'` DISCARD TABLESPACE;') FROM INFORMATION_SCHEMA.TABLES   WHERE table_schema = DATABASE(); 
		EOF
		mysql --defaults-extra-file=${mdl_creds_file} -N -s -r "${dbname}" <<-'EOF'  > ${dbbakdir}/"${dbname}".IMPORT.sql
			SELECT CONCAT('ALTER TABLE `',table_name,'` IMPORT TABLESPACE;') FROM INFORMATION_SCHEMA.TABLES   WHERE table_schema = DATABASE(); 
		EOF
	fi
	if [ "$mysqldump" != "0" -a "$mysqldump" != "" ]; then
		mysqldump --defaults-extra-file=${mdl_creds_file} -c -e --single-transaction "${dbname}" > ${dbbakdir}/"${dbname}".FULL.sql
	fi
}

function mysql_prep_backup()
{
	if [ "$xtrabackup" != "0" -a "$xtrabackup" != "" ]; then
		echo "Prepping the database files"
		innobackupex --apply-log --export ${dbbakdir}
	fi
}

function mysql_restore_db()
{
	local restoredbname=$1
	local method=$2
	if [ -e ${dbbakdir}/"${dbname}".sql -a "$method" != "mysqldump" ]; then
		echo "Restoring database via xtrabackup."
		echo "Creating tables..."
		mysql --defaults-extra-file=${root_creds_file} "${restoredbname}" < ${dbbakdir}/"${dbname}".sql
		echo "Discarding tablespaces..."
		mysql --defaults-extra-file=${root_creds_file} "${restoredbname}" < ${dbbakdir}/"${dbname}".DISCARD.sql
		echo "Copying ibd and cfg files..."
		cp ${dbbakdir}/"${dbname}"/*.ibd ${dbfiles}/"${restoredbname}"
		cp ${dbbakdir}/"${dbname}"/*.cfg ${dbfiles}/"${restoredbname}"
		echo "Correcting file ownership..."
		chown ${mysqluser}:${mysqlgrp} ${dbfiles}/"${restoredbname}"/*.cfg ${dbfiles}/"${restoredbname}"/*.ibd
		echo "Importing..."
		mysql --defaults-extra-file=${root_creds_file} "${restoredbname}" < ${dbbakdir}/"${dbname}".IMPORT.sql
		echo "Killing .cfg files..."
		rm -f ${dbfiles}/"${restoredbname}"/*.cfg 
	elif [ -e ${dbbakdir}/"${dbname}".FULL.sql -a "$method" != "xtrabackup" ]; then
		echo "Restoring database via mysqldump."
		mysql --defaults-extra-file=${root_creds_file} "${restoredbname}" < ${dbbakdir}/"${dbname}".FULL.sql
	else
		echo "ERROR: no backup file found"
		exit -1
	fi
}

function gemma_do_backup()
{
	echo "Backing up data files..."
	cp -rfp ${datadir} ${databakdir}
	mysql_backup_db
	mysql_prep_backup
	echo "Backing up site files..."
	if [ "$1"=="move"  ]; then
		mv ${sitedir} ${sitebakdir}
	else
		cp -rf ${sitedir} ${sitebakdir}
	fi
}

functions_inc=1

