sample_app - A Sample CoreOS ELKstack application 
=================================================

This is a sample application for running on CoreOS and is for the most part based off of the fine work by Marcel DeGraaf in his two blog posts:

Part1: http://marceldegraaf.net/2014/04/24/experimenting-with-coreos-confd-etcd-fleet-and-cloudformation.html

Part2: http://marceldegraaf.net/2014/05/05/coreos-follow-up-sinatra-logstash-elasticsearch-kibana.html

And his repositories contain files to back these two blog posts are:

Part 1: https://github.com/marceldegraaf/blog-coreos-1

Part 2: https://github.com/marceldegraaf/blog-coreos-2

## Prerequisites

You will need a working CoreOS setup. There are a number of implementations. The one used initially in this example is the Vagrant CoreOS setup, using the VMWare driver. The Vagrant CoreOS information can be found at https://coreos.com/docs/running-coreos/platforms/vagrant/. The important thing is to make sure to have the most up to date box.

### Set up Discovery

Make sure to set up discovery for the CoreOS boxes prior to starting them. This can easily be done with uncommenting the lines in the file you copied as config.rb.sample that starts with "# To automatically replace the discovery token on 'vagrant up', uncomment"

### Set up SSH
When you run ```vagrant up```, there will be three CoreOS boxes that are running. One thing that will make life easier is to run the following:


## SSH setup for Vagrant

To make sure that fleet can talk to other as well as make SSH to your hosts not require ```vagrant ssh```, run the following commands that first will add the vagrant hosts to ```~/.ssh/config``` as well as put the ssh key on all of the boxes. 

```
/path/vagrant-coreos $ vagrant ssh-config>> ~/.ssh/config
/path/vagrant-coreos $ scp -i ~/.vagrant.d/insecure_private_key ~/.vagrant.d/insecure_private_key core@core-02:/home/core/.ssh
```


## Verify Fleet is running

### Access one of the CoreOS boxes 

SSH into the host:
```$ ssh core-1```


### Verify cluster machines membership

Verify what machines are in the cluster:
```
core@core-01 ~ $ fleetctl list-machines
MACHINE		IP		METADATA
78927354...	172.17.8.102	-
ce81f0d7...	172.17.8.103	-
fee4602c...	172.17.8.101	-
```

### Verify that there are no units running

```
core@core-01 ~ $ fleetctl list-units
UNIT	MACHINE	ACTIVE	SUB
```

## Install and setup the test application 

### Pre-pull the Docker images on each of the boxes in the cluster (this will be automated by Ansible)

```core@core-01 ~ $ docker pull capttofu/elasticsearch```
```core@core-01 ~ $ docker pull capttofu/logstash```
```core@core-01 ~ $ docker pull capttofu/sinatra-with-logstash```
```core@core-01 ~ $ docker pull capttofu/nginx```


The following steps can be run from one of the boxes or locally. The requirement is that you have fleet set up. This is obviously already working on the CoreOS boxes, though it is probably easier to do this from one place, so setting up Fleet on the workstation is desirable.

### Check out the application project repo

```$ git clone https://github.com/HPATG/sample_app```

### Unit file submission and starting 

#### Elasticsearch 

In the project repo, there will be a number of systemd unit files. These will have to be submitted and started. The first one is for Elasticsearch:

```
core@core-02 ~/sample_app $ fleetctl submit unit_files/elasticsearch.service
```
Verify it was submitted:

```
core@core-02 ~/sample_app $ fleetctl list-unit-files
UNIT			HASH	DSTATE		STATE		TARGET
elasticsearch.service	9e8ae4f	inactive	inactive	-
```

Start the Elasticsearch service:

```
core@core-02 ~/sample_app $ fleetctl start elasticsearch.service
Unit elasticsearch.service launched on 78927354.../172.17.8.102
```

Verify that it has started the service:

```
core@core-02 ~/sample_app $ fleetctl list-units
UNIT			MACHINE				ACTIVE	SUB
elasticsearch.service	78927354.../172.17.8.102	active	running
```

It is also possible to use the journal to observe a service:

