# -*- mode: ruby -*-
# # vi: set ft=ruby :

# For help on using kubespray with vagrant, check out docs/vagrant.md

require 'fileutils'

Vagrant.require_version ">= 2.0.0"

CONFIG = File.join(File.dirname(__FILE__), ENV['KUBESPRAY_VAGRANT_CONFIG'] || 'vagrant/config.rb')

FLATCAR_URL_TEMPLATE = "https://%s.release.flatcar-linux.net/amd64-usr/current/flatcar_production_vagrant.json"

SUPPORTED_OS = {
  "flatcar-stable"      => {box: "flatcar-stable",             user: "core", box_url: FLATCAR_URL_TEMPLATE % ["stable"]},
  "flatcar-beta"        => {box: "flatcar-beta",               user: "core", box_url: FLATCAR_URL_TEMPLATE % ["beta"]},
  "flatcar-alpha"       => {box: "flatcar-alpha",              user: "core", box_url: FLATCAR_URL_TEMPLATE % ["alpha"]},
  "flatcar-edge"        => {box: "flatcar-edge",               user: "core", box_url: FLATCAR_URL_TEMPLATE % ["edge"]},
  "ubuntu2004"          => {box: "generic/ubuntu2004",         user: "vagrant"},
  "ubuntu2204"          => {box: "generic/ubuntu2204",         user: "vagrant"},
  "ubuntu2404"          => {box: "bento/ubuntu-24.04",         user: "vagrant"},
  "centos"              => {box: "centos/7",                   user: "vagrant"},
  "centos-bento"        => {box: "bento/centos-7.6",           user: "vagrant"},
  "centos8"             => {box: "centos/8",                   user: "vagrant"},
  "centos8-bento"       => {box: "bento/centos-8",             user: "vagrant"},
  "almalinux8"          => {box: "almalinux/8",                user: "vagrant"},
  "almalinux8-bento"    => {box: "bento/almalinux-8",          user: "vagrant"},
  "rockylinux8"         => {box: "rockylinux/8",               user: "vagrant"},
  "rockylinux9"         => {box: "bento/rockylinux-9.4",       user: "vagrant"},
  "fedora37"            => {box: "fedora/37-cloud-base",       user: "vagrant"},
  "fedora38"            => {box: "fedora/38-cloud-base",       user: "vagrant"},
  "opensuse"            => {box: "opensuse/Leap-15.4.x86_64",  user: "vagrant"},
  "opensuse-tumbleweed" => {box: "opensuse/Tumbleweed.x86_64", user: "vagrant"},
  "oraclelinux"         => {box: "generic/oracle7",            user: "vagrant"},
  "oraclelinux8"        => {box: "generic/oracle8",            user: "vagrant"},
  "rhel7"               => {box: "generic/rhel7",              user: "vagrant"},
  "rhel8"               => {box: "generic/rhel8",              user: "vagrant"},
  "debian11"            => {box: "debian/bullseye64",          user: "vagrant"},
  "debian12"            => {box: "debian/bookworm64",          user: "vagrant"},
}

if File.exist?(CONFIG)
  require CONFIG
end

# Defaults for config options defined in CONFIG
$num_instances ||= 3
$instance_name_prefix ||= "k8s"
$vm_gui ||= false
$vm_memory ||= 8192
$vm_cpus ||= 8
$kube_master_vm_memory ||= 4096
$kube_master_vm_cpus ||= 4
$upm_control_plane_vm_memory ||= 16384
$upm_control_plane_vm_cpus ||= 8
$shared_folders ||= {}
$forwarded_ports ||= {}
$subnet ||= "172.18.8"
$subnet_split4 ||=100
$subnet_ipv6 ||= "fd3c:b398:0698:0756"
$netmask ||= "255.255.255.0"
$gateway ||= "172.18.8.1"
$bridge_nic ||= "eth0"
$os ||= "rockylinux9"
$network_plugin ||= "flannel"
# Setting multi_networking to true will install Multus: https://github.com/k8snetworkplumbingwg/multus-cni
$multi_networking ||= "False"
$download_run_once ||= "True"
$download_force_cache ||= "False"
$kube_version ||= "v1.29.7"
# The first three nodes are etcd servers
$etcd_instances ||= [$num_instances, 3].min
# The first two nodes are kube masters
$kube_master_instances ||= [$num_instances, 2].min
# All nodes are kube nodes
$kube_node_instances ||= $num_instances
# UPM controller nodes
$upm_ctl_instances ||= 1
# The following only works when using the libvirt provider
$kube_node_instances_with_disks ||= false
$kube_node_instances_with_disks_size ||= "20G"
$kube_node_instances_with_disks_number ||= 2
$kube_node_instances_with_disk_dir ||= ENV['HOME']
$kube_node_instances_with_disk_suffix ||= 'xxxxxxxx'
$override_disk_size ||= false
$disk_size ||= "20GB"
$local_path_provisioner_enabled ||= "False"
$local_path_provisioner_claim_root ||= "/opt/local-path-provisioner/"
$libvirt_nested ||= false
# boolean or string (e.g. "-vvv")
$ansible_verbosity ||= false
$ansible_tags ||= ENV['VAGRANT_ANSIBLE_TAGS'] || ""

