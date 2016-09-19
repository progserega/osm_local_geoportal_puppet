class osm_osmbot (
	$osmbot_git_src="https://github.com/progserega/osmbot.git",
	$install_path="/opt/osm/local_utils"
	){

  	if !defined(Class['git']) {
		include git
	}
  	if !defined(package['python-lxml']) {
		package {"python-lxml":
			ensure => installed
		}
	}
  	if !defined(package['libxml2-dev']) {
		package {"libxml2-dev":
			ensure => installed
		}
	}
	if !defined(exec ["mkdir $install_path"]) {
		exec {"mkdir $install_path":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${install_path}",
			creates => "${install_path}",
		}
	}
	if !defined(package ["build-essential"]) {
		package {"build-essential":
			ensure   => installed,
		}
	}

	file {"${install_path}/osmbot":
		ensure => directory,
		require => exec ["mkdir ${install_path}"],
	}
	file {"${install_path}/osmbot/bin":
		ensure => directory,
		require => file ["${install_path}/osmbot"],
	}
	file {"${install_path}/osmbot/config":
		ensure => directory,
		require => file ["${install_path}/osmbot"],
	}
	file {"${install_path}/osmbot/tmp":
		ensure => directory,
		require => file ["${install_path}/osmbot"],
	}

	exec { "git_import_osmbot":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone $osmbot_git_src src",
		cwd => "${install_path}/osmbot",
		creates => "${install_path}/osmbot/src",
		require => [
			package['git'], 
			file["${install_path}/osmbot"], 
			],
	}
	# сборка сишного патчера (устаревший):
	exec { "make c-patcher":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "make",
		cwd => "${install_path}/osmbot/src",
		creates => "${install_path}/osmbot/src/osmpatch",
		require => [
			exec['git_import_osmbot'], 
			package ["libxml2-dev"],
			package ["build-essential"],
			]
		}

	# Создаём ссылки:
	file {"${install_path}/osmbot/bin/osmpatch":
		ensure => link,
		target => "${install_path}/osmbot/src/osmpatch",
		require => [
			exec['make c-patcher'], 
			file ["${install_path}/osmbot/bin"],
			],
	}
	file {"${install_path}/osmbot/bin/osmpatch.py":
		ensure => link,
		target => "${install_path}/osmbot/src/osmpatch.py",
		require => [
			exec['git_import_osmbot'], 
			file ["${install_path}/osmbot/bin"],
			],
	}
	file {"${install_path}/osmbot/bin/run_bot.sh":
		ensure => link,
		target => "${install_path}/osmbot/src/run_bot.sh",
		require => [
			exec['git_import_osmbot'], 
			file ["${install_path}/osmbot/bin"],
			],
	}
}
