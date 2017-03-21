#!/bin/bash

######################################################################
# TrinityX
# Copyright (c) 2016  ClusterVision B.V.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License (included with the sources) for more
# details.
######################################################################

# Pull docker image if exists on registry; fail otherwise
# DOCKER_IMAGE is set in the job script

if ! docker pull $DOCKER_IMAGE &>/dev/null; then
    echo "[ERR] Could not find the image $DOCKER_IMAGE in the registry" 1>&2;
    exit 1;
fi

# Fetch user/group info (real uid is supplied by mpi-drun)
# since this script is run as root by mpi-drun (setuid)

USER_ID=$1
USER_NAME=$(id -u $1 -n)
GROUP_ID=$(id -g)
GROUP_NAME=$(id -gn)

# If DOCKER_SHARES is defined, check if every host dir exists.
# Fail early otherwise.
# ~/.ssh is excluded in case a user mounts their home dir

if [[ ! -z $DOCKER_SHARES ]]; then

    for SHARE in $(echo "$DOCKER_SHARES" | tr ';' ' '); do
        DIR=$(echo "$SHARE" | cut -d':' -f1);

        [[ ! -e "$DIR" ]] && echo "[ERR] $DIR not found on host. Aborting" 1>&2 && exit 1;

        if [[ "x$DIR" == "x$HOME" ]]; then
            VOLUMES="$VOLUMES -v $SHARE -v /home/$USER_NAME/.ssh/";
        else
            VOLUMES="$VOLUMES -v $SHARE";
        fi
    done

fi

# Get list of nodes allocated to the job

NODE_LIST=$(scontrol show hostname $SLURM_JOB_NODELIST | paste -d, -s)

# Checks to be run on the HPN only
# (if DOCKER_INIT is not set)

if [[ -z $DOCKER_INIT ]]; then

    # Check if user has passwordless access to the nodes

    NODE=$(echo $NODE_LIST | cut -d',' -f2)

    su -c "ssh -oNumberOfPasswordPrompts=0 $NODE echo" $USER_NAME &>/dev/null
    if [[ $? != 0 ]]; then
        echo "[ERR] User $USER_NAME does not have passwordless access to $NODE_LIST" 1>&2
        exit 1
    fi

    # Check if WORKDIR is supplied
    
    [[ -z $DOCKER_WORKDIR ]] && \
    echo "[WARN] No DOCKER_WORKDIR has been supplied." \
    "This may cause issues if $APPLICATION looks for data in the same directory." 1>&2;

    # Check if extra MPI parameters are supplied

    [[ -z $MPI_OPTS ]] && \
    echo "[WARN] No MPI parameters are supplied. mpirun will be invoked without any." 1>&2;
    
fi

# Save the image's entrypoint
# Docker inspect provides values in the format: {[/path/to/cmd --params]}

IMAGE_ENTRYPOINT="$(docker inspect -f '{{.Config.Entrypoint}}' $DOCKER_IMAGE | cut -d'[' -f2 | cut -d']' -f1)"

# Set of commands to initialize a new container
# Will run the image's entrypoint if already initialized

SET_ENV="if [[ ! -e /opt/mpi-drun ]]; then
            ssh-keygen -A &>/dev/null;

            groupadd -g $GROUP_ID $GROUP_NAME;
            useradd -u $USER_ID -g $GROUP_NAME -d /home/$USER_NAME -m -s /bin/bash $USER_NAME 2>/dev/null;
            usermod -a -G \$(stat -c '%G' $DOCKER_WORKDIR) $USER_NAME;

            mkdir -p /home/$USER_NAME/.ssh/;
            tar xpf - -C /home/$USER_NAME;

            echo 'Host *' > /home/$USER_NAME/.ssh/config;
            echo '    StrictHostKeyChecking no' >> /home/$USER_NAME/.ssh/config;
            echo '    Port 2222' >> /home/$USER_NAME/.ssh/config;

            chmod 700 /home/$USER_NAME/.ssh/;
            chmod 600 /home/$USER_NAME/.ssh/config;
            chown -R $USER_NAME. /home/$USER_NAME/.ssh;

            touch /opt/mpi-drun;
         else
            $IMAGE_ENTRYPOINT;
         fi
"

# Detect present infiniband/infinipath devices if any
# These need to be exposed to the docker containers

if [[ -d "/sys/class/infiniband" ]]; then
    IB_DEVICES=$(find /dev/infiniband -printf " --device=%p")
fi

if [[ -e /dev/ipath ]]; then
    IB_DEVICES=${IB_DEVICES}$(find /dev/ipath -printf " --device=%p")
fi

for DEV in $(ls /dev/hfi* 2>/dev/null); do
    IB_DEVICES="${IB_DEVICES} --device=$DEV";
done

# Create and initialize a new container using image DOCKER_IMAGE
# The container will need to run an ssh daemon on port 2222

tar cpf - -C ~/ .ssh | docker run -i \
                                  --ulimit memlock=819200000:819200000 \
                                  --name job-$SLURM_JOBID \
                                  -p 2222:2222 \
                                  --net host \
                                  --entrypoint /bin/bash \
                                  $VOLUMES \
                                  $IB_DEVICES \
                                  $DOCKER_IMAGE \
                                  -c "$SET_ENV"

docker start job-$SLURM_JOBID &>/dev/null

# Exit at this point if DOCKER_INIT is set
# This is to prevent nodes, aside from the HPN to run the mpi application.

[[ ! -z $DOCKER_INIT ]] && exit 0

# Create docker containers on all nodes allocated for this job
# This will skip the HPN

touch /tmp/hpn

su -c "DOCKER_WORKDIR=$DOCKER_WORKDIR \
       DOCKER_IMAGE=$DOCKER_IMAGE \
       DOCKER_SHARES=\"$DOCKER_SHARES\" \
       DOCKER_INIT=1 \
       srun --jobid $SLURM_JOBID /bin/bash -c '[[ -e /tmp/hpn ]] || mpi-drun'\
      " - $USER_NAME

rm -f /tmp/hpn

# Run the mpi application
# APPLICATION is supplied in the job script

docker exec -i job-$SLURM_JOBID /bin/bash -lc "su -c \"cd $DOCKER_WORKDIR; 
                                                       mpirun $MPI_OPTS --host $NODE_LIST $APPLICATION
                                                     \" $USER_NAME"

# When done, delete the container from all the allocated nodes

su -c "srun --jobid $SLURM_JOBID mpi-drun clean" - $USER_NAME

