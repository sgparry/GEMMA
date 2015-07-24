# GEMMA
GEMMA Eases Muti-instance Moodle Admin

GEMMA is a collection of bash scripts, with some embedded PHP and SQL, designed to simplify the administration of Moodle 2.7+ installations in a LAMP environment, especially those having multiple instances.

REQUIREMENTS

- Linux
- Apache 2
- MySQL 5.5+, configured for InnoDB and innodb_file_per_table
- PHP 5.x Moodle 2.7 or higher
- Percona XtraBackup

GEMMA has a recommended directory layout which is detailed in etc/GEMMA. Some of this is compulsory; some can be configured via /etc/GEMMA.

Without file-per-table, all your moodle instances will live in a single database file. This is considered bad practice all round and causes performance issues.
see http://stackoverflow.com/questions/3927690/howto-clean-a-mysql-innodb-storage-engine/
In MySQL 5.6+ file per table is the default.

Note that even with file per table, Percona is pretty useless for MySQL 5.5-. version 0.2+ of GEMMA defaults to using mysqldump for MySQL 5.5-.

Ubuntu 14.04 users: If you want to upgrade MySQL 5.6 but want to remain on Ubuntu 14.04, you can do so by using Oracle's own MySQL apt repo. This has worked well for me, but look out for some gotchas, especially the permissions on /etc/mysql/my.cnf.

INSTALLATION

Download and extract the source as zip. Execute:

	md GEMMA
	cd GEMMA
	unzip GEMMA-master.zip
	sudo ./install.sh

Then review and edit /etc/GEMMA.

USAGE

Most programs give usage just by typing their name:

gemma-install

Single command to install a new instance - automates the site-named database and user creation, random db passwords, apache configuration and the directory creation. It feeds the resulting config into the standard Moodle install process.

gemma-upgrade

Single command to backup and upgrade a single instance, from download through to database upgrade (inclusive).

gemma-upgrade-plugins

Single command to update all plugins within a single instance.

gemma-lock-unlock-site-files

Turns on / off the write protection on the main site php files. Whilst write protection is on, the site is more secure. Turning protection off allows plugin installations and upgrades from within the web interface.

gemma-install-custom-assets

Pulls assets from a pre-assigned directory into the moodle install. Useful for things like web favourite icons that cannot be assigned through the regular theme interface.

gemma-restore-config

Restores the config.php file from a recent GEMMA backup.

gemma-backup

Backs up the complete moodle site, data and database to a set of dated directories.

gemma-backupdb

Backs up the moodle database to a dated directory using mysqldump or xtrabackup.

gemma-restoredb

Restores the moodle database backup to a new database.

COPYRIGHT

GEMMA is Copyright (C) 2015 Stephen Parry

Moodle is a registered trademark of the Moodle Trust.
GEMMA is in no way maintained or endorsed by the Moodle Trust.

