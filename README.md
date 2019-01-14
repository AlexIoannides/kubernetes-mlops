# Machine Learning Operations on Kubernetes

TODO

## Containerising a Simple Test API

All of the ML applications and services we want to demonstrate use Kubernetes as the underlying deployment platform. Consequently, they assume a basic knowledge of both Docker containers and Kubernetes - e.g. how to build a Docker image that containerises a service and how to create a Kubernetes cluster and configure a Kubernetes service that runs the container and exposes it to the public internet.

We start by demonstrating how to achieve these basic competencies, using the simple Python test API contained in the `services/test_api.py` module together with the Dockerfile in this project's root directory.

### Building a Docker Image

We assume that there is a Docker client and host running locally, that the client is logged into an account on DockerHub and that there is a terminal open in the this project's root directory. To build the image described in the Dockerfile run,

```bash
docker build --tag alexioannides/test-ml-score-api py-flask-ml-score-api
```

Where 'alexioannides' refers to the name of the DockerHub account that we will push the image to, once we have tested it. To test that the image can be used to create a Docker container that functions as we expect it to, use,

```bash
docker run --name test-api -p 5000:5000 -d alexioannides/test-ml-score-api
```

And then check that the container is listed as running,

```bash
docker ps
```

And then test the exposed API endpoint using,

```bash
curl --header "Content-Type: application/json" \
     --request POST \
     --data '{"X": [1, 2]}' \
     http://localhost:5000/score
```

Where you should expect a response along the lines of,

```json
{"score":[1,2]}
```

Now that the container has confirmed as operational, we can stop and remove it,

```bash
docker stop test-api
docker rm test-api
```

### Pushing a Docker Image to DockerHub

In order for a remote Docker host or Kubernetes cluster to have access to the image we've created, we need to publish it to image registry. All the cloud computing providers that offer managed Docker-based services will provide private image registry, but by far the easiest way forwards for us, is to use the public image registry at DockerHub. To push our new image to DockerHub (where my account ID is 'alexioannides'), use,

```bash
docker push alexioannides/test-ml-score-api
```

And log onto DockerHub to confirm that the upload has been successful.

## Installing Minikube for Local Development and Testing

