class osm2mp (
	$svn_src="http://osm2mp.googlecode.com/svn",
	$install_path="/opt/osm/local_utils",
	$bin_path="/opt/osm/local_utils/bin",
	){

  	if !defined(package['subversion']) {
		package{"subversion":
			ensure => installed,
		}
	}
  	if !defined(package['perl']) {
		package{"perl":
			ensure => installed,
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

	exec { "svn_import_osm2mp":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "svn checkout $svn_src osm2mp",
		cwd => "${install_path}/",
		creates => "${install_path}/osm2mp",
		require => [
			package['subversion'], 
			exec ["mkdir ${install_path}"], 
			],
	}
	file {"${bin_path}/osm2mp":
		ensure => link,
		target => "${install_path}/osm2mp/trunk/osm2mp.pl",
		require => [
			exec['svn_import_osm2mp'], 
			exec ["mkdir ${bin_path}"],
			],
	}
	# FIXME: нужно доставить модули, чтобы osm2mp запускалось
}
