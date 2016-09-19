class osm_import_from_mail (
	$install_path="/opt/osm/local_utils/",
	$bin_path="/opt/osm/local_utils/bin",
	$gpx_store_path="${install_path}/osm_import_from_mail/gpx_store",
	$maildir_path="${install_path}/osm_import_from_mail/maildir",
	$cron_user_for_start="osm_local_utils",
	$log_path="/var/log/osm/osm_import_from_mail",
	$list_of_lines_path="${install_path}/osm_import_from_mail/list_names_of_lines.txt",
	$manual_path="${install_path}/osm_import_from_mail/Manual_GPS_DRSK.doc",
	$email_csv_to="",
	$email_osm_to="semenov@rsprim.ru,dolganin@prim.drsk.ru,lipovskiy@prim.drsk.ru,shupta@rsprim.ru,nikolaev@rsprim.ru",
	$email_admin="osm_admin@rsprim.ru,nikolaev@rsprim.ru",
	$email_server="mail-rsprim-ru.rs.int",
	$points_stat_dir_path="/var/spool/osm",

	$email_import="osm_import@rsprim.ru",
	$email_import_passwd,

	$tmpdir="/tmp/osm_import_from_mail",
	){

	$base_dir="${install_path}/osm_import_from_mail"
	$points_stat_path="${points_stat_dir_path}/osm_import_from_mail_points.stat"
	$maildir="${maildir_path}/new"
	$maildir_cur="${maildir_path}/cur"
	$maildir_tmp="${maildir_path}/tmp"
	$backup_maildir="${maildir_path}/complete"
	$error_maildir="${maildir_path}/error"

	#========================   Нужные пакеты: ===================
  	if !defined(package['sendemail']) {
		package {"sendemail":
			ensure => installed
		}
	}
  	if !defined(package['convmv']) {
		package {"convmv":
			ensure => installed
		}
	}
  	if !defined(package['getmail4']) {
		package {"getmail4":
			ensure => installed
		}
	}
	#===================== Пользователь: =====================
  	if !defined(user["${cron_user_for_start}"]) {
		user {"add osm_local_utils":
			name => "${cron_user_for_start}",
			ensure => present,
			comment => "user which run local osm utils",
			groups => ["www-data"],
			# Создаём домашнюю директорию:
			managehome => true,
			shell => "/bin/bash",
		}
	}

	#=========================  Пути: ========================
	if !defined(exec ["mkdir ${bin_path}"]) {
		exec {"mkdir ${bin_path}":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${bin_path}",
			creates => "${bin_path}",
		}
	}
	if !defined(exec ["mkdir ${base_dir}"]) {
		exec {"mkdir ${base_dir}":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${base_dir}",
			creates => "${base_dir}",
		}
	}
	if !defined(exec ["mkdir ${gpx_store_path}"]) {
		exec {"mkdir ${gpx_store_path}":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${gpx_store_path} && chown ${cron_user_for_start} ${gpx_store_path}",
			creates => "${gpx_store_path}",
			require => user["add osm_local_utils"],
		}
	}
	if !defined(exec ["mkdir ${maildir_path}"]) {
		exec {"mkdir ${maildir_path}":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${maildir_path} && chown ${cron_user_for_start} ${maildir_path}",
			creates => "${maildir_path}",
		}
	}
	if !defined(exec ["mkdir ${log_path}"]) {
		exec {"mkdir ${log_path}":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${log_path} && chown ${cron_user_for_start} ${log_path}",
			creates => "${log_path}",
		}
	}
	if !defined(exec ["mkdir ${points_stat_dir_path}"]) {
		exec {"mkdir ${points_stat_dir_path}":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${points_stat_dir_path} && chown ${cron_user_for_start} ${points_stat_dir_path}",
			creates => "${points_stat_dir_path}",
		}
	}
	if !defined(exec ["mkdir ${tmpdir}"]) {
		exec {"mkdir ${tmpdir}":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${tmpdir} && chown ${cron_user_for_start} ${tmpdir}",
			creates => "${tmpdir}",
		}
	}
	if !defined(exec ["mkdir ${maildir_path}"]) {
		exec {"mkdir ${maildir_path}":
			path   => "/usr/bin:/usr/sbin:/bin",
			command => "mkdir -p ${maildir_path} && chown ${cron_user_for_start} ${maildir_path}",
			creates => "${maildir_path}",
		}
	}
	file{"${maildir}":
		ensure => directory,
		owner => "${cron_user_for_start}",
		require => exec ["mkdir ${maildir_path}"],
	}
	file{"${maildir_tmp}":
		ensure => directory,
		owner => "${cron_user_for_start}",
		require => exec ["mkdir ${maildir_path}"],
	}
	file{"${maildir_cur}":
		ensure => directory,
		owner => "${cron_user_for_start}",
		require => exec ["mkdir ${maildir_path}"],
	}
	file{"${backup_maildir}":
		ensure => directory,
		owner => "${cron_user_for_start}",
		require => exec ["mkdir ${maildir_path}"],
	}
	file{"${error_maildir}":
		ensure => directory,
		owner => "${cron_user_for_start}",
		require => exec ["mkdir ${maildir_path}"],
	}
	file{"${base_dir}/.getmail":
		ensure => directory,
		owner => "${cron_user_for_start}",
		require => exec ["mkdir ${base_dir}"],
	}

	#===================== Скрипты: ==========================
	file {"${base_dir}/osm_check_gpx_file_name.sh":
		content => template("osm_import_from_mail/osm_check_gpx_file_name.sh.erb"),
		replace => yes,
		owner => "${cron_user_for_start}",
		group => www-data,
		mode => 0755,
		ensure => file,
		require => exec ["mkdir ${base_dir}"],
	}
	file {"${base_dir}/osm_import_from_mail.sh":
		content => template("osm_import_from_mail/osm_import_from_mail.sh.erb"),
		replace => yes,
		owner => "${cron_user_for_start}",
		group => www-data,
		mode => 0755,
		ensure => file,
		require => exec ["mkdir ${base_dir}"],
	}
	#================== конфиги: ==============================
	file {"${base_dir}/.getmail/getmailrc":
		content => template("osm_import_from_mail/getmailrc.erb"),
		replace => yes,
		owner => "${cron_user_for_start}",
		group => www-data,
		mode => 0640,
		ensure => file,
		require => file ["${base_dir}/.getmail"],
	}
	file {"${points_stat_path}":
		content => "0",
		replace => no,
		owner => "${cron_user_for_start}",
		group => www-data,
		mode => 0644,
		ensure => file,
		require => exec ["mkdir ${points_stat_dir_path}"],
	}
	file {"${list_of_lines_path}":
		replace => no,
		owner => "${cron_user_for_start}",
		group => www-data,
		mode => 0664,
		ensure => file,
		require => exec ["mkdir ${base_dir}"],
	}


	#=================== ссылки: =======================

	file {"${bin_path}/osm_import_from_mail.sh":
		ensure => link,
		target => "${base_dir}/osm_import_from_mail.sh",
		require => [
			exec ["mkdir ${bin_path}"],
			],
	}
	#=============== CRON ====================
	# Добавляем в cron:
file { "/etc/cron.d/osm_import_from_mail":
		ensure => file,
		content => "# Do not edit manualy. Created by puppet.
# Импорт данных в gpx и конвертация их в csv и osm, отправка результата по почте:
*/10 * * * * osm_local_utils ${bin_path}/osm_import_from_mail.sh
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}
}
