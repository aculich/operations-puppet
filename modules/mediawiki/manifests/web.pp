# mediawiki::web

class mediawiki::web ( $workers_limit = undef, $use_sites_available = false ) {
    tag 'mediawiki', 'mw-apache-config'

    include ::mediawiki
    include ::mediawiki::monitoring::webserver
    include ::apache

    $apache_server_limit = 256

    if is_integer($workers_limit) {
        $max_req_workers = min($apache_server_limit, $workers_limit)
    } else {
        $mem_available   = to_bytes($::memorytotal) * 0.7
        $mem_per_worker  = to_bytes('85M')
        $max_req_workers = inline_template('<%= [( @mem_available / @mem_per_worker ).to_i, @apache_server_limit.to_i].min %>')

        # testing min/floor
        $max_req_workers_test = min(floor($mem_available /$mem_per_worker), $apache_Server_limit)
        notice("${max_req_workers} == ${max_req_workers_test}")
    }

    file { '/etc/apache2/apache2.conf':
        content => template('mediawiki/apache/apache2.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        before  => Service['apache2'],
        require => Package['apache2'],
    }

    file { '/etc/apache2/envvars':
        source  => 'puppet:///modules/mediawiki/apache/envvars.appserver',
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        before  => Service['apache2'],
        require => Package['apache2'],
    }

    if ! $use_sites_available {
        file { '/etc/apache2/wikimedia':
            ensure  => directory,
            recurse => true,
            source  => 'puppet:///modules/mediawiki/apache/config',
            before  => Service['apache2'],
        }
    } else {
        include ::mediawiki::web::sites
    }
}
