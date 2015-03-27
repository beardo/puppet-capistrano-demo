namespace :puppet do
  task :prepare do
    on roles (:puppet_prepare) do |host|
      # this makes sure we get the latest version of the packages we want
      # also sometimes you'll get a lot of errors if you're base image is old
      sudo("apt-get", "update")

      # install the packages we need to install things with puppet
      # also don't worry if this isn't the ruby version you want
      # that's installed by puppet and the ruby version required by
      # puppet to run is the system version (1.9 now) and librarin-puppet
      # gems needs to be installed on that version.
      sudo("apt-get", "install -yq puppet git-core ruby1.9 ruby")

      # install librarian puppet gem for managing modules
      sudo("gem", "install librarian-puppet --no-ri --no-rdoc")

      # this is where all of our puppet information goes
      sudo("mkdir", "-p /etc/puppet/files")

      # make sure we have access to this directory
      user = capture('whoami')
      sudo("chown", "-R #{user} /etc/puppet")
    end
  end

  desc "Run intall puppet and apply configuration"
  task :install do
    on roles(:puppet_prepare) do |host|
      # upload our the files you use for puppet configuration
      upload! "puppet/fileserver.conf", "/etc/puppet/", recursive: true
      upload! "puppet/Puppetfile", "/etc/puppet"
      upload! "puppet/Puppetfile.lock", "/etc/puppet"
      upload! "puppet/manifests", "/etc/puppet", recursive: true

      # this is so we can have environment (stages in capistrano) specific
      # files. Like in my staging nginx.conf I block all internet traffic that's
      # not from me.
      stage = fetch(:stage)
      upload! "puppet/files/#{stage}", "/etc/puppet/files", recursive: true

      # upload the files for set for all environments.
      upload! "puppet/files/all", "/etc/puppet/files", recursive: true
      within "/etc/puppet/" do
        # copy everything to the directory specified in fileserver.conf
        execute :cp, "/etc/puppet/files/all/*", "/etc/puppet/files/"
        execute :cp, "/etc/puppet/files/#{stage}/*", "/etc/puppet/files/"
      end
      # install our puppet modules
      within "/etc/puppet/" do
        execute :"librarian-puppet", "install"
      end
      # execute puppet
      sudo("puppet", "apply --verbose /etc/puppet/manifests/init.pp --modulepath=/etc/puppet/modules --fileserverconfig=/etc/puppet/fileserver.conf")
    end
  end
end
