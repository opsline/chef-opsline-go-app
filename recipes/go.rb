#
# Cookbook Name:: opsline-go-app
# Recipe:: go
#
# Author:: Radek Wierzbicki
#
# Copyright 2014, OpsLine, LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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
