
Running docker apps on a cluster
================================

TrinityX comes with the ability to run arbitrary dockerized MPI jobs on a cluster.
Please consult the `official docker documentation <https://docs.docker.com/>`_ for more information.

The only requirement to be able to run such jobs is to have openssh-server running in the container and listening on the non-standard port 2222.

It must also be kept in mind that the application that is to be run as an MPI job needs to be installed or pre-compiled in the container image.
All of its dependencies need to be installed/pre-compiled as well.

Building a docker image
-----------------------

To be able to run the dockerized MPI job you need first to provide it to the cluster as a docker image. To do so, two options are available:

Building on the controller
``````````````````````````

A trinityX controller comes pre-installed with docker and docker-registry (assuming that the docker option was selected at install time).
This makes it possible for an administrator to create a docker image that can subsequently be run on the cluster.

It is worth repeating here, in other words, that regular users cannot issue docker commands and that it is up to the admins to do so.

With that cleared-up, let's build a docker image that we can then use to run a hello world MPI job:

1. First we need to create an empty directory to serve as our workdir.
2. Let's write our application called `hello.c`. A simple search on the internet can provide us with many files we can use.
3. We also need a special file called `Dockerfile` that we will use to build the docker image; an example is provided below::

    FROM centos:latest
    RUN yum -y install epel-release && \
        yum -y install openssh-server openssh-clients \
                       environment-modules \
                       openmpi openmpi-devel libibverbs librdmacm && \
        yum clean all

    RUN echo "module load mpi" >> /etc/profile.d/openmpi.sh 
    RUN chmod +x /etc/profile.d/openmpi.sh

    COPY ./hello.c /opt/
    RUN /bin/bash -lc "mpicc -o /opt/hello /opt/hello.c"

    ENTRYPOINT ["/usr/sbin/sshd", "-p", "2222", "-D"]


As you can see, this Dockerfile satisfies the trinityX requirements as it sets up openssh-server correctly.
It also installs all the dependencies required to run our hello world application.

4. We then can build our image using `docker build`::

    docker build -t <controller-hostname>:5000/helloworld .

Make sure to replace <controller-hostname> with the correct hostname.

5. Lastly, we need to publish our image so that the compute nodes can fetch it when required::

    docker push <controller-hostname>:5000/helloworld


Using a remote docker registry
``````````````````````````````

If you prefer to build your images elsewhere and store them on a docker registry other than the one provided by trinityX then you need to update your compute images.
 
Since compute nodes will need to query a remote docker registry for docker images, this one needs to be decalred in `/etc/sysconfig/docker` in your compute images.

You can update it using `lchroot`.


Job scripts
-----------

Now that our image is ready, we need to create a job script that we will use to run our dockerized helloworld application.

A job script would need to include, the following commands (besides the usual directives):

- A docker image name::

    export DOCKER_IMAGE=<docker_image_to_run>

- A path to an executable::

    export APPLICATION=<path_to_mpi_app>

- Optionally, a list of shared folders and mount points::

    export DOCKER_SHARES="/host/share-1:/docker/mnt-1;/host/share-2:/docker/mnt-2;"

- The ``mpi-drun`` command

Following is an example that we can use to run our previous helloworld image::

    #!/bin/bash

    #SBATCH --partition=defq
    #SBATCH --nodes=2
    #SBATCH --ntasks-per-node=1
    #SBATCH --job-name="hello"

    export DOCKER_IMAGE="<controller-hostname>:5000/helloworld"
    export APPLICATION=/opt/hello
    mpi-drun

Then, as a user, you can submit the job using sbatch::

    sbatch job.sh

