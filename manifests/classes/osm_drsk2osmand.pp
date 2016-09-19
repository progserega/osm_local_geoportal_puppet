class osm_drsk2osmand (
		$email_error_to="semenov@rsprim.ru", 
		$email_server="mail-rsprim-ru.rs.int", 
		$drsk_osm_url="http://export.osm.prim.drsk.ru/drsk_osm_full_dump_latest.osm.gz", 
		$export_path="/opt/osm/exports/osmand/",
		$mapcreator_url="http://download.osmand.net/latest-night-build/OsmAndMapCreator-main.zip",
		$log_path="/var/log/osm/drsk2osmand.log",
		$log_path_java="/var/log/osm/drsk2osmand_java.log",
		$osmconvert="/opt/osm/osmconvert/osmconvert",
	){

	$work_dir="/opt/osm/local_utils/osmand_map_generation"
	$var_dir="/var/osm/drskmap2osmand/"
	$var_dir_create_osm="${var_dir}/osm_files"
	$var_dir_create_osm_index="${var_dir_create_osm}/index_files"
	$var_dir_create_osm_gen_files="${var_dir_create_osm}/gen_files"
	$export_file="${export_path}/drsk.obf"

	# standart osm-tool osm2pbf (см. http://wiki.openstreetmap.org/wiki/Osmconvert ):


	$import_data_file_osm_gz="$var_dir/drsk_osm_data.osm.gz"
	$import_data_file_osm="$var_dir/drsk_osm_data.osm"
	#$import_data_file_pbf="$var_dir/drsk_osm_data.pbf"
	$import_data_file_pbf="$var_dir_create_osm/COUNTRY.osm.pbf"

	package {"openjdk-7-jre-headless":
		ensure => installed
	}

	exec { "create ${export_path}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p $export_path",
		creates => "${export_path}",
	}
	file { "${export_path}/drsk.render.xml":
		ensure => file,
		source => "puppet:///modules/osm_drsk2osmand/drsk.render.xml",
		owner => root,
		group => root,
		mode => 0644,
		require => exec ["create ${export_path}"],
	}
	exec { "create work dir":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p $work_dir",
		creates => "${work_dir}",
	}
	exec { "create var dir":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${var_dir_create_osm} && mkdir -p ${var_dir_create_osm_index} && mkdir -p ${var_dir_create_osm_gen_files}",
		creates => "${var_dir}",
	}

	exec { "get OsmAndMapCreator":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "wget -c \"${mapcreator_url}\" -O OsmAndMapCreator-main.zip",
		cwd => "${work_dir}",
		creates => "${work_dir}/OsmAndMapCreator-main.zip",
		require => exec [ "create work dir" ],
	}
	exec { "unpack OsmAndMapCreator":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "unzip OsmAndMapCreator-main.zip",
		cwd => "${work_dir}",
		creates => "${work_dir}/OsmAndMapCreator.sh",
		require => exec [ "get OsmAndMapCreator" ],
	}
	# создаём скрипты конвертации:
	file { "${work_dir}/drsk_osm2pbf.sh":
		ensure => file,
		content => template("osm_drsk2osmand/drsk_osm2pbf.sh.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "unpack OsmAndMapCreator" ],
	}
	file { "${work_dir}/create_map.sh":
		ensure => file,
		content => template("osm_drsk2osmand/create_map.sh.erb"),
		replace => yes,
		mode => 0755,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "unpack OsmAndMapCreator" ],
	}

	# Конфиг для OsmAndMapCreator:
	file { "${work_dir}/batch.xml":
		ensure => file,
		content => template("osm_drsk2osmand/batch.xml.erb"),
		replace => yes,
		mode => 0644,
		owner => "root",
		group => "root",
		backup => false,
		require => exec [ "unpack OsmAndMapCreator" ],
	}

	# Конфиг для логирования OsmAndMapCreator :
	file_line { 'java.util.logging.FileHandler.pattern':
		ensure  => present,
		path  => "${work_dir}/logging.properties",
		line  => "java.util.logging.FileHandler.pattern=$log_path_java",
		match => '^.*java.util.logging.FileHandler.pattern.*',
		require => exec [ "unpack OsmAndMapCreator" ],
	}

	#=============== CRON ====================
	# Добавляем в cron:
file { "/etc/cron.d/osm_drsk2osmand":
		ensure => file,
		content => "# Конвертация данных ДРСК в карту для OsmAnd:
10 2 * * * root ${work_dir}/create_map.sh
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}
	
}