[Minikube](https://github.com/kubernetes/minikube) allows a single node Kubernetes cluster to run within a Virtual Machine (VM) on a local machine, for development purposes. On Mac OS X, the steps required to get up-and-running are as follows:

- make sure [Homebrew](https://brew.sh) package manager for OS X is installed;
- install VirtualBox using, `brew cask install virtualbox` (you may need to approve installation via OS X System Preferences); and then,
- install Minikube using, `brew cask install minikube`.

To stark the test cluster run,

```bash
minikube start --memory 4096
```

This may take a while. To test that the cluster is operation run,

```bash
kubectl cluster-info
```

### Launching the Test API Container on Minikube

To launch our test service on Kubernetes start by running the container using a Kubernetes replication controller using,

```bash
kubectl run test-ml-score-api --image=alexioannides/test-ml-score-api:latest --port=5000 --generator=run/v1
```

And to check that it's running in a Kubernetes pod run,

```bash
kubectl get pods
```

It is possible to use [port forwarding](https://en.wikipedia.org/wiki/Port_forwarding) to test an individual container without exposing it to the public internet. To use this, open a separate terminal and run (for example),

```bash
kubectl port-forward test-ml-score-api-szd4j 5000:5000
```

And then from your original terminal run,

```bash
curl --header "Content-Type: application/json" \
     --request POST \
     --data '{"X": [1, 2]}' \
     http://localhost:5000/score
```

To repeat our test request against the same container running on Kubernetes.

To expose the container as a (load balanced) service to the outside world, we have to create a Kubernetes service that references it. This is achieved with the following command,

```bash
kubectl expose rc test-ml-score-api --type=LoadBalancer --name test-ml-score-api-http
```

To check that this has worked and to find the services external IP address run,

```bash
minikube service list
```

And we can then test our new service - for example,

```bash
curl --header "Content-Type: application/json" \
     --request POST \
     --data '{"X": [1, 2]}' \
     http://192.168.99.100:30888/score
```

Note that we need to use Minikube-specific commands as Minikube cannot setup a load balancer for real. To tear-down the load balancer, replication controller and Minikube cluster run the following commands,

```bash
kubectl delete rc test-ml-score-api
kubectl delete service test-ml-score-api-http
minikube delete
```

## Configuring a Multi-Node Cluster on Google Cloud Platform

In order to perform testing on a real-world Kubernetes cluster with far greater resources that those available on a laptop, the easiest way is to use a managed Kubernetes platform from a cloud provider. We will use Kubernetes Engine on Google Cloud Platform (GCP).

### Getting Up-and-Running with Google Cloud Platform

Before we can use Google Cloud Platform sign-up for an account and create a project specifically for this work. Next, make sure that the GCP SDK is installed on your local machine - for example,

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

Firstly, within the GCP UI visit the Kubernetes Engine page to trigger the Kubernetes API start-up. Then from the command line we start a cluster (eligible for use with the GCP free-tier) using,

```bash
gcloud container clusters create k8s-test-cluster --num-nodes 3 --machine-type g1-small
```

And then go make a cup of coffee while you wait for the cluster to be created.

### Launching the Test API Container and Load Balancer on the GCP

This is largely the same as we did for running the test API locally using Minikube,

```bash
kubectl run test-ml-score-api --image=alexioannides/test-ml-score-api:latest --port=5000 --generator=run/v1
kubectl expose rc test-ml-score-api --type=LoadBalancer --name test-ml-score-api-http
```

But, to find the external IP address for the GCP cluster we need to use,

```bash
kubectl get services
```

And then we can test our service on GCP - for example,

```bash
curl --header "Content-Type: application/json" \
     --request POST \
     --data '{"X": [1, 2]}' \
     http://35.234.149.50:5000/score
```

Or, we could again use port forwarding to attach to a single pod - for example,

```bash
kubectl port-forward test-ml-score-api-nl4sc 5000:5000
```

And then in a separate terminal,

```bash
curl --header "Content-Type: application/json" \
     --request POST \
     --data '{"X": [1, 2]}' \
     http://localhost:5000/score
```

Finally, we tear-down the replication controller and load balancer,

```bash
kubectl delete rc test-ml-score-api
kubectl delete service test-ml-score-api-http
```

## Switching Between Kubectl Contexts

If you are running both with Minikube locally and with a cluster on GCP then you can switch Kubectl 'context' from one cluster to the other using, for example,

```bash
kubectl config use-context minikube
```

Where the list of available context can be found using,

```bash
kubectl config get-contexts
```

## Installing Ksonnet

Both Seldon and KubeFlow use [Ksonnet](https://ksonnet.io) - a templating system for configuring Kubernetes to deploy ML applications. The easiest way to install Ksonnet (on Mac OS X) is to use Homebrew again,

```bash
brew install ksonnet/tap/ks
```

Conform that the installation has been successful by running,

```bash
ks version
```

## Using Seldon to Build a Machine Learning Service on Kubernetes

TODO

### Installing Source-to-Image

Seldon-core depends heavily on [Source-to-Image](https://github.com/openshift/source-to-image) - a tool for building artifacts from source and injecting into docker images. In Seldon's use-case the artifacts are the different pieces of an ML pipeline. We use Homebrew to install on Mac OS X,

```bash
brew install source-to-image
```

To confirm that it has been installed correctly run,

```bash
s2i version
```

### Install the Seldon-Core Python Package

We're using [Pipenv](https://pipenv.readthedocs.io/en/latest/) to manage the Python dependencies in this project. To install `seldon-core` into a virtual environment that is only used by this project use,

```bash
pipenv install --python 3.6 seldon-core
```

### Building an ML Component for Seldon

We follow [these guidelines](https://github.com/SeldonIO/seldon-core/blob/master/docs/wrappers/python.md) for defining a Python class that wraps an ML model. Start by ensuring the docker daemon is running and then run,

```bash
s2i build seldon-ml-score-component seldonio/seldon-core-s2i-python3:0.4 alexioannides/seldon-ml-score-component
```

Launch the container using Docker locally,

```bash
docker run --name seldon-s2i-test -p 5000:5000 -d alexioannides/seldon-ml-score-component
```

Then test it,

```bash
pipenv run seldon-core-tester seldon-ml-score-component/contract.json localhost 5000 -p
```

And then push it to an image registry,

```bash
docker push alexioannides/seldon-ml-score-component
```

### Building a Test API with Seldon-Core

[TODO](https://github.com/SeldonIO/seldon-core/blob/master/docs/install.md#with-ksonnet)

Preamble for GCP,

```bash
kubectl create clusterrolebinding kube-system-cluster-admin \
    --clusterrole cluster-admin \
    --user $(gcloud info --format="value(config.account)")
```

or for Minikube,

```bash
kubectl create clusterrolebinding kube-system-cluster-admin \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:default
```

Then,

```bash
kubectl create namespace seldon
kubectl config set-context $(kubectl config current-context) --namespace=seldon
```

Then,

```bash
ks init seldon-ksonnet-ml-score-app --api-spec=version:v1.8.0
```

Then,

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

Then,

```bash
ks apply default
```

Then,

```bash
ks generate seldon-serve-simple-v1alpha2 test-seldon-ml-score-api --image alexioannides/seldon-ml-score-component
ks apply default -c test-seldon-ml-score-api
```

#### Expose the Test API to the Outside World

If working on GCP,

```bash
kubectl expose deployment seldon-core-ambassador --type=LoadBalancer --name=seldon-core-ambassador-external
```

Then retrieve the external IP,

```bash
kubectl get services
```

#### Testing the API

##### Via Port Forwarding

For GCP,

```bash
kubectl port-forward $(kubectl get pods -n seldon -l service=ambassador -o jsonpath='{.items[0].metadata.name}') -n seldon 8003:8080
```

Or if working locally with Minikube,

```bash
kubectl port-forward $(kubectl get pods -n seldon -l service=ambassador -o jsonpath='{.items[0].metadata.name}') -n seldon 8003:8080
```

Then,

```bash
curl -v http://localhost:8003/seldon/test-seldon-ml-score-api/api/v0.1/predictions \
    -H "Content-Type: application/json" \
    -d '{"data":{"names":["a","b"],"tensor":{"shape":[2,2],"values":[0,0,1,1]}}}'
```

##### Via the Public Internet

For GCP,

```bash
curl -v 35.230.142.73:8080/seldon/test-seldon-ml-score-api/api/v0.1/predictions -d '{"data":{"names":["a","b"],"tensor":{"shape":[2,2],"values":[0,0,1,1]}}}' -H "Content-Type: application/json"
```

#### Tear Down

```bash
cd seldon-ksonnet-ml-score-app && ks delete default
```

Then,

```bash
rm -rf seldon-ksonnet-ml-score-app
```

And if the GCP cluster needs to be killed,

```bash

```
