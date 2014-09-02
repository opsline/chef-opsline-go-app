class Chef::Recipe
  include Opsline::GoApp::Helpers
end

include_recipe 'opsline-go-app::go'

# install required packages
package 'daemontools'
package 'inotify-tools'

directory node['opsline-go-app']['apps_root'] do
  action :create
  owner node['opsline-go-app']['owner']
  group node['opsline-go-app']['owner']
  mode 0755
end
