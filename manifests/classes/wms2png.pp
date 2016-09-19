class wms2png (
	$git_src="https://github.com/progserega/wms2png.git",
	$install_path="/opt/osm/local_utils",
	$bin_path="/opt/osm/local_utils/bin",
	$wms_url="http://wms.osm.prim.drsk.ru/tilecache.cgi",
	$out_dir="${install_path}/wms2png/out/",
	$log_path="/var/log/osm",

	){
	$log_dir="${log_path}/wms2png/"

  	if !defined(Class['git']) {
		include git
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
	if !defined(exec ["mkdir $out_dir"]) {
		exec {"mkdir $out_dir":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${out_dir}",
			creates => "${out_dir}",
		}
	}
	if !defined(exec ["mkdir $log_dir"]) {
		exec {"mkdir $log_dir":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${log_dir}",
			creates => "${log_dir}",
		}
	}

	exec { "git_import_wms2png":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone $git_src wms2png",
		cwd => "${install_path}/",
		creates => "${install_path}/wms2png",
		require => [
			package['git'], 
			exec ["mkdir ${install_path}"], 
			],
	}
	# Конфиг:
	file {"${install_path}/wms2png/wms2png.conf":
		content => template("wms2png/wms2png.conf.erb"),
		replace => no,
		owner => root,
		group => root,
		mode => 0644,
		ensure => file,
		require => exec ["git_import_wms2png"],
	}
}
