class osmconvert (
		$install_path="/opt/osm/osmconvert",
		$osmconvert_src="http://m.m.i24.cc/osmconvert.c",
		$zlib_name="zlib1g",
	){
  	if !defined(package ['build-essential']) {
		package { 'build-essential':
			ensure => installed
		}
	}
	# zlib - нужно для сборки osmconvert:
  	if !defined(package ["${zlib_name}"]) {
		package { "${zlib_name}":
			ensure => installed
		}
	}
  	if !defined(package ["${zlib_name}-dev"]) {
		package { "${zlib_name}-dev":
			ensure => installed
		}
	}
	# создаём путь:
	exec { "mkdir ${install_path}":
		path   => "/usr/bin:/usr/sbin:/bin:/usr/src/linux-source-$kernelmajversion/drivers/staging/usbip/userspace/",
		command => "mkdir -p ${install_path}",
		cwd => "/",
		creates => "${install_path}",
	}

	# Скачиваем исходник:
	exec { "wget osmconvert src":
		path   => "/usr/bin:/usr/sbin:/bin:/usr/src/linux-source-$kernelmajversion/drivers/staging/usbip/userspace/",
		command => "wget ${osmconvert_src} -O osmconvert.c",
		cwd => "${install_path}",
		creates => "${install_path}/osmconvert.c",
		require => exec ["mkdir ${install_path}"],
	}

	exec { "build_osmconvert":
		path   => "/usr/bin:/usr/sbin:/bin:/usr/src/linux-source-$kernelmajversion/drivers/staging/usbip/userspace/",
		command => "cc -x c -lz -O3 -o osmconvert osmconvert.c",
		cwd => "${install_path}",
		creates => "${install_path}/osmconvert",
		require => [
			exec ["wget osmconvert src"],
			package ["${zlib_name}"],
			package ["${zlib_name}-dev"],
			package ["build-essential"],
			],
	}
}
