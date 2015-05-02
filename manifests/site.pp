import "classes/*.pp"
import "nodes/*.pp"

# Для всех нод по-умолчанию:
node default {
	# В интернет через prx.rs.int:
	class {'proxy':
	      proxy_host => 'prx.rs.int',
		  proxy_port => '3128',
	}
}
