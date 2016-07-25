#!/bin/bash
set -e
source "$POST_CONFIG"
source /etc/trinity.sh
source "$TRIX_SHADOW"

echo_info "Check if variables are defined."

echo "MONGODB_FLOATING_HOST=${MONGODB_FLOATING_HOST:?"Should be defined"}"
echo "MONGODB_MASTER_HOST=${MONGODB_MASTER_HOST:?"Should be defined"}"
echo "MONGODB_SLAVE_HOST=${MONGODB_SLAVE_HOST:?"Should be defined"}"
LUNA_MONGO_ROOT_PASS=`get_password $LUNA_MONGO_ROOT_PASS`

echo "LUNA_MONGO_ROOT_PASS=${LUNA_MONGO_ROOT_PASS:?"Should be defined"}" >/dev/null

echo_info "Check if remote host is available."

MONGODB_SLAVE_HOSTNAME=`/usr/bin/ssh ${MONGODB_SLAVE_HOST} hostname || (echo_error "Unable to connect to ${MONGODB_SLAVE_HOST}"; exit 1)`

echo_info "Create key file."

/usr/bin/openssl rand -base64 741 > /etc/mongo.key
/usr/bin/chown mongodb: /etc/mongo.key
/usr/bin/chmod 400 /etc/mongo.key

echo_info "Change mongod.conf file."

/usr/bin/sed -i -e "s/^[#\t ]*bind_ip = .*/bind_ip = 127.0.0.1,${MONGODB_MASTER_HOST}/"  /etc/mongod.conf
/usr/bin/sed -i -e "s/^[#\t ]*keyFile = .*/keyFile = \/etc\/mongo.key/"  /etc/mongod.conf
/usr/bin/sed -i -e "s/^[#\t ]*replSet = .*/replSet = luna/"  /etc/mongod.conf

echo_info "Stop luna services."

/usr/bin/systemctl stop lweb
/usr/bin/systemctl stop ltorrent

echo_info "Restart MongoDB service"

/usr/bin/systemctl restart mongod


echo_info "Initiate replica set."

/usr/bin/mongo -u root -p${LUNA_MONGO_ROOT_PASS} --authenticationDatabase admin <<EOF
rs.initiate()
EOF

echo_info "Start luna services."

/usr/bin/systemctl start ltorrent
/usr/bin/systemctl start lweb

echo_info "Configure slave node."

/usr/bin/cp /etc/mongod.conf /etc/mongod-slave.conf
/usr/bin/sed -i -e "s/^[#\t ]*bind_ip = .*/bind_ip = 127.0.0.1,${MONGODB_SLAVE_HOST}/"  /etc/mongod-slave.conf
/usr/bin/scp /etc/mongod-slave.conf ${MONGODB_SLAVE_HOST}:/etc/mongod.conf
/usr/bin/scp /etc/mongo.key ${MONGODB_SLAVE_HOST}:/etc/mongo.key
/usr/bin/scp ~/.mongorc.js ${MONGODB_SLAVE_HOST}:~/.mongorc.js
/usr/bin/ssh ${MONGODB_SLAVE_HOST} "/usr/bin/chown mongodb: /etc/mongo.key"
/usr/bin/ssh ${MONGODB_SLAVE_HOST} "/usr/bin/chmod 400 /etc/mongo.key"

echo_info "Restart MongoDB on slave node."

/usr/bin/ssh ${MONGODB_SLAVE_HOST} "/usr/bin/systemctl restart mongod"

echo_info "Add slave host to replica set."

/usr/bin/mongo -u root -p${LUNA_MONGO_ROOT_PASS} --authenticationDatabase admin <<EOF
rs.add("${MONGODB_SLAVE_HOST}")
EOF

echo_info "Get status."

/usr/bin/mongo -u root -p${LUNA_MONGO_ROOT_PASS} --authenticationDatabase admin <<EOF
rs.status()
EOF

echo_info "Setup MongoDB arbiter."

/usr/bin/cp /etc/mongod.conf /etc/mongod-arbiter.conf
/usr/bin/sed -i \
-e "s/^[#\t ]*bind_ip = .*/bind_ip = 127.0.0.1,${MONGODB_FLOATING_HOST}/"  \
-e "s/^[#\t ]*port = .*/port = 27018/" \
-e "s/^[#\t ]*pidfilepath = .*/pidfilepath = \/var\/run\/mongodb-arbiter\/mongod.pid/" \
-e "s/^[#\t ]*logpath = .*/logpath = \/var\/log\/mongodb\/mongod-arbiter.log/" \
-e "s/^[#\t ]*unixSocketPrefix = .*/unixSocketPrefix = \/var\/run\/mongodb-arbiter/" \
-e "s/^[#\t ]*dbpath = .*/dbpath = \/var\/lib\/mongodb-arbiter/" \
-e "s/^[#\t ]*nojournal = .*/nojournal = true/" \
-e "s/^[#\t ]*noprealloc = .*/noprealloc = true/" \
-e "s/^[#\t ]*smallfiles = .*/smallfiles = true/" \
/etc/mongod-arbiter.conf

/usr/bin/cp ${POST_FILEDIR}/mongod-arbiter-sysconfig /etc/sysconfig/mongod-arbiter
/usr/bin/cp ${POST_FILEDIR}/mongod-arbiter.service /etc/systemd/system/mongod-arbiter.service

/usr/bin/systemctl daemon-reload


/usr/bin/mkdir /var/lib/mongodb-arbiter
/usr/bin/chown mongodb:root /var/lib/mongodb-arbiter
/usr/bin/chmod 750 /var/lib/mongodb-arbiter

/usr/bin/systemctl start mongod-arbiter

echo_info "Add arbiter to replica set."

/usr/bin/mongo -u root -p${LUNA_MONGO_ROOT_PASS} --authenticationDatabase admin <<EOF
rs.addArb("${MONGODB_FLOATING_HOST}:27018")
EOF

echo_info "Stop arbiter and copy its data to slave host."

/usr/bin/systemctl stop mongod-arbiter
TMPFILE=$(/usr/bin/mktemp)
pushd /
/usr/bin/tar -S -czf ${TMPFILE} /etc/mongod-arbiter.conf /etc/sysconfig/mongod-arbiter /etc/systemd/system/mongod-arbiter.service /var/lib/mongodb-arbiter
popd
/usr/bin/scp -pr ${TMPFILE} ${MONGODB_SLAVE_HOST}:${TMPFILE}
/usr/bin/ssh ${MONGODB_SLAVE_HOST} "cd / && /usr/bin/tar -xzf ${TMPFILE}"

/usr/bin/ssh ${MONGODB_SLAVE_HOST} "/usr/bin/mkdir /var/lib/mongodb-arbiter"
/usr/bin/ssh ${MONGODB_SLAVE_HOST} "/usr/bin/chown mongodb:root /var/lib/mongodb-arbiter"
/usr/bin/ssh ${MONGODB_SLAVE_HOST} "/usr/bin/chmod 750 /var/lib/mongodb-arbiter"

echo_info "Get status."

/usr/bin/mongo -u root -p${LUNA_MONGO_ROOT_PASS} --authenticationDatabase admin <<EOF
rs.status()
EOF
