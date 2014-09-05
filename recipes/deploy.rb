class Chef::Recipe
  include Opsline::GoApp::Helpers
end

# install all configured go apps
node['opsline-go-app']['apps'].each do |app_id|

  # read app data bag item
  if node['opsline-go-app']['encrypted_databag']
    app_data = Chef::EncryptedDataBagItem.load(node['opsline-go-app']['databag'], app_id).to_hash
  else
    app_data = data_bag_item(node['opsline-go-app']['databag'], app_id)
  end

  # read inherited data bag item
  if app_data.has_key?('inherits')
    if node['opsline-go-app']['encrypted_databag']
      inherited_data = Chef::EncryptedDataBagItem.load(node['opsline-go-app']['databag'], app_data['inherits']).to_hash
    else
      inherited_data = data_bag_item(node['opsline-go-app']['databag'], app_data['inherits'])
    end
  else
    inherited_data = nil
  end

  # get app name
  if app_data.has_key?('name')
    app_name = app_data['name']
  else
    app_name = app_id
  end

  # skip non-go apps
  next unless app_data['type'] == 'go'

  # initial environment variables hash
  app_data['app_env'] = {}
  app_data['app_env']['HOME'] = "/home/#{node['opsline-go-app']['owner']}"
  app_data['app_env']['PATH'] = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  app_data['app_env']['GOPATH'] = "#{app_data['deploy_to']}/current"

  # merge inherited environment
  unless inherited_data.nil?
    if inherited_data.has_key?('environment')
      app_data['app_env'].merge!(get_env_value(inherited_data['environment']))
    end
    if inherited_data.has_key?('version')
      app_data['version'] = inherited_data['version']
    end
    if inherited_data.has_key?('deploy_to')
      app_data['deploy_to'] = inherited_data['deploy_to']
    end
    if inherited_data.has_key?('package_type')
      app_data['package_type'] = inherited_data['package_type']
    end
    if inherited_data.has_key?('artifact_name')
      app_data['artifact_name'] = inherited_data['artifact_name']
    end
    if inherited_data.has_key?('artifact_location')
      app_data['artifact_location'] = inherited_data['artifact_location']
    end
    if inherited_data.has_key?('jenkins_job_name')
      app_data['jenkins_job_name'] = inherited_data['jenkins_job_name']
    end
  end

  # set default parameters if not provided
  unless app_data.has_key?('deploy_to')
    app_data['deploy_to'] = "#{node['opsline-go-app']['apps_root']}/#{app_name}"
  end
  unless app_data.has_key?('package_type')
    app_data['package_type'] = 'tar.gz'
  end
  unless app_data.has_key?('artifact_name')
    app_data['artifact_name'] = app_name
  end
  unless app_data.has_key?('artifact_location')
    app_data['artifact_location'] = "s3://s3.amazonaws.com/#{node['opsline-go-app']['s3_bucket']}/#{app_data['artifact_name']}"
  end
  app_data['version'] = get_env_value(app_data['version'])
  app_data['artifact'] = "#{app_data['artifact_name']}-#{app_data['version']}.#{app_data['package_type']}"
  if app_data.has_key?('jenkins_job_name')
    app_data['artifact'] = "jobs/#{app_data['jenkins_job_name']}/#{app_data['version']}/#{app_data['artifact']}"
  end
  unless app_data.has_key?('container')
    app_data['container'] = 'process'
  end
  if app_data.has_key?('container_parameters')
    app_data['container_parameters'] = get_env_value(app_data['container_parameters'])
  else
    app_data['container_parameters'] = {}
  end

  # merge environment from data bag
  if app_data.has_key?('environment')
    app_data['app_env'].merge!(get_env_value(app_data['environment']))
  end

  # create app directory
  directory app_data['deploy_to'] do
    action :create
    owner node['opsline-go-app']['owner']
    group node['opsline-go-app']['owner']
    mode 0755
  end

  # install pre-requisite packages
  if app_data.has_key?('packages')
    app_data['packages'].each do |pkg_name|
      package pkg_name do
        action :install
      end
    end
  end

  # configure logrotate
  unless app_data.has_key?('logrotate')
    logrotate = true
  else
    logrotate = to_bool(app_data['logrotate'])
  end
  if logrotate
    unless app_data.has_key?('logrotate_days')
      days = 7
    else
      days = app_data['logrotate_days'].to_i
    end
    logrotate_app app_name do
      cookbook 'logrotate'
      path "#{app_data['deploy_to']}/shared/log/*.log"
      options ['copytruncate', 'missingok', 'compress', 'notifempty', 'delaycompress']
      frequency 'daily'
      rotate days
    end
  end

  app_data['shared_directories'] = %w{ bundle config log pids sockets system }
  app_data['symlinks'] = {'log' => 'log'}
  # additional shared_subdirectories
  if app_data.has_key?('shared_subdirectories')
    app_data['shared_subdirectories'].each do |dir|
      app_data['shared_directories'] << dir
      app_data['symlinks'][dir] = dir
    end
  end

  services_to_restart = []
  pids_to_signal = []
  restart_after_deploy = false

  # deploy artifact
  artifact_deploy app_name do
    version app_data['version']
    artifact_location "#{app_data['artifact_location']}/#{app_data['artifact']}"
    deploy_to app_data['deploy_to']
    owner node['opsline-go-app']['owner']
    group node['opsline-go-app']['owner']
    environment app_data['app_env']
    shared_directories app_data['shared_directories']
    symlinks(app_data['symlinks'])
    action :deploy
    keep 3
    force false

    # remove log directory before linking
    before_symlink Proc.new {
      directory "#{app_data['deploy_to']}/releases/#{app_data['version']}/log" do
        action :delete
        recursive true
      end
    }

    # configure proc
    configure Proc.new {

      # PROCESS
      if app_data['container'] == 'process'
        unless app_data['container_parameters'].has_key?('frontend')
          app_data['container_parameters']['frontend'] = 'none'
        end

        env_dir app_data do
          deploy_to app_data['deploy_to']
          variables app_data['app_env']
          owner node['opsline-rails-app']['owner']
          group node['opsline-rails-app']['owner']
          notifies [:restart, "service[#{app_name}]"]
        end

        template "/etc/init/#{app_name}.conf" do
          source 'upstart.conf.erb'
          cookbook 'opsline-go-app'
          owner 'root'
          group 'root'
          mode 0644
          action :create
          notifies :restart, "service[#{app_name}]", :delayed
          variables({
            :app_name => app_name,
            :user => node['opsline-go-app']['owner'],
            :group => node['opsline-go-app']['owner'],
            :deploy_to => app_data['deploy_to'],
            :executable => app_data['executable']
          })
        end
        service app_name do
          provider Chef::Provider::Service::Upstart
          action :nothing
        end
        services_to_restart << [app_name, Chef::Provider::Service::Upstart]

        if app_data['container_parameters']['frontend'] == 'nginx'
          if app_data['container_parameters'].has_key?('frontend_ports')
            app_data['container_parameters']['upstream_ports'] = app_data['container_parameters']['frontend_ports']
          else
            app_data['container_parameters']['upstream_ports'] = []
          end
          if app_data['container_parameters'].has_key?('frontend_sockets')
            app_data['container_parameters']['upstream_sockets'] = app_data['container_parameters']['frontend_sockets']
          else
            app_data['container_parameters']['upstream_sockets'] = []
          end

          services_to_restart << ['nginx', Chef::Provider::Service::Init]

          nginx_app_config "nginx config for #{app_name}" do
            app_name app_name
            app_data app_data
          end
        end
      end

      # WORKER
      if app_data['container'] == 'worker'
        unless app_data['container_parameters'].has_key?('number_of_workers')
          app_data['container_parameters']['number_of_workers'] = 4
        end
        unless app_data['container_parameters'].has_key?('frontend')
          app_data['container_parameters']['frontend'] = 'none'
        end

        env_dir app_data do
          deploy_to app_data['deploy_to']
          variables app_data['app_env']
          owner node['opsline-rails-app']['owner']
          group node['opsline-rails-app']['owner']
          notifies [:restart, "service[#{app_name}]"]
        end

        template "/etc/init/#{app_name}-worker.conf" do
          source 'upstart.worker.conf.erb'
          cookbook 'opsline-go-app'
          owner 'root'
          group 'root'
          mode 0644
          action :create
          notifies :restart, "service[#{app_name}]", :delayed
          variables({
            :app_name => app_name,
            :user => node['opsline-go-app']['owner'],
            :group => node['opsline-go-app']['owner'],
            :deploy_to => app_data['deploy_to'],
            :executable => app_data['executable']
          })
        end

        template "/etc/init/#{app_name}.conf" do
          source 'upstart.workers.conf.erb'
          cookbook 'opsline-go-app'
          owner 'root'
          group 'root'
          mode 0644
          action :create
          notifies :restart, "service[#{app_name}]", :delayed
          variables({
            :app_name => app_name,
            :user => node['opsline-go-app']['owner'],
            :group => node['opsline-go-app']['owner'],
            :deploy_to => app_data['deploy_to'],
            :number_of_workers => app_data['container_parameters']['number_of_workers']
          })
        end
        service app_name do
          provider Chef::Provider::Service::Upstart
          action :nothing
        end
        services_to_restart << [app_name, Chef::Provider::Service::Upstart]

        if app_data['container_parameters']['frontend'] == 'nginx'
          if app_data['container_parameters'].has_key?('frontend_ports')
            app_data['container_parameters']['upstream_ports'] = app_data['container_parameters']['frontend_ports']
          else
            app_data['container_parameters']['upstream_ports'] = []
          end
          if app_data['container_parameters'].has_key?('frontend_sockets')
            app_data['container_parameters']['upstream_sockets'] = app_data['container_parameters']['frontend_sockets']
          else
            app_data['container_parameters']['upstream_sockets'] = []
          end

          services_to_restart << ['nginx', Chef::Provider::Service::Init]

          nginx_app_config "nginx config for #{app_name}" do
            app_name app_name
            app_data app_data
          end
        end
      end

    }

    # restart proc
    restart Proc.new {
      restart_after_deploy = true
    }

    # after_deploy proc
    after_deploy Proc.new {
      if restart_after_deploy
        restart_services "restart #{app_name} services" do
          services_to_restart services_to_restart
          pids_to_signal pids_to_signal
        end
      end
    }

  end

end
