class osm_local_web_tools (
	$install_path="/opt/osm/local_web_services/",
	$vhost_name="tools.map.prim.drsk.ru",
	$list_names_of_lines_path="/opt/osm/local_utils/import_from_mail/list_names_of_lines.txt",
	$lines_with_zero_altitude_src="http://git.rs.int/osm/lines_with_zero_altitude.git",
	$map_power_station_list_src="http://git.rs.int/osm/map_power_station_list.git",
	$osm_deleted_chengesets_src="http://git.rs.int/osm/osm_deleted_chengesets.git",
	$osm_deleted_chengesets_base_url="http://osm.prim.drsk.ru/changeset",
	$power_lines_profile_src="http://git.rs.int/osm/power_lines_profile.git",
	$tp_station_list_src="http://git.rs.int/osm/tp_station_list.git",
	$vector_src="http://git.rs.int/semenov_sv/vectors_web_summ.git",
	$osm_api_server_db_host="db.rs.int",
	$osm_api_server_db_name="drsk_dev_osm",
	$osm_api_server_db_user="osm_read_only",
	$osm_api_server_db_passwd=undef,

	){
	$fires_url="http://${vhost_name}/fires"

  	if !defined(Class['git']) {
		include git
	}
  	if !defined(package['python-lxml']) {
		package {"python-lxml":
			ensure => installed
		}
	}
  	if !defined(package['gnuplot']) {
		package {"gnuplot":
			ensure => installed
		}
	}

	exec { "mkdir ${install_path}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${install_path}",
		cwd => "/",
		creates => "${install_path}",
	}

	#======================= vector:  ======================
	$vector_url="http://${vhost_name}/vector/"

	$vector_path="${install_path}/vector/"

	exec { "git_clone_vector":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone ${vector_src} ${vector_path}",
		cwd => "${install_path}",
		creates => "${vector_path}",
		require => [package['git'], exec["mkdir ${install_path}"] ],
	}
	file {"${vector_path}/graphs":
		ensure => directory,
		owner => "www-data",
		group => "www-data",
		require => exec [ "git_clone_vector"]
	}
	# Добавляем в cron:
	file { "/etc/cron.d/vector":
		ensure => file,
		content => "# # Чистка устаревших графиков:
59 23 * * * www-data find ${vector_path}/graphs/ -type f -a -mtime 1 -delete
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}

	#======================= tp_station_list:  ======================
	$tp_station_list_url="http://${vhost_name}/tp_station_list/"

	$tp_station_list_path="${install_path}/tp_station_list/"

	exec { "git_clone_tp_station_list":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone ${tp_station_list_src} ${tp_station_list_path}",
		cwd => "${install_path}",
		creates => "${tp_station_list_path}",
		require => [package['git'], exec["mkdir ${install_path}"] ],
	}

	file { "${tp_station_list_path}/db_config.py":
		ensure => file,
		content => template("osm_local_web_tools/tp_station_list_db_config.py.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => exec ["git_clone_tp_station_list"],
	}

	#======================= power_lines_profile:  ======================
	$power_lines_profile_url="http://${vhost_name}/power_lines_profile/"

	$power_lines_profile_path="${install_path}/power_lines_profile/"

	exec { "git_clone_power_lines_profile":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone ${power_lines_profile_src} ${power_lines_profile_path}",
		cwd => "${install_path}",
		creates => "${power_lines_profile_path}",
		require => [package['git'], exec["mkdir ${install_path}"] ],
	}
	file {"${power_lines_profile_path}/graphs":
		ensure => directory,
		owner => "www-data",
		group => "www-data",
		require => exec [ "git_clone_power_lines_profile"]
	}

	file { "${power_lines_profile_path}/db_config.py":
		ensure => file,
		content => template("osm_local_web_tools/power_lines_profile_db_config.py.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => exec ["git_clone_power_lines_profile"],
	}
	
	# Добавляем в cron:
	file { "/etc/cron.d/power_lines_profile":
		ensure => file,
		content => "# # Чистка устаревших графиков:
59 23 * * * www-data find ${power_lines_profile_path}/graphs/ -type f -a -mtime 1 -delete
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}

	#======================= osm_deleted_chengesets:  ======================
	$osm_deleted_chengesets_url="http://${vhost_name}/osm_deleted_chengesets/"

	$osm_deleted_chengesets_path="${install_path}/osm_deleted_chengesets/"

	exec { "git_clone_osm_deleted_chengesets":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone ${osm_deleted_chengesets_src} ${osm_deleted_chengesets_path}",
		cwd => "${install_path}",
		creates => "${osm_deleted_chengesets_path}",
		require => [package['git'], exec["mkdir ${install_path}"] ],
	}

	file { "${osm_deleted_chengesets_path}/db_config.py":
		ensure => file,
		content => template("osm_local_web_tools/osm_deleted_chengesets_db_config.py.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => exec ["git_clone_osm_deleted_chengesets"],
	}

	#======================= map_power_station_list:  ======================
	$map_power_station_list_url="http://${vhost_name}/map_power_station_list/"

	$map_power_station_list_path="${install_path}/map_power_station_list/"

	exec { "git_clone_map_power_station_list":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone ${map_power_station_list_src} ${map_power_station_list_path}",
		cwd => "${install_path}",
		creates => "${map_power_station_list_path}",
		require => [package['git'], exec["mkdir ${install_path}"] ],
	}

	file { "${map_power_station_list_path}/db_config.py":
		ensure => file,
		content => template("osm_local_web_tools/map_power_station_list_db_config.py.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => exec ["git_clone_map_power_station_list"],
	}

	#======================= lines_with_zero_altitude:  ======================
	$lines_with_zero_altitude_url="http://${vhost_name}/lines_with_zero_altitude/index.cgi"

	$lines_with_zero_altitude_path="${install_path}/lines_with_zero_altitude/"

	exec { "git_clone_lines_with_zero_altitude":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone ${lines_with_zero_altitude_src} ${lines_with_zero_altitude_path}",
		cwd => "${install_path}",
		creates => "${lines_with_zero_altitude_path}",
		require => [package['git'], exec["mkdir ${install_path}"] ],
	}

	file { "${lines_with_zero_altitude_path}/db_config.py":
		ensure => file,
		content => template("osm_local_web_tools/lines_with_zero_altitude_db_config.py.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => exec ["git_clone_lines_with_zero_altitude"],
	}
	
	# Добавляем в cron:
	file { "/etc/cron.d/lines_with_zero_altitude":
		ensure => file,
		content => "# Обновление списка линий с опорами, высота оснований которых равна 0:
10 2 * * * root ${lines_with_zero_altitude_path}/index.cgi > ${lines_with_zero_altitude_path}/index.html
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}

	#======================= list_name_vl:  ======================
	$list_name_vl_url="http://${vhost_name}/list_name_vl/"

	$list_name_vl_path="${install_path}/list_name_vl/"

	file {"${list_name_vl_path}":
		ensure => directory,
		require => exec ["mkdir ${install_path}"],
	}
	file { "${list_name_vl_path}/index.cgi":
		ensure => file,
		content => template("osm_local_web_tools/list_name_vl.html.cgi.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => file ["${list_name_vl_path}"],
	}


	#======================= add_new_vl_name:  ======================
	$add_new_vl_name_url="http://${vhost_name}/add_new_vl_name/"

	$add_new_vl_name_path="${install_path}/add_new_vl_name/"

	file {"${add_new_vl_name_path}":
		ensure => directory,
		require => exec ["mkdir ${install_path}"],
	}
	file { "${add_new_vl_name_path}/add_new_vl.cgi":
		ensure => file,
		content => template("osm_local_web_tools/add_new_vl_name.cgi.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => file ["${add_new_vl_name_path}"],
	}
	file { "${add_new_vl_name_path}/index.html":
		ensure => file,
		content => template("osm_local_web_tools/add_new_vl_name_index.html.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => file ["${add_new_vl_name_path}"],
	}

	#======================= main index:  ======================
	$main_index_url="http://${vhost_name}/index.html"

	file { "${install_path}/index.html":
		ensure => file,
		content => template("osm_local_web_tools/main_index.html.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
	}

	# ===========================  Настройка apache:  ======================
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

	#================= Виртуальный хост утилит: ========================

	apache::vhost { $vhost_name:
		port => '80',
		docroot => "${install_path}",
		access_log_file => "access_${vhost_name}.log",
		error_log_file => "error_${vhost_name}.log",
		directories => [
		  { path      => "${lines_with_zero_altitude_path}/",
		  	addhandlers => [
				{ 
					handler => 'cgi-script', 
					extensions => ['.cgi']
				},
				{ 
					handler => 'cgi-script', 
					extensions => ['.py']
				},
				],
			options        => ['+ExecCGI', '-MultiViews', '+SymLinksIfOwnerMatch'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		  { path      => "${install_path}/fires/",
		  	addhandlers => [
				{ 
					handler => 'cgi-script', 
					extensions => ['.cgi']
				},
				{ 
					handler => 'cgi-script', 
					extensions => ['.py']
				},
				],
			options        => ['+ExecCGI', '-MultiViews', '+SymLinksIfOwnerMatch'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		  { path      => "${add_new_vl_name_path}/",
		  	addhandlers => [
				{ 
					handler => 'cgi-script', 
					extensions => ['.cgi']
				},
				{ 
					handler => 'cgi-script', 
					extensions => ['.py']
				},
				],
			options        => ['+ExecCGI', '-MultiViews', '+SymLinksIfOwnerMatch'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		  { path      => "${list_name_vl_path}/",
		  	addhandlers => [
				{ 
					handler => 'cgi-script', 
					extensions => ['.cgi']
				},
				{ 
					handler => 'cgi-script', 
					extensions => ['.py']
				},
				],
			options        => ['+ExecCGI', '-MultiViews', '+SymLinksIfOwnerMatch'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		  { path      => "${power_lines_profile_path}/",
		  	addhandlers => [
				{ 
					handler => 'cgi-script', 
					extensions => ['.cgi']
				},
				{ 
					handler => 'cgi-script', 
					extensions => ['.py']
				},
				],
			options        => ['+ExecCGI', '-MultiViews', '+SymLinksIfOwnerMatch'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		  { path      => "${tp_station_list_path}/",
		  	addhandlers => [
				{ 
					handler => 'cgi-script', 
					extensions => ['.cgi']
				},
				{ 
					handler => 'cgi-script', 
					extensions => ['.py']
				},
				],
			options        => ['+ExecCGI', '-MultiViews', '+SymLinksIfOwnerMatch'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		  { path      => "${vector_path}/",
		  	addhandlers => [
				{ 
					handler => 'cgi-script', 
					extensions => ['.cgi']
				},
				{ 
					handler => 'cgi-script', 
					extensions => ['.py']
				},
				],
			options        => ['+ExecCGI', '-MultiViews', '+SymLinksIfOwnerMatch'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		  { path      => "${map_power_station_list_path}/",
		  	addhandlers => [
				{ 
					handler => 'cgi-script', 
					extensions => ['.cgi']
				},
				{ 
					handler => 'cgi-script', 
					extensions => ['.py']
				},
				],
			options        => ['+ExecCGI', '-MultiViews', '+SymLinksIfOwnerMatch'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		  { path      => "${osm_deleted_chengesets_path}/",
		  	addhandlers => [
				{ 
					handler => 'cgi-script', 
					extensions => ['.cgi']
				},
				{ 
					handler => 'cgi-script', 
					extensions => ['.py']
				},
				],
			options        => ['+ExecCGI', '-MultiViews', '+SymLinksIfOwnerMatch'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },

		],
	}
}
