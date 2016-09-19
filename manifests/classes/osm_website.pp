class osm_website_postgres_db (
		$db_prod_name="osm_www_prod",
		$db_prod_user="osm_www_prod",
		$db_prod_passwd="XXXXXXXX",
		$db_dev_name="osm_www_dev",
		$db_dev_user="osm_www_dev",
		$db_dev_passwd="XXXXXXXX",

		$db_prod_search_name="osm_www_search",
		$db_prod_search_user="osm_www_search",
		$db_prod_search_passwd="XXXXXXXX",

		$db_dev_search_name="osm_www_search_dev",
		$db_dev_search_user="osm_www_search",
		$db_dev_search_passwd="XXXXXXXX",
	){

	#=====================   Настройка postgres-сервера: ====================

	# Если нет базовой конфигурации - создаём:
  	if !defined(Class['postgresql::server']) {
		class { 'postgresql::globals':
			encoding => 'UTF-8',
			locale   => 'en_US.UTF-8',
		}->
		class { 'postgresql::server': 
			listen_addresses           => '*',
			ip_mask_allow_all_users    => $db_access_netmask,
		
		}
	}

	# Создаём таблицы:
	postgresql::server::db { $db_prod_name:
		user     => $db_prod_user,
		password => postgresql_password($db_prod_user, $db_prod_passwd),
	}

	# ставим расширение hstore
	postgresql::server::extension{ "hstore to $db_prod_name":
		extension_name => "hstore",
		database => $db_prod_name,
		ensure => present,
	}

	postgresql::server::db { $db_dev_name:
		user     => $db_dev_user,
		password => postgresql_password($db_dev_user, $db_dev_passwd),
	}

	# ставим расширение hstore
	postgresql::server::extension{ "hstore to $db_dev_name":
		extension_name => "hstore",
		database => $db_dev_name,
		ensure => present,
	}

	postgresql::server::db { $db_prod_search_name:
		user     => $db_prod_search_user,
		password => postgresql_password($db_prod_search_user, $db_prod_search_passwd),
	}

	postgresql::server::db { $db_dev_search_name:
		user     => $db_dev_search_user,
		password => postgresql_password($db_dev_search_user, $db_dev_search_passwd),
	}

}