$vagrant_pwd ||= "root"
$vagrant_dir ||= File.join(File.dirname(__FILE__), ".vagrant")

$playbook ||= "cluster.yml"
$extra_vars ||= {}

node_instances_begin = [$etcd_instances, $kube_master_instances].max
upm_instances_end = 
host_vars = {}

# throw error if os is not supported
if ! SUPPORTED_OS.key?($os)
  puts "Unsupported OS: #{$os}"
  puts "Supported OS are: #{SUPPORTED_OS.keys.join(', ')}"
  exit 1
end

$box = SUPPORTED_OS[$os][:box]
# if $inventory is not set, try to use example
$inventory = "inventory/sample" if ! $inventory
$inventory = File.absolute_path($inventory, File.dirname(__FILE__))

# if $inventory has a hosts.ini file use it, otherwise copy over
# vars etc to where vagrant expects dynamic inventory to be
if ! File.exist?(File.join(File.dirname($inventory), "hosts.ini"))
  $vagrant_ansible = File.join(File.absolute_path($vagrant_dir), "provisioners", "ansible")
  FileUtils.mkdir_p($vagrant_ansible) if ! File.exist?($vagrant_ansible)
  $vagrant_inventory = File.join($vagrant_ansible,"inventory")
  FileUtils.rm_f($vagrant_inventory)
  FileUtils.ln_s($inventory, $vagrant_inventory)
end

if Vagrant.has_plugin?("vagrant-proxyconf")
  $no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
  (1..$num_instances).each do |i|
      $no_proxy += ",#{$subnet}.#{i+$subnet_split4}"
  end
end