```
$ fleetctl journal -f elasticsearch.service
-- Logs begin at Mon 2014-11-17 23:19:08 UTC. --
Nov 20 01:05:20 core-02 docker[23678]: [2014-11-20 01:05:20,332][INFO ][node                     ] [Tess-One] initializing ...
Nov 20 01:05:20 core-02 docker[23678]: [2014-11-20 01:05:20,342][INFO ][plugins                  ] [Tess-One] loaded [], sites [kopf, kibana3]
Nov 20 01:05:23 core-02 docker[23678]: [2014-11-20 01:05:23,273][INFO ][node                     ] [Tess-One] initialized
Nov 20 01:05:23 core-02 docker[23678]: [2014-11-20 01:05:23,274][INFO ][node                     ] [Tess-One] starting ...
Nov 20 01:05:23 core-02 docker[23678]: [2014-11-20 01:05:23,349][INFO ][transport                ] [Tess-One] bound_address {inet[/0:0:0:0:0:0:0:0:9300]}, publish_address {inet[/10.0.0.11:9300]}
Nov 20 01:05:26 core-02 docker[23678]: [2014-11-20 01:05:26,408][INFO ][cluster.service          ] [Tess-One] new_master [Tess-One][xoYqROQ8T86PUDYPgr3eCQ][006d83578c5a][inet[/10.0.0.11:9300]], reason: zen-disco-join (elected_as_master)
```

#### Logstash

The next service, Logstash, the same steps that were used for submitting, starting, and verifying the Elasticsearch service can be repeated:

```
core@core-02 ~/sample_app $ fleetctl submit unit_files/logstash.service
```
```
core@core-02 ~/sample_app $ fleetctl list-unit-files
UNIT			HASH	DSTATE		STATE		TARGET
elasticsearch.service	9e8ae4f	launched	launched	78927354.../172.17.8.102
logstash.service	29c35f3	inactive	inactive	-
```
```
core-02 ~/sample_app $ fleetctl start logstash.service
Unit logstash.service launched on ce81f0d7.../172.17.8.103
```
```
core@core-02 ~/sample_app $ fleetctl list-units
UNIT			MACHINE				ACTIVE	SUB
elasticsearch.service	78927354.../172.17.8.102	active	running
logstash.service	ce81f0d7.../172.17.8.103	active	running
```

Now browse to the IP address for the Elasticsearch web admin interface on port 9200. In this example, it would be http://172.17.8.102:9200/_plugin/kopf/

#### Sinatra 

In this case, 4 Sinatra services:

```
core@core-02 ~/sample_app $ fleetctl submit unit_files/sinatra\@500{0..3}.service
```
```
core@core-02 ~/sample_app $ fleetctl list-unit-files
UNIT			HASH	DSTATE		STATE		TARGET
elasticsearch.service	9e8ae4f	launched	launched	78927354.../172.17.8.102
logstash.service	29c35f3	launched	launched	ce81f0d7.../172.17.8.103
sinatra@5000.service	055d9cf	inactive	inactive	-
sinatra@5001.service	055d9cf	inactive	inactive	-
sinatra@5002.service	055d9cf	inactive	inactive	-
sinatra@5003.service	055d9cf	inactive	inactive	-
```

```
core@core-02 ~/sample_app $ fleetctl start sinatra@500{0..3}.service
Unit sinatra@5002.service launched on ce81f0d7.../172.17.8.103
Unit sinatra@5001.service launched on 78927354.../172.17.8.102
Unit sinatra@5003.service launched on fee4602c.../172.17.8.101
Unit sinatra@5000.service launched on fee4602c.../172.17.8.101
```

```
core@core-02 ~/sample_app $ fleetctl list-units
UNIT			MACHINE				ACTIVE	SUB
elasticsearch.service	78927354.../172.17.8.102	active	running
logstash.service	ce81f0d7.../172.17.8.103	active	running
sinatra@5000.service	fee4602c.../172.17.8.101	active	running
sinatra@5001.service	78927354.../172.17.8.102	active	running
sinatra@5002.service	ce81f0d7.../172.17.8.103	active	running
sinatra@5003.service	fee4602c.../172.17.8.101	active	running
```

