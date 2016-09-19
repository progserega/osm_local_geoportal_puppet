# db.rs.int
node "db.rs.int" inherits default {
	# Уникальные:

	# OSM базы для API-сервера:
	class {"osm_postgres_db_setup":
		# development база:
		db_dev_name => "drsk_dev_osm",
		db_dev_user_name => "openstreetmap",
		db_dev_passwd => "XXXXXX",

		# prodaction база:
		db_prodaction_name => "drsk_prodaction_osm",
		db_prodaction_user_name => "openstreetmap",
		db_prodaction_passwd => "XXXXX",

		# test база:
		db_test_name => "drsk_test_osm",
		db_test_user_name => "openstreetmap",
		db_test_passwd => "XXXXX",

		# Доступ к базе на чтение для основных таблиц (для ботов):
		db_dev_ro_user	=> 	"osm_read_only",
		db_dev_ro_user_passwd	=> 	"XXXXX",

		# Доступ к базе на чтение для всех таблиц (для экспорта):
		db_dev_full_ro_user	=> "osm_full_read_only",
		db_dev_full_ro_user_passwd => "XXXXXX",

		# Доступ к базе для блокировки пользователей (select на users, select и insert на user_blocks):
		db_dev_ban_access_user => "osm_ban_access_only",
		db_dev_ban_access_user_passwd => "XXXXX",

		install_path => "/opt/osm",

		# Доступ к postgres-серверу:
		db_access_netmask => "172.21.250.0/21",
	}

	# Базы данных и пользовати для сайта карты (на базе OpenStreetMap.ru):
	class {"osm_website_postgres_db":
		db_prod_name=>"osm_www_prod",
		db_prod_user=>"osm_www_prod",
		db_prod_passwd=>"XXXXX",
		db_dev_name=>"osm_www_dev",
		db_dev_user=>"osm_www_dev",
		db_dev_passwd=>"XXXXX",
		db_prod_search_name=>"osm_www_search",
		db_prod_search_user=>"osm_www_search",
		db_prod_search_passwd=>"XXXXX",
		db_dev_search_name=>"osm_www_search_dev",
		db_dev_search_user=>"osm_www_search_dev",
		db_dev_search_passwd=>"XXXXX",
	}
	# база данных stapio:
	include "osm_stapio_postgres_db"
}
