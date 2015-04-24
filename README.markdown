## Deploying Rails projects with Puppet and Capistrano

See [my blog post](http://danielsullivan.me/rails-puppet-capistrano-demo/)
for an explanation and the reasoning behind why I did this the way I did it.

This is an example project to show how to configure a linux server for rails
(using postgres, nginx, and passenger) and deploy it in one command.

# Disclaimers!

This is a work in progress so there are some limitations.

1. This isn't the most secure set up yet.
   there currently isn't any way to set
   `SECRET_KEY_BASE` in production
   and all of the passwords are in plaintext in files
   that are checked into git.
   This can be bad.
   I know what I need to do to fix this but again haven't
   had the time to do it yet so use at your own risk.
2. This is a single server setup.
   No way to do seperate db and app servers or anything fancy like that.
   I'd like to have that option
   (or probably seperate example project)
   eventually but I don't really need it right now
   and I haven't gotten around to it yet.

# Using the example project
To run the example you need to have an ssh public key from `~/.ssh/some_key.pub`
to copy to `puppet-capistrano-demo/puppet/files/all/ssh_authorized_keys`.
If you don't have any public keys and don't know how to generate one
[github has a nice tutorial](https://help.github.com/articles/generating-ssh-keys/).
I'm also assuming you alread have [vagrant](http://vagrantup.com/)
and [virtual box](https://www.virtualbox.org/wiki/Downloads) installed.

Then all you have to do are run the following commands:

    git clone https://github.com/beardo/puppet-capistrano-demo
    cp ~/.ssh/your_key.pub puppet-capistrano/puppet/files/all/ssh_authorized_keys
    cd puppet-capistrano-demo/puppet
    vagrant up
    cd ..
    # the password it's about to ask you for is vagrant
    cap vagrant cold_start

Then go to [192.168.123.21/hello_world](http://192.168.123.21/hello_world)
and if you see something like this:
![webpage with a Hello world! header and it worked body](https://raw.githubusercontent.com/beardo/puppet-capistrano-demo/master/example_images/hello-world.png)

Then it worked!
If not I'm not sure what went wrong.
Maybe create an issue with the last few lines of the
`/var/log/nginx/error.log`
file on your vagrant machine and I'll try and help.

To get that file run:

    vagrant ssh
    sudo tail /var/log/nginx/error.log

# Adapting the project for your own use

## Puppet set up
Pretty much everything in the `puppet/` directory is required for this to work.
You don't really need my vimrc file because it's mostly there as an example.
If you remove it remove the part in `puppet/manifests/init.pp`
that refers to it or you'll get errors in your puppet install.

Because I haven't figured out the hiera and secrets stuff yet
the `deploy` user created by puppet
and used by `capistrano` doesn't have a password.
*Ok* it also doesn't have a password because
I didn't like having to type one in my testing.
Regardless you have to either add a password in `puppet/manifests/init.pp`
or change `puppet/files/all/ssh_authorized_keys` to add a public key like is
described above.

Everything in `puppet/files/all` is uploaded to your server
(specified later)
along with whatever is is `puppet/files/capistrano_stage/`.
So if you're deploying to vagrant then everything in `puppet/files/vagrant` is sent
or if you're deploying to staging then everything in `puppet/files/staging` will
be sent and so on.
The reason I set it up this way is so that I can have different versions of files on
different stages.
Mostly I use this for my nginx configuration.
In the vagrant stage there isn't a hostname but in production there is
and in staging I block all traffic that isn't from me
which I obviously don't want to do in production.

The `puppet/fileserver.conf` file is necessary for using masterless puppet.
Basically what it does is tell masterless puppet to look for source files
in the root of `/etc/puppet/files/`
which is where capistrano uploads them to.
You can change this and I'm thinking I might change it to `/tmp/puppet`
or something
because in retrospect I don't really see a reason to keep them persisted.
In "normal" non masterless puppet these files would probably be somewhere on
the puppet master and copied out to the nodes from there but again that's
overkill for my stuff.

`puppet/Puppetfile` and `puppet/Puppetfile.lock` are like `Gemfile`
and `Gemfile.lock` but for puppet modules instead of ruby gems.
This simplifies installation quite a bit.
For more information on how to use these see
[librarian-puppet on github.](https://github.com/rodjek/librarian-puppet)

`manifests/init.pp` is meat of our puppet install.
It installs all of the packages we need and sets up
all the users and files for us.
Honestly it should probably be broken up into smaller files
for modularity
and simplifying any future moves to needing multiple servers.
But I'm still trying to figure this puppet thing out
and I don't know the best way to do that right now
so for now it's one monolithic file.
Currently it installs and configures:

* postgres
  * our application's database
* nginx (with passenger)
* redis (which we don't use but I left in there because evenutally)
* a specific ruby version for our application (2.1.5)
  * also bundler
* our deploy user
* some utility packages (htop and vim)

I tried to include comments with more information
and my reasoning throughout the file.

## Capistrano setup

To run capistrano for this project you need `Capfile`, `config/deploy.rb`,
at least `config/deploy/vagrant.rb`, `lib/capistrano/tasks/puppet_install.rake`,
and `lib/capistrano/tasks/cold_start.rake`.

`Capfile` specifies what all capistrano modules you're using and where your
capistrano tasks are located.

`config/deploy.rb` is your where you do your global configuration for capistrano.
You'll probably want to change this file
unless you really only want to run versions of this demo.
To get started all you really need to change are the following two lines
(it looks like more because I'm long winded):

    # change this line to whatever your project name is
    # you also should also update puppet/manifests/init.pp
    # and puppet/files/vagrant/puppet-capistrano-nginx
    # because they both refer to the location set by this variable
    set :application, 'puppet-capistrano-demo'
    # update this with a link to your git repo or you'll just
    # keep getting versions of my demo project
    set :repo_url, 'git@github.com:beardo/puppet-capistrano-demo'

The files in the `config/deploy/` directory set up what capistrano calls stages.
In these files we define roles
and give the user and address of those roles.
The default (and required) roles for capistrano are: app, web, and db.
Since I only need one server these are all the same for me.
I also defined a seperate role called `puppet_prepare`.
This role is only used for setting up our sever to use puppet.
and actually running puppet on our file.
This role has a diffrent user than the others
because this role needs to run before the `deploy` user exists
and this role needs to have sudo which deploy does not need.
The `no_release: true` makes sure that this role is
ignorned in normal `cap stage deploy` commands because it isn't needed there
and so it can use different authentication methods than the `deploy` user.

The files `lib/capistrano/tasks/puppet_install.rake`
and `lib/capistrano/tasks/cold_start.rake`
define three capistrano tasks:

* `puppet:prepare` (e.g. `cap vagrant puppet:prepare`)
This task sets things up so you can run puppet on your stage.
It does an `apt-get update`, installs ruby, puppet,
and the librarian-puppet gem.
* `puppet:install` (e.g. `cap vagrant puppet:install`)
This command actually runs puppet on your stage.
It uploads everything you need to run puppet
and then runs puppet.
Afterwards your server is how you defined it to be.
* `cold_start` (e.g. `cap vagrant cold_start`)
This task is basically just a wrapper task.
It runs `puppet:prepare` then `puppet:install`
and finally `deploy`.
Using this one command you can go from a
fresh install of ubuntu 14.04
to having everything installed
and set up for
your app in one command.

If you change things in your puppet manifest
or files you need uploaded you can
run `cap stage puppet:install`
and puppet will update your stage.

If only update your app code and want to deploy those changes
without running puppet again
you can run `cap stage deploy` and capistrano will only
update your application.
