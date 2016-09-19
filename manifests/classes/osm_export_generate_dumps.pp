class osm_export_generate_dumps (
	$osm_api_server_db_host="db.rs.int",
	$osm_api_server_db_name="drsk_dev_osm",
	$osm_api_server_db_user="osm_full_read_only",
	$osm_api_server_db_passwd,

	$vhost_name="export.osm.prim.drsk.ru",
	$serveraliases = ["exports.$fqdn", "export.map.prim.drsk.ru",],

	$scripts_path="/opt/osm/scripts",
	$export_path="/opt/osm/exports",
	$var_dir="/opt/osm/exports",
	$log_dir="/var/log/osm",
	$osmconvert_install_path="/opt/osm/osmconvert",
	$osmconvert_bin_path="/opt/osm/osmconvert/osmconvert",
	){

	$var_dir_diff="${var_dir}/diff/"

  	if !defined(Class['osmconvert']) {
		class {"osmconvert":
			install_path => "${osmconvert_install_path}"
		}
	}
  	if !defined(package['osmosis']) {
		package {"osmosis":
			ensure => installed
		}
	}
  	if !defined(package['python-lxml']) {
		package {"python-lxml":
			ensure => installed
		}
	}
  	if !defined(package['sendemail']) {
		package {"sendemail":
			ensure => installed
		}
	}
  	if !defined(package['curl']) {
		package {"curl":
			ensure => installed
		}
	}

	# Директории для скрипта generate_drsk_osm_diff.sh:
	exec { "mkdir ${var_dir_diff}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${var_dir_diff}",
		cwd => "/",
		creates => "${var_dir_diff}",
	}
	exec { "mkdir ${log_dir}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${log_dir}",
		cwd => "/",
		creates => "${log_dir}",
	}
	exec { "mkdir ${scripts_path}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${scripts_path}",
		cwd => "/",
		creates => "${scripts_path}",
	}

	#======================= generate_osm_api_diff.sh:  ======================
	file { "${scripts_path}/generate_osm_api_diff.sh":
		ensure => file,
		content => template("osm_export_generate_dumps/generate_osm_api_diff.sh.erb"),
		replace => yes,
		mode => 0750,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "mkdir ${scripts_path}" ],
	}

	#======================= generate_osm_api_full_dump.sh:  ======================
	file { "${scripts_path}/generate_osm_api_full_dump.sh":
		ensure => file,
		content => template("osm_export_generate_dumps/generate_osm_api_full_dump.sh.erb"),
		replace => yes,
		mode => 0750,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "mkdir ${scripts_path}" ],
	}

	#=============== CRON ====================
	# Добавляем в cron:
	file { "/etc/cron.d/osm_export_generate_dumps":
		ensure => file,
		content => "# Do not edit manualy. Created by Puppet.
# Каждый час - разница:
02 * * * * root [ -z \"`ps aux|grep generate_drsk_osm_diff|grep -v grep`\" ] && ${scripts_path}/generate_osm_api_diff.sh
32 * * * * root [ -z \"`ps aux|grep generate_drsk_osm_diff|grep -v grep`\" ] && ${scripts_path}/generate_osm_api_diff.sh

# раз в день - полный дамп:
15 23 * * * root ${scripts_path}/generate_osm_api_full_dump.sh

# Чистка устаревших:
30 0 * * * root find ${export_path} -type f -a -mtime 7 -delete
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
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

	#================= Виртуальный хост экспорта: ========================

	apache::vhost { $vhost_name:
		port => '80',
		serveraliases => $serveraliases,
		docroot => "${export_path}/",
		access_log_file => "access_${vhost_name}.log",
		error_log_file => "error_${vhost_name}.log",
		directories => [
		  { path      => "/",
			options        => ['FollowSymLinks'],
			allow_override => 'All',
			order          => 'deny,allow',
			allow           => 'from all',
		  },
		],
	}
}