Vagrant.configure("2") do |config|

  config.vm.box = $box
  if SUPPORTED_OS[$os].has_key? :box_url
    config.vm.box_url = SUPPORTED_OS[$os][:box_url]
  end
  config.ssh.username = SUPPORTED_OS[$os][:user]

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  # always use Vagrants insecure key
  config.ssh.insert_key = false

  if ($override_disk_size)
    unless Vagrant.has_plugin?("vagrant-disksize")
      system "vagrant plugin install vagrant-disksize"
    end
    config.disksize.size = $disk_size
  end

  (1..$num_instances).each do |i|
    config.vm.define vm_name = "%s-%01d" % [$instance_name_prefix, i] do |node|

      node.vm.hostname = vm_name

      if Vagrant.has_plugin?("vagrant-proxyconf")
        node.proxy.http     = ENV['HTTP_PROXY'] || ENV['http_proxy'] || ""
        node.proxy.https    = ENV['HTTPS_PROXY'] || ENV['https_proxy'] ||  ""
        node.proxy.no_proxy = $no_proxy
      end

      if i <= node_instances_begin
        memory_size = "#{$kube_master_vm_memory}"
        cpu_num = "#{$kube_master_vm_cpus}"
      elsif i > node_instances_begin && i <= node_instances_begin + $upm_ctl_instances
        memory_size = "#{$upm_control_plane_vm_memory}"
        cpu_num = "#{$upm_control_plane_vm_cpus}"
      else
        memory_size = "#{$vm_memory}"
        cpu_num = "#{$vm_cpus}"
      end

      ["vmware_fusion", "vmware_workstation"].each do |vmware|
        node.vm.provider vmware do |v|
          v.vmx['memsize'] = memory_size
          v.vmx['numvcpus'] = cpu_num
        end
      end

      node.vm.provider :virtualbox do |vb|
        vb.memory = memory_size
        vb.cpus = cpu_num
        vb.gui = $vm_gui
        vb.linked_clone = true
        vb.customize ["modifyvm", :id, "--vram", "8"] # ubuntu defaults to 256 MB which is a waste of precious RAM
        vb.customize ["modifyvm", :id, "--audio", "none"]
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      end

      node.vm.provider :libvirt do |lv|
        lv.nested = $libvirt_nested
        lv.cpu_mode = "host-model"
        lv.memory = memory_size
        lv.cpus = cpu_num
        lv.default_prefix = 'kubespray'
        # Fix kernel panic on fedora 28
        if $os == "fedora"
          lv.cpu_mode = "host-passthrough"
        end
      end

      if $kube_node_instances_with_disks && i > node_instances_begin
        # install lvm2 package
         node.vm.provision "shell", inline: "sudo dnf install -y lvm2"
        # Libvirt
        driverletters = ('a'..'z').to_a
        disk_dir = "#{$kube_node_instances_with_disk_dir}"
        node.vm.provider :libvirt do |lv|
          # always make /dev/sd{a/b/c} so that CI can ensure that
          # virtualbox and libvirt will have the same devices to use for OSDs
          (1..$kube_node_instances_with_disks_number).each do |d|
            disk_path = "#{disk_dir}/disk-#{i}-#{driverletters[d]}-#{$kube_node_instances_with_disk_suffix}.disk"
            lv.storage :file, :device => "hd#{driverletters[d]}", :path => disk_path, :size => $kube_node_instances_with_disks_size, :bus => "scsi"
          end
        end
        node.vm.provider :virtualbox do |vb|
          # always make /dev/sd{a/b/c} so that CI can ensure that
          # virtualbox and libvirt will have the same devices to use for OSDs
          (1..$kube_node_instances_with_disks_number).each do |d|
            disk_path = "#{disk_dir}/disk-#{i}-#{driverletters[d]}-#{$kube_node_instances_with_disk_suffix}.disk"
            if !File.exist?(disk_path)
              vb.customize ['createhd', '--filename', disk_path, '--size', $kube_node_instances_with_disks_size] # 10GB disk
            end
            vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', d, '--device', 0, '--type', 'hdd', '--medium', disk_path, '--nonrotational', 'on', '--mtype', 'normal']
          end
        end
      end

      if $expose_docker_tcp
        node.vm.network "forwarded_port", guest: 2375, host: ($expose_docker_tcp + i - 1), auto_correct: true
      end

      $forwarded_ports.each do |guest, host|
        node.vm.network "forwarded_port", guest: guest, host: host, auto_correct: true
      end

      if ["rhel7","rhel8"].include? $os
        # Vagrant synced_folder rsync options cannot be used for RHEL boxes as Rsync package cannot
        # be installed until the host is registered with a valid Red Hat support subscription
        node.vm.synced_folder ".", "/vagrant", disabled: false
        $shared_folders.each do |src, dst|
          node.vm.synced_folder src, dst
        end
      else
        node.vm.synced_folder ".", "/vagrant", disabled: false, type: "rsync", rsync__args: ['--verbose', '--archive', '--delete', '-z'] , rsync__exclude: ['.git','venv']
        $shared_folders.each do |src, dst|
          node.vm.synced_folder src, dst, type: "rsync", rsync__args: ['--verbose', '--archive', '--delete', '-z']
        end
      end

      ip = "#{$subnet}.#{i+$subnet_split4}"
      node.vm.network :public_network,
        :ip => ip,
        :netmask => $netmask,
        :bridge => $bridge_nic,
        :libvirt__guest_ipv6 => 'yes',
        :libvirt__ipv6_address => "#{$subnet_ipv6}::#{i+$subnet_split4}",
        :libvirt__ipv6_prefix => "64",
        :libvirt__forward_mode => "none",
        :libvirt__dhcp_enabled => false
      # Set default gateway
      node.vm.provision "shell", inline: <<-SHELL
        sudo nmcli connection modify "eth0" ipv4.gateway ""
        sudo nmcli connection modify "eth0" ipv4.never-default yes
        sudo nmcli connection modify "System eth1" +ipv4.routes "0.0.0.0/0 #{$gateway}"
        sudo nmcli connection modify "System eth1" ipv4.gateway "#{$gateway}"
        sudo nmcli connection up "eth0"
        sudo nmcli connection up "System eth1"
      SHELL

      # Disable swap for each vm
      node.vm.provision "shell", inline: "swapoff -a"

      # Set password for vagrant user
      node.vm.provision "shell", inline: "echo 'vagrant:#{$vagrant_pwd}' | sudo chpasswd"

      # link kubectl to /usr/bin/kubectl
      node.vm.provision "shell", inline: <<-SHELL
        sudo ln -s /usr/local/bin/kubectl /usr/bin/kubectl
        sudo ln -s /usr/local/bin/helm /usr/bin/helm
        sudo ln -s /usr/local/bin/nerdctl /usr/bin/nerdctl
        sudo ln -s /usr/local/bin/crictl /usr/bin/crictl
      SHELL
      # ubuntu2004 and ubuntu2204 have IPv6 explicitly disabled. This undoes that.
      if ["ubuntu2004", "ubuntu2204"].include? $os
        node.vm.provision "shell", inline: "rm -f /etc/modprobe.d/local.conf"
        node.vm.provision "shell", inline: "sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf /etc/sysctl.conf"
      end
      # Hack for fedora37/38 to get the IP address of the second interface
      if ["fedora37", "fedora38"].include? $os
        config.vm.provision "shell", inline: <<-SHELL
          nmcli conn modify 'Wired connection 2' ipv4.addresses $(cat /etc/sysconfig/network-scripts/ifcfg-eth1 | grep IPADDR | cut -d "=" -f2)
          nmcli conn modify 'Wired connection 2' ipv4.method manual
          service NetworkManager restart
        SHELL
      end

      # Rockylinux boxes needs UEFI
      if ["rockylinux8", "rockylinux9"].include? $os
        config.vm.provider "libvirt" do |domain|
          domain.loader = "/usr/share/OVMF/x64/OVMF_CODE.fd"
        end
      end

      # Disable firewalld on oraclelinux/redhat vms
      if ["oraclelinux","oraclelinux8","rhel7","rhel8","rockylinux8"].include? $os
        node.vm.provision "shell", inline: "systemctl stop firewalld; systemctl disable firewalld"
      end

      host_vars[vm_name] = {
        "ip": ip,
        "flannel_interface": "eth1",
        "kube_network_plugin": $network_plugin,
        "kube_network_plugin_multus": $multi_networking,
        "download_run_once": $download_run_once,
        "download_localhost": "False",
        "download_cache_dir": ENV['HOME'] + "/kubespray_cache",
        # Make kubespray cache even when download_run_once is false
        "download_force_cache": $download_force_cache,
        # Keeping the cache on the nodes can improve provisioning speed while debugging kubespray
        "download_keep_remote_cache": "False",
        "docker_rpm_keepcache": "1",
        # These two settings will put kubectl and admin.config in $inventory/artifacts
        "kubeconfig_localhost": "True",
        "kubectl_localhost": "True",
        "local_path_provisioner_enabled": "#{$local_path_provisioner_enabled}",
        "local_path_provisioner_claim_root": "#{$local_path_provisioner_claim_root}",
        "helm_enabled": "True",
        "ansible_ssh_user": SUPPORTED_OS[$os][:user],
        "ansible_ssh_private_key_file": File.join(Dir.home, ".vagrant.d", "insecure_private_key"),
        "unsafe_show_logs": "True",
        "kube_version": "#{$kube_version}"
      }

      # Only execute the Ansible provisioner once, when all the machines are up and ready.
      # And limit the action to gathering facts, the full playbook is going to be ran by testcases_run.sh
      if i == $num_instances
        node.vm.provision "ansible" do |ansible|
          ansible.playbook = $playbook
          ansible.compatibility_mode = "2.0"
          ansible.verbose = $ansible_verbosity
          $ansible_inventory_path = File.join( $inventory, "hosts.ini")
          if File.exist?($ansible_inventory_path)
            ansible.inventory_path = $ansible_inventory_path
          end
          ansible.become = true
          ansible.limit = "all,localhost"
          ansible.host_key_checking = false
          ansible.raw_arguments = ["--forks=#{$num_instances}", "--flush-cache", "-e ansible_become_pass=vagrant"]
          ansible.host_vars = host_vars
          ansible.extra_vars = $extra_vars
          if $ansible_tags != ""
            ansible.tags = [$ansible_tags]
          end
          ansible.groups = {
            "etcd" => ["#{$instance_name_prefix}-[1:#{$etcd_instances}]"],
            "kube_control_plane" => ["#{$instance_name_prefix}-[1:#{$kube_master_instances}]"],
            "kube_node" => ["#{$instance_name_prefix}-[1:#{$kube_node_instances}]"],
            "k8s_cluster:children" => ["kube_control_plane", "kube_node"],
          }
        end
      end
    end
  end
end