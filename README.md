# Deploying Machine Learning Models on Kubernetes

A common pattern for deploying Machine Learning (ML) models into production environments - e.g. a ML model trained using the SciKit Learn package in Python and ready to provide predictions on new data - is to expose them as a RESTful API microservices that are hosted from within Docker containers, that are in-turn deployed to a cloud environment for handling everything required for maintaining continuous availability - e.g. fail-over, auto-scaling, load balancing and rolling service updates.

The configuration details for a continuously available cloud deployment are specific to the targeted cloud provider(s) - e.g. the deployment process and topology for Amazon Web Services is not the same as that for Microsoft Azure. This constitutes knowledge that needs to be acquired for every targeted cloud provider. Furthermore, it is difficult (some would say near impossible) to test entire deployment strategies locally, which makes issues such as networking hard to debug.

[Kubernetes](https://kubernetes.io) is a container orchestration platform that seeks to address these issues. Briefly, it provides a mechanism for defining **entire** microservice-based application deployment topologies and their service-level requirements for maintaining continuous availability. It is agnostic to the targeted cloud provider, can be run on-premises and even locally - all that's required is a cluster of virtual machines running Kubernetes - i.e. a Kubernetes cluster.

This repository contains the code, configuration files and Kubernetes instructions for demonstrating how a simple Python ML model can be turned into a production-grade RESTful model scoring (or prediction) API service, using Kubernetes - both locally and with Google Cloud Platform (GCP). It is not a comprehensive guide to Kubernetes or ML - more of a 'ML on Kubernetes 101' to demonstrate capability and allow newcomers to Kubernetes to get up-and-running and become familiar with the basic concepts.

We perform the ML model deployment using two different approaches: a first principles approach using Docker and Kubernetes; and then a deployment using the [Seldon-Core](https://www.seldon.io) framework for managing ML model pipelines on Kubernetes. The former will help to appreciate the latter, which constitutes a powerful framework for deploying and performance-monitoring many complex ML model pipelines.

## Containerising a Simple ML Model Scoring Service

We start by demonstrating how to achieve this basic competence using the simple Python ML model scoring REST API contained in the `py-flask-ml-score-api/api.py` module, together with the Dockerfile in the `py-flask-ml-score-api` directory.

### Building a Docker Image

We assume that there is a [Docker client and Docker daemon](https://www.docker.com) running locally, that the client is logged into an account on [DockerHub](https://hub.docker.com) and that there is a terminal open in the this project's root directory. To build the image described in the Dockerfile run,

```bash
docker build --tag alexioannides/test-ml-score-api py-flask-ml-score-api
```

Where 'alexioannides' refers to the name of the DockerHub account that we will push the image to, once we have tested it. To test that the image can be used to create a Docker container that functions as we expect it to use,

```bash
docker run --name test-api -p 5000:5000 -d alexioannides/test-ml-score-api
```

Where we have mapped port 5000 from the Docker container - i.e. the port our ML model scoring service is listening to - to port 5000 on our host machine (localhost). Then check that the container is listed as running using,

```bash
docker ps
```

And then test the exposed API endpoint using,

```bash
curl http://localhost:5000/score \
    --request POST \
    --header "Content-Type: application/json" \
    --data '{"X": [1, 2]}'
```

Where you should expect a response along the lines of,

```json
{"score":[1,2]}
```

All our test model does is return the input data - i.e. it is the identity function (only a few lines of additional code are required to modify this service to load a SciKit Learn model from disk and pass new data to it's 'predict' method for generating predictions). Now that the container has been confirmed as operational, we can stop and remove it,

```bash
docker stop test-api
docker rm test-api
```

### Pushing a Docker Image to DockerHub

In order for a remote Docker host or Kubernetes cluster to have access to the image we've created, we need to publish it to an image registry. All the cloud computing providers that offer managed Docker-based services will provide private image registries, but we will use the public image registry at DockerHub. To push our new image to DockerHub (where my account ID is 'alexioannides') use,

```bash
docker push alexioannides/test-ml-score-api
```

Where we can now see that our chosen naming convention for the image is intrinsically linked to our target image registry (and you will need to insert your own account ID where necessary). Once the upload is finished, log onto DockerHub to confirm that the upload has been successful via the [DockerHub UI](https://hub.docker.com/u/alexioannides).

## Installing Minikube for Local Development and Testing

[Minikube](https://github.com/kubernetes/minikube) allows a single node Kubernetes cluster to run within a Virtual Machine (VM) on a local machine for development purposes. On Mac OS X, the steps required to get up-and-running are as follows:

- make sure the [Homebrew](https://brew.sh) package manager for OS X is installed; then,
- install VirtualBox using, `brew cask install virtualbox` (you may need to approve installation via OS X System Preferences); and then,
- install Minikube using, `brew cask install minikube`.

To start the test cluster run,

```bash
minikube start --memory 4096
```

Where we have specified the minimum amount of memory required to deploy a single Seldon ML component. This may take a while. To test that the cluster is operational run,

```bash
kubectl cluster-info
```

Where `kubectl` is the standard Command Line Interface (CLI) client for interacting with the Kubernetes API (which was installed as part of Minikube, but is also available separately).

### Launching the Containerised ML Model Scoring Service on Minikube

To launch our test model scoring service on Kubernetes, start by running the container within a Kubernetes [pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) that is managed by a [replication controller](https://kubernetes.io/docs/concepts/workloads/controllers/replicationcontroller/),

```bash
kubectl run test-ml-score-api --image=alexioannides/test-ml-score-api:latest --port=5000 --generator=run/v1
```

Where the `--generator=run/v1` flag triggers the construction of the replication controller to manage the pod and will in this instance ensure that there is always at least one pod (running our container), active on the cluster at any one time. To check that it's running use,

```bash
kubectl get pods
```

It is possible to use [port forwarding](https://en.wikipedia.org/wiki/Port_forwarding) to test an individual container without exposing it to the public internet. To use this, open a separate terminal and run (for example),

```bash
kubectl port-forward test-ml-score-api-szd4j 5000:5000
```

Where `test-ml-score-api-szd4j` is the precise name of the pod currently active on the cluster, as determined from the `kubectl get pods` command. Then from your original terminal, to repeat our test request against the same container running on Kubernetes run,

```bash
curl http://localhost:5000/score \
    --request POST \
    --header "Content-Type: application/json" \
    --data '{"X": [1, 2]}'
```

To expose the container as a (load balanced) [service](https://kubernetes.io/docs/concepts/services-networking/service/) to the outside world, we have to create a Kubernetes service that references it. This is achieved with the following command,

```bash
kubectl expose rc test-ml-score-api --type=LoadBalancer --name test-ml-score-api-http
```

To check that this has worked and to find the services's external IP address run,

```bash
minikube service list
```

And we can then test our new service - for example,

```bash
curl http://192.168.99.100:30888/score \
    --request POST \
    --header "Content-Type: application/json" \
    --data '{"X": [1, 2]}'
```

Note that we need to use Minikube-specific commands as Minikube cannot setup a load balancer for real. To tear-down the load balancer, replication controller, pod and Minikube cluster run the following commands in sequence,

```bash
kubectl delete rc test-ml-score-api
kubectl delete service test-ml-score-api-http
minikube delete
```

## Configuring a Multi-Node Cluster on Google Cloud Platform

In order to perform testing on a real-world Kubernetes cluster with far greater resources that those available on a laptop, the easiest way is to use a managed Kubernetes platform from a cloud provider. We will use Kubernetes Engine on [Google Cloud Platform (GCP)](https://cloud.google.com).

### Getting Up-and-Running with Google Cloud Platform

Before we can use Google Cloud Platform, sign-up for an account and create a project specifically for this work. Next, make sure that the GCP SDK is installed on your local machine - e.g.,

```bash
brew cask install google-cloud-sdk
```

Or by downloading an installation image [directly from GCP](https://cloud.google.com/sdk/docs/quickstart-macos). Note, that if you haven't installed Minikube and all of the tools that come packaged with it, then you will need to install Kubectl, which can be done using the GCP SDK,

```bash
gcloud components install kubectl
```

We then need to initialise the SDK,

```bash
gcloud init
```

Which will open a browser and guide you through the necessary authentication steps. Make sure you pick the project you created, together with a default zone and region (if this has not been set via Compute Engine -> Settings).

### Initialising a Kubernetes Cluster

Firstly, within the GCP UI visit the Kubernetes Engine page to trigger the Kubernetes API start-up. Then from the command line we start a cluster using,

```bash
gcloud container clusters create k8s-test-cluster --num-nodes 3 --machine-type g1-small
```

And then go make a cup of coffee while you wait for the cluster to be created.

### Launching the Containerised ML Model Scoring Service on the GCP

This is largely the same as we did for running the test service locally using Minikube - run the following commands in sequence,

```bash
kubectl run test-ml-score-api --image=alexioannides/test-ml-score-api:latest --port=5000 --generator=run/v1
kubectl expose rc test-ml-score-api --type=LoadBalancer --name test-ml-score-api-http
```

But, to find the external IP address for the GCP cluster we will need to use,

```bash
kubectl get services
```

And then we can test our service on GCP - for example,

```bash
curl http://35.234.149.50:5000/score \
    --request POST \
    --header "Content-Type: application/json" \
    --data '{"X": [1, 2]}'
```

Or, we could again use port forwarding to attach to a single pod - for example,

```bash
kubectl port-forward test-ml-score-api-nl4sc 5000:5000
```

And then in a separate terminal,

```bash
curl http://localhost:5000/score \
    --request POST \
    --header "Content-Type: application/json" \
    --data '{"X": [1, 2]}'
```

Finally, we tear-down the replication controller and load balancer,

```bash
kubectl delete rc test-ml-score-api
kubectl delete service test-ml-score-api-http
```

## Switching Between Kubectl Contexts

If you are running both with Minikube locally and with a cluster on GCP then you can switch Kubectl [context](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/) from one cluster to the other using, for example,

```bash
kubectl config use-context minikube
```

Where the list of available contexts can be found using,

```bash
kubectl config get-contexts
```

## Using YAML Files to Define Kubernetes Apps

Up to this point we have been using Kubectl commands to define and deploy a basic version of our ML model scoring service. This is fine for demonstrative purposes, but quickly becomes unmanageable. In practice, the standard way of defining entire applications is with YAML files that are posted to the Kubernetes API. The `py-flask-ml-score.yaml` file in the `py-flask-ml-score-api` is an example of how our ML model scoring service can be defined in a single YAML file. This can now be deployed using a single command,

```bash
kubectl create -f py-flask-ml-score-api/py-flask-ml-score.yaml
```

Note, that we have defined three separate Kubernetes components in this single file: a replication controller, a load-balancer service and a [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) for all of these components (and their sub-components) - using `---` to delimit the definition of each separate component. To see all components deployed into this namespace use,

```bash
kubectl get all --namespace test-ml-app
```

And likewise set the `--namespace` flag when using any `kubectl get` command to inspect the different components of our test app. Alternatively, we ca set our new namespace as the default context,

```bash
kubectl config set-context $(kubectl config current-context) --namespace=test-ml-app
```

And then run,

```bash
kubectl get all
```

Where we can switch back to the default namespace using,

```bash
kubectl config set-context $(kubectl config current-context) --namespace=default
```

To tear-down this application we can then use,

```bash
kubectl delete -f py-flask-ml-score-api/py-flask-ml-score.yaml
```

Which saves us from having to use multiple commands to delete each component individually. Refer to the [official documentation for the Kubernetes API](https://kubernetes.io/docs/home/) to understand the contents of this YAML file in greater depth.

## Installing Ksonnet

Seldon uses [Ksonnet](https://ksonnet.io) - a templating system for configuring Kubernetes to deploy applications. Although we haven't made extenisve use of it thus far, the standard way of defining and creating pods and services on Kubernetes is by posting YAML files to the Kubernetes API - e.g. `py-flask-ml-score-api/py-flask-ml-score.yaml`, that was discussed in-passing above. These can grow quite large and be hard to manage, especially when it comes to composing complicated deployments. This is where Ksonnet comes in - by allowing you to define naturally composable Kubernetes application components using templated JSON-object configuration files, instead of having to write a 'wall of YAML' for every deployment. The easiest way to install Ksonnet (on Mac OS X) is to use Homebrew,

```bash
brew install ksonnet/tap/ks
```

Conform that the installation has been successful by running,

```bash
ks version
```

## Using Seldon to Deploy a ML Model Scoring Service on Kubernetes

Seldon's core mission is to simplify the deployment of complex ML prediction pipelines on top of Kubernetes. In this demonstration we are going to focus on the simplest possible example - i.e. the simple ML model scoring API we have already been using.

### Installing Source-to-Image

Seldon-core depends heavily on [Source-to-Image](https://github.com/openshift/source-to-image) - a tool for automating the process of building code artifacts from source and injecting them into docker images. In Seldon's use-case the artifacts are the different pieces of an ML pipeline. We use Homebrew to install on Mac OS X,

```bash
brew install source-to-image
```

To confirm that it has been installed correctly run,

```bash
s2i version
```

### Install the Seldon-Core Python Package

We're using [Pipenv](https://pipenv.readthedocs.io/en/latest/) to manage the Python dependencies for this project. To install `seldon-core` into a virtual environment that is only used by this project use,

```bash
pipenv install --python 3.6 seldon-core
```

If you don't wish to use `pipenv` you can install `seldon-core` using `pip` into whatever environment is most convenient and then drop the use of `pipenv run` when testing with Seldon-Core (below).

### Building an ML Component for Seldon

To deploy a ML component using Seldon, we need to create Seldon-compatible Docker containers. We start by following [these guidelines](https://github.com/SeldonIO/seldon-core/blob/master/docs/wrappers/python.md) for defining a Python class that wraps an ML model targeted for deployment with Seldon. This is contained within the `seldon-ml-score-component` directory. Firstly, ensure that the docker daemon is running locally and then run,

```bash
s2i build seldon-ml-score-component seldonio/seldon-core-s2i-python3:0.4 alexioannides/seldon-ml-score-component
```

Launch the container using Docker locally,

```bash
docker run --name seldon-s2i-test -p 5000:5000 -d alexioannides/seldon-ml-score-component
```

And then test the resulting Seldon component using the dedicated testing application from the `seldon-core` Python package,

```bash
pipenv run seldon-core-tester seldon-ml-score-component/contract.json localhost 5000 -p
```

If it works as expected (i.e. without throwing any errors), push it to an image registry - for example,

```bash
docker push alexioannides/seldon-ml-score-component
```

### Deploying a ML Component with Seldon-Core

We now move on to deploying our Seldon compatible ML component and creating a service form it. To achieve this, we will [deploy Seldon-Core using KSonnet](https://github.com/SeldonIO/seldon-core/blob/master/docs/install.md#with-ksonnet). Before we can proceed any further, we will need to grant a cluster-wide super-user role to our user, using Role-Based Access Control (RBAC). On GCP this is achieved with,

```bash
kubectl create clusterrolebinding kube-system-cluster-admin \
    --clusterrole cluster-admin \
    --user $(gcloud info --format="value(config.account)")
```

And for Minikube with,

```bash
kubectl create clusterrolebinding kube-system-cluster-admin \
    --clusterrole cluster-admin \
    --serviceaccount kube-system:default
```

Next, we create a Kubernetes namespace for all Seldon components that we will deploy, and we switch to it as a default,

```bash
kubectl create namespace seldon
kubectl config set-context $(kubectl config current-context) --namespace=seldon
```

We now need to define our Seldon ML deployment using Seldon's Ksonnet templates. We start by initialising a new Ksonnet application,

```bash
ks init seldon-ksonnet-ml-score-app --api-spec=version:v1.8.0
```

This will create a new directory - `seldon-ksonnet-ml-score-app` - that contains all of the necessary base configuration files for a Ksonnet-based deployment. We now need to add the necessary Seldon-Core components to the application using the following set of concatenated commands,

```bash
cd seldon-ksonnet-ml-score-app && \
    ks registry add seldon-core github.com/SeldonIO/seldon-core/tree/master/seldon-core && \
    ks pkg install seldon-core/seldon-core@master && \
    ks generate seldon-core seldon-core \
    --withApife=false \
    --withAmbassador=true \
    --withRbac=true \
    --singleNamespace=true \
    --namespace=seldon
```

We can now deploy Seldon-Core (**without** our ML component) using,

```bash
ks apply default
```

Finally, we deploy our model scoring API component on Seldon-Core by creating the new Ksonnet component that reference the Seldon-Core Docker image containing the model scoring API, and then applying it,

```bash
ks generate seldon-serve-simple-v1alpha2 test-seldon-ml-score-api --image alexioannides/seldon-ml-score-component
ks apply default -c test-seldon-ml-score-api
```

#### Expose the ML Model Scoring Service to the Outside World

If working on GCP we can expose the service via the `ambassador` [API gateway](https://microservices.io/patterns/apigateway.html) component deployed as part of Seldon-Core,

```bash
kubectl expose deployment seldon-core-ambassador --type=LoadBalancer --name=seldon-core-ambassador-external
```

And then retrieve the external IP,

```bash
kubectl get services
```

#### Testing the API

##### Via Port Forwarding

We follow the same general approach as we did for our first-principles Kubernetes deployment above, but using embedded bash commands to find the Ambassador API gateway component we need to target for port-forwarding. We start with GCP,

```bash
kubectl port-forward $(kubectl get pods -n seldon -l service=ambassador -o jsonpath='{.items[0].metadata.name}') -n seldon 8003:8080
```

Or if working locally with Minikube,

```bash
kubectl port-forward $(kubectl get pods -n seldon -l service=ambassador -o jsonpath='{.items[0].metadata.name}') -n seldon 8003:8080
```

We can then test the model scoring API deployed via Seldon-Core, using the API defined by Seldon-Core,

```bash
curl http://localhost:8003/seldon/test-seldon-ml-score-api/api/v0.1/predictions \
    -request POST
    -header "Content-Type: application/json" \
    -data '{"data":{"names":["a","b"],"tensor":{"shape":[2,2],"values":[0,0,1,1]}}}'
```

##### Via the Public Internet

For the GCP service we exposed to the public internet use,

```bash
curl 35.230.142.73:8080/seldon/test-seldon-ml-score-api/api/v0.1/predictions
    -request POST
    -header "Content-Type: application/json"
    -data '{"data":{"names":["a","b"],"tensor":{"shape":[2,2],"values":[0,0,1,1]}}}'
```

#### Tear Down

We start by deleting the Ksonnet deployment from the Kubernetes cluster,

```bash
cd seldon-ksonnet-ml-score-app
ks delete default
cd ..
```

Then we delete the Ksonnet application,

```bash
rm -rf seldon-ksonnet-ml-score-app
```

If the GCP cluster needs to be killed run,

```bash
gcloud container clusters delete k8s-test-cluster
```

And likewise if working with Minikube,

```bash
minikube stop
minikube delete
```
