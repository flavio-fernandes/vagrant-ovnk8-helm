IP=""
while [ -z "$IP" ]; do
   IP=`ip addr show eth1 | grep 'inet' | grep -v inet6 |  awk '{print $2}' | awk -F\/ '{print $1}'`
done
echo "The IP address for master is $IP"

sudo rm -f /vagrant/kubeadm.log

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


sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    python3-pip

sudo mkdir -p /etc/apt/keyrings


# For containerd package
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# kubernetes components
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update

# Install containerd
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

# Install kubernetes
# apt-cache policy  kubelet : To get the version numbers
K8S_VERSION=1.29.2-1.1
sudo apt install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION

sudo apt-mark hold kubelet kubeadm kubectl

# To make sure that kubelet does not use vagrant's node local IP.
echo "KUBELET_EXTRA_ARGS=\"--node-ip=$IP\"" | sudo tee /etc/default/kubelet
sudo systemctl restart kubelet

# kubeadm init
sudo kubeadm init --pod-network-cidr=192.168.64.0/21 --apiserver-advertise-address=$IP \
  --service-cidr=172.31.1.0/24 --skip-phases addon/kube-proxy 2>&1 | tee kubeadm.log
grep -A1 "kubeadm join" kubeadm.log | sudo tee /vagrant/kubeadm.log

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Wait till kube-apiserver is up
while true; do
    kubectl get node `hostname`
    if [ $? -eq 0 ]; then
        break
    fi
    echo "waiting for kube-apiserver to be up"
    sleep 1
done

# Note: To delete kube-proxy daemonset, if there was one.
# The "--skip-phases addon/kube-proxy" flag above should be enough.
# kubectl -n kube-system delete daemonset kube-proxy ||:

# Add aliases
echo "alias k='kubectl'" >> .bashrc
echo "alias kk='kubectl -n kube-system'" >> .bashrc
echo "alias kn='kubectl -n ovn-kubernetes'" >> .bashrc
echo "alias ko='kubectl -n ovn-kubernetes'" >> .bashrc

# HACK YUCK: work around known issue with Helm on DNS config
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
echo "nameserver 9.9.9.9" | sudo tee /etc/resolv.conf
