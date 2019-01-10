# Machine Learning Operations on Kubernetes

TODO

## Containerising a Simple Test API

All of the ML applications and services we want to demonstrate use Kubernetes as the underlying deployment platform. Consequently, they assume a basic knowledge of both Docker containers and Kubernetes - e.g. how to build a Docker image that containerises a service and how to create a Kubernetes cluster and configure a Kubernetes service that runs the container and exposes it to the public internet.

We start by demonstrating how to achieve these basic competencies, using the simple Python test API contained in the `services/test_api.py` module together with the Dockerfile in this project's root directory.

### Building a Docker Image

We assume that there is a Docker client and host running locally, that the client is logged into an account on DockerHub and that there is a terminal open in the this project's root directory. To build the image described in the Dockerfile run,

```bash
docker build --tag alexioannides/py-flask-test-api .
```

Where 'alexioannides' refers to the name of the DockerHub account that we will push the image to, once we have tested it. To test that the image can be used to create a Docker container that functions as we expect it to, use,

```bash
docker run --name py-flask-test-api -p 5000:5000 -d alexioannides/py-flask-test-api
```

And then check that the container is listed as running,

```bash
docker ps
```

And then test the exposed API endpoint using,

```bash
curl http://localhost:5000/test_api
```

Where you should expect a response along the lines of,

```json
{"message":"Hello 172.17.0.1, you've reached 172.17.0.2"}
```

Now that the container has confirmed as operational, we can stop and remove it,

```bash
docker stop py-flask-test-api
docker rm py-flask-test-api
```

### Pushing a Docker Image to DockerHub

In order for a remote Docker host or Kubernetes cluster to have access to the image we've created, we need to publish it to image registry. All the cloud computing providers that offer managed Docker-based services will provide private image registry, but by far the easiest way forwards for us, is to use the public image registry at DockerHub. To push our new image to DockerHub (where my account ID is 'alexioannides'), use,

```bash
docker push alexioannides/py-flask-test-api
```

And log onto DockerHub to confirm that the upload has been successful.

## Installing Minikube for Local Development and Testing

[Minikube](https://github.com/kubernetes/minikube) allows a single node Kubernetes cluster to run within a Virtual Machine (VM) on a local machine, for development purposes. On Mac OS X, the steps required to get up-and-running are as follows:

- make sure [Homebrew](https://brew.sh) package manager for OS X is installed;
- install VirtualBox using, `brew cask install virtualbox` (you may need to approve installation via OS X System Preferences); and then,
- install Minikube using, `brew cask install minikube`.

To stark the test cluster run,

```bash
minikube start
```

This may take a while. To test that the cluster is operation run,

```bash
kubectl cluster-info
```

### Launching the Test API Container on Minikube

To launch our test service on Kubernetes run,

```bash
kubectl run py-flask-test-api --image=alexioannides/py-flask-test-api:latest --port=5000 --generator=run/v1
```

And to check that it's running in a Kubernetes pod run,

```bash
kubectl get pods
```

To expose the container as a (load balanced) service to the outside world, we have to create a Kubernetes service that references it. This is achieved with the following command,

```bash
kubectl expose rc py-flask-test-api --type=LoadBalancer --name py-flask-test-api-http
```

To check that this has worked and to find the services external IP address run,

```bash
minikube service list
```

And we can then test our new service - for example,

```bash
curl http://192.168.99.100:31195/test_api
```

Note that we need to use Minikube-specific commands as Minikube cannot setup a load balancer for real.

## Configuring a Multi-Node Cluster on Google Cloud Platform

In order to perform testing on a real-world Kubernetes cluster with far greater resources that those available on a laptop, the easiest way is to use a managed Kubernetes platform from a cloud provider. We will use Kubernetes on Google Cloud Platform (GCP).

### Getting Up-and-Running with Google Cloud Platform

Before we can use Google Cloud Platform sign-up for an account and create a project specifically for this work. Next, make sure that the GCP SDK is installed on your local machine - for example,

```bash
brew cask install goodle-cloud-sdk
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
gcloud container clusters create k8s-test-cluster --num-nodes 3 --machine-type f1-micro
```

And then go make a cup of coffee while you wait for the cluster to be created.

### Launching the Test API Container on the GCP

This is largely the same as we did for running the test API locally using Minikube,

```bash
kubectl run py-flask-test-api --image=alexioannides/py-flask-test-api:latest--port=5000 --generator=run/v1
kubectl expose rc py-flask-test-api --type=LoadBalancer --name py-flask-test-api-http
```

But, to find the external IP address for the GCP cluster we need to use,

```bash
kubectl get services
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

And then we can test our service on GCP - for example,

```bash
curl http://35.234.149.50:5000/test_api
```
