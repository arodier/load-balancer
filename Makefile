##############################################################################
# BASIC TARGETS TO BUILD AND RUN THE PROGRAM
##############################################################################

# Standard env
GO ?= /usr/bin/go
MARKDOWN ?= /usr/bin/markdown
BUILD_OPTIONS ?= -race
PORT ?= 8484
IP ?= 127.0.0.1
URL ?= http://$(IP):$(PORT)/

all: clean build

clean:
	@echo "Removing binaries"
	@rm -rf lib bin

dirs:
	@echo "Creating temporary/working directories"
	@test -d tmp || mkdir tmp
	@test -d instances || mkdir instances
	@test -d tests || mkdir tests
	@test -d tests/images || mkdir tests/images
	@test -d tests/temp || mkdir tests/temp
	@test -d logs || mkdir logs

build:
	@echo -n "Building the program: "
	@$(GO) build $(BUILD_OPTIONS) -o bin/sains src/main.go && echo 'OK'


##############################################################################
# DEPLOYMENT
# rsync or simple scp is OK for this demo.
# But ansible would be better for more than just a files
##############################################################################

deploy-remus:
	@echo 'Deploying backend on remus'
	scp -p -i deploy/id_rsa -P 2284 deploy/service.sh root@localhost:/etc/init.d/sains
	ssh -i deploy/id_rsa -p 2284 root@localhost service sains stop
	scp -p -i deploy/id_rsa -P 2284 bin/sains root@localhost:/usr/bin/sains
	ssh -i deploy/id_rsa -p 2284 root@localhost update-rc.d sains defaults
	ssh -i deploy/id_rsa -p 2284 root@localhost service sains start
	ssh -i deploy/id_rsa -p 2284 root@localhost ifconfig eth0 >tmp/remus.ifconfig
	cat tmp/remus.ifconfig|grep 'inet addr'|sed -r 's/.*addr:([0-9\.]+) .*/\1/' >tmp/remus.ip

deploy-romulus:
	@echo 'Deploying backend on romulus'
	scp -p -i deploy/id_rsa -P 2285 deploy/service.sh root@localhost:/etc/init.d/sains
	ssh -i deploy/id_rsa -p 2285 root@localhost service sains stop
	scp -p -i deploy/id_rsa -P 2285 bin/sains root@localhost:/usr/bin/sains
	ssh -i deploy/id_rsa -p 2285 root@localhost update-rc.d sains defaults
	ssh -i deploy/id_rsa -p 2285 root@localhost service sains start
	ssh -i deploy/id_rsa -p 2285 root@localhost ifconfig eth0 >tmp/romulus.ifconfig
	cat tmp/romulus.ifconfig|grep 'inet addr'|sed -r 's/.*addr:([0-9\.]+) .*/\1/' >tmp/romulus.ip

deploy-backends: deploy-remus deploy-romulus

deploy-rhea:
	echo 'Deploying the web front end on Rhea'
	cp deploy/nginx.conf /tmp
	sed -i s/ROMULUS_IP/`cat tmp/romulus.ip`/ /tmp/nginx.conf
	sed -i s/REMUS_IP/`cat tmp/remus.ip`/ /tmp/nginx.conf
	ssh -i deploy/id_rsa -p 2280 root@localhost apt-get -y install nginx
	scp -i deploy/id_rsa -P 2280 /tmp/nginx.conf root@localhost:/etc/nginx/sites-available/sains.conf
	ssh -i deploy/id_rsa -p 2280 root@localhost ln -nsf /etc/nginx/sites-available/sains.conf /etc/nginx/sites-enabled/sains.conf
	ssh -i deploy/id_rsa -p 2280 root@localhost rm -f /etc/nginx/sites-enabled/default
	ssh -i deploy/id_rsa -p 2280 root@localhost service nginx restart
	rm -f /tmp/nginx.conf


##############################################################################
# INSTALL NEEDED PACKAGES FOR DOCKER AND ANSIBLE.
##############################################################################
packages:
	@echo 'Installing needed packages (docker/debootstrap/ansible/etc.)'
	sudo apt-get -qq install debootstrap docker.io ansible

