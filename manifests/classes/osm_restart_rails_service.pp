class osm_restart_rails_service {
	# Задание по проверке работы сервиса:
	file { "/etc/cron.d/osm_restart_rails_service":
		ensure => file,
		content => "# Created by Puppet. Do not edit manual.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin:/usr/x86_64-pc-linux-gnu/gcc-bin/4.3.2
# Задание по проверке работы сервиса:
*/5 * * * * root /scripts/osm_rails_server_restart.sh
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}
}
