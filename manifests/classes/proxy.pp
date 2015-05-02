class proxy ($proxy_host="prx.rs.int", $proxy_port="3128") {
	$host=$proxy_host
	$port=$proxy_port

	file { "/etc/wgetrc":
		content => template("proxy/wgetrc.erb"),
		replace => yes
	}
	
	file { "/etc/apt/apt.conf.d/50proxy":
		content => template("proxy/50proxy.erb"),
		replace => yes
	}
}
