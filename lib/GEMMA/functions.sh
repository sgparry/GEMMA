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

function check_root() {
  if [[ $EUID -ne 0 ]]; then
     echo "This script must be run as root" 1>&2
     exit 1
  fi
}

function parse_version() {
  version=(${1//\./ })
  baseversion=${version[0]}${version[1]}
  if [ ${version[-1]} == x ]; then
    archive=moodle-latest-${baseversion}.tgz
  else
    archive=moodle-$1.tgz
  fi
}

function parse_site_address() {
  sitedomain=${1%%/*}
  sitepath=${1#*/}
  if [ "$sitepath" = "$1" ]; then
    sitepath=
  fi
}

function set_main_dirs() {
  sitedir=${wwwroot}/${sitedomain}/${htdocs}
  datadir=${dataroot}/${sitedomain}
  assetsdir=${assetsroot}/${sitedomain}
  if ! [ "${sitepath}" = "" ]; then
    sitedir=${sitedir}/${sitepath}
    datadir=${datadir}/${sitepath}
    assetsdir=${assetsdir}/${sitepath}
  fi
}

function set_db_name() {
  dbname=$(sudo -u $a2user php -r 'define('\''CLI_SCRIPT'\'',true); require('\'${sitedir}/config.php\''); print($CFG->dbname);') || exit -1
}

function set_backup_dirs() {
  if [ "$1" = "" ]; then
    backupdate=`date +%Y%m%d`
  else
    backupdate=$1
  fi
  sitebakdir=${sitedir}.${backupdate}
  databakdir=${datadir}.${backupdate}
  if [ "$dbname" != "" ]; then
    dbbakdir=${dbbackuproot}/${dbname}/${backupdate}
  fi
}

function print_main_dirs() {
  if [ "$archive" != "" ]; then
    echo "archive    = stable${baseversion}/${archive}"
  fi
  echo "sitedomain = ${sitedomain}"
  echo "sitepath   = ${sitepath}"
  echo "sitedir    = ${sitedir}"
  echo "datadir    = ${datadir}"
  echo "assetsdir  = ${assetsdir}"
}

function print_backup_dirs() {
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

function check_main_dirs() {
  if ( ! [ -d ${dbdir} ] ); then
    echo Database files missing from ${dbdir}
    exit -1
  fi

  if ! [ -d ${sitedir} ]; then
    echo "\"${sitedir}\": not a vaild moodle site dir"
    exit -1
  fi
  if ! [ -d ${datadir}/moodledata ]; then
    echo "\"${datadir}\": not a vaild moodle data dir"
    exit -1
  fi
}

function check_backup_dirs() {
  if [ -e ${sitebakdir} ] || [ -e ${databakdir} ]; then
    echo "Backup already exists for today; roll back or rename the existing backup before proceeding"
    exit -1
  fi
}

function fetch_and_extract_archive() {
  archivedir=/tmp/$$/
  [ -e ${archivedir}/moodle ] && rm -rf ${archivedir}/moodle 
  mkdir -p ${archivedir}
  [ -e ${archivedir}/${archive} ] && rm ${archivedir}/${archive}
  wget http://downloads.sourceforge.net/project/moodle/Moodle/stable${baseversion}/${archive} -P ${archivedir} || exit -1
  echo "Extracting files..."
  (tar xvzf ${archivedir}/${archive} -C ${archivedir} | awk '/^.*\/$/{printf "."}' ) || exit -1
  rm ${archivedir}/${archive}
  echo "done"
}

function mdl_endisable_maint_mode() {
  pushd ${sitedir} 2>&1 1>/dev/null
  sudo -u $a2user /usr/bin/php ${sitedir}/admin/cli/maintenance.php --$1 || exit -1
  popd 2>&1 1>/dev/null
}

function mdl_upgrade() {
  pushd ${sitedir} 2>&1 1>/dev/null
  sudo -u $a2user /usr/bin/php ${sitedir}/admin/cli/upgrade.php || exit -1
  popd 2>&1 1>/dev/null
}

function mdl_install() {
  pushd ${sitedir} 2>&1 1>/dev/null
  sudo -u $a2user /usr/bin/php ${sitedir}/admin/cli/install.php || exit -1
  popd 2>&1 1>/dev/null
}

function mdl_get_update_list() {
  pushd ${sitedir} 2>&1 1>/dev/null
  update_list="$(sudo -u $a2user php <<'EOF'
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

function mdl_deploy_updates()
{
  pushd ${sitedir} 2>&1 1>/dev/null
  echo "$update_list"
  for a in $update_list; do echo ${a//|/ }; sudo -u www-data php mdeploy.php --upgrade ${a//|/ } || exit -1; done
  popd 2>&1 1>/dev/null
}


function do_backup() {
  echo "Backing up data files..."
  cp -rfp ${datadir} ${databakdir} || exit -1
  echo "Backing up database files"
  mkdir -p ${dbbakdir}
  xtrabackup --databases=${dbname} ${xtrabackupflags} --target-dir=${dbbakdir} --backup || exit -1
  echo "Backing up site filles..."
  mv ${sitedir} ${sitebakdir} || exit -1
}

function install_site_files() {
  echo "Instating new site files..."
  mv /tmp/$$/moodle ${sitedir}/ || exit -1
}

function restore_config() {
  echo "Re-instating config..."
  cp -p ${sitebakdir}/config.php ${sitedir}/ || exit -1
}

function install_custom_assets() {
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

function restore_permissions() {
  echo "Correcting ownership and permissons..."
  chown -R root:$a2user ${sitedir}/
  chmod -R u+rwX,g+rwX,o-rwx ${sitedir}/
}

functions_inc=1

