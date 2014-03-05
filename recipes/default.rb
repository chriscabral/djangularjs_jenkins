#
# Cookbook Name:: djangoapp
# Recipe:: default
#
# Copyright 2014, Chris Cabral
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'nmap'
include_recipe 'curl'
include_recipe 'jenkins::master'
include_recipe 'mysql::server'
include_recipe 'mysql::client'
include_recipe 'database'
include_recipe 'database::mysql'
include_recipe 'python'
include_recipe 'git'

mysql_database 'myschedule' do
  connection(
    :host     => 'localhost',
    :username => 'root',
    :password => node['mysql']['server_root_password']
  )
  action :create
end

package 'vim'
package 'build-essential'
package 'gcc'
package 'g++'
package 'libpcre3'
package 'libpcre3-dev'
package 'libssl-dev'
package 'python-dev'

user "developer" do
  supports :manage_home => true
  uid 1234
  home "/home/developer"
  shell "/bin/bash"
  password "$1$3WfMmIJB$C64eMimUsCaJzDL4zMn8Z/"
end


python_virtualenv "/home/vagrant/venv" do
  action :delete
end

python_virtualenv "/home/vagrant/venv" do
  owner "jenkins"
  group "jenkins"
  action :create
end

execute 'delete project' do
  command "cd /home/vagrant;rm -rf #{node.default['djangoapp']['project']['name']}"
end

execute 'install uwsgi' do
  command "/home/vagrant/venv/bin/pip install uwsgi"
end

execute 'install gunicorn' do
  command '/home/vagrant/venv/bin/pip install gunicorn'
end

execute 'install django' do
  command "/home/vagrant/venv/bin/pip install django"
end

execute 'create project' do
  command "source /home/vagrant/venv/bin/activate;pip install gunicorn;cd /home/vagrant;django-admin.py startproject --template=#{node.default['djangoapp']['project']['template']} #{node.default['djangoapp']['project']['name']}"
end

execute 'commit project' do
  command "cd /home/vagrant/#{node.default['djangoapp']['project']['name']}; git init; git add -A; git commit -m 'initial commit'"
end

jenkins_plugins = {
  'postbuild-task' => '1.8',
  'ssh-credentials' => '1.5.1', 
  'scm-api' => '0.1',
  'credentials' => '1.9.3',
  'multiple-scms' => '0.3',
  'git-client' => '1.6.0',
  'git' => '2.0.1',
  'violations' => '0.7.11',
  'cobertura' => '1.9.3',
  'maven-plugin' => '2.1',
  'javadoc' => '1.1',
  'mailer' => '1.8',
}

jenkins_plugins.each{|key, value| 
  jenkins_plugin key do
    version value
  end
}

xml = File.join(Chef::Config[:file_cache_path], 'bacon-config.xml')

template xml do
  source 'custom-config.xml.erb'
  variables(
    :project_name => node.default['djangoapp']['project']['name']
  )
end

jenkins_job node.default['djangoapp']['project']['name'] do
  config xml
end

jenkins_command 'safe-restart'

file "/home/vagrant/test.py" do
  owner "developer"
  group "developer"
  mode "0755"
  action :create
end

execute 'test wsgi' do
  command "source /home/vagrant/venv/bin/activate;cd /home/vagrant"
end

#uwsgi --http :8000 --wsgi-file test.pyx  
