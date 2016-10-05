Mesos Cluster Silent Installer
==============================

This is an utility script that helps with preparation, installation and deployment of a DC/OS Mesos Cluster.

Before you start
----------------

Clone the repository in the master node of the cluster

```
git clone https://github.com/lresende/mesos-cluster-install.git
cd mesos-cluster-install
```

**Update information related to your cluster in mesos-cluster.sh :**

- Hosts : A list of FQDN for all cluster nodes 
- Bootstrap : The FQDN for the DC/OS Boostrap node 
- Master Public : The public IP for the DC/OS Master

Installing DC/OS and deploying the cluster
------------------------------------------

Now that we have the cluster information properly configured in the mesos-cluster.sh, we can easily install the cluster issuing the following command :

```
sh mesos-cluster.sh
```

This will perform the following steps :

-	Perform a system update
-	Perform docker installation in the Boostrap node
-	Perform installation of DC/OS Boostrap scripts and perform instalation of the cluster

Now the cluster is ready to use. Point your browser to the URL below :

```
http://<master-public-ip>
```

Troubleshooting
---------------

Comming soon.
