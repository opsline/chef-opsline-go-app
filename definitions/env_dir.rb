define :env_dir, :deploy_to => nil, :variables => {}, :owner => 'root', :group => 'root', :action => :create, :notifies => nil do
  app_name = params[:name]
  env_d = "#{params[:deploy_to]}/env"

  directory env_d do
    recursive true
    owner params[:owner]
    group params[:group]
    mode 0755
    action params[:action]
  end

  configured_vars = params[:variables].keys

  if File.directory?(env_d)
    existing_vars = Dir.entries(env_d).select {|f| !File.directory? f}

    # remove files that should not exist
    (existing_vars - configured_vars).each do |var|
      file var do
        path "#{env_d}/#{var}"
        owner params[:owner]
        group params[:group]
        action :delete
        mode 0644
        notifies params[:notifies][0], params[:notifies][1]
      end
    end
  end

  # create all var files
  configured_vars.each do |var|
    file var do
      path "#{env_d}/#{var}"
      owner params[:owner]
      group params[:group]
      action params[:action]
      mode 0644
      content params[:variables][var].to_s
      notifies params[:notifies][0], params[:notifies][1]
    end
  end
end
