class osm_stapio_postgres_db (
		$db_stapio_name="stapio",
		$db_stapio_user="stapio",
		$db_stapio_passwd=undef,
		$postgis_version="1.5"
	){
	$tmp_path="/home/postgres"

	#=====================   Настройка postgres-сервера: ====================

  	if !defined(package['postgresql-contrib']) {
		package { "postgresql-contrib":
			ensure => installed,
		}
	}


	# Если нет базовой конфигурации - создаём:
  	if !defined(Class['postgresql::server']) {
		class { 'postgresql::globals':
			encoding => 'UTF-8',
			locale   => 'en_US.UTF-8',
		}->
		class { 'postgresql::server': 
			listen_addresses           => '*',
			#ip_mask_allow_all_users    => $db_access_netmask,
		
		}
	}

	# Создаём таблицу:
	postgresql::server::db { $db_stapio_name:
		user     => $db_stapio_user,
		password => postgresql_password($db_stapio_user, $db_stapio_passwd),
		notify => exec [ "run db_init script"],
	}
	# ставим расширение hstore
	postgresql::server::extension{ "hstore to $db_stapio_name":
		extension_name => "hstore",
		database => $db_stapio_name,
		ensure => present,
	}
	if $postgis_version >= 2.0 {
		# ставим расширение postgis (актуально для версий postgis >=2.0)
		postgresql::server::extension{ "postgis to $db_stapio_name":
			extension_name => "postgis",
			database => $db_stapio_name,
			ensure => present,
		}
	}


	# Инициализация базы:
	exec {"${tmp_path}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${tmp_path};chown postgres ${tmp_path}",
		creates => "${tmp_path}",
	}
	# sql для создания базы:
	file {"${tmp_path}/stapio_db_init.sql":
		content => template("osm_stapio_and_osmcatalog/stapio_db_init.sql.erb"),
		replace => yes,
		owner => postgres,
		group => postgres,
		mode => 0600,
		ensure => file,
		require => [
			exec ["${tmp_path}"],
		],
	}
	if $postgis_version >= 2.0 {
		file {"${tmp_path}/stapio_db_init.sh":
			content => "#!/bin/bash
log=\"${tmp_path}/stapio_db_init.log\"
stat_file=\"${tmp_path}/stapio_db_init.stat\"

# Создаём таблицы:
su -c \"psql ${db_stapio_name} < ${tmp_path}/stapio_db_init.sql\" postgres &> \${log}
if [ 0 -eq \$? ]
then
	echo \"success db init!\" >> \${log}
	touch \${stat_file}
	exit 0
else
	echo \"error db init!\" >> \${log}
	exit 1
fi
# В новом (2.0) postgis переименовали функции (http://www.postgis.org/docs/PostGIS_FAQ.html#legacy_faq), поэтому может потребоваться запуск создания алиасов на старые (1.5) функции: ):
su -c \"psql ${db_stapio_name} < /usr/share/postgresql/9.1/contrib/postgis-2.1/legacy.sql\" postgres &> \${log}
if [ 0 -eq \$? ]
then
	echo \"success db init!\" >> \${log}
	touch \${stat_file}
	exit 0
else
	echo \"error db init!\" >> \${log}
	exit 1
fi
",
			replace => yes,
			owner => root,
			group => root,
			mode => 0755,
			ensure => file,
			require => [
				exec ["${tmp_path}"],
			],
		}
	}
	if $postgis_version < 2.0 {
		file {"${tmp_path}/stapio_db_init.sh":
			content => "#!/bin/bash
log=\"${tmp_path}/stapio_db_init.log\"
stat_file=\"${tmp_path}/stapio_db_init.stat\"
# добавляем postgis вручную (актуально) (1.5)
su -c \"createlang plpgsql ${db_stapio_name}\" postgres &> \${log}
if [ 0 -eq \$? ]
then
	echo \"error createlang plpgsql!\" >> \${log}
	exit 1
fi

postgis_sql=\"`find  /usr/share/postgresql/ -name postgis.sql`\"
spatial_ref_sys_sql=\"`find  /usr/share/postgresql/ -name spatial_ref_sys.sql`\"

echo \"start: psql -d ${db_stapio_name} -f \${postgis_sql} \" >> \${log}
su -c \"psql -d ${db_stapio_name} -f \${postgis_sql} \" postgres &>> \${log}
if [ 0 ! -eq \$? ]
then
	echo \"return code of add postgis.sql is \$?!\" >> \${log}
fi

echo \"start: psql -d ${db_stapio_name} -f \${spatial_ref_sys_sql} \" >> \${log}
su -c \"psql -d ${db_stapio_name} -f \${spatial_ref_sys_sql} \" postgres &>> \${log}
if [ 0 ! -eq \$? ]
then
	echo \"return code of add spatial_ref_sys.sql is \$?!\" >> \${log}
fi

# Создаём таблицы:
su -c \"psql ${db_stapio_name} < ${tmp_path}/stapio_db_init.sql\" postgres &>> \${log}
if [ 0 -eq \$? ]
then
	echo \"success db init!\" >> \${log}
	touch \${stat_file}
	exit 0
else
	echo \"error db init!\" >> \${log}
	exit 1
fi
",
			replace => yes,
			owner => root,
			group => root,
			mode => 0755,
			ensure => file,
			require => [
				exec ["${tmp_path}"],
			],
		}
	}

	
	if $postgis_version < 2.0 {
		# запуск скрипта инициализации базы:
		exec { "run db_init script":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "${tmp_path}/stapio_db_init.sh",
			cwd => "${tmp_path}",
			creates => "${tmp_path}/stapio_db_init.stat",
			refreshonly => true,
			require => [
				file ["${tmp_path}/stapio_db_init.sql"],
				file ["${tmp_path}/stapio_db_init.sh"],
				postgresql::server::db [ $db_stapio_name ],
				],
		}
	}
	
	if $postgis_version >= 2.0 {
		# запуск скрипта инициализации базы:
		exec { "run db_init script":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "${tmp_path}/stapio_db_init.sh",
			cwd => "${tmp_path}",
			creates => "${tmp_path}/stapio_db_init.stat",
			refreshonly => true,
			require => [
				file ["${tmp_path}/stapio_db_init.sql"],
				file ["${tmp_path}/stapio_db_init.sh"],
				postgresql::server::db [ $db_stapio_name ],
				postgresql::server::extension["postgis to $db_stapio_name"],
			],
		}
	}
	
}

