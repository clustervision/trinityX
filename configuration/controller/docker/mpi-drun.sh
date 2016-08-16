#!/bin/bash

# If DOCKER_SHARES is defined, check if every host dir exists.
# Fail early otherwise.

if [[ ! -z $DOCKER_SHARES ]]; then

    for SHARE in $(echo "$DOCKER_SHARES" | tr ';' ' '); do
        DIR=$(echo "$SHARE" | cut -d':' -f1);

        [[ ! -d "$DIR" ]] && echo "$DIR not found on host. Aborting" && exit 1;

        VOLUMES="$VOLUMES -v $SHARE";
    done

fi

# Pull docker image if exists on registry; fail otherwise
# DOCKER_IMAGE is set in the job script

docker pull $DOCKER_IMAGE &>/dev/null && (

# Fetch user/group info (real uid is supplied by mpi-drun)
# since this script is run as root by mpi-drun (setuid)

USER_ID=$1
USER_NAME=$(id -u $1 -n)
GROUP_ID=$(id -g)
GROUP_NAME=$(id -gn)

# Set of commands to initialize a new container
# Will run the default docker entrypoint if already initialized

SET_ENV="if [[ ! -e /opt/mpi-drun ]]; then
            ssh-keygen -A &>/dev/null;

            groupadd -g $GROUP_ID $GROUP_NAME;
            useradd -u $USER_ID -g $GROUP_NAME -d /home/$USER_NAME -m -s /bin/bash $USER_NAME;

            mkdir /home/$USER_NAME/.ssh/;
            chmod 700 /home/$USER_NAME/.ssh/;

            echo 'Host *' > /home/$USER_NAME/.ssh/config;
            echo '    StrictHostKeyChecking no' >> /home/$USER_NAME/.ssh/config;
            echo '    Port 2222' >> /home/$USER_NAME/.ssh/config;

            chmod 600 /home/$USER_NAME/.ssh/config;
            chown -R $USER_NAME. /home/$USER_NAME/.ssh;

            tar xpf - -C /home/$USER_NAME;

            touch /opt/mpi-drun;
         else
            /docker-entrypoint.sh;
         fi
"

# Create and initialize a new container using image DOCKER_IMAGE
# The container will need to run an ssh daemon on port 2222

tar cpf - -C ~/ .ssh | docker run -i --name job-$SLURM_JOBID -p 2222:2222 --net host --entrypoint /bin/bash $VOLUMES $DOCKER_IMAGE -c "$SET_ENV"
docker start job-$SLURM_JOBID &>/dev/null

# Exit at this point if DOCKER_INIT is set
# This is to prevent nodes, aside from the HPN to run the mpi application.

[[ ! -z $DOCKER_INIT ]] && exit 0

# Create docker containers on all nodes allocated for this job
# This will skip the HPN

touch /tmp/hpn
su -c "DOCKER_IMAGE=$DOCKER_IMAGE DOCKER_SHARES=\"$DOCKER_SHARES\" DOCKER_INIT=1 srun --jobid $SLURM_JOBID /bin/bash -c '[[ -e /tmp/hpn ]] || mpi-drun'" - $USER_NAME
rm -f /tmp/hpn

# Run the mpi application
# APPLICATION is supplied in the job script

docker exec -i job-$SLURM_JOBID /bin/bash -lc "su -c \"mpirun --mca orte_base_help_aggregate 0 --host $(scontrol show hostname $SLURM_JOB_NODELIST | paste -d, -s) $APPLICATION\" - $USER_NAME"

# When done, delete the container from all the allocated nodes

su -c "srun --jobid $SLURM_JOBID mpi-drun clean" - $USER_NAME

) || (echo "Could not find the image $DOCKER_IMAGE in the registry" && exit 1);

