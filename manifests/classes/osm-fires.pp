class osm-fires (
	$var_dir="/var/osm/fires/",
	$install_path="/opt/osm",
	$osm_site_prod_path="/opt/osm/openstreetmap.ru/OpenStreetMap.ru_prodaction",
	$log_path="/var/log/osm",

	$db_name="drsk_dev_osm",
	$db_user="osm_read_only",
	$db_passwd=undef,
	$db_host="db.rs.int",

	# Интерфал обновления данных о пожарах (каждые N часов):
	$fires_data_update_time="4",

	# Время в часах, не позже которого от текущего момента анализируются пожары для создания списка 
	# их приближённости к объектам ДРСК:
	$time_window_warning_list="24",
	# Минимально допустимое расстояние в метрах между объектами ДРСК и пожарами:
	$min_fire_distance="2000",

	$email_error_to="semenov@rsprim.ru",
	$email_server="mail-rsprim-ru.rs.int",
	){

	$tp_list="$var_dir/tp_list.csv"
	$station_list="$var_dir/station_list.csv"
	
	$fires_data_file="$var_dir/NASA_fires_Russia_and_Asia_24h.csv"

	$station_data_file="$var_dir/station_list.csv"
	$tp_data_file="$var_dir/tp_list.csv"

	$station_warning_list="$var_dir/station_warning_list.csv"
	$tp_warning_list="$var_dir/tp_warning_list.csv"
	

  	if !defined(Class['git']) {
		include git
	}
  	if !defined(package['python3-psycopg2']) {
		package {"python3-psycopg2":
			ensure => installed
		}
	}
	file {"/var/osm":
		ensure => directory,
	}
	file {"/var/osm/fires":
		ensure => directory,
		require => file ["/var/osm"],
	}
	if !defined(file["${install_path}"])
	{
		file {"${install_path}":
			ensure => directory,
		}
	}
	file {"${install_path}/local_utils":
		ensure => directory,
		require => file["${install_path}"],
	}
	exec { "git_fires_tools":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone http://git.rs.int/osm/fires_data_process.git",
		cwd => "${install_path}/local_utils",
		creates => "${install_path}/local_utils/fires_data_process",
		require => [package['git'], file["${install_path}/local_utils"] ],
	}
	#======================= Конфиг для run.sh:  ======================
	file { "${install_path}/local_utils/fires_data_process/nasa/config.sh":
		ensure => file,
		content => template("osm-fires/nasa_config.sh.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "git_fires_tools" ],
	}

	#=====================  Конфиг для fires_csv2json.py:  ======================
	exec { "fires_csv2json.py config":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "cp fires_csv2json_conf.py.example fires_csv2json_conf.py",
		cwd => "${install_path}/local_utils/fires_data_process/nasa",
		creates => "${install_path}/local_utils/fires_data_process/nasa/fires_csv2json_conf.py",
		require => exec['git_fires_tools'],
	}
	# Правим базовый конфиг для fires_csv2json.py:
	file_line { 'time_window value':
		ensure  => present,
		path  => "${install_path}/local_utils/fires_data_process/nasa/fires_csv2json_conf.py",
		line  => "time_window=${time_window_warning_list}",
		match => '^time_window',
		require => exec['fires_csv2json.py config'],
	}

	# ===================  Конфиг для corp_data_list: =====================
	exec { "corp_data_list config":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "cp db_config.py.example db_config.py",
		cwd => "${install_path}/local_utils/fires_data_process/corp_data_list",
		creates => "${install_path}/local_utils/fires_data_process/corp_data_list/db_config.py",
		require => exec['git_fires_tools'],
	}
	# Правим базовый конфиг для corp_data_list:
	file_line { 'corp_data_list db_host value':
		ensure  => present,
		path  => "${install_path}/local_utils/fires_data_process/corp_data_list/db_config.py",
		line  => "db_host=\"${db_host}\"",
		match => '^db_host',
		require => exec['corp_data_list config'],
	}
	file_line { 'corp_data_list db_name value':
		ensure  => present,
		path  => "${install_path}/local_utils/fires_data_process/corp_data_list/db_config.py",
		line  => "db_name=\"${db_name}\"",
		match => '^db_name',
		require => exec['corp_data_list config'],
	}
   	file_line { 'corp_data_list db_user value':
		ensure  => present,
		path  => "${install_path}/local_utils/fires_data_process/corp_data_list/db_config.py",
		line  => "db_user=\"${db_user}\"",
		match => '^db_user',
		require => exec['corp_data_list config'],
	}
   	file_line { 'corp_data_list db_passwd value':
		ensure  => present,
		path  => "${install_path}/local_utils/fires_data_process/corp_data_list/db_config.py",
		line  => "db_passwd=\"${db_passwd}\"",
		match => '^db_passwd',
		require => exec['corp_data_list config'],
	}
   

	# ===================  Конфиги для warning_fires_list: =====================
	file { "${install_path}/local_utils/fires_data_process/warning_fires_list/config.sh":
		ensure => file,
		content => template("osm-fires/generate_warning_fires_list_run_config.sh.erb"),
		replace => yes,
		mode => 0750,
		owner => "root",
		group => "www-data",
		backup => false,
		require => exec [ "git_fires_tools"],
	}
	file { "${install_path}/local_utils/fires_data_process/warning_fires_list/generate_warning_fires_list_config.py":
		ensure => file,
		content => template("osm-fires/generate_warning_fires_list_config.py.erb"),
		replace => yes,
		mode => 0750,
		owner => "root",
		group => "www-data",
		backup => false,
		require => exec [ "git_fires_tools"],
	}
    
      
	
	#=============== CRON ====================
	# Добавляем в cron:
file { "/etc/cron.d/fires_layer_update":
		ensure => file,
		content => "# Обновление данных по пожарам и следом списка объектов, приближённых к пожарам:
10 */$fires_data_update_time * * * root ${install_path}/local_utils/fires_data_process/nasa/run.sh ${install_path}/local_utils/fires_data_process/nasa/config.sh; ${install_path}/local_utils/fires_data_process/warning_fires_list/run.sh ${install_path}/local_utils/fires_data_process/warning_fires_list/config.sh
# Обновление данных по объектам ОАО ДРСК:
20 0 * * * root ${install_path}/local_utils/fires_data_process/corp_data_list/get_station_list.py $station_list; ${install_path}/local_utils/fires_data_process/corp_data_list/get_tp_list.py $tp_list
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}

	#=========== web view ===============
  	if !defined(file ["${install_path}/local_web_services"]) {
		file {"${install_path}/local_web_services":
			ensure => directory,
		}
	}
	file {"${install_path}/local_web_services/fires":
		ensure => directory,
		require => file["${install_path}/local_web_services"],
	}
	file { "${install_path}/local_web_services/fires/index.cgi":
		ensure => file,
		content => template("osm-fires/index.cgi_web_list_warnings.erb"),
		replace => yes,
		mode => 0755,
		owner => "www-data",
		group => "www-data",
		backup => false,
		require => file [ "${install_path}/local_web_services/fires" ],
	}
	file { "${install_path}/local_web_services/fires/.htaccess":
		ensure => file,
		source => "puppet:///modules/osm-fires/htaccess_web_list_warnings",
		replace => yes,
		mode => 0644,
		owner => "www-data",
		group => "www-data",
		backup => false,
		require => file [ "${install_path}/local_web_services/fires" ],
	}
	file { "${install_path}/local_web_services/fires/favicon.png":
		ensure => file,
		source => "puppet:///modules/osm-fires/favicon.png",
		replace => yes,
		mode => 0644,
		owner => "www-data",
		group => "www-data",
		backup => false,
		require => file [ "${install_path}/local_web_services/fires" ],
	}
}
