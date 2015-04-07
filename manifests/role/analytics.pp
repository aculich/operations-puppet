# analytics servers (RT-1985)

@monitoring::group { 'analytics_eqiad': description => 'analytics servers in eqiad' }

# == Class role::analytics
# Base class for all analytics nodes.
# All analytics nodes should include this.
class role::analytics {
    system::role { 'role::analytics': description => 'analytics server' }

    if !defined(Package['openjdk-7-jdk']) {
        package { 'openjdk-7-jdk':
            ensure => 'installed',
        }
    }
}

# == Class role::analytics::clients
# Includes common client classes for
# working with hadoop and other analytics services.
class role::analytics::clients {
    include role::analytics

    # Include Hadoop ecosystem client classes.
    include role::analytics::hadoop::client,
        role::analytics::hive::client,
        role::analytics::oozie::client,
        role::analytics::pig,
        role::analytics::sqoop,
        role::analytics::mahout,
        role::analytics::spark

    # This packages conflicts with the hadoop-fuse-dfs
    # script in that two libjvm.so files get added
    # to LD_LIBRARY_PATH.  We dont't need this
    # package anyway, so ensure it is absent.
    package { 'icedtea-7-jre-jamvm':
        ensure => 'absent'
    }
    # Mount HDFS via Fuse on Analytics client nodes.
    # This will mount HDFS at /mnt/hdfs read only.
    class { 'cdh::hadoop::mount':
        # Make sure this package is removed before
        # cdh::hadoop::mount evaluates.
        require => Package['icedtea-7-jre-jamvm'],
    }

    # jq is very useful, install it.
    if !defined(Package['jq']) {
        package { 'jq':
            ensure => 'installed',
        }
    }

    # ipython-notebook is very useful, install it.
    if !defined(Package['ipython-notebook']) {
        package { 'ipython-notebook':
            ensure => 'installed',
        }
    }

    # include maven to build jars for Hadoop.
    include ::maven

}

# == Class role::analytics::hadoop::monitor_disks
# Installs monitoring plugins for disks
#
class role::analytics::monitor_disks {
    if hiera('has_ganglia', true) {
        ganglia::plugin::python { 'diskstat': }
    }

}

# == Class role::analytics::password::research
# Install the researcher MySQL username and password
# into a file and make it readable by analytics-privatedata-users
#
class role::analytics::password::research {
    include passwords::mysql::research

    mysql::config::client { 'analytics-research':
        user  => $::passwords::mysql::research::user,
        pass  => $::passwords::mysql::research::pass,
        group => 'analytics-privatedata-users',
        mode  => '0440',
    }
}


# == Class role::analytics::rsyncd
# Set up an rsync module at certain paths to
# allow read only rsync access to analytics generated data.
#
class role::analytics::rsyncd {

    $hosts_allow = [
        'stat1001.eqiad.wmnet',
        'stat1002.eqiad.wmnet',
        'stat1003.eqiad.wmnet',
        'analytics1027.eqiad.wmnet',
        'dataset1001.wikimedia.org',
    ]

    # This will allow $hosts_allow to host public data files
    # generated by the analytics cluster.
    # Note that this requires that cdh::hadoop::mount
    # be present and mounted at /mnt/hdfs
    rsync::server::module { 'hdfs-archive':
        path        => "${::cdh::hadoop::mount::mount_point}/wmf/data/archive",
        read_only   => 'yes',
        list        => 'yes',
        hosts_allow => $hosts_allow,
        require     => Class['cdh::hadoop::mount'],
    }
}
