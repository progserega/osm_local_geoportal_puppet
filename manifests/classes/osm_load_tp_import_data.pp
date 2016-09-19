class osm_load_tp_import_data (
	$osmbot_user, 
	$osmbot_passwd, 
	$load_xml_url="http://1c-base.drsk.ru/DataTPForMapXML.xml", 
	$email_error_to="semenov@rsprim.ru", 
	$email_server="mail-rsprim-ru.rs.int",
	$install_path="/opt/osm",
	$var_dir="/var/osm"
	){

	$var_dir_util="${var_dir}/load_tp_import/"
	$import_data_file="$var_dir/import_data_from_1C.xml"
	$osmbot_config="${install_path}/local_utils/import_tp_loading/osmbot.conf"
	$osmbot_rules="$var_dir/osmbot_rule.xml"

  	if !defined(Class['git']) {
		include git
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
	if !defined(file ["${var_dir}"]) {
		file {"${var_dir}":
			ensure => directory,
		}
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
	file {"${var_dir_util}":
		ensure => directory,
		require => file ["${var_dir_util}"],
	}

	exec { "git_import_tp_loading":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone http://git.rs.int/osm/import_tp_loading.git",
		cwd => "${install_path}/local_utils",
		creates => "${install_path}/local_utils/import_tp_loading",
		require => [package['git'], file["${install_path}/local_utils"] ],
	}
	#======================= Конфиг для run.sh:  ======================
	file { "${install_path}/local_utils/import_tp_loading/config.sh":
		ensure => file,
		content => template("osm_load_tp_import_data/config.sh.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "git_import_tp_loading" ],
	}
	#======================= Конфиг для run.sh:  ======================
	file { "${install_path}/local_utils/import_tp_loading/osmbot.conf":
		ensure => file,
		content => template("osm_load_tp_import_data/osmbot.conf.erb"),
		replace => yes,
		mode => 0644,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "git_import_tp_loading" ],
	}

	#=============== CRON ====================
	# Добавляем в cron:
file { "/etc/cron.d/load_tp_layer_update":
		ensure => file,
		content => "# Обновление данных по загрузке подстанций:
30 1 2 * * root ${install_path}/local_utils/import_tp_loading/run.sh ${install_path}/local_utils/import_tp_loading/config.sh
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}
}
