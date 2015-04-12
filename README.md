# GEMMA
GEMMA Eases Muti-instance Moodle Admin

GEMMA is a collection of bash scripts, with some embedded PHP, designed to simplify the administration of Moodle 2.7+ installations in a LAMP environment, especially those having multiple instances.

REQUIREMENTS

- Linux
- Apache 2
- MySQL 5.5, configured for InnoDB and innodb_file_per_table
- PHP 5.x Moodle 2.7 or higher
- Percona XtraBackup

GEMMA has a recommended directory layout which is detailed in etc/GEMMA. Some of this is compulsory; some can be configured via /etc/GEMMA.

Without file-per-table, all your moodle instances will live in a single database file and XtraBackup will backup the whole system every time. This is considered bad practice all round and causes performance issues. see http://stackoverflow.com/questions/3927690/howto-clean-a-mysql-innodb-storage-engine/

INSTALLATION

Download and extract the source as zip. Execute:

	md GEMMA
	cd GEMMA
	unzip GEMMA-master.zip
	sudo ./install.sh

Then review and edit /etc/GEMMA.

USAGE

Most programs give usage just by typing their name:

gemma-upgrade

Single command to backup and upgrade a single instance, from download through to database upgrade (inclusive).

gemma-upgrade-plugins

Single command to update all plugins within a single instance

gemma-install-custom-assets

Pulls assets from a pre-assigned directory into the moodle install. Useful for things like web favourite icons that cannot be assigned through the regular theme interface.

gemma-restore-config

Restores the config.php file from a recent GEMMA backup.

COPYRIGHT

GEMMA is Copyright (C) 2015 Stephen Parry

Moodle is a registered trademark of the Moodle Trust.
GEMMA is in no way maintained or endorsed by the Moodle Trust.

