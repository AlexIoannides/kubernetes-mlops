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
minikube start --memory 4096
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

In order to perform testing on a real-world Kubernetes cluster with far greater resources that those available on a laptop, the easiest way is to use a managed Kubernetes platform from a cloud provider. We will use Kubernetes Engine on Google Cloud Platform (GCP).

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
gcloud container clusters create k8s-test-cluster --num-nodes 3 --machine-type g1-small
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

And then we can test our service on GCP - for example,

```bash
curl http://35.234.149.50:5000/test_api
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

### Installing Seldon-Core using Ksonnet

We follow the [official documentation](https://github.com/SeldonIO/seldon-core/blob/master/docs/install.md#with-ksonnet) for installing Seldon-Core with Ksonnet and configuring it to use the Ambassador reverse proxy as the API endpoint for our Seldon ML services. We start by creating a Seldon Ksonnet app,

```bash
ks init seldon-core-test-api --api-spec=version:v1.8.0
```

This will create a directory called `seldon-core-test-api` in the project's root directory, containing all of the components necessary for a Ksonnet app. And then configure the Ksonnet app to deploy Seldon-core,

```bash
cd seldon-core-test-api && \
    ks registry add seldon-core github.com/SeldonIO/seldon-core/tree/master/seldon-core && \
    ks pkg install seldon-core/seldon-core@master && \
    ks generate seldon-core seldon-core \
       --withApife=false \
       --withAmbassador=true \
       --withRbac=false \
       --singleNamespace=true
```

Deploy the app using,

```bash
ks apply default
```

We will use our cluster on GCP for testing. Confirm that the deployment has worked by using,

```bash
kubectl get services
```

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

We're using [Pipenv](https://pipenv.readthedocs.io/en/latest/) to manage the Python dependencies in this project. To install `seldon-core` into the virtual environment use,

```bash
pipenv install --dev seldon-core
```

Where the `--dev` flags that this is a development dependency (i.e. don't include it as part of the Docker image that we use for our simple test API).

### Building an ML Component for Seldon

Following [these guidelines](https://github.com/SeldonIO/seldon-core/blob/master/docs/wrappers/python.md) for defining a Python class that wraps an ML model.

Generate a `requirements.txt` file,

```bash
pipenv lock -r > seldon-component/requirements.txt
```

Make sure the docker daemon is running and then run,

```bash
s2i build seldon-component seldonio/seldon-core-s2i-python3:0.4 alexioannides/seldon-test-model
```

Launch the container using Docker locally,

```bash
docker run --name seldon-test -p 5000:5000 -d seldon-test-model
```

Then test it,

```bash
seldon-core-tester seldon-component/contract.json localhost 5000 -p
```

And then push it to an image registry,

```bash
docker push alexioannides/seldon-test-model
```

### Building a Test API with Seldon-Core

[TODO](https://github.com/SeldonIO/seldon-core/blob/master/docs/install.md#with-ksonnet)

Preamble for GCP,

```bash
kubectl create clusterrolebinding my-cluster-admin-binding \
    --clusterrole=cluster-admin
    --user=$(gcloud info --format="value(config.account)")
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
ks init seldon-ksonnet-app --api-spec=version:v1.8.0
```

Then,

```bash
cd seldon-ksonnet-app
ks registry add seldon-core github.com/SeldonIO/seldon-core/tree/master/seldon-core
ks pkg install seldon-core/seldon-core@master
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
ks generate seldon-serve-simple-v1alpha2 seldon-test-model --image alexioannides/seldon-test-model
ks apply default -c seldon-test-model
```

#### Expose the Test API to the Outside World

If working on GCP,

```bash
kubectl expose deployment seldon-core-ambassador --type=LoadBalancer --name=seldon-core-ambassador-external
```

Get external IP,

```bash
kubectl get services
```

Or if working locally with Minikube,

```bash
kubectl port-forward $(kubectl get pods -n seldon -l service=ambassador -o jsonpath='{.items[0].metadata.name}') -n seldon 8003:8080
```

#### Testing the API

But in any case, this is what we're aiming to use for testing. For GCP,

```bash
curl -v 35.242.173.29:8080/seldon/seldon-test-model/api/v0.1/predictions -d '{"data":{"names":["a","b"],"tensor":{"shape":[2,2],"values":[0,0,1,1]}}}' -H "Content-Type: application/json"
```

Or for Minikube,

```bash
curl -v localhost:8003/seldon/seldon-test-model/api/v0.1/predictions -d '{"data":{"names":["a","b"],"tensor":{"shape":[2,2],"values":[0,0,1,1]}}}' -H "Content-Type: application/json"
```

#### Tear Down

```bash
cd seldon-ksonnet-app && ks delete default
```

Then,

```bash
rm -rf seldon-ksonnet-app
```
