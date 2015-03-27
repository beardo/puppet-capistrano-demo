desc "Check if agent forwarding is working"
task :cold_start do
  on roles (:all) do |h|
    invoke 'puppet:prepare'
    invoke 'puppet:install'
    invoke 'deploy'
  end
end

