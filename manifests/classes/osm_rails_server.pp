class osm_rails_server (
	$server_url="$fqdn",
	$server_name="OSM Объекты ДРСК",
	$email_from="ДРСК OSM <osm@rsprim.ru>",
	$email_return_path="osm@rsprim.ru",
	$email_admin="semenov@rsprim.ru",
	$email_server="mail-rsprim-ru.rs.int",

	# development база:
	$db_dev_name="drsk_dev_osm",
	$db_dev_user_name="openstreetmap",
	$db_dev_passwd="XXXXXXX",
	$db_dev_host="db.rs.int",

	# prodaction база:
	$db_prodaction_name="drsk_prodaction_osm",
	$db_prodaction_user_name="openstreetmap",
	$db_prodaction_passwd="XXXXXXX",
	$db_prodaction_host="db.rs.int",

	# test база:
	$db_test_name="drsk_test_osm",
	$db_test_user_name="openstreetmap",
	$db_test_passwd="XXXXXXX",
	$db_test_host="db.rs.int",


	$install_path="/opt/osm",
	$openstreetmap_website_install_path="/opt/osm/openstreetmap-website",
	$osm_rails_server_source = "https://github.com/openstreetmap/openstreetmap-website.git",
	$nodejs_source = "http://nodejs.org/dist/node-latest.tar.gz",
){

	$build_path="${install_path}/build_package"
	$nodejs_build_path="${build_path}/nodejs"
	$nodejs_build_log="${build_path}/nodejs_build.log"

	$rails_server_log_dir="/var/log/osm/"
	$rails_server_log_path="${rails_server_log_dir}/rail_server.log"


	#$pkg_osm_rail_server_deps=[ "ruby-rmagick", "rails", "rubygems","ruby-switch","libxml-ruby1.9.1","ruby1.9.1","libruby1.9.1","ruby1.9.1-dev","ri1.9.1","libmagickwand-dev","libxml2-dev","libxslt1-dev","checkinstall","osm2pgsql","php5-odbc","php-db","php5-pgsql","python-mapnik2", "osmosis", "imagemagick", "autoconf","automake", "apache2", "apache2-mpm-prefork",]
	$pkg_osm_rail_server_deps=[ "ruby-rmagick", "rails", "ruby-libxml","ruby","libruby","ruby-dev","ri","libmagickwand-dev","libxml2-dev","libxslt1-dev","checkinstall","osm2pgsql","php5-odbc","php-db","php5-pgsql","python-mapnik2", "osmosis", "imagemagick", "autoconf","automake", "apache2", "apache2-mpm-prefork",]

	package { $pkg_osm_rail_server_deps:
		ensure => installed,
	}

  	if !defined(package['libpq-dev']) {
		package { "libpq-dev":
			ensure => installed,
		}
	}

  	if !defined(package['libsasl2-dev']) {
		package { "libsasl2-dev":
			ensure => installed,
		}
	}

  	if !defined(package['build-essential']) {
		package { "build-essential":
			ensure => installed,
		}
	}

	# Ставим бандл:
	file {"${build_path}/bundle_install.sh":
		content => "#!/bin/bash
log=\"${build_path}/bundle_install.log\"
cd \"${openstreetmap_website_install_path}\"
gem install bundle --no-rdoc --no-ri &>> \"\${log}\"
if [ 0 != $? ]
then
	exit 1
fi
bundle install &>> \"\${log}\"
if [ 0 != $? ]
then
	exit 1
fi
touch ${build_path}/install_bundle.stat
exit 0
		", 
		replace => yes,
		owner => root,
		group => root,
		mode => 0755,
		ensure => file,
		require => exec ["mkdir ${nodejs_build_path}"],
	}
	exec {"install bundle":
		path   => "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin",
		command => "${build_path}/bundle_install.sh",
		# запускаемся только по notify:
		cwd => "${build_path}",
		timeout => 1200,
		require => [ package [ $pkg_osm_rail_server_deps ], exec ["mkdir ${nodejs_build_path}"], file["${build_path}/bundle_install.sh"], ],
		creates => "${build_path}/install_bundle.stat",
	}
	
	# Создаём пути, куда ставим:
	exec {"mkdir ${install_path}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${install_path}",
		creates => "${install_path}",
	}
	exec {"mkdir ${nodejs_build_path}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${nodejs_build_path}",
		creates => "${nodejs_build_path}",
	}
	exec {"mkdir ${rails_server_log_dir}":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mkdir -p ${rails_server_log_dir}",
		creates => "${rails_server_log_dir}",
	}

	# Убеждаемся, что git установлен:
  	if !defined(Class['git']) {
		include git
	}

	# Скачиваем исходник OSM Rail-server:
	exec {"git clone osm_rails_server":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone $osm_rails_server_source",
		cwd => "$install_path",
		timeout => 1200,
		creates => "${install_path}/openstreetmap-website",
		require  => [ Package['git'], exec ["mkdir ${install_path}"] ],
	}

	# =========================== Ставим NodeJS: ======================
	exec {"get nodejs":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "wget -N $nodejs_source -O ${nodejs_build_path}/node-latest.tar.gz",
		creates => "${nodejs_build_path}/node-latest.tar.gz",
		cwd => "${nodejs_build_path}",
		require => exec ["mkdir ${nodejs_build_path}"],
	}
	file {"${nodejs_build_path}/nodejs_install_script.sh":
		content => "#!/bin/bash
tar xzf node-latest.tar.gz &>> \"${nodejs_build_log}\"
cd ${nodejs_build_path}/node-v*
./configure &>> \"${nodejs_build_log}\"
checkinstall -y --install=no --pkgversion $(echo $(pwd) | sed -n -re's/.+node-v(.+)$/\1/p') make -j$(($(nproc)+1)) install &>> \"${nodejs_build_log}\"
if [ ! 0 -eq $? ]
then
	echo \"`date +%Y.%m.%d-%T`: ERROR! build deb\" &>> \"${nodejs_build_log}\"
	exit 1
fi
echo \"`date +%Y.%m.%d-%T`: success end build deb\" &>> \"${nodejs_build_log}\"
if [ -f node_*.deb ]
then
	echo \"`date +%Y.%m.%d-%T`: start install deb!\" &>> \"${nodejs_build_log}\"
	dpkg -i node_*.deb &>> \"${nodejs_build_log}\"
	mv node_*.deb ${nodejs_build_path}/nodejs.deb
else
	echo \"`date +%Y.%m.%d-%T`: ERROR! no deb!\" &>> \"${nodejs_build_log}\"
	exit 1
fi
echo \"`date +%Y.%m.%d-%T`: success end script\" &>> \"${nodejs_build_log}\"
exit 0
", 
		replace => yes,
		owner => root,
		group => root,
		mode => 0755,
		ensure => file,
		require => exec ["get nodejs"],
	}

	exec {"exec ${nodejs_build_path}/nodejs_install_script.sh":
		path   => "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin",
		command => "${nodejs_build_path}/nodejs_install_script.sh",
		creates => "${nodejs_build_path}/nodejs.deb",
		cwd => "${nodejs_build_path}",
		# Сборка проходит долго:
		timeout => 1200,
		require => [ 
			exec ["get nodejs"],
			file ["${nodejs_build_path}/nodejs_install_script.sh"],
			package [ $pkg_osm_rail_server_deps ],
			package [ "build-essential"],
			package [ "libpq-dev" ],
			package [ "libsasl2-dev" ],
			],
	}

	#================ конфиги ===================:
	if $lsbdistid == "Debian" and $lsbmajdistrelease < 8 {
		$bundle_path="/usr/local/bin/bundle"
	
		# Скрипт запуска сервера:
		file {"/etc/init.d/osm-rails-server":
			content => template("osm_rails_server/osm-rails-server_initd_script.erb"),
			replace => yes,
			owner => root,
			group => root,
			mode => 0755,
			ensure => file,
		} 
	}
	if $lsbdistid == "Debian" and $lsbmajdistrelease > 7 {
		$bundle_path="/usr/bin/bundle"
		# Скрипт запуска сервера:
		file {"/etc/init.d/osm-rails-server":
			content => template("osm_rails_server/osm-rails-server_initd_script_systemd.erb"),
			replace => yes,
			owner => root,
			group => root,
			mode => 0755,
			ensure => file,
		}
	}

	file {"/etc/openstreetmap-website":
		ensure => link,
		target => "${install_path}/openstreetmap-website/config/",
		require => exec ["git clone osm_rails_server"],
	}

	# Конфиг приложения сервера:
	file {"${openstreetmap_website_install_path}/config/application.yml":
		content => template("osm_rails_server/application.yml.erb"),
		replace => no,
		owner => root,
		group => root,
		mode => 0644,
		ensure => file,
		require => exec ["git clone osm_rails_server"],
	} 
	# Конфиг баз данных:
	file {"${openstreetmap_website_install_path}/config/database.yml":
		content => template("osm_rails_server/database.yml.erb"),
		replace => no,
		owner => root,
		group => root,
		mode => 0644,
		ensure => file,
		require => exec ["git clone osm_rails_server"],
	} 
	#================ инициализация баз ===================:
	file {"${build_path}/db_init.sh":
		content => "#!/bin/bash
log=\"${build_path}/db_init.log\"
cd \"${openstreetmap_website_install_path}\"
bundle exec rake db:migrate RAILS_ENV=production &>> \"\${log}\"
if [ 0 != $? ]
then
	#echo \"error db:migrate prodaction\" > ${build_path}/db_init.stat
	echo \"error db:migrate prodaction\" >> \"\${log}\"
	exit 1
fi
bundle exec rake db:migrate RAILS_ENV=test &>> \"\${log}\"
if [ 0 != $? ]
then
	#echo \"error db:migrate test\" > ${build_path}/db_init.stat
	echo \"error db:migrate test\" >> \"\${log}\"
	exit 1
fi
bundle exec rake db:migrate RAILS_ENV=development &>> \"\${log}\"
if [ 0 != $? ]
then
	#echo \"error db:migrate development\" > ${build_path}/db_init.stat
	echo \"error db:migrate development\" >> \"\${log}\"
	exit 1
fi
bundle exec rake test &>> \"\${log}\"
if [ \" 0 errors\" != \"`tail -n 3 \${log}|egrep '.*runs.*errors.*skips'|awk '{print \$4}' FS=','`\" ]
then 
	#echo \"error rake test\" > ${build_path}/db_init.stat
	echo \"error rake test\" >> \"\${log}\"
	exit 1
fi
#if [ 0 != $? ]
#then
#	exit 1
#fi
echo \"success\" > ${build_path}/db_init.stat
exit 0
		", 
		replace => yes,
		owner => root,
		group => root,
		mode => 0755,
		ensure => file,
		require => exec ["mkdir ${nodejs_build_path}"],
	}
		
	exec {"db init":
		path   => "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin",
		command => "${build_path}/db_init.sh",
		# запускаемся только по notify:
		cwd => "$openstreetmap_website_install_path",
		timeout => 2400,
		require => [ 
			file ["${openstreetmap_website_install_path}/config/application.yml"] ,  
			file ["${openstreetmap_website_install_path}/config/database.yml"], 
			exec ["git clone osm_rails_server"], 
			exec ["install bundle"],
			file ["${build_path}/db_init.sh"],
			],
		creates => "${build_path}/db_init.stat",
	}
	service { "osm-rails-server":
		ensure => "running",
		subscribe => file ["${openstreetmap_website_install_path}/config/application.yml"],
		require => [
			file ["${openstreetmap_website_install_path}/config/application.yml"],
			file ["${openstreetmap_website_install_path}/config/database.yml"],
			exec ["db init"],
			exec ["mkdir ${rails_server_log_dir}"],
		],
		restart => true,
	}
	#======================== настройка apache: ==========================

	#if !defined(Class['apache::mod::proxy']) {
	#	include apache::mod::proxy
	#}
	#if !defined(Class['apache::mod::proxy_http']) {
	#	include apache::mod::proxy_http
	#}
	#if !defined(Class['apache::mod::proxy_balancer']) {
	#	include apache::mod::proxy_balancer
	#}
	# Конфиг приложения сервера:
	file {"/etc/apache2/sites-available/$server_url.conf":
		content => template("osm_rails_server/vhost.conf.erb"),
		replace => no,
		owner => root,
		group => root,
		mode => 0644,
		ensure => file,
		require => package [ $pkg_osm_rail_server_deps ],
	}
	file {"/etc/apache2/sites-enabled/$server_url.conf":
		ensure => link,
		target => "/etc/apache2/sites-available/$server_url.conf",
		require => file["/etc/apache2/sites-available/$server_url.conf"],
		notify => Exec["apache2 module enable"],
	}
	if $lsbdistid == "Debian" and $lsbmajdistrelease < 8 {
		exec {"apache2 module enable":
			path   => "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin",
			command => "a2enmod proxy && a2enmod && a2enmod proxy_http && a2enmod proxy_balancer && service apache2 restart",
			cwd => "/",
			# Сборка проходит долго:
			refreshonly => true,
		}
	}
	if $lsbdistid == "Debian" and $lsbmajdistrelease > 7 {
		exec {"apache2 module enable":
			path   => "/usr/bin:/usr/sbin:/bin:/usr/local/sbin:/usr/sbin:/sbin",
			command => "a2enmod proxy && a2enmod && a2enmod proxy_http && a2enmod proxy_balancer && a2enmod lbmethod_byrequests && service apache2 restart",
			cwd => "/",
			# Сборка проходит долго:
			refreshonly => true,
		}
	}
	service { "apache2":
		ensure => "running",
		subscribe => file [ "/etc/apache2/sites-enabled/$server_url.conf" ],
		restart => true,
	}

	#======================= настройка перенаправления почты ==============
	file {"${build_path}/exim4-config.preseed":
		content => template("osm_rails_server/exim4-config.preseed.erb"),
		replace => yes,
		owner => root,
		group => root,
		mode => 0644,
		ensure => file,
	}
	package { "exim4-config":
		ensure => installed,
		responsefile => "${build_path}/exim4-config.preseed",
		require => File["${build_path}/exim4-config.preseed"],
	}
	package { "exim4":
		ensure => installed,
		responsefile => "${build_path}/exim4-config.preseed",
		require => [ File["${build_path}/exim4-config.preseed"], package ["exim4-config"] ],
	}
	#===================== обработка лог-файлов: ===================
	file {"/etc/logrotate.d/osm_server":
		content => "# Created by Puppet, do not edit manualy.
/opt/osm/openstreetmap-website/log/development.log
{       
	rotate 7
	size 10M
	missingok
	nocreate
	delaycompress
	compress
}
",
		replace => yes,
		owner => root,
		group => root,
		mode => 0644,
		ensure => file,
	}

}
