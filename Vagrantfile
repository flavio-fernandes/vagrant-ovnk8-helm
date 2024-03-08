# -*- mode: ruby -*-
# vi: set ft=ruby :
#
vagrant_config = YAML.load_file("provisioning/vm_config.conf.yml")

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"

  config.nfs.verify_installed = false
  config.vm.synced_folder ".", "/vagrant", type: "sshfs", sshfs_opts: "cache=yes,kernel_cache,compression=no,large_read"
  
  # For the private network, the following route in host is added by vagrant/virtualbox
  # 192.168.56.0/24 dev vboxnet0 proto kernel scope link src 192.168.56.1
  # You can make virtualbox add it by creating a test VM from another vagrant directory
  # if it goes missing.

  config.vm.define "master", primary: true do |k8smaster|
    k8smaster.vm.network "private_network", ip: "192.168.56.10", netmask: "255.255.255.0", libvirt__network_name: "vagrant-ovn-kubernetes0", libvirt__network_address: "192.168.56.0/24"
    k8smaster.vm.hostname = vagrant_config['k8smaster']['host_name']
    k8smaster.vm.provision "shell", path: "provisioning/setup-master.sh", privileged: false
    k8smaster.vm.provision "shell", path: "provisioning/setup-ovn-via-helm.sh", privileged: false
    k8smaster.vm.provider "virtualbox" do |vb|
      vb.name = vagrant_config['k8smaster']['short_name']
       vb.memory = vagrant_config['k8smaster']['memory']
       vb.cpus = vagrant_config['k8smaster']['cpus']
       vb.customize [
           "guestproperty", "set", :id,
           "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 10000
          ]
    end
    k8smaster.vm.provider "libvirt" do |lv, override|
      lv.memory = vagrant_config['k8smaster']['memory']
      lv.cpus = vagrant_config['k8smaster']['cpus']
      lv.nested = true
    end
  end
  config.vm.define "minion1" do |k8sminion1|
    k8sminion1.vm.network "private_network", ip: "192.168.56.11", netmask: "255.255.255.0", libvirt__network_name: "vagrant-ovn-kubernetes0", libvirt__network_address: "192.168.56.0/24"
    k8sminion1.vm.hostname = vagrant_config['k8sminion1']['host_name']
    k8sminion1.vm.provision "shell", path: "provisioning/setup-minion.sh", privileged: false
    k8sminion1.vm.provider "virtualbox" do |vb|
      vb.name = vagrant_config['k8sminion1']['short_name']
       vb.memory = vagrant_config['k8sminion1']['memory']
       vb.cpus = vagrant_config['k8sminion1']['cpus']
       vb.customize [
           "guestproperty", "set", :id,
           "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 10000
          ]
    end
    k8sminion1.vm.provider "libvirt" do |lv, override|
      lv.memory = vagrant_config['k8sminion1']['memory']
      lv.cpus = vagrant_config['k8sminion1']['cpus']
      lv.nested = true
    end
  end
  config.vm.define "minion2" do |k8sminion2|
    k8sminion2.vm.network "private_network", ip: "192.168.56.12", netmask: "255.255.255.0", libvirt__network_name: "vagrant-ovn-kubernetes0", libvirt__network_address: "192.168.56.0/24"
    k8sminion2.vm.hostname = vagrant_config['k8sminion2']['host_name']
    k8sminion2.vm.provision "shell", path: "provisioning/setup-minion.sh", privileged: false
    k8sminion2.vm.provider "virtualbox" do |vb|
      vb.name = vagrant_config['k8sminion2']['short_name']
       vb.memory = vagrant_config['k8sminion2']['memory']
       vb.cpus = vagrant_config['k8sminion2']['cpus']
       vb.customize [
           "guestproperty", "set", :id,
           "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 10000
          ]
    end
    k8sminion2.vm.provider "libvirt" do |lv, override|
      lv.memory = vagrant_config['k8sminion2']['memory']
      lv.cpus = vagrant_config['k8sminion2']['cpus']
      lv.nested = true
    end
  end
end