#### Nginx

```
core@core-02 ~/sample_app $ fleetctl submit unit_files/nginx.service
```
```
core@core-02 ~/sample_app $ fleetctl start nginx.service
Unit nginx.service launched on 78927354.../172.17.8.102
```
```
core@core-02 ~/sample_app $ fleetctl list-units
UNIT			MACHINE				ACTIVE	SUB
elasticsearch.service	78927354.../172.17.8.102	active	running
logstash.service	ce81f0d7.../172.17.8.103	active	running
nginx.service		78927354.../172.17.8.102	active	running
sinatra@5000.service	fee4602c.../172.17.8.101	active	running
sinatra@5001.service	78927354.../172.17.8.102	active	running
sinatra@5002.service	ce81f0d7.../172.17.8.103	active	running
sinatra@5003.service	fee4602c.../172.17.8.101	active	running
```

### Using the app

#### Manually access the Sinatra web app

The nginx service is running on machine 78927354, 172.17.8.102 in this example. The web address for the application is simply http://172.17.8.102. Verify that it simply has an output of "Hello world!". 

#### Verify that the single access shows up in Kibana

The Elasticsearch service is also running on 172.17.8.102. To access Kibana, go to http://172.17.8.102:9200/_plugin/kibana3/index.html#/dashboard/file/logstash.json. The single access should show up in "EVENTS OVER TIME". 

#### Run the benchmark script

In the sample_app repository, there is the bin directory which contains a script ```benchmark.rb```. It runs 8 threads in a loop against whatever URL is specified. This is simply no generate traffic against the app hence have results show up in Kibana. 

```
$ ./benchmark.rb http://172.17.8.102
Accessing http://172.17.8.102
loop 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25....
```

#### Observe accesses due to benchmark script in Kibana. 

Again, access the URL http://172.17.8.102:9200/_plugin/kibana3/index.html#/dashboard/file/logstash.json and observe accesses showing up in the graph. If this script is allowed to run for a prolonged period, then there will be a good asmple of data to get a idea of what this example app does. 


## Dealing with issues

In the following example, a unit failed to start. In most cases, the unit can be destroyed, re-submitted, and then restarted the problem should be resolved. However, in this particular instance, having to access the machine in the cluster with the problem and remove the offending docker container was required.

Listing of units showed a problem:

```
core@core-02 ~/sample_app $ fleetctl list-units
UNIT			MACHINE				ACTIVE	SUB
elasticsearch.service	78927354.../172.17.8.102	active	running
logstash.service	ce81f0d7.../172.17.8.103	active	running
nginx.service		78927354.../172.17.8.102	active	running
sinatra@5000.service	fee4602c.../172.17.8.101	active	running
sinatra@5001.service	78927354.../172.17.8.102	active	running
sinatra@5002.service	ce81f0d7.../172.17.8.103	active	running
sinatra@5003.service	fee4602c.../172.17.8.101	failed	failed
```

Using journal, the problem can be seen:

```
core@core-02 ~/sample_app $ fleetctl journal -f sinatra@5003.service
The authenticity of host '172.17.8.101' can't be established.
RSA key fingerprint is 1d:09:d9:d5:ec:51:68:f2:9c:69:4b:7f:51:cf:c3:a6.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '172.17.8.101' (RSA) to the list of known hosts.
-- Logs begin at Mon 2014-11-17 23:18:21 UTC. --
Nov 19 22:14:00 core-01 systemd[1]: Stopped sinatra.
Nov 19 22:14:07 core-01 systemd[1]: Starting sinatra...
Nov 19 22:14:07 core-01 docker[12425]: Pulling repository capttofu/sinatra-with-logstash
Nov 19 22:14:09 core-01 docker[12425]: Status: Image is up to date for capttofu/sinatra-with-logstash:latest
Nov 19 22:14:09 core-01 docker[12431]: 2014/11/19 22:14:09 Error response from daemon: Conflict, The name sinatra-5003 is already assigned to 44364c8ae2d7. You have to delete (or rename) that container to be able to assign sinatra-5003 to a container again.
Nov 19 22:14:09 core-01 systemd[1]: sinatra@5003.service: main process exited, code=exited, status=1/FAILURE
Nov 19 22:14:09 core-01 etcdctl[12432]: 172.17.8.101:5003
Nov 19 22:14:09 core-01 docker[12444]: sinatra-5003
Nov 19 22:14:09 core-01 systemd[1]: Failed to start sinatra.
Nov 19 22:14:09 core-01 systemd[1]: Unit sinatra@5003.service entered failed state.
```

