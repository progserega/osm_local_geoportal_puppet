# geo2.rs.int - Rails-сервер OSM на Debian 8 (т.к. в ней более стабильный ruby)
#node "geo1.rs.int" inherits default {
node "geo2.rs.int" {
	# В интернет через prx.rs.int:
	class {'proxy':
	      proxy_host => 'prx.rs.int',
		  proxy_port => '3128',
	}
	# Базовая настройка:
	include "network_setup"
	include "ntpdate"
	include "locales"
	include "timezone"
	# Прописываем нужный DNS-сервер:
	include "set_dns_server"
	# ставим gpg и создаём файл с указанием прокси-сервера:
	include "gnupg"
	# Системные репозитарии:
	class {"debian_repo_updates":
		release => "jessie",
	}
	# локальный репозитарий ДРСК
	#include "drsk_repo"
	# Ставим zabbix_agent:
	include "zabbix_agent"
	# Настраиваем запуск puppet-агента при запуске системы:
	include "puppet_agent"
	# Берём скрипты из git в /scripts
	include "linux_scripts"
	# Добавляем нужных пользователей в систему и ssh-ключи для них:
	include "access_to_system"
	# vim и его настройка:
	include "vim"
	# настройка bash:
	include "bash"
	# ставим mc:
	include "mc"
	# ставим screen:
	include "screen"
	# Настройка sudo:
	include "sudo_drsk"
	# свежая версия apt, т.к. в старой ошибки:
	include "apt_get_update"
	include "apt_package"
	# Шлём логи на сервер логов:
	class {"syslog-client":
		syslog_server => "syslog.rs.int"
	}
	# Клиент бакулы:
	class {'bacula_client':
	      bacula_director_name => 'jabber.rs.int-dir',
		  bacula_director_host => 'bacula.rs.int',
		  passwd_len => 40
	}

	# OSM API-server:
	class {"osm_rails_server":
		server_url => "osm.prim.drsk.ru",
		server_name => "OSM Объекты ДРСК",
		email_from => "ДРСК OSM <osm@rsprim.ru>",
		email_return_path => "osm@rsprim.ru",
		email_admin => "semenov@rsprim.ru",

		# development база:
		db_dev_name => "drsk_dev_osm",
		db_dev_user_name => "openstreetmap",
		db_dev_passwd => "XXXXX",
		db_dev_host => "db.rs.int",

		# prodaction база:
		db_prodaction_name => "drsk_prodaction_osm",
		db_prodaction_user_name => "openstreetmap",
		db_prodaction_passwd => "XXXXXX",
		db_prodaction_host => "db.rs.int",

		# test база:
		db_test_name => "drsk_test_osm",
		db_test_user_name => "openstreetmap",
		db_test_passwd => "XXXXX",
		db_test_host => "db.rs.int",

		install_path => "/opt/osm",
		
		# свежая, 4.0 nodejs не собирается, поэтому берём самую последнюю прошлую версию:
		nodejs_source => "https://nodejs.org/dist/latest-v0.12.x/node-v0.12.7.tar.gz",
	}
	# рестарт и логирование падающего OSM-сервера, если он таки упадёт:
	include "osm_restart_rails_service"
}