class osm_stapio_and_osmcatalog (
	$install_path="/opt/osm/openstreetmap.ru",
	$urlpbf_src="http://export.osm.prim.drsk.ru/drsk_osm_full_dump_latest.pbf",
	$urlpbf_meta_src="http://export.osm.prim.drsk.ru/drsk_osm_full_dump_latest.pbf.meta",
	$out_poidatatree_json_file="/opt/osm/openstreetmap.ru/OpenStreetMap.ru_prodaction/www/data/poidatatree.json",
	$out_poimarker_json_file="/opt/osm/openstreetmap.ru/OpenStreetMap.ru_prodaction/www/data/poimarker.json",
	$out_file_listPerm_json="/opt/osm/openstreetmap.ru/OpenStreetMap.ru_prodaction/www/data/poidatalistperm.json",
	$path_markers="/opt/osm/openstreetmap.ru/OpenStreetMap.ru_prodaction/www/img/poi_marker/",
	$email_admin="semenov@rsprim.ru",
	$email_smtp_server="mail-rsprim-ru.rs.int",

	$db_prod_name="osm_www_prod",
	$db_prod_user="osm_www_prod",
	$db_prod_passwd=undef,
	$db_prod_host="db.rs.int",

	$db_stapio_host="db.rs.int",
	$db_stapio_name="stapio",
	$db_stapio_user="stapio",
	$db_stapio_passwd=undef,

	#$osmcatalog_git_src="https://github.com/ErshKUS/osmCatalog.git",
	#$stapio_git_src="https://github.com/ErshKUS/stapio.git",
	$osmcatalog_git_src="http://git.rs.int/osm/osmcatalog_drsk.git",
	$stapio_git_src="http://git.rs.int/osm/stapio_drsk.git",
	){

	# Необходимые пакеты:
	if !defined(package['php5']) {
		package { "php5":
			ensure => installed,
		}
	}
	if !defined(package['python-psycopg2']) {
		package { "python-psycopg2":
			ensure => installed,
		}
	}
	if !defined(package['php5-curl']) {
		package { "php5-curl":
			ensure => installed,
		}
	}

	if !defined(Class['git']) {
		include git
	}

	# Создаём пути:
	if !defined(exec ["mkdir ${install_path}"]) {
		exec {"mkdir ${install_path}":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${install_path}",
			creates => "${install_path}",
		}
	}
	if !defined(package ['osmosis']) {
		package {"osmosis":
			ensure => installed,
		}
	}

	# скачиваем stapio:
	exec { "git_clone_stapio":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone ${stapio_git_src} stapio",
		cwd => "${install_path}",
		creates => "${install_path}/stapio",
		require => [package['git'], exec["mkdir ${install_path}"] ],
	}
	# скачиваем osmcatalog:
	exec { "git_clone_osmcatalog":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone ${osmcatalog_git_src} osmCatalog",
		cwd => "${install_path}",
		creates => "${install_path}/osmCatalog",
		require => [package['git'], exec["mkdir ${install_path}"] ],
	}
	# Создаём директорию для текущих файлов:
	file {"${install_path}/stapio/actual":
		ensure => directory,
		require => [
			exec ["git_clone_stapio"],
		],
	}

	# Создаём конфиг для stapio:
	file {"${install_path}/stapio/stapio_config.py":
		content => template("osm_stapio_and_osmcatalog/stapio_config.py.erb"),
		replace => yes,
		owner => root,
		group => root,
		mode => 0600,
		ensure => file,
		require => [
			exec ["git_clone_stapio"],
		],
	}

	# Создаём конфиг для osmosis с данными доступа к базе:
	file {"${install_path}/stapio/.auth_osmosis":
		content => "host=${db_stapio_host}
database=${db_stapio_name}
user=${db_stapio_user}
password=${db_stapio_passwd}
",
		replace => yes,
		owner => root,
		group => root,
		mode => 0600,
		ensure => file,
		require => [
			exec ["git_clone_stapio"],
		],
	}

	# Дополнительная инициализация базы данных:
	file {"${install_path}/stapio/db_init.sh":
		content => "#!/bin/bash
echo \"${db_stapio_host}:5432:${db_stapio_name}:${db_stapio_user}:${db_stapio_passwd}\" > /root/.pgpass
chmod 600 /root/.pgpass

# Ищем файлы схем:
schema=`find /usr/share/ -name pgsnapshot_schema_0.6.sql`
schema_line=`find /usr/share/ -name pgsnapshot_schema_0.6_linestring.sql`

if [ -f \"\${schema}\" ]
then
	psql -U ${db_stapio_user} -h ${db_stapio_host} ${db_stapio_name} < \${schema} &> ${install_path}/stapio/log/db_init.log
else
	echo 'can not find pgsnapshot_schema_0.6.sql' >> ${install_path}/stapio/log/db_init.log
	exit 1
fi
if [ -f \"\${schema_line}\" ]
then
	psql -U ${db_stapio_user} -h ${db_stapio_host} ${db_stapio_name} < \${schema_line} &> ${install_path}/stapio/log/db_init.log
else
	echo 'can not find pgsnapshot_schema_0.6_linestring.sql' >> ${install_path}/stapio/log/db_init.log
	exit 1
fi

# Запуск создания оставшихся таблиц с помощью stapio:
cd ${install_path}/stapio/
${install_path}/stapio/run.py install >> ${install_path}/stapio/log/db_init.log
if [ 0 != \$? ]
then
	echo 'error ${install_path}/stapio/run.py install' >> ${install_path}/stapio/log/db_init.log
	exit 1
fi

touch ${install_path}/stapio/db_init.stat
exit 0
",
		replace => yes,
		owner => root,
		group => root,
		mode => 0750,
		ensure => file,
		require => exec ["git_clone_stapio"],
	} 
	exec { "init db":
		path   => "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin",
		command => "${install_path}/stapio/db_init.sh",
		cwd => "${install_path}/stapio/",
		creates => "${install_path}/stapio/db_init.stat",
		require => [
			file ["${install_path}/stapio/stapio_config.py"],
			file["${install_path}/stapio/db_init.sh"],
			package ["osmosis"],
			],
	}


	#=============== CRON ====================
	# Добавляем в cron:
	file { "/etc/cron.d/stapio":
		ensure => file,
		content => "# Do not edit. Added automaticaly by Puppet.
# Запускаем миграцию POI из OSM в stapio:
01 1 * * * root ${install_path}/stapio/run.py --onlyPOI --load insert

# Формируем дерево POI на сайте из osmCatalog:
01 0 * * * root python ${install_path}/stapio/stapio_poi.py createTree
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}
	
	
	
}
