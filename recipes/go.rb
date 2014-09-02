if node['opsline-go-app']['install_go']
  bash "install go #{node['opsline-go-app']['go_version']}" do
    user 'root'
    cwd '/tmp'
    code <<-EOH
      cd /tmp
      curl -O #{node['opsline-go-app']['godeb_url']}
      tar zxvf #{node['opsline-go-app']['godeb_url'].split('/')[-1]}
      /tmp/godeb install #{node['opsline-go-app']['go_version']}
      rm -f #{node['opsline-go-app']['godeb_url'].split('/')[-1]}
    EOH
    not_if "/usr/bin/go version |grep -q '#{node['opsline-go-app']['go_version']}'"
  end
end
