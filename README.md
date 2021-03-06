# Load balancer example

_A simple and funny round robin load balancer example, using nginx as a frontend,
and Golang compiled programs as the backend_

Docker is used for the local running.

The load balancer is called Rhea, and the two backends are called Romulus and Remus

This is a proof of concept to show nginx load balancing feature.
The project is simple enough to place almost all the instructions in the Makefile
For a more complex project, use Ansible or Puppet to deploy the application.

## Requirements

First, you need Debian or Ubuntu distribution.
I have tested with Debian Jessie, I don't know the other distributions.

At the very least to start this program, you should have Gnu make and sudo installed on your system,
and be part of the sudo group.

Once these basic requirement satisfied, you need these

- golang, to compile the backend
- docker, to create, start the instances
- debootstrap to build the image template from the last official debian image
- tar
- ssh client

## Steps

This is an overview of the steps that will be used for this exercise.
The details of the steps are described below.
Since we are using a makefile, steps are often depending on previous targets.
This is specified in the makefile
In theory, you could start directly the step 4, but if you want to see what's happen if there
is a problem, it's better to do it step by step

1. Check that the required packages are installed on the system
2. Build the go backend
3. Create a Debian Jessie image, to be imported by docker
4. Create a docker image, using the debootstrap
5. Create and start three docker instances, for Rhea, Romus and Remulus
6. Deploy the backend on Romus and Remulus
7. Deploy the frontend on Rhea
8. Check if it's running

### 1. Check the required packages

This is done via the makefile:

    make packages

### 2. Build the Go backend

Just type make.

    make

### 3. Create a Debian Jessie image

Create the Debian jessie image (the format is tar), that will be used for docker. This is a long step.

    make image-jessie

### 4. Create the Debian Jessie image for Docker

This will create the docker image from the debootstrap image.

    make docker-jessie-build

### 5. Create and start the docker instances

This step will create _and start_ the three instance, Rhea, Romus and Romulus.

    make docker-jessie-start-all

- Each image is accessible via SSH, with the key "deploy/id_rsa" (dynamically generated)
- The ssh key is dynamically generated using ssh-keygen when installing the program for the first time


### 6. Deploy the backend on Romus and Remulus

Deploy the backend on Romus and Remulus

    make deploy-backends

### 7. Deploy the frontend on Rhea

    make deploy-rhea

### 8. Check if it's running

To check if the load balancer is running, open a browser at this address:

    http://localhost:9080/

And refresh the page. You should see, alternatively:

- Hi there, I'm served from remus!
- Hi there, I'm served from romulus!

## To use with a CI tool (e.g. Jenkins)

The deployment can be automated, using the makefile commands and environment variables:

### Example for the backend

This is an example on how to deploy the backend, using a simple set of environment variables

    export DEPLOY_SERVER=192.168.42.44
    export DEPLOY_KEY=/var/lib/jenkins/.ssh/id_rsa
    make deploy-backend

This will build and deploy the backend on the server 192.168.42.44, using an SSH key in the jenkins
home directory.

### Example for the frontend

For the frontend, this can be achieved almost the same way:

    export BACKEND_ADDRESSES=192.168.42.2,192.168.42.3,192.168.42.4
    export DEPLOY_SERVER=192.168.42.44
    export DEPLOY_KEY=/var/lib/jenkins/.ssh/id_rsa
    make deploy-frontend

This will generate an nginx configuration file, with the backend addresses from BACKEND_ADDRESSES.

The template for the nginx configuration file is in deploy/nginx-generic.conf.
It can be customised the way you want, for instance the logging options.
