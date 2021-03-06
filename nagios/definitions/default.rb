require "socket"

define :nagios_host, :use => nil, :address => nil, :host_alias => nil, :contact_groups => nil, :hostgroups => nil, :group => "hosts" do
  extend Chef::Nagios

  begin
    if params[:address].nil?
      begin
          address = Socket.getaddrinfo(params[:name], nil, Socket::AF_INET6).first[3]
      rescue
          address = Socket.getaddrinfo(params[:name], nil, Socket::AF_UNSPEC).first[3]
      end
    else
      address = params[:address]
    end
  rescue SocketError
    raise if params[:address].nil?
    address = params[:address]
  end

  t = nil
  begin
    t = resources(:template => "#{node.nagios.server.dir}/hosts/#{params[:group]}.cfg")
  rescue
    t = template "#{node.nagios.server.dir}/hosts/#{params[:group]}.cfg" do
          source "etc/nagios3/hosts.cfg"
          owner node.nagios.server.uid
          group node.nagios.server.gid
          mode  0770
          variables :hosts => {}
          notifies :restart, "service[#{node.nagios.server.service}]", :delayed
    end
  end

  # run_stateに登録したホスト名を記録する
  node.run_state[:nagios_hosts] = [] if node.run_state[:nagios_hosts].nil?
  node.run_state[:nagios_hosts].push params[:name]

  use = params[:use].nil? ? node.nagios.server.use : params[:use]
  host_alias  = params[:host_alias]
  contact_groups = params[:contact_groups].nil? ? node.nagios.server.contact_groups : params[:contact_groups]
  hostgroups = params[:hostgroups].nil? ? getHostgroups(params[:name]) : params[:hostgroups]

  node.set[:nagios][:server][:myhosts] = Mash.new if node[:nagios][:server][:myhosts].nil?

  myhost = Mash.new
  myhost[:address] = address
  myhost[:host_alias] = host_alias
  myhost[:contact_groups] = contact_groups
  myhost[:hostgroups] = hostgroups
  myhost[:use] = use

  t.variables[:hosts][params[:name]] = myhost
  Chef::Log.debug("registering nagios host #{params[:name]}")
end

define :nagios_generic, :config => nil, :group => "default", :generic_type => "host" do
  t = nil

  begin
    t = resources(:template => "#{node.nagios.server.dir}/generics/#{params[:group]}.cfg")
  rescue
    t = template "#{node.nagios.server.dir}/generics/#{params[:group]}.cfg" do
          source "etc/nagios3/generic.cfg"
          owner node.nagios.server.uid
          group node.nagios.server.gid
          mode  0770
          variables :generics => {}
          notifies :restart, "service[#{node.nagios.server.service}]", :delayed
    end
  end

  t.variables[:generics][params[:name]] = Mash.new if t.variables[:generics][params[:name]].nil?
  t.variables[:generics][params[:name]][:config] = params[:config]
  t.variables[:generics][params[:name]][:type]   = params[:generic_type]
  Chef::Log.debug("registering nagios generic #{params[:name]}")
end

define :nagios_service, :use => nil, :hostgroups => nil, :description => nil, :command => nil, :args => nil, :host => nil, :group => "services" do
  t = nil

  begin
    t = resources(:template => "#{node.nagios.server.dir}/conf.d/services_nagios2.cfg")
  rescue
    t = template "#{node.nagios.server.dir}/conf.d/services_nagios2.cfg" do
          source "etc/nagios3/conf.d/services_nagios2.cfg"
          owner node.nagios.server.uid
          group node.nagios.server.gid
          mode  0770
          variables :services => {}
          notifies :restart, "service[#{node.nagios.server.service}]", :delayed
    end
  end

  # ホスト登録がない場合あるいはrun_state[:nagios_hosts]が空の場合はエラー
  # ただし、ホストグループ指定がある場合はエラーにしない(= ホストグループ指定がない場合はエラー)
  if (node.run_state[:nagios_hosts].nil? || !node.run_state[:nagios_hosts].include?(params[:host])) || !params[:hostgroups].nil?
    Chef::Log.error("#{params[:host]} is not registered as nagios host. skipped....")
    next
  end

  use  = params[:use].nil? ? node.nagios.server.use : params[:use]
  hostgroups = params[:hostgroups]
  description = params[:description].nil? ? params[:name].upcase : params[:description]

  myservice = Mash.new
  myservice[:host_name] = params[:host]
  myservice[:hostgroups] = hostgroups.nil? ? hostgroups : hostgroups.join(",")
  myservice[:use] = use
  myservice[:description] = description

  command = params[:command]
  command << "!#{params[:args].join("!")}" unless params[:args].nil?
  myservice[:command] = command

  t.variables[:services][params[:name]] = [] unless t.variables[:services].has_key?(params[:name])
  t.variables[:services][params[:name]].push myservice
  Chef::Log.debug("registering nagios service #{params[:name]} on #{params[:host]}")
end

define :nagios_checkcommand, :command_line => nil do
  t = nil

  begin
    t = resources(:template => "#{node.nagios.server.dir}/conf.d/checkcommands.cfg")
  rescue
    t = template "#{node.nagios.server.dir}/conf.d/checkcommands.cfg" do
          source "etc/nagios3/checkcommands.cfg"
          owner node.nagios.server.uid
          group node.nagios.server.gid
          mode  0770
          variables :commands => {}
          notifies :restart, "service[#{node.nagios.server.service}]", :delayed
    end
  end

  raise if params[:command_line].nil?

  t.variables[:commands][params[:name]] = params[:command_line] if t.variables[:commands][params[:name]].nil?
  Chef::Log.debug("registering nagios check command #{params[:name]}")
end
