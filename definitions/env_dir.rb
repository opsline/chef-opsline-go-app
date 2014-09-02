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

  params[:variables].each do |key, value|
    file key do
      path "#{env_d}/#{key}"
      owner params[:owner]
      group params[:group]
      action params[:action]
      mode 0644
      content value.to_s
      notifies params[:notifies][0], params[:notifies][1]
    end
  end
end
