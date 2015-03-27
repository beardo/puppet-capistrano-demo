# Simple Role Syntax
# ==================
# Supports bulk-adding hosts to roles, the primary server in each group
# is considered to be the first unless any hosts have the primary
# property set.  Don't declare `role :all`, it's a meta role.

set :rails_env, "development"

# this is the role that does the puppet setup
# when this role is run there's no deploy user so we have to use the default
# vagrant user. If you adapt this for another stage/environment make sure whoever
# this user has sudo access.
# the `no_release: true` argument keeps this stage out of `cap deploy`.
role :puppet_prepare, %w{vagrant@192.168.123.21}, no_release: true

# these are the users/stages you want to deploy and run your app.
role :app, %w{deploy@192.168.123.21}
role :web, %w{deploy@192.168.123.21}
role :db,  %w{deploy@192.168.123.21}


# Capistrano examples.

# Extended Server Syntax
# ======================
# This can be used to drop a more detailed server definition into the
# server list. The second argument is a, or duck-types, Hash and is
# used to set extended properties on the server.

#server '192.168.123.21', user: 'deploy', roles: %w{web app}, my_property: :my_value
#server '192.168.123.21', user: 'deploy', roles: %w{web app}


# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult[net/ssh documentation](http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start).
#
# Global options
# --------------
#  set :ssh_options, {
#    keys: %w(/home/rlisowski/.ssh/id_rsa),
#    forward_agent: false,
#    auth_methods: %w(password)
#  }
#
# And/or per server (overrides global)
# ------------------------------------
# server 'example.com',
#   user: 'user_name',
#   roles: %w{web app},
#   ssh_options: {
#     user: 'user_name', # overrides user setting above
#     keys: %w(/home/user_name/.ssh/id_rsa),
#     forward_agent: false,
#     auth_methods: %w(publickey password)
#     # password: 'please use keys'
#   }
