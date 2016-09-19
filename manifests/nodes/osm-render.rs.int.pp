# osm-render.rs.int:

node "osm-render.rs.int" inherits default {
	# Уникальные:
	class {"osm-render-server":
	      db_host => 'db.rs.int',
		  db_user => 'openstreetmap',
		  db_passwd => 'XXXX',
		  db_local_osm_relese_name => 'local_osm_gis',
		  db_local_osm_tmp_name => 'local_osm_gis_tmp',
		  db_corp_name => 'drsk_gis',
		  osm_xml_config => '/etc/mapnik/osm_local.xml',
	}
}