##############################################################################
# CREATE THE FULL DOCKER IMAGES FOR TESTING / RUNNING
##############################################################################

ssh-cleanup:
	ssh-keygen -f ~/.ssh/known_hosts -R '[localhost]:2280'
	ssh-keygen -f ~/.ssh/known_hosts -R '[localhost]:2284'
	ssh-keygen -f ~/.ssh/known_hosts -R '[localhost]:2285'

# Dynamically generate a new SSH key used for deployment
ssh-keys: ssh-cleanup
	rm -f deploy/id_rsa deploy/id_rsa.pub
	ssh-keygen -N '' -q -C 'sains-auth-key' -t rsa -b 2048 -f deploy/id_rsa

# Create a full Debian Jessie image, using debootstrap
# This is needed only once, to run the tests on a Debian machine
image-jessie: packages dirs ssh-keys
	@echo "Creating image: Debian Jessie, this may take a while, have a coffee…"
	sudo debootstrap jessie instances/jessie/
	sudo test -d instances/jessie/root/.ssh || sudo mkdir instances/jessie/root/.ssh
	sudo cp -f deploy/id_rsa.pub instances/jessie/root/.ssh/authorized_keys
	sudo bash -c "cd instances/jessie/ && tar cf ../../tmp/jessie.tar ."
	sudo chown $(USER):$(USER) tmp/jessie.tar
	mv tmp/jessie.tar tests/images/
	sudo rm -rf jessie

##############################################################################
# DOCKER TARGETS  BUILDING, STARTING AND STOPPING
##############################################################################

# Import the Jessie image
docker-jessie-import:
	test -f tests/images/jessie.tar || make image-jessie
	sudo docker import - debootstrap/jessie < tests/images/jessie.tar

# Build jessie
docker-jessie-build: docker-jessie-import
	sudo docker build -t=sains-server - < deploy/debian-jessie.runit

# Run jessie instance 1: remus
docker-jessie-start-remus:
	sudo docker run -d -h remus -p 2284:22 -p 9084:8484 --cidfile=tests/temp/remus-server.id sains-server
	ssh-keyscan -p 2284 -H localhost >>~/.ssh/known_hosts

# Run jessie instance 2: romulus
docker-jessie-start-romulus:
	sudo docker run -d -h romulus -p 2285:22 -p 9085:8484 --cidfile=tests/temp/romulus-server.id sains-server
	ssh-keyscan -p 2285 -H localhost >>~/.ssh/known_hosts

# Web front end: rhea
docker-jessie-start-rhea:
	sudo docker run -d -h rhea -p 2280:22 -p 9080:80 --cidfile=tests/temp/rhea-server.id sains-server
	ssh-keyscan -p 2280 -H localhost >>~/.ssh/known_hosts

docker-jessie-start-all: docker-jessie-build docker-jessie-start-romulus docker-jessie-start-remus docker-jessie-start-rhea

# Export the Jessie image into an image.
docker-jessie-export:
	sudo docker export `cat tests/temp/sains-server.id` > tests/images/sains-server.tar

# Commit changes on the docker
docker-jessie-commit:
	sudo docker commit `cat tests/temp/sains-server.id` sains-server

# stop all instances
docker-jessie-stop-remus:
	sudo test -f tests/temp/remus-server.id && sudo docker stop -t 30 `cat tests/temp/remus-server.id`
	sudo rm -f tests/temp/remus-server.id

docker-jessie-stop-romulus:
	sudo test -f tests/temp/romulus-server.id && sudo docker stop -t 30 `cat tests/temp/romulus-server.id`
	sudo rm -f tests/temp/romulus-server.id

docker-jessie-stop-rhea:
	sudo test -f tests/temp/rhea-server.id && sudo docker stop -t 30 `cat tests/temp/rhea-server.id`
	sudo rm -f tests/temp/rhea-server.id

# Simple shortcut to connect on the vm
docker-jessie-connect-remus:
	ssh -i deploy/id_rsa -p 2284 sains@localhost

docker-jessie-connect-romulus:
	ssh -i deploy/id_rsa -p 2285 sains@localhost

docker-jessie-connect-rhea:
	ssh -i deploy/id_rsa -p 2280 sains@localhost

