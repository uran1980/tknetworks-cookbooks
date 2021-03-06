#
# Author:: Ken-ichi TANABE (<nabeken@tknetworks.org>)
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

directory node[:openvpn][:dir] do
  action :create
end

if node[:platform] == "openbsd"
  template "/etc/rc.d/openvpn" do
    owner "root"
    group node[:etc][:passwd][:root][:gid]
    mode 0555
    source "openvpn.rc"
  end
end

if node[:platform] != "openbsd"
  package node[:openvpn][:package] do
    action :install
    source "ports" if node[:platform] == "freebsd"
  end
end

# generate dh params
execute "openvpn-generate-dh-params" do
  command "openssl dhparam -out #{node[:openvpn][:ssl][:dh]} " +
          "#{node[:openvpn][:ssl][:dh_bit]}"
  not_if do
    ::File.exists?(node[:openvpn][:ssl][:dh])
  end
end
