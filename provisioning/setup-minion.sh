IP=""
while [ -z "$IP" ]; do
   IP=`ip addr show eth1 | grep 'inet' | grep -v inet6 |  awk '{print $2}' | awk -F\/ '{print $1}'`
done
echo "The IP address for minion is $IP"

sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv6.conf.all.rp_filter = 0
EOF

# apply above config
sudo sysctl --system

# Install crictl

VERSION="v1.29.0" # check latest version from https://github.com/kubernetes-sigs/cri-tools/releases
curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-${VERSION}-linux-amd64.tar.gz --output crictl-${VERSION}-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz

# Install containerd

sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y containerd.io

sudo mkdir -p /etc/containerd
# containerd config default is a command on the binary containerd
sudo sh -c 'containerd config default>/etc/containerd/config.toml'

# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd
sudo sed -i 's/SystemdCgroup.*/SystemdCgroup = true/g' /etc/containerd/config.toml

sudo systemctl enable --now containerd
#sudo systemctl status containerd
sudo systemctl restart containerd

# Verify containerd:
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps

# kubernetes components
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://dl.k8s.io/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
# Install OVS
sudo apt-get install openvswitch-common openvswitch-switch -y

# apt-cache policy  kubelet : To get the version numbers
K8S_VERSION=1.28.2-00
sudo apt install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION

sudo apt-mark hold kubelet kubeadm kubectl

# Make sure that kubelet uses the non-local vagrant IP at eth0
echo "KUBELET_EXTRA_ARGS=\"--node-ip=$IP\"" | sudo tee /etc/default/kubelet
sudo systemctl restart kubelet

start_time=$(date +%s)
# Loop until the file exists and is not empty, or until it is time to give up
while true; do
    if [ -s /vagrant/kubeadm.log ]; then
        break
    fi

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ "$elapsed_time" -ge 600 ]; then
        >&2 echo "Timeout: /vagrant/kubeadm.log is still empty or does not exist."
        exit 1
    fi

    echo "Waiting for /vagrant/kubeadm.log to be populated..."
    sleep 10
done

# Start kubelet join the cluster
cat /vagrant/kubeadm.log > kubeadm_join.sh
sudo sh kubeadm_join.sh
