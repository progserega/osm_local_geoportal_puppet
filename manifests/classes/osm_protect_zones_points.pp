class osm_protect_zones_points (
	$db_host="localhost", 
	$db_name="osm_www", 
	$db_user="osm_www", 
	$db_passwd, 
	$personal_map_id, 
	$out_file,
	$install_path="/opt/osm"
	) {
  	if !defined(package['sendemail']) {
		package {"sendemail":
			ensure => installed
		}
	}
  	if !defined(Class['git']) {
		include git
	}
	if !defined(file ["${install_path}"]) {
		file {"${install_path}":
			ensure => directory,
		}
	}
	if !defined(file ["${install_path}/local_utils"]) {
		file {"${install_path}/local_utils":
			ensure => directory,
			require => file["${install_path}"],
		}
	}
	
	# Берём утилиту из git:
	exec { "git_personal_map2osm_layer":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone http://git.rs.int/osm/personal_map2osm_layer.git personal_map2osm_layer",
		cwd => "${install_path}/local_utils",
		creates => "${install_path}/local_utils/personal_map2osm_layer",
		require => package['git']
	}
	#Создаём конфиг для утилиты:
	file { "${install_path}/local_utils/personal_map2osm_layer/db_config.py":
		ensure => file,
		content => template("osm_protect_zones_points/db_config.py.erb"),
		replace => yes,
		mode => 0755,
		owner => root,
		group => root,
		backup => true,
	}

	# Задание по мограции данных:
	file { "/etc/cron.d/personal_map2osm_layer":
		ensure => file,
		content => "# Created by Puppet. Do not edit manual.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin:/usr/x86_64-pc-linux-gnu/gcc-bin/4.3.2

# Миграция данных из персональной карты в слой на карте:
*/20 * * * * root ${install_path}/local_utils/personal_map2osm_layer/personal_map2osm_layer.py $out_file  > /dev/null 2>&1
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}

}
