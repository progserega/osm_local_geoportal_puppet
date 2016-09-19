class osm-render-server (
	$db_host="db.rs.int", 
	$db_port="5432", 
	$db_user="openstreetmap", 
	$db_passwd="openstreetmap", 
	$db_corp_name="drsk_gis", 
	$db_local_osm_relese_name="local_osm_gis", 
	$db_local_osm_tmp_name="local_osm_gis_tmp", 
	$osm_xml_config="/etc/mapnik/osm_local.xml",
	$email_admin="semenov@rsprim.ru",
	$email_from="osm_import@rsprim.ru",
	$email_server="mail-rsprim-ru.rs.int",
	$tile_render_domain="tile.osm.prim.drsk.ru",
	$wms_render_domain="wms.osm.prim.drsk.ru",
	$export_server_domain="export.osm.prim.drsk.ru",
	# путь к модулям, зависит от версии установленного мапника, при неверном указании - мапник не грузит shape-файлы границ, узнать можно с помощью команды: 'mapnik-config --input-plugins'
	$mapnik_plugins_dir="/usr/lib/mapnik/2.0/input",
	$postgres_version="9.1"
	) {

	# ====================== Установка mod_tile ===================
	if !defined(package ['osm2pgsql'])
	{
		package { 'osm2pgsql':
			ensure => installed
		}
	}
	if !defined(package ['python-mapnik2'])
	{
		package { 'python-mapnik2':
			ensure => installed
		}
	}
	if !defined(package ['mapnik-utils'])
	{
		package { 'mapnik-utils':
			ensure => installed
		}
	}
	package { 'tilecache':
		ensure => installed
	}
	if !defined(package ['build-essential'])
	{
		package { 'build-essential':
			ensure => installed
		}
	}
	if !defined(package ['fakeroot'])
	{
		package { 'fakeroot':
			ensure => installed
		}
	}
	if !defined(package ['debhelper'])
	{
		package { 'debhelper':
			ensure => installed
		}
	}
	if !defined(package ['apache2-mpm-prefork'])
	{
		package { 'apache2-mpm-prefork':
			ensure => installed
		}
	}
	if !defined(package ['libapache2-mod-python'])
	{
		package { 'libapache2-mod-python':
			ensure => installed
		}
	}
	if !defined(package ['apache2-prefork-dev'])
	{
		package { 'apache2-prefork-dev':
			ensure => installed
		}
	}
	package { 'libmapnik2-dev':
		ensure => installed
	}
	if !defined(package ['autoconf'])
	{
		package { 'autoconf':
			ensure => installed
		}
	}
	if !defined(package ['automake'])
	{
		package { 'automake':
			ensure => installed
		}
	}
	if !defined(package ['m4'])
	{
		package { 'm4':
			ensure => installed
		}
	}
	package { 'libtool':
		ensure => installed
	}
	package { 'unifont':
		ensure => installed
	}
	package { 'ttf-unifont':
		ensure => installed
	}
	if !defined(package ["postgresql-client-${postgres_version}"])
	{
		package { "postgresql-client-${postgres_version}":
			ensure => installed
		}
	}
	package { 'sendemail':
		ensure => installed
	}
	# Для получения файлов инициализации postgis-базы:
	package { "postgresql-contrib-${postgres_version}":
		ensure => installed
	}
	if !defined(package ['postgis'])
	{
		package { 'postgis':
			ensure => installed
		}
	}
	if !defined(package ['osmosis'])
	{
		package { 'osmosis':
			ensure => installed
		}
	}
	if !defined(package ["postgresql-${postgres_version}-postgis"])
	{
		package { "postgresql-${postgres_version}-postgis":
			ensure => installed
		}
	}
	# Демон нам не нужен - отключаем:
	#service {"postgresql":
	#	ensure => stopped,
	#	enable => false,
	#	require => package['postgresql-contrib-9.1'],
	#	status => 'test 0 != `ps aux|grep postgres|grep -v grep|wc -l`',
	#}

	file { "/opt/osm":
		ensure => directory,
	}
	# mod_tile:
	include git
	exec { "git_mod_tile":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone https://github.com/openstreetmap/mod_tile/",
		cwd => "/opt/osm",
		creates => "/opt/osm/mod_tile",
		require => package['git']
	}
	# Патчим исходники для успешной сборки:
	file { "/opt/osm/mod_tile/mod_tile_build.patch":
		ensure => file,
		source => "puppet:///modules/osm-render-server/mod_tile_build.patch",
		replace => yes,
		backup => false,
		require => file['/opt/osm'],
	}
	exec { "patch mod_tile":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "patch -p1 < /opt/osm/mod_tile/mod_tile_build.patch",
		cwd => "/opt/osm/mod_tile",
		require => file['/opt/osm/mod_tile/mod_tile_build.patch'],
		onlyif => "fgrep apache2-dev /opt/osm/mod_tile/debian/control",
	}

	exec { "build_mod_tile":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "dpkg-buildpackage -B -rfakeroot -us -uc",
		cwd => "/opt/osm/mod_tile",
		creates => "/opt/osm/mod_tile/debian/renderd/usr/bin/renderd",
		require => exec['patch mod_tile'],
		# Отключаем таймаут пуппета (300 секунд) для этого ресурса:
		timeout => 0,
	}
	# Переименовываем:
	exec { "rename renderd debs":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "mv libapache2-mod-tile_*.deb libapache2-mod-tile.deb; mv renderd_*.deb renderd.deb",
		cwd => "/opt/osm/",
		creates => "/opt/osm/renderd.deb",
		require => exec['build_mod_tile'],
	}
	# Ставим собранные пакеты:
	package { 'renderd':
		ensure => installed,
		provider => dpkg,
		source => "/opt/osm/renderd.deb",
		require => exec['rename renderd debs'],
	}
	package { 'libapache2-mod-tile':
		ensure => installed,
		provider => dpkg,
		source => "/opt/osm/libapache2-mod-tile.deb",
		require => package['renderd'],
	}

	# Правим имя сайта:
	file_line { 'site name':
		ensure  => present,
		path  => '/etc/apache2/sites-available/tileserver_site.conf',
		line  => '    ServerName tile.osm-render.rs.int',
		match => '^ *ServerName',
		require => package['libapache2-mod-tile']
	}
	file_line { 'site vhost':
		ensure  => present,
		path  => '/etc/apache2/sites-available/tileserver_site.conf',
		line  => "<VirtualHost ${tile_render_domain}:80>",
		match => '^ *<VirtualHost ',
		require => package['libapache2-mod-tile']
	}
	file_line { 'site alias':
		ensure  => present,
		path  => '/etc/apache2/sites-available/tileserver_site.conf',
		line  => "    ServerAlias ${tile_render_domain} a.tile.openstreetmap.org b.tile.openstreetmap.org c.tile.openstreetmap.org osm-render.rs.int",
		match => '^ *ServerAlias',
		require => file_line['site name'],
	}
	exec { "restart_apache2":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "service apache2 reload",
		onlyif => "test 600 -gt $(expr `date +%s` - `stat -c '%Z' /etc/apache2/sites-available/`)",
		require => file_line['site alias'],
	}

	include subversion
	# Берём mapnik и скрипты из него из svn:
	exec { "mapnik tools svn":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "svn co http://svn.openstreetmap.org/applications/rendering/mapnik/",
		cwd => "/opt/osm/",
		creates => "/opt/osm/mapnik",
		require => package['subversion']
	}
	# Скачиваем границы:
	file { "/opt/osm/world_boundaries":
		ensure => directory,
		require => exec['mapnik tools svn'],
	}
	exec { "get world_boundaries":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "/opt/osm/mapnik/get-coastlines.sh",
		cwd => "/opt/osm/world_boundaries",
		creates => "/opt/osm/world_boundaries/world_boundaries-spherical.tgz",
		require => file['/opt/osm/world_boundaries'],
		# Отключаем таймаут пуппета (300 секунд) для этого ресурса:
		timeout => 0,
	}
	file { "/etc/mapnik":
		ensure => directory,
		require => exec['get world_boundaries'],
	}
	# Правим ошибку отсутствующих шрифтов:
	file { "/usr/share/fonts/truetype/ttf-dejavu/unifont.ttf":
		ensure => link,
		target => "/usr/share/fonts/truetype/unifont/unifont.ttf",
		require => package['ttf-unifont'],
	}

	file { "/opt/osm/mapnik/create_osm_xml_config.sh":
		ensure => file,
		content => template("osm-render-server/create_osm_xml_config.sh.erb"),
		replace => yes,
		mode => 0750,
		backup => true,
		require => [ file['/etc/mapnik'], exec [ "mapnik tools svn"] ],
	}
	exec { "create osm_local.xml":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "/opt/osm/mapnik/create_osm_xml_config.sh",
		cwd => "/opt/osm/mapnik",
		creates => "/etc/mapnik/osm_local.xml",
		require => [ file['/opt/osm/mapnik/create_osm_xml_config.sh'], exec ['get world_boundaries'], file ['/usr/share/fonts/truetype/ttf-dejavu/unifont.ttf'] ],
	}

	# Скрипты по загрузке OSM-России в postgis-базу:
	file { "/opt/osm/scripts":
		ensure => directory,
	}
	# Файл доступа к postgress без пароля:
	file { "/root/.pgpass":
		ensure => file,
		content => template("osm-render-server/pgpass.erb"),
		replace => yes,
		mode => 0600,
		owner => root,
		backup => true,
		require => package ['osm2pgsql'],
	}
	# Скрипт обновления local OSM postgis-базы из полного дампа России:
	file { "/opt/osm/scripts/full_update_local_osm_gis_from_gislab_dump.sh":
		ensure => file,
		content => template("osm-render-server/full_update_local_osm_gis_from_TMP_BASE.sh.erb"),
		replace => yes,
		mode => 0750,
		owner => root,
		group => root,
		backup => false,
		require => file ['/root/.pgpass'],
	}
	# Скрипт обновления local OSM postgis-базы из списка регионов:
	file { "/opt/osm/scripts/full_update_local_osm_gis_east_russia.sh":
		ensure => file,
		content => template("osm-render-server/full_update_local_osm_gis_east_russia.sh.erb"),
		replace => yes,
		mode => 0750,
		owner => root,
		group => root,
		backup => false,
		require => file ['/root/.pgpass'],
	}

	# Скрипт полного обновления corp OSM postgis-базы из полного дампа:
	file { "/opt/osm/scripts/corp_osm2corp_gis_from_full_remote_dump.sh":
		ensure => file,
		content => template("osm-render-server/corp_osm2corp_gis_from_full_remote_dump.sh.erb"),
		replace => yes,
		mode => 0750,
		owner => root,
		group => root,
		backup => false,
		require => file ['/root/.pgpass'],
	}
	file { "/etc/renderd.conf":
		ensure => file,
		content => template("osm-render-server/renderd.conf.erb"),
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => true,
		require => package ['renderd'],
	}
	service { "renderd":
		ensure => "running",
		#subscribe => file [ '/etc/renderd.conf' ],
		#restart => true,
		status => 'test 0 != `/bin/ps aux|/bin/grep renderd|/bin/grep -v grep|/usr/bin/wc -l`',
		#status => 'test 0 == 0 ',
		#status => '/bin/true',
	}
	service { "apache2":
		ensure => "running",
		subscribe => file [ '/etc/renderd.conf' ],
		restart => true,
	}
	# Добавляем регулярные обновления копии OSM-базы в cron:
	file { "/etc/cron.d/local_osm_import":
		ensure => file,
		source => "puppet:///modules/osm-render-server/local_osm_import.cron",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
		require => package ['renderd'],
	}
	
	# Загружаем дампы из OSM:
	exec { "update local gis":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "/opt/osm/scripts/full_update_local_osm_gis_east_russia.sh",
		cwd => "/opt/osm",
		creates => "/var/lib/mod_tile/planet-import-complete",
		require => file['/opt/osm/scripts/full_update_local_osm_gis_east_russia.sh'],
		# Отключаем таймаут пуппета (300 секунд) для этого ресурса:
		timeout => 0,
	}
	# Создаём и проверяем конфиг для рендеринга OSM:
	exec { "create_osm_xml_config":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "/opt/osm/mapnik/create_osm_xml_config.sh",
		cwd => "/opt/osm",
		creates => "/etc/mapnik/osm_local.xml",
		require => exec['update local gis']
	}
	# Загружаем дамп корпоративной базы в корпоративную gis-базу:
	exec { "import corp OSM db in corp gis":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "/opt/osm/scripts/corp_osm2corp_gis_from_full_remote_dump.sh",
		cwd => "/opt/osm",
		creates => "/var/log/osm/corp_osm2corp_gis_from_full_remote_dump.log",
		require => [ file['/opt/osm/scripts/corp_osm2corp_gis_from_full_remote_dump.sh'], exec ['git_drsk_osm_map_styles'] ],
		# Отключаем таймаут пуппета (300 секунд) для этого ресурса:
		timeout => 0,
	}

	#================ Установка tilecache  ================

	exec { "git_kothic":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone https://github.com/kothic/kothic",
		cwd => "/opt/osm",
		creates => "/opt/osm/kothic",
		require => package['git']
	}
	# Добавляем параметры авторизации:
	file { "/opt/osm/kothic/kothic_auth.patch":
		ensure => file,
		source => "puppet:///modules/osm-render-server/kothic_auth.patch",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
		require => exec ['git_kothic'],
	}
	exec { "patch auth kothic":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "patch -p1 < /opt/osm/kothic/kothic_auth.patch",
		cwd => "/opt/osm/kothic",
		require => file['/opt/osm/kothic/kothic_auth.patch'],
		onlyif => "test 0 -eq \"$(fgrep db_passwd /opt/osm/kothic/src/komap.conf|wc -l)\"",
	}
	# Правим ошибку масштаба с плавающей точкой (на генерируемые  котиком xml mapnik2 ругается):
	file { "/opt/osm/kothic/kothic_size.patch":
		ensure => file,
		source => "puppet:///modules/osm-render-server/kothic_size.patch",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
		require => exec ['git_kothic'],
	}
	exec { "patch size kothic":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "patch -p1 < /opt/osm/kothic/kothic_size.patch",
		cwd => "/opt/osm/kothic",
		require => file['/opt/osm/kothic/kothic_size.patch'],
		onlyif => "test 0 -eq \"$(fgrep 'str(int(float(size.split' /opt/osm/kothic/src/libkomapnik.py|wc -l)\"",
	}
	# Правим ошибку параметра 'dash' для рисования прерывистых линий. На самом деле это какой-то хак, как сделать правильно - я не разбирался особо:
	file { "/opt/osm/kothic/kothic_dash.patch":
		ensure => file,
		source => "puppet:///modules/osm-render-server/kothic_dash.patch",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
		require => exec ['git_kothic'],
	}
	exec { "patch dash kothic":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "patch -p1 < /opt/osm/kothic/kothic_dash.patch",
		cwd => "/opt/osm/kothic",
		require => file['/opt/osm/kothic/kothic_dash.patch'],
		onlyif => "test 0 -eq \"$(fgrep 'if len(dashes) == 2' /opt/osm/kothic/src/libkomapnik.py|wc -l)\"",
	}

	# Правим конфиг kothic:
	file { "/opt/osm/kothic/src/komap.conf":
		ensure => file,
		content => template("osm-render-server/komap.conf.erb"),
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => true,
		require => [ exec ['patch auth kothic'], exec ['patch dash kothic'], exec ['patch size kothic'] ]
	}

	# =========== частный наш случай сборки стилей и конфига tilecache =============
	# Генерируем конфиг tilecache из наших стилей ():
	exec { "git_drsk_osm_map_styles":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "git clone http://git.rs.int/osm/drsk_osm_map_styles.git",
		cwd => "/opt/osm",
		creates => "/opt/osm/drsk_osm_map_styles",
		require => file['/opt/osm/kothic/src/komap.conf']
	}
	exec { "create tilecache.conf":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "/opt/osm/drsk_osm_map_styles/drsk_mapcss_styles/convert_mapcss2mapnik2",
		cwd => "/opt/osm/drsk_osm_map_styles/drsk_mapcss_styles/",
		creates => "/etc/tilecache.d",
		require => exec['git_drsk_osm_map_styles'],
	}
	# Особый конфиг для рендеринга данных из OSM-ной локальной базы:
	file { "/opt/osm/drsk_osm_map_styles/osm_mapcss_styles/komap.conf":
		ensure => file,
		content => template("osm-render-server/komap.conf.local_osm.erb"),
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => true,
		require => exec ['create tilecache.conf'],
	}
	exec { "create admin levels configs":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "/opt/osm/drsk_osm_map_styles/osm_mapcss_styles/generate_admin_level_mapcss_from_admin_names && /opt/osm/drsk_osm_map_styles/osm_mapcss_styles/convert_mapcss2mapnik2",
		cwd => "/opt/osm/drsk_osm_map_styles/osm_mapcss_styles",
		creates => "/opt/osm/drsk_osm_map_styles/osm_mapcss_styles/admin_levels.mapcss",
		require => file['/opt/osm/drsk_osm_map_styles/osm_mapcss_styles/komap.conf'],
	}
	#===============================================================================
	# Конфиг апача для tilecache:
	file { "/etc/apache2/sites-available/${wms_render_domain}.conf":
		ensure => file,
		content => template("osm-render-server/wms-apache.conf.erb"),
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
		#require => exec ['create tilecache.conf'],
	}
	file { "/etc/apache2/conf.d/NameVirtualHost":
		ensure => file,
		content => "NameVirtualHost $ipaddress:80\n",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
		require => package ['apache2-mpm-prefork'],
	}
	exec { "enable wms-site":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "a2ensite ${wms_render_domain}.conf && service apache2 reload",
		creates => "/etc/apache2/sites-enabled/${wms_render_domain}.conf",
		require => file["/etc/apache2/sites-available/${wms_render_domain}.conf"],
	}
	file { "/var/www/tilecache/":
		ensure => directory,
	}
	file { "/var/www/tilecache/tilecache.cgi":
		ensure => link,
		target => "/usr/lib/cgi-bin/tilecache.cgi",
		require => file ['/var/www/tilecache/'],
	}
	# Патчим tilecache для поддержки mapnik2:
	file { "/tmp/tilecache_mapnik2.patch":
		ensure => file,
		source => "puppet:///modules/osm-render-server/tilecache_mapnik2.patch",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
		require => package ['tilecache'],
	}
	exec { "patch tilecache":
		path   => "/usr/bin:/usr/sbin:/bin",
		command => "patch -p1 < /tmp/tilecache_mapnik2.patch",
		cwd => "/usr/share/pyshared/TileCache",
		require => file['/tmp/tilecache_mapnik2.patch'],
		onlyif => "test 0 -eq \"$(fgrep mapnik2 /usr/share/pyshared/TileCache/Layers/Mapnik.py|wc -l)\"",
	}
	# Прописываем наши хосты в /etc/hosts, чтобы работали виртуальные хосты apache2:
	host {'vhost to hosts':
		ensure => present,
		comment  => "for tilecache and mod_tile apache2 vhosts",
		ip => $ipaddress,
		name => $fqdn,
		host_aliases => ["wms.osm.prim.drsk.ru",
			"wms.map.prim.drsk.ru",
			"tile.osm.prim.drsk.ru",
			"a.tile.openstreetmap.org",
			"b.tile.openstreetmap.org",
			"c.tile.openstreetmap.org",
			],
	}
	# Копируем тестовую страничку для тестирования нашего сервера:
	file { "/var/www/index.html":
		ensure => file,
		content => template("osm-render-server/test_render_view_openlayer_web.html.erb"),
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}

	# Ставим необходимые скрипты:
	file { "/opt/osm/scripts/tilecache_delete_all_layers_cache.sh":
		ensure => file,
		source => "puppet:///modules/osm-render-server/tilecache_delete_all_layers_cache.sh",
		replace => yes,
		mode => 0755,
		owner => root,
		group => root,
		backup => false,
	}
	# Задание по очистке кэшей каждый день:
	file { "/etc/cron.d/osm_clear_tilecache_cache":
		ensure => file,
		content => "# Полная очистка тайлов tilecache:
50 3 * * * root /opt/osm/scripts/tilecache_delete_all_layers_cache.sh
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}

	file { "/opt/osm/scripts/update_drsk_gis_from_remoute_diff.sh":
		ensure => file,
		content => template("osm-render-server/update_drsk_gis_from_remoute_diff.sh.erb"),
		replace => yes,
		mode => 0755,
		owner => root,
		group => root,
		backup => false,
	}
	file { "/opt/osm/scripts/expire-tilecache-disk.pl":
		ensure => file,
		source => "puppet:///modules/osm-render-server/expire-tilecache-disk.pl",
		replace => yes,
		mode => 0755,
		owner => root,
		group => root,
		backup => false,
	}
	# Задание по миграции данных из OSM-базы в postgis-базу:
	file { "/etc/cron.d/osm_update_drsk_gis":
		ensure => file,
		content => "# обновление drsk_gis с удалённого сервера:
25 * * * * root [ -z \"`ps aux|grep update_drsk_gis_from_remoute_diff.sh|grep -v grep`\" ] && /opt/osm/scripts/update_drsk_gis_from_remoute_diff.sh
55 * * * * root [ -z \"`ps aux|grep update_drsk_gis_from_remoute_diff.sh|grep -v grep`\" ] && /opt/osm/scripts/update_drsk_gis_from_remoute_diff.sh
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}
	# Задание по миграции данных из OSM-базы в postgis-базу из полного дампа (для исключения сбоев):
	file { "/etc/cron.d/osm_update_drsk_gis_from_ful_dump":
		ensure => file,
		content => "# обновление drsk_gis с удалённого сервера:
30 23 * * * root [ -z \"`ps aux|grep update_drsk_gis_from_remoute_diff.sh|grep -v grep`\" ] && /opt/osm/scripts/corp_osm2corp_gis_from_full_remote_dump.sh
",
		replace => yes,
		mode => 0644,
		owner => root,
		group => root,
		backup => false,
	}

}
