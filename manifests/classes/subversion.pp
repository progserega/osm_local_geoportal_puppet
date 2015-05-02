class subversion {
	$proxy_host=$proxy::host
	$proxy_port=$proxy::port

	package { 'subversion':
		ensure => latest
	}

	# прописываем прокси:
	file {"/root/.subversion":
		ensure => directory,
	}
	file {"/root/.subversion/servers":
		ensure => file,
		content => template("subversion/servers.erb"),
		replace => yes,
		backup => true,
	}
}
