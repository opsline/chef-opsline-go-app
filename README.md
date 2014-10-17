# opsline-go-app-cookbook
This cookbook has been created to install, configure, and manage go applications.
Applications are installed from artifacts stored in S3. All configuration parameters
are stored in data bag items.


# Requirements
#### cookbooks
- `artifact` - Artifact Deploy LWRP
- `logrotate` - Logrotate


# Attributes
* `node['opsline-go-app']['databag']` - data bag name to store app details
* `node['opsline-go-app']['apps']` - list of apps to deploy
* `node['opsline-go-app']['encrypted_databag']` - true to use encrypted data bags
* `node['opsline-go-app']['s3_bucket']` - name of the S3 bucket that holds artifacts
* `node['opsline-go-app']['owner']` - unix user used to own and run applications
* `node['opsline-go-app']['install_go']` - flag to install go lang binaries
* `node['opsline-go-app']['go_version']` - go version
* `node['opsline-go-app']['godeb_url']` - go deb url


#Usage
#### opsline-go-app::default
Prepares for deployment:
* installs required packages
* configured ruby if configured

#### opsline-go-app::deploy
Deploys go applications.

Rails applications are defined as data bag items in a data bag defined in attributes.

Example of app definition:
```json
{
  "id": "testapp",
  "name": "testapp",
  "artifact_name": "testapp",
  "container": "worker",
  "container_parameters": {
    "default": {
      "number_of_workers": "4",
      "frontend": "none
    }
  },
  "type": "go",
  "version": {
    "production": "1",
    "default": "2"
  },
  "environment": {
    "production": {
      "REDIS_URL": "redis://redis-prod.example.com:6379",
      "PGBACKUPS_URL": "https://user:pass@postgresql-prod.example.com/schema"
    },
    "default": {
      "REDIS_URL": "redis://redis-test.example.com:6379",
      "PGBACKUPS_URL": "https://user:pass@postgresql-test.example.com/schema"
    }
  }
  "packages": []
}
```

Define a list of go apps to deploy in attributes.
```ruby
name "go-testapp"
description "go test app"
run_list(
  "role[base]",
  "recipe[opsline-go-app::default]",
  "recipe[opsline-go-app::deploy]"
)
default_attributes(
  opsline-go-app" => {
    "owner" => "go",
    "s3_bucket" => "example.artifacts",
    "apps" => ["testapp"],
    "install_go" => false
  }
)
```

Valid containers are:
* worker
* process

#### opsline-go-app::go
Installs go lang binaries.


License and Authors
-------------------
* Author:: Radek Wierzbicki

```text
Copyright 2014, OpsLine, LLC.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

