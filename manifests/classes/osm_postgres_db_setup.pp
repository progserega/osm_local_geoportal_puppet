class osm_postgres_db_setup (
	$db_access_netmask="0.0.0.0/0",

	$email_from="ДРСК OSM <osm@rsprim.ru>",
	$email_return_path="osm@rsprim.ru",
	$email_admin="semenov@rsprim.ru",

	# development база:
	$db_dev_name="drsk_dev_osm",
	$db_dev_user_name="openstreetmap",
	$db_dev_passwd,

	$db_dev_ro_user="osm_read_only",
	$db_dev_ro_user_passwd,

	$db_dev_full_ro_user="osm_full_read_only",
	$db_dev_full_ro_user_passwd,

	$db_dev_ban_access_user="osm_ban_access_only",
	$db_dev_ban_access_user_passwd,

	# prodaction база:
	$db_prodaction_name="drsk_prodaction_osm",
	$db_prodaction_user_name="openstreetmap",
	$db_prodaction_passwd,

	# test база:
	$db_test_name="drsk_test_osm",
	$db_test_user_name="openstreetmap",
	$db_test_passwd,

	# базы для рендеринга:
	$local_osm_gis="local_osm_gis",
	$local_osm_gis_tmp="local_osm_gis_tmp",
	$drsk_gis="drsk_gis",


	$install_path="/opt/osm",
	$openstreetmap_website_install_path="/opt/osm/openstreetmap-website",
	$osm_rails_server_source = "https://github.com/openstreetmap/openstreetmap-website.git",
	$nodejs_source = "http://nodejs.org/dist/node-latest.tar.gz",
){

	$build_path="${install_path}/build_package"
	$nodejs_build_path="${build_path}/nodejs"
	$nodejs_build_log="${nodejs_build_path}/nodejs_build.log"

	$rails_server_log_path="/var/log/osm/rail_server.log"


	$pkg_osm_rail_server_deps_postgres=[ "postgis","postgresql","postgresql-contrib","postgresql-server-dev-all"]
	
  	if !defined(package['build-essential']) {
		package { "build-essential":
			ensure => installed,
		}
	}
  	if !defined(package['libsasl2-dev']) {
		package { "libsasl2-dev":
			ensure => installed,
		}
	}
  	if !defined(package['libpq-dev']) {
		package { "libpq-dev":
			ensure => installed,
		}
	}

	package { $pkg_osm_rail_server_deps_postgres:
		ensure => installed,
	}

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

	# Создаём базы:
	postgresql::server::db { $db_dev_name:
		user     => $db_dev_user_name,
		password => postgresql_password($db_dev_user_name, $db_dev_passwd),
	}
	postgresql::server::db { $db_prodaction_name:
		user     => $db_prodaction_user_name,
		password => postgresql_password($db_prodaction_user_name, $db_prodaction_passwd),
	}
	postgresql::server::db { $db_test_name:
		user     => $db_test_user_name,
		password => postgresql_password($db_test_user_name, $db_test_passwd),
	}

	# Создаём базы для сервера рендеринга:
	postgresql::server::db { $local_osm_gis:
		user     => $db_test_user_name,
		password => postgresql_password($db_dev_user_name, $db_dev_passwd),
	}
	postgresql::server::db { $local_osm_gis_tmp:
		user     => $db_dev_user_name,
		password => postgresql_password($db_dev_user_name, $db_dev_passwd),
	}
	postgresql::server::db { $drsk_gis:
		user     => $db_dev_user_name,
		password => postgresql_password($db_dev_user_name, $db_dev_passwd),
	}

	# Даём права на пересоздание тестовой таблицы: 
	postgresql::server::grant { "create db for test-user":
		privilege => ALL,
		db => $db_test_name,
		role => $db_test_user_name,
	}
	postgresql::server::role{$db_test_user_name:
		createdb => true,
		superuser => true,
	}

	# ставим расширение btree_gist
	postgresql::server::extension{ "btree_gist to $db_prodaction_name":
		extension_name => "btree_gist",
		database => $db_prodaction_name,
		ensure => present,
	}
	postgresql::server::extension{ "btree_gist to $db_dev_name":
		extension_name => "btree_gist",
		database => $db_dev_name,
		ensure => present,
	}
	postgresql::server::extension{ "btree_gist to $db_test_name":
		extension_name => "btree_gist",
		database => $db_test_name,
		ensure => present,
	}
	#postgresql::server::extension{ "btree_gist":
	#	database => $db_test_name,
	#	ensure => present,
	#}

	# добавляем функции к основной базе:


	# Создаём пути, куда ставим:
	exec {"mkdir2 ${install_path}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${install_path}",
		creates => "${install_path}",
	}
	exec {"mkdir2 ${build_path}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${build_path}",
		creates => "${build_path}",
	}
	# Убеждаемся, что git установлен:
  	if !defined(Class['git']) {
		include git
	}
	# Скачиваем исходник OSM Rail-server:
	exec {"git2 clone osm_rails_server":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone $osm_rails_server_source",
		cwd => "$install_path",
		timeout => 1200,
		creates => "${install_path}/openstreetmap-website",
		require  => [ Package['git'], exec ["mkdir2 ${install_path}"] ],
	}

	# собираем библиотеку:
	exec { 'make libpgosm.so':
		path   => "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin",
		command     => "make libpgosm.so",
		cwd => "${openstreetmap_website_install_path}/db/functions",
		creates => "${openstreetmap_website_install_path}/db/functions/libpgosm.so",
		require     => exec ["git2 clone osm_rails_server"],
	}
	file { "${build_path}/CREATE_FUNCTION.sh":
		ensure => file,
		content => "#!/bin/bash
psql -d ${db_prodaction_name} -c \"CREATE FUNCTION maptile_for_point(int8, int8, int4) RETURNS int4 AS '${openstreetmap_website_install_path}/db/functions/libpgosm', 'maptile_for_point' LANGUAGE C STRICT\"  &>> /tmp/CREATE_FUNCTION.sh.log
psql -d ${db_prodaction_name} -c \"CREATE FUNCTION tile_for_point(int4, int4) RETURNS int8 AS '${openstreetmap_website_install_path}/db/functions/libpgosm', 'tile_for_point' LANGUAGE C STRICT\" &>> /tmp/CREATE_FUNCTION.sh.log
psql -d ${db_prodaction_name} -c \"CREATE FUNCTION xid_to_int4(xid) RETURNS int4 AS '${openstreetmap_website_install_path}/db/functions/libpgosm', 'xid_to_int4' LANGUAGE C STRICT\" &>> /tmp/CREATE_FUNCTION.sh.log

psql -d ${db_dev_name} -c \"CREATE FUNCTION maptile_for_point(int8, int8, int4) RETURNS int4 AS '${openstreetmap_website_install_path}/db/functions/libpgosm', 'maptile_for_point' LANGUAGE C STRICT\" &>> /tmp/CREATE_FUNCTION.sh.log
psql -d ${db_dev_name} -c \"CREATE FUNCTION tile_for_point(int4, int4) RETURNS int8 AS '${openstreetmap_website_install_path}/db/functions/libpgosm', 'tile_for_point' LANGUAGE C STRICT\" &>> /tmp/CREATE_FUNCTION.sh.log
psql -d ${db_dev_name} -c \"CREATE FUNCTION xid_to_int4(xid) RETURNS int4 AS '${openstreetmap_website_install_path}/db/functions/libpgosm', 'xid_to_int4' LANGUAGE C STRICT\" &>> /tmp/CREATE_FUNCTION.sh.log
",
		mode => 0755,
		owner => root,
		require => exec ["mkdir2 ${build_path}"],
		notify      => Exec['CREATE FUNCTION'],
	}

	exec { 'CREATE FUNCTION':
		refreshonly => true,
		path   => "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin",
		command     => "${build_path}/CREATE_FUNCTION.sh",
		cwd => "${openstreetmap_website_install_path}/db/functions",
		user => postgres,
		require => [
			postgresql::server::db [$db_dev_name],
			postgresql::server::db [$db_prodaction_name],
			postgresql::server::db [$db_test_name],
			exec [ 'make libpgosm.so'],
			exec [ "git2 clone osm_rails_server" ],
			],
	}
	
	#########################################################################################################
	#
	# ===============================     дополнительные пользователи: ======================================
	#
	#########################################################################################################

	postgresql::server::role { "$db_dev_ro_user":
		password_hash => postgresql_password("$db_dev_ro_user", "$db_dev_ro_user_passwd"),
	}
	$db_ro_list=[
		"changesets",
		"node_tags",
		"nodes",
		"relation_members",
		"relation_tags",
		"relations",
		"way_nodes",
		"way_tags",
		"ways",
	]

	define ro_access_to_table (
		$username,
		$access_rule="SELECT",
		$table_name=$name,
		$db_name
		) {

		#notify { "db: $db_name, table: $table_name, user: $username, access: $access_rule":}

		postgresql::server::table_grant { "SELECT to $username on db $db_name to table $table_name ":
			privilege => "${access_rule}",
			table     => "${table_name}",
			db        => "${db_name}",
			role      => "${username}",
		}

		postgresql::server::database_grant { "CONNECT to $username on db $db_name to $table_name":
			privilege => "CONNECT",
			db        => "${db_name}",
			role      => "${username}",
		}

	}
	# Вызываем ro_access_to_table для каждого элемента списка db_ro_list:
	ro_access_to_table{$db_ro_list:
		username  => "${db_dev_ro_user}",
		access_rule => "SELECT",
		db_name   => "${db_dev_name}",
	} 
	#===========================  доступ для бана пользователей: ===================
	postgresql::server::role { "$db_dev_ban_access_user":
		password_hash => postgresql_password("$db_dev_ban_access_user", "$db_dev_ban_access_user_passwd"),
	}

	postgresql::server::table_grant { "SELECT to $db_dev_ban_access_user on db $db_dev_name to table users":
		privilege => "SELECT",
		table     => "users",
		db        => "${db_dev_name}",
		role      => "${db_dev_ban_access_user}",
	}

	postgresql::server::table_grant { "SELECT,INSERT to $db_dev_ban_access_user on db $db_dev_name to table user_blocks":
		privilege => "SELECT,INSERT",
		table     => "user_blocks",
		db        => "${db_dev_name}",
		role      => "${db_dev_ban_access_user}",
	}
	
	#===========================  Полный доступ на чтение ко всем базам для db_dev_full_ro_user: ===================
	postgresql::server::role { "$db_dev_full_ro_user":
		password_hash => postgresql_password("$db_dev_full_ro_user", "$db_dev_full_ro_user_passwd"),
	}
	$db_full_ro_list=[
	"acls",
	"changeset_comments",
	"changeset_tags",
	"changesets",
	"changesets_subscribers",
	"client_applications",
	"current_node_tags",
	"current_nodes",
	"current_relation_members",
	"current_relation_tags",
	"current_relations",
	"current_way_nodes",
	"current_way_tags",
	"current_ways",
	"diary_comments",
	"diary_entries",
	"friends",
	"gps_points",
	"gpx_file_tags",
	"gpx_files",
	"languages",
	"messages",
	"node_tags",
	"nodes",
	"note_comments",
	"notes",
	"oauth_nonces",
	"oauth_tokens",
	"redactions",
	"relation_members",
	"relation_tags",
	"relations",
	"schema_migrations",
	"user_blocks",
	"user_preferences",
	"user_roles",
	"user_tokens",
	"users",
	"way_nodes",
	"way_tags",
	"ways",
	]

	define ro_access_to_table2 (
		$username,
		$access_rule="SELECT",
		$table_name=$name,
		$db_name
		) {

		#notify { "db: $db_name, table: $table_name, user: $username, access: $access_rule":}

		postgresql::server::table_grant { "SELECT to $username on db $db_name to table $table_name ":
			privilege => "${access_rule}",
			table     => "${table_name}",
			db        => "${db_name}",
			role      => "${username}",
		}

		postgresql::server::database_grant { "CONNECT to $username on db $db_name to $table_name":
			privilege => "CONNECT",
			db        => "${db_name}",
			role      => "${username}",
		}
	}
	
	# Вызываем ro_access_to_table2 для каждого элемента списка db_full_ro_list:
	ro_access_to_table2{$db_full_ro_list:
		username  => "${db_dev_full_ro_user}",
		access_rule => "SELECT",
		db_name   => "${db_dev_name}",
	} 

}
