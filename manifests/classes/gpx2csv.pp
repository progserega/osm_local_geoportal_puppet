class gpx2csv (
	$git_src="https://github.com/progserega/gpx2csv.git",
	$install_path="/opt/osm/local_utils",
	$bin_path="/opt/osm/local_utils/bin",
	){

  	if !defined(Class['git']) {
		include git
	}
  	if !defined(package['libxml2-dev']) {
		package {"libxml2-dev":
			ensure => installed
		}
	}
	if !defined(package ["build-essential"]) {
		package {"build-essential":
			ensure   => installed,
		}
	}
	if !defined(exec ["mkdir $install_path"]) {
		exec {"mkdir $install_path":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${install_path}",
			creates => "${install_path}",
		}
	}
	if !defined(exec ["mkdir $bin_path"]) {
		exec {"mkdir $bin_path":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${bin_path}",
			creates => "${bin_path}",
		}
	}

	exec { "git_import_gpx2csv":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone $git_src gpx2csv",
		cwd => "${install_path}/",
		creates => "${install_path}/gpx2csv",
		require => [
			package['git'], 
			exec ["mkdir ${install_path}"], 
			],
	}
	# сборка сишного патчера (устаревший):
	exec { "make gpx2csv":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "make",
		cwd => "${install_path}/gpx2csv",
		creates => "${install_path}/gpx2csv/gpx2csv",
		require => [
			exec['git_import_gpx2csv'], 
			package ["libxml2-dev"],
			package ["build-essential"],
			]
		}

	file {"${bin_path}/gpx2csv":
		ensure => link,
		target => "${install_path}/gpx2csv/gpx2csv",
		require => [
			exec['git_import_gpx2csv'], 
			exec ["mkdir ${bin_path}"],
			],
	}
}
