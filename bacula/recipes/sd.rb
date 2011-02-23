package node.bacula.sd.package do
    action :install
end

service node.bacula.sd.service do
    action :enable
end

dir_host = search(:node, "role:bacula_dir")

template node.bacula.sd.config do
    source "bacula-sd.conf"
    owner  "bacula"
    group  "bacula"
    mode   0644
    variables({
        :devices      => {},
        :dir_hostname => dir_host.first.hostname,
        :tls          => node.bacula.tls,
        :password     => node.bacula.password,
        :dir          => node.bacula.dir,
        :working_dir  => node.bacula.working_dir,
        :pid_dir      => node.bacula.pid_dir,
        :hostname     => node.hostname,
        :maximum_concurrent_jobs => node.bacula.maximum_concurrent_jobs
    })
    notifies :restart, resources(:service => node.bacula.sd.service)
end

node.bacula.sd.devices.each do |name, config|
    bacula_sd_device name do
        device config[:device]
    end
end

# ready to startup
service node.bacula.sd.service do
    action :start
end
