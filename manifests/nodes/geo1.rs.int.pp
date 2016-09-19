# Сайт карты, утилиты OSM
node "geo1.rs.int" inherits default {

	# Уникальные:
	# Пожары:
	include "osm-fires"

	# osmbot:
	include "osm_osmbot"
	
	# csv2osm:
	include "csv2osm"

	# gpx2csv:
	include "gpx2csv"

	# утилита конвертации osm -> mp ("польский формат"):
	include "osm2mp"

	# утилита разбора почтовых вложений
	include "ripmime"

	# утилита для сборки большой растровой карты
	include "wms2png"
	
	# сборка из исходников osmconvert:
	include "osmconvert"

	# Конвертация данных ДРСК в карту для OsmAnd:
	include "osm_drsk2osmand"

	# Импорт данных загрузки Подстанций:
	class {"osm_load_station_import_data":
		osmbot_user 	=> "osmbot",
		osmbot_passwd 	=> "XXXXXX",
		load_xml_url 	=> "http://1c-base.drsk.ru/DataForMapXML.xml",
	}
	# Импорт данных загрузки ТП
	class {"osm_load_tp_import_data":
		osmbot_user => "osmbot",
		osmbot_passwd => "XXXXXX",
		load_xml_url => "http://1c-base.drsk.ru/DataTPForMapXML.xml",
	}
	# Миграция данных для слоя заявок о нарушениях охранных линий:
	class {"osm_protect_zones_points":
		db_host	=>	"db.rs.int",
		db_name	=>	"osm_www_prod",
		db_user	=>	"osm_www_prod",
		db_passwd	=>	"XXXXXX",
		personal_map_id => "612982436",
		out_file	=> "/opt/osm/openstreetmap.ru/OpenStreetMap.ru_prodaction/www/js/page.map/protect_zones_points.js",
	}
	
	# Сайт ДРСК, на основе OpenStreetMap.ru
	class {"osm_website":
		vhost_prodaction=>"map.prim.drsk.ru",
		vhost_dev=>"beta.map.prim.drsk.ru",
		install_path=>"/opt/osm",
		site_git_src=>"http://git.rs.int/osm/openstreetmap-ru_drsk.git",

		db_prod_name=>"osm_www_prod",
		db_prod_user=>"osm_www_prod",
		db_prod_passwd=>"XXXXXX",
		db_prod_host=>"db.rs.int",
		db_dev_name=>"osm_www_dev",
		db_dev_user=>"osm_www_dev",
		db_dev_passwd=>"XXXXX",
		db_dev_host=>"db.rs.int",

		db_stapio_host=>"db.rs.int",
		db_stapio_name=>"stapio",
		db_stapio_user=>"stapio",
		db_stapio_passwd=>"XXXXX",

		db_prod_search_host=>"db.rs.int",
		db_prod_search_name=>"osm_www_search",
		db_prod_search_user=>"osm_www_search",
		db_prod_search_passwd=>"XXXXX",

		db_dev_search_host=>"db.rs.int",
		db_dev_search_name=>"osm_www_search_dev",
		db_dev_search_user=>"osm_www_search_dev",
		db_dev_search_passwd=>"XXXXX",
	
		db_osm_host=>"db.rs.int",
		db_osm_name=>"drsk_dev_osm",
		db_osm_user=>"osm_read_only",
		db_osm_passwd=>"XXXXX",
	}
	# stapio:
	class {"osm_stapio_and_osmcatalog":
		install_path => "/opt/osm/openstreetmap.ru",
		osmcatalog_git_src => "http://git.rs.int/osm/osmcatalog_drsk.git",
		stapio_git_src => "http://git.rs.int/osm/stapio_drsk.git",
		urlpbf_src => "http://export.osm.prim.drsk.ru/drsk_osm_full_dump_latest.pbf",
		urlpbf_meta_src => "http://export.osm.prim.drsk.ru/drsk_osm_full_dump_latest.pbf.meta",
		out_poidatatree_json_file => "/opt/osm/openstreetmap.ru/OpenStreetMap.ru_prodaction/www/data/poidatatree.json",
		out_poimarker_json_file => "/opt/osm/openstreetmap.ru/OpenStreetMap.ru_prodaction/www/data/poimarker.json",
		out_file_listPerm_json => "/opt/osm/openstreetmap.ru/OpenStreetMap.ru_prodaction/www/data/poidatalistperm.json",
		path_markers => "/opt/osm/openstreetmap.ru/OpenStreetMap.ru_prodaction/www/img/poi_marker/",
		email_admin => "semenov@rsprim.ru",
		email_smtp_server => "mail-rsprim-ru.rs.int",
		db_stapio_host => "db.rs.int",
		db_stapio_name => "stapio",
		db_stapio_user => "stapio",
		db_stapio_passwd => "XXXXXX",
	}

	# Добавление новой линии для обработчика писем:
	class {"osm_local_web_tools":
		install_path				=>	"/opt/osm/local_web_services/",
		vhost_name					=>	"tools.map.prim.drsk.ru",
		list_names_of_lines_path	=>	"/opt/osm/local_utils/osm_import_from_mail/list_names_of_lines.txt",
	}
	# Выгрузка дампов OSM-данных:
	class {"osm_export_generate_dumps":
		osm_api_server_db_host => "db.rs.int",
		osm_api_server_db_name => "drsk_dev_osm",
		osm_api_server_db_user => "osm_full_read_only",
		osm_api_server_db_passwd => "XXXXX",
	}
	# Импорт данных из gpx:
	class {"osm_import_from_mail":
		install_path	=>	"/opt/osm/local_utils/",
		email_import	=>	"osm_import@rsprim.ru",
		email_import_passwd => "XXXXX",
		email_osm_to	=> "semenov@rsprim.ru,dolganin@prim.drsk.ru,nikolaev@rsprim.ru",
		email_csv_to	=> "",
		email_admin		=> "osm_admin@rsprim.ru,nikolaev@rsprim.ru",
	}
	# Бан пользователей:
	class {"osm_ban_users":
		osm_api_server_db_host => "db.rs.int",
		osm_api_server_db_name => "drsk_dev_osm",
		osm_api_server_db_user => "osm_ban_access_only",
		osm_api_server_db_passwd => "XXXXXX",
	}
}
