class osm_load_station_import_data (
	$osmbot_user, 
	$osmbot_passwd, 
	$load_xml_url="http://1c-base.drsk.ru/DataForMapXML.xml",
	$email_error_to="semenov@rsprim.ru",
	$email_server="mail-rsprim-ru.rs.int",
	){
	$var_dir="/var/osm/load_station_import/"

	$import_data_file="$var_dir/import_data_from_1C.xml"
	#$load_xml_url="http://export.osm.prim.drsk.ru/tmp/1C_export_station_power_load.xml"
	
	
	$osmbot_config="/opt/osm/local_utils/import_station_loading/osmbot.conf"
	$osmbot_rules="$var_dir/osmbot_rule.xml"


  	if !defined(Class['git']) {
		include git
	}
  	if !defined(package['python-lxml']) {
		package {"python-lxml":
			ensure => installed
		}
	}
#	file {"/var/osm":
#		ensure => directory,
#	}
#	file {"/opt/osm":
#		ensure => directory,
#	}
#	file {"/opt/osm/local_utils":
#		ensure => directory,
#		require => file["/opt/osm"],
#	}
	file {"/var/osm/load_station_import":
		ensure => directory,
		require => file ["/var/osm"],
	}

	exec { "git_import_station_loading":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone http://git.rs.int/osm/import_station_loading.git",
		cwd => "/opt/osm/local_utils",
		creates => "/opt/osm/local_utils/import_station_loading",
		require => [package['git'], file["/opt/osm/local_utils"] ],
	}
	#======================= Конфиг для run.sh:  ======================
	file { "/opt/osm/local_utils/import_station_loading/config.sh":
		ensure => file,
		content => template("osm_load_station_import_data/config.sh.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "git_import_station_loading" ],
	}
	#======================= Конфиг для run.sh:  ======================
	file { "/opt/osm/local_utils/import_station_loading/osmbot.conf":
		ensure => file,
		content => template("osm_load_station_import_data/osmbot.conf.erb"),
		replace => yes,
		mode => 0644,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "git_import_station_loading" ],
	}

	#=============== CRON ====================
	# Добавляем в cron:
file { "/etc/cron.d/load_station_layer_update":
		ensure => file,
		content => "# Обновление данных по загрузке подстанций:
10 3 1 * * root /opt/osm/local_utils/import_station_loading/run.sh /opt/osm/local_utils/import_station_loading/config.sh
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}
}
