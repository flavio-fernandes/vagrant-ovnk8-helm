Kubernetes and OVN via Helm
===========================

This repo contains a Vagrant setup for Kubernetes and OVN integration.

It deploys K8s using kubeadm and OVN via Helm.

This has been tested with Virtualbox 7.0 on a Ubuntu 22.04 with
Vagrant 2.2.19.

How-to
------

From the cloned repository, run:

* vagrant up

Then:

* vagrant status
* vagrant ssh main
* kn get pod -owide --watch
