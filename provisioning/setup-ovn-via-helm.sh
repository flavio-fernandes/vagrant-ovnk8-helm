IP=""
while [ -z "$IP" ]; do
   IP=`ip addr show eth1 | grep 'inet' | grep -v inet6 |  awk '{print $2}' | awk -F\/ '{print $1}'`
done
echo "The IP address for master is $IP"

# optional: k9s
[ -x /usr/local/bin/k9s ] || {
    mkdir -pv /tmp/k9_install && cd /tmp/k9_install
    wget --quiet https://github.com/derailed/k9s/releases/download/v0.26.7/k9s_Linux_x86_64.tar.gz
    tar xzvf k9s_Linux_x86_64.tar.gz k9s
    chmod 755 ./k9s
    sudo mv -vf ./k9s /usr/local/bin/
}

# get helm
[ -x "/usr/local/bin/helm" ] || {
    mkdir -pv /tmp/helm_download && cd /tmp/helm_download
    wget -qO- https://get.helm.sh/helm-v3.14.2-linux-amd64.tar.gz | tar -xvzf -
    chmod 755 ./linux-amd64/helm
    sudo mv -v linux-amd64/helm /usr/local/bin/helm
}

# get ovn helm chart
[ -d "/home/vagrant/ovn-kubernetes" ] || {
    cd
    git clone https://github.com/flavio-fernandes/ovn-kubernetes.git \
        --depth 1 --branch xiaobinHelm
}

export CURRENT_CONTEXT=$(kubectl config current-context)
export APISERVER=$(kubectl config view --minify --context=$CURRENT_CONTEXT -o jsonpath='{.clusters[0].cluster.server}')

cd "/home/vagrant/ovn-kubernetes/helm/ovn-kubernetes" && \
  helm install ovn-kubernetes . -f values.yaml \
  --set k8sAPIServer=${APISERVER} \
  --set global.image.repository=ghcr.io/ovn-org/ovn-kubernetes/ovn-kube-u \
  --set global.image.tag=master && \
  echo ok
