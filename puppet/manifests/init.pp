class install_postgres {
  class { 'postgresql::server':
    listen_addresses => '*',
    postgres_password => 'password',
  }

  # development database
  # password is not a secure password and you should change it
  # also this isn't the most secure way to set your password
  # because you're storing in plaintext and all. See the README
  # for more information on how to do this securely
  postgresql::server::db { 'puppet_capistrano_development':
    user => 'deploy',
    owner => 'deploy',
    password => 'password',
  }

  # packages rails needs to talk to postgresql
  package {'libpq-dev':
    ensure => installed,
    require => Class['postgresql::server'],
  }
  package { 'postgresql-contrib':
    ensure => installed,
    require => Class['postgresql::server'],
  }
}

class create_users {
  group { "deployers":
    ensure => present,
  }

  # I initially wanted the application to be run by a different
  # user than the one that deployed it but the documentation for
  # doing that with capistrano was hard to find/non-existent
  # and my reason for wanting it was vague so I gave up
  # anyway heres a way to make a user
  user { 'puppet_capistrano' :
    ensure => present,
    shell => '/bin/bash',
    home => '/home/puppet_capistrano/',
    managehome => true,
  }

  # this is the user we use to deploy with capistrano
  # it doesn't need sudo access
  user { 'deploy' :
    ensure => present,
    shell => '/bin/bash',
    home => '/home/deploy/',
    groups => ["deployers"],
    managehome => true,
    require => Group["deployers"],
  }

  # These are so we can run `cap deploy` without the password
  # Also in this set up we don't have a password because I haven't
  # worked out the heira stuff yet.
  # This requires that you put the PUBLIC key in
  # puppet/files/stage/ssh_authorized_keys
  # the public key is in ~/.ssh/key_name.pub
  # use the first two columns of that file
  file { "/home/deploy/.ssh/":
    owner => "deploy",
    group => "deployers",
    ensure => "directory",
    mode => 700,
    require => User["deploy"],
  }
  file { "/home/deploy/.ssh/authorized_keys":
    owner => "deploy",
    group => "deployers",
    source => 'puppet:///files/ssh_authorized_keys',
    ensure => present,
    require => File['/home/deploy/.ssh/'],
    mode => 600,
  }

  file { "/home/puppet_capistrano/.ssh/":
    owner => "puppet_capistrano",
    ensure => "directory",
    mode => 700,
    require => User["puppet_capistrano"],
  }
  file { "/home/puppet_capistrano/.ssh/authorized_keys":
    owner => "puppet_capistrano",
    #group => "puppet_capistrano",
    source => 'puppet:///files/ssh_authorized_keys',
    ensure => present,
    require => File["/home/puppet_capistrano/.ssh/"],
    mode => 600,
  }
}

# These are just convience packages I like to have on machines I use
# add or remove from here as you will none of this is necessary.
class utils {
  package { "htop":
    ensure => installed
  }
  package { "tmux":
    ensure => installed
  }
  package { "vim":
    ensure => installed
  }
}

# this is for utility configurations
# again this is a nice to have and not a necessity
class util_config_files {
  file { '/home/deploy/.vimrc':
      source => 'puppet:///files/vimrc',
      mode => '644',
      owner => 'deploy',
      group => 'deployers',
      require => [Class['create_users'], Group["deployers"]],
  }
}

# nginx configuration and packages
class install_nginx {
  package { "libcurl4-openssl-dev":
    ensure => latest
  }

  class { 'nginx':
    package_source => 'passenger',
    package_name => "nginx-extras",
    http_cfg_append => {
      passenger_root => '/usr/lib/ruby/vendor_ruby/phusion_passenger/locations.ini',
      passenger_ruby => '/usr/bin/ruby2.1',
    },
  }

  # You can specify site configuration in puppet
  # I'm copying out manually created config files
  # but I have no particular reason for that
  # do whatever you prefer
  nginx::resource::vhost { 'www.example.com':
    www_root => '/var/www/www.example.com',
    vhost_cfg_append => {
      'passenger_enabled' => 'on',
      'passenger_ruby' => '/usr/bin/ruby',
    }
  }

  # This is where capistrano will put our site
  file { "/var/www/":
    ensure => "directory",
  }
  file { "/var/www/puppet-capistrano":
    ensure => "directory",
    owner => "deploy",
    group => "deployers",
    mode => "664",
    require => File['/var/www'],
  }

  # This is how I'm doing file based nginx configuration for our site
  file { "/etc/nginx/sites-available/puppet-capistrano":
    source => 'puppet:///files/puppet-capistrano-nginx',
    mode => '664',
    group => 'deployers',
    owner => 'deploy',
  }
  file { "/etc/nginx/sites-enabled/puppet-capistrano":
    ensure => 'link',
    target => '/etc/nginx/sites-available/puppet-capistrano',
    require => File['/etc/nginx/sites-available/puppet-capistrano'],
  }
}

# Install our prefered version of ruby so we're not stuck on the system version
class install_ruby {
  include apt
  apt::ppa{'ppa:brightbox/ruby-ng-experimental':}
  class{'ruby':
    version         => '2.1.5',
    switch          => true,
    latest_release  => true,
    require         => Apt::Ppa['ppa:brightbox/ruby-ng-experimental'],
  }

  package {'bundler':
    ensure => installed,
    require => Class['ruby'],
  }

  package {'ruby2.1-dev':
    ensure => installed,
    require => Package['bundler'],
  }
}

# The declarations above only declare nothing is actually installed until these
# declarations are added.
# The order is more determined by the require statments in the classes above
# than the order of these declarations.
class { 'install_ruby': }
class { 'install_postgres': }
class { 'install_nginx': }
class { 'redis::install': }
class { 'utils': }
class { 'util_config_files': }
class { 'create_users': }