class osm_website (
		$vhost_prodaction="map.prim.drsk.ru",
		$vhost_dev="beta.map.prim.drsk.ru",
		$install_path="/opt/osm",
		$site_git_src="http://git.rs.int/osm/openstreetmap-ru_drsk.git",

		$db_prod_name="osm_www_prod",
		$db_prod_user="osm_www_prod",
		$db_prod_passwd="XXXXXXXX",
		$db_prod_host="db.rs.int",
		$db_dev_name="osm_www_dev",
		$db_dev_user="osm_www_dev",
		$db_dev_passwd="XXXXXXXXXXX",
		$db_dev_host="db.rs.int",

		$db_stapio_host="db.rs.int",
		$db_stapio_name="stapio",
		$db_stapio_user="stapio",
		$db_stapio_passwd="XXXXXXXX",

		$db_prod_search_host="db.rs.int",
		$db_prod_search_name="osm_www_search",
		$db_prod_search_user="osm_www_search",
		$db_prod_search_passwd="XXXXXXXX",
		$db_prod_search_update_log_path="/var/log/osm/osm2power_search_db_update.log",

		$db_dev_search_host="db.rs.int",
		$db_dev_search_name="osm_www_search_dev",
		$db_dev_search_user="osm_www_search",
		$db_dev_search_passwd="XXXXXXXX",
		$db_dev_search_update_log_path="/var/log/osm/osm2power_search_db_update.log",

		$db_osm_host="db.rs.int",
		$db_osm_name="drsk_dev_osm",
		$db_osm_user="osm_read_only",
		$db_osm_passwd="XXXXXXXX",
	){

	$website_path="${install_path}/openstreetmap.ru"
	$website_prod_path="${website_path}/OpenStreetMap.ru_prodaction"
	$website_dev_path="${website_path}/OpenStreetMap.ru_dev"

	# Ставим нужные пакеты:
	$packages_to_install=["php5-curl","python-psycopg2", "postgresql-client-common", "postgresql-client", "php5-odbc", "php5-pgsql","python-numpy", "python-opencv"]
	package { $packages_to_install:
		ensure => installed,
	}
  	if !defined(Class['git']) {
		include git
	}
	if !defined(file ["${install_path}"]) {
		file {"${install_path}":
			ensure => directory,
		}
	}
	if !defined(file ["${website_path}"]) {
		file {"${website_path}":
			ensure => directory,
			require => file["${install_path}"],
		}
	}

	# Скачиваем код сайта:
	exec { "git_clone_prod_website":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone ${site_git_src} ${website_prod_path}",
		cwd => "${website_path}",
		creates => "${website_prod_path}",
		require => [package['git'], file["${website_path}"] ],
	}
	exec { "git_clone_dev_website":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone ${site_git_src} ${website_dev_path}",
		cwd => "${website_path}",
		creates => "${website_dev_path}",
		require => [package['git'], file["${website_path}"] ],
	}

	# Настройка apache:
 	if !defined(Class['apache']) {
		class { 'apache':
		  mpm_module        => 'prefork',
		  keepalive         => 'off',
		  keepalive_timeout => '4',
		  timeout           => '45',
		  default_vhost     => false,
		}
	}
	if !defined(Class['apache::mod::php']) {
		include apache::mod::php
	}
  	if !defined(Class['apache::mod::rewrite']) {
    	include apache::mod::rewrite
  	}
  	if !defined(Class['apache::mod::python']) {
    	include apache::mod::python
  	}
	# правим конфиг php:
	file_line { 'apache short_open_tag = On':
		ensure  => present,
		path  => '/etc/php5/apache2/php.ini',
		line  => 'short_open_tag = On',
		match => '^ *short_open_tag',
		require => Class['apache::mod::php']
	}

	apache::vhost { $vhost_prodaction:
		port => '80',
		docroot => "${website_prod_path}/www",
		aliases => [
			{ scriptalias      => '/api/',
				path             => "${website_prod_path}/api/",
			},
		],
		redirect_source => ['/about/js/', '/help/js/'],
		redirect_dest   => ['/js/','/js/'],
		access_log_file => "access_${vhost_prodaction}.log",
		error_log_file => "error_${vhost_prodaction}.log",
		directories => [
		  { path      => "${website_prod_path}/www",
			options        => ['+Indexes', '+FollowSymLinks','-MultiViews'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		  { path      => "${website_prod_path}/api",
			options        => ['+ExecCGI', '+SymLinksIfOwnerMatch','-MultiViews'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		],

		require => [
			exec [ "git_clone_prod_website"],
			]
	}

	apache::vhost { $vhost_dev:
		port => '80',
		docroot => "${website_dev_path}/www",
		aliases => [
			{ scriptalias      => '/api/',
				path             => "${website_dev_path}/api/",
			},
		],
		redirect_source => ['/about/js/', '/help/js/'],
		redirect_dest   => ['/js/','/js/'],
		access_log_file => "access_${vhost_dev}.log",
		error_log_file => "error_${vhost_dev}.log",
		directories => [
		  { path      => "${website_dev_path}/www",
			options        => ['+Indexes', '+FollowSymLinks','-MultiViews'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		  { path      => "${website_dev_path}/api",
			options        => ['+ExecCGI', '+SymLinksIfOwnerMatch','-MultiViews'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		],
		require => [
			exec [ "git_clone_dev_website"],
			]
	}
	
	# Настройка доступа к базе данных:
	file {"${website_prod_path}/www/include/passwd.php":
		content => template("osm_website/db_config_prod.erb"),
		replace => yes,
		owner => www-data,
		group => www-data,
		mode => 0600,
		ensure => file,
		require => exec ["git_clone_prod_website"],
	} 
	file {"${website_dev_path}/www/include/passwd.php":
		content => template("osm_website/db_config_dev.erb"),
		replace => yes,
		owner => www-data,
		group => www-data,
		mode => 0600,
		ensure => file,
		require => exec ["git_clone_dev_website"],
	} 
	# доступ к stapio-базе:
	file {"${website_prod_path}/api/db_config.py":
		content => template("osm_website/api_db_prod_config.py.erb"),
		replace => yes,
		owner => www-data,
		group => www-data,
		mode => 0750,
		ensure => file,
		require => exec ["git_clone_prod_website"],
	} 
	file {"${website_dev_path}/api/db_config.py":
		content => template("osm_website/api_db_dev_config.py.erb"),
		replace => yes,
		owner => www-data,
		group => www-data,
		mode => 0750,
		ensure => file,
		require => exec ["git_clone_dev_website"],
	} 

	# доступ к базе поиска для cron-задания:
	file {"${website_prod_path}/cron/db_config.py":
		content => template("osm_website/cron_db_search_prod_config.py.erb"),
		replace => yes,
		owner => www-data,
		group => www-data,
		mode => 0750,
		ensure => file,
		require => exec ["git_clone_prod_website"],
	} 
	file {"${website_dev_path}/cron/db_config.py":
		content => template("osm_website/cron_db_search_dev_config.py.erb"),
		replace => yes,
		owner => www-data,
		group => www-data,
		mode => 0750,
		ensure => file,
		require => exec ["git_clone_dev_website"],
	} 

	# Инициализация базы:

	# База основного сайта:
	file {"${website_prod_path}/install_www/db_init.sh":
		content => "#!/bin/bash
# Доступ:
echo \"${db_prod_host}:5432:${db_prod_name}:${db_prod_user}:${db_prod_passwd}\" > /root/.pgpass
chmod 600 /root/.pgpass

psql -U ${db_prod_user} -h ${db_prod_host} ${db_prod_name} < db_pg.sql &> ${website_prod_path}/install_www/db_init.log
if [ 0 -eq $? ]
then
	touch ${website_prod_path}/install_www/db_init.stat
fi
",
		replace => yes,
		owner => root,
		group => root,
		mode => 0750,
		ensure => file,
		require => exec ["git_clone_prod_website"],
	} 
	exec { "init db ${db_prod_name}":
		path   => "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin",
		command => "${website_prod_path}/install_www/db_init.sh",
		cwd => "${website_prod_path}/install_www/",
		creates => "${website_prod_path}/install_www/db_init.stat",
		require => [
			file["${website_prod_path}/install_www/db_init.sh"],
			],
	}

	# База сайта в разработке:
	file {"${website_dev_path}/install_www/db_init.sh":
		content => "#!/bin/bash
echo \"${db_dev_host}:5432:${db_dev_name}:${db_dev_user}:${db_dev_passwd}\" > /root/.pgpass
chmod 600 /root/.pgpass

psql -U ${db_dev_user} -h ${db_dev_host} ${db_dev_name} < db_pg.sql &> ${website_dev_path}/install_www/db_init.log
if [ 0 -eq $? ]
then
	touch ${website_dev_path}/install_www/db_init.stat
else
	exit 1
fi
exit 0
",
		replace => yes,
		owner => root,
		group => root,
		mode => 0750,
		ensure => file,
		require => exec ["git_clone_dev_website"],
	} 
	exec { "init db ${db_dev_name}":
		path   => "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin",
		command => "${website_dev_path}/install_www/db_init.sh",
		cwd => "${website_dev_path}/install_www/",
		creates => "${website_dev_path}/install_www/db_init.stat",
		require => [
			file["${website_dev_path}/install_www/db_init.sh"],
			],
	}

	# Задание по обновлению базы данных поиска сайта:
	file { "/etc/cron.d/update_osm_website_search_db":
		ensure => file,
		content => "# Created by Puppet. Do not edit manual.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin:/usr/x86_64-pc-linux-gnu/gcc-bin/4.3.2
# Обновление базы данных поиска на сайте (${db_prod_search_host}:${db_prod_search_name}):
01 1 * * * root ${website_prod_path}/cron/osm2power_search.py >> ${db_prod_search_update_log_path}
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}

}
