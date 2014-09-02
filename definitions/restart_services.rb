define :restart_services, :services_to_restart => [], :pids_to_signal => [] do
  params[:services_to_restart].each do |service_to_restart|
    service service_to_restart[0] do
      provider service_to_restart[1]
      action :restart
    end
  end
  params[:pids_to_signal].each do |pid_to_signal|
    pid = pid_to_signal[0]
    signal = pid_to_signal[1]
    execute "signal #{signal} #{pid}" do
      user 'root'
      command "kill -#{signal} #{pid}"
      action :run
    end
  end
end
