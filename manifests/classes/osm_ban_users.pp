class osm_ban_users (
	$osm_api_server_db_host="db.rs.int",
	$osm_api_server_db_name="drsk_dev_osm",
	$osm_api_server_db_user="osm_full_write_access",
	$osm_api_server_db_passwd,

	$scripts_path="/opt/osm/scripts",
	$log_dir="/var/log/osm",
	){

  	if !defined(package['postgresql-client']) {
		package {"postgresql-client":
			ensure => installed
		}
	}
	exec { "mkdir ${log_dir} for osm_ban_users":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${log_dir}",
		cwd => "/",
		creates => "${log_dir}",
	}
	exec { "mkdir ${scripts_path} for osm_ban_users":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${scripts_path}",
		cwd => "/",
		creates => "${scripts_path}",
	}

	#======================= ban_user.sh:  ======================
	file { "${scripts_path}/ban_user.sh":
		ensure => file,
		content => template("osm_ban_users/ban_user.sh.erb"),
		replace => yes,
		mode => 0750,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "mkdir ${scripts_path}" ],
	}
}