Attempt at destroying the container:

```
core@core-02 ~/sample_app $ fleetctl destroy sinatra@5003.service
Destroyed sinatra@5003.service
```

Re-submit and start
```
core@core-02 ~/sample_app $ fleetctl submit unit_files/sinatra@5003.service
```
```
core@core-02 ~/sample_app $ fleetctl start sinatra@5003.service
Unit sinatra@5003.service launched on fee4602c.../172.17.8.101
```

Verification shows that destroying and restarting did not solve the issue:

```
core@core-02 ~/sample_app $ fleetctl list-units
UNIT			MACHINE				ACTIVE	SUB
elasticsearch.service	78927354.../172.17.8.102	active	running
logstash.service	ce81f0d7.../172.17.8.103	active	running
nginx.service		78927354.../172.17.8.102	active	running
sinatra@5000.service	fee4602c.../172.17.8.101	active	running
sinatra@5001.service	78927354.../172.17.8.102	active	running
sinatra@5002.service	ce81f0d7.../172.17.8.103	active	running
sinatra@5003.service	fee4602c.../172.17.8.101	failed	failed
```

In this case, ```fleetctl destroy``` didn't work. More hands-on fixing is required.

Using the information from journal, and the above information of what machine corresponds to fee4602c, 172.17.8.101, which corresponds to core-01, access that machine, find out the ID of the container in question and remove it.

View all containers, even those that are no longer running. The one in question has no value for ```STATUS```, hence is the offending container:

```
core@core-01 ~ $ docker ps -a
CONTAINER ID        IMAGE                                   COMMAND                CREATED             STATUS              PORTS                    NAMES
44364c8ae2d7        capttofu/sinatra-with-logstash:latest   "/bin/sh -c /boot.sh   3 minutes ago                                                    sinatra-5003
ea10b8daceaa        capttofu/sinatra-with-logstash:latest   "/bin/sh -c /boot.sh   3 minutes ago       Up 3 minutes        0.0.0.0:5000->5000/tcp   sinatra-5000
```

Remove the offending container and verify:
```
core@core-01 ~ $ docker rm 44364c8ae2d7
44364c8ae2d7
core@core-01 ~ $ docker ps -a
CONTAINER ID        IMAGE                                   COMMAND                CREATED             STATUS              PORTS                    NAMES
ea10b8daceaa        capttofu/sinatra-with-logstash:latest   "/bin/sh -c /boot.sh   3 minutes ago       Up 3 minutes        0.0.0.0:5000->5000/tcp   sinatra-5000
```

Back on the server you are performing work on, destroy, submit, and re-start:

```
core@core-02 ~/sample_app $ fleetctl destroy sinatra@5003.service
Destroyed sinatra@5003.service
core@core-02 ~/sample_app $ fleetctl submit unit_files/sinatra@5003.service
core@core-02 ~/sample_app $ fleetctl start sinatra@5003.service
Unit sinatra@5003.service launched on fee4602c.../172.17.8.101
core@core-02 ~/sample_app $ fleetctl list-units
UNIT			MACHINE				ACTIVE	SUB
elasticsearch.service	78927354.../172.17.8.102	active	running
logstash.service	ce81f0d7.../172.17.8.103	active	running
nginx.service		78927354.../172.17.8.102	active	running
sinatra@5000.service	fee4602c.../172.17.8.101	active	running
sinatra@5001.service	78927354.../172.17.8.102	active	running
sinatra@5002.service	ce81f0d7.../172.17.8.103	active	running
sinatra@5003.service	fee4602c.../172.17.8.101	active	running
```

All is well now!
