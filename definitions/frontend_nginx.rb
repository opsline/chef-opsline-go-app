define :nginx_app_config, :app_name => nil, :app_data => {}, :template => 'nginx.conf.erb', :cookbook => 'opsline-rails-app', :action => :create do

  app_name = params[:app_name]
  app_data = params[:app_data]

  service 'nginx' do
    action :nothing
  end

  template "/etc/nginx/sites-available/#{app_name}" do
    source params[:template]
    cookbook 'opsline-rails-app'
    owner 'root'
    group 'root'
    mode 0644
    action params[:action]
    notifies :restart, resources(:service => 'nginx'), :delayed
    variables({
      :app_name => app_name,
      :app_data => app_data,
      :server_name => "#{app_name}.#{node.domain}"
    })
  end
  link "#{app_name} nginx site" do
    target_file "/etc/nginx/sites-enabled/#{app_name}"
    to "/etc/nginx/sites-available/#{app_name}"
    action params[:action]
  end

end
