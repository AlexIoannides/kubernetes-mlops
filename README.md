# Deploying Machine Learning Models on Kubernetes

A common pattern for deploying Machine Learning (ML) models into production environments - e.g. ML models trained using the SciKit Learn or Keras packages (for Python), that are ready to provide predictions on new data - is to expose these ML as RESTful API microservices, hosted from within [Docker](https://www.docker.com) containers. These can then deployed to a cloud environment for handling everything required for maintaining continuous availability - e.g. fault-tolerance, auto-scaling, load balancing and rolling service updates.

The configuration details for a continuously available cloud deployment are specific to the targeted cloud provider(s) - e.g. the deployment process and topology for Amazon Web Services is not the same as that for Microsoft Azure, which in-turn is not the same as that for Google Cloud Platform. This constitutes knowledge that needs to be acquired for every cloud provider. Furthermore, it is difficult (some would say near impossible) to test entire deployment strategies locally, which makes issues such as networking hard to debug.

[Kubernetes](https://kubernetes.io) is a container orchestration platform that seeks to address these issues. Briefly, it provides a mechanism for defining **entire** microservice-based application deployment topologies and their service-level requirements for maintaining continuous availability. It is agnostic to the targeted cloud provider, can be run on-premises and even locally on your laptop - all that's required is a cluster of virtual machines running Kubernetes - i.e. a Kubernetes cluster.

This README is designed to be read in conjunction with the code in this repository, that contains the Python modules, Docker configuration files and Kubernetes instructions for demonstrating how a simple Python ML model can be turned into a production-grade RESTful model-scoring (or prediction) API service, using Docker and Kubernetes - both locally and with Google Cloud Platform (GCP). It is not a comprehensive guide to Kubernetes, Docker or ML - think of it more as a 'ML on Kubernetes 101' for demonstrating capability and allowing newcomers to Kubernetes (e.g. data scientists who are more focused on building models as opposed to deploying them), to get up-and-running quickly and become familiar with the basic concepts and patterns.

We will demonstrate ML model deployment using two different approaches: a first principles approach using Docker and Kubernetes; and then a deployment using the [Seldon-Core](https://www.seldon.io) Kubernetes native framework for streamlining the deployment of ML services. The former will help to appreciate the latter, which constitutes a powerful framework for deploying and performance-monitoring many complex ML model pipelines.

**Table of Contents**

[TOC]

## Containerising a Simple ML Model Scoring Service using Flask and Docker

We start by demonstrating how to achieve this basic competence using the simple Python ML model scoring REST API contained in the `api.py` module, together with the `Dockerfile`, both within the `py-flask-ml-score-api` directory, whose core contents are as follows,

```bash
py-flask-ml-score-api/
 | Dockerfile
 | Pipfile
 | Pipfile.lock
 | api.py
```

If you're already feeling lost then these files are discussed in the points below, otherwise feel free to skip to the next section.

### Defining the Flask Service in the `api.py` Module

This is a Python module that uses the [Flask](http://flask.pocoo.org) framework for defining a web service (`app`), with a function (`score`), that executes in response to a HTTP request to a specific URL (or 'route'), thanks to being wrapped by the `app.route` function. For reference, the relevant code is reproduced below,

```python
from flask import Flask, jsonify, make_response, request

app = Flask(__name__)


@app.route('/score', methods=['POST'])
def score():
    features = request.json['X']
    return make_response(jsonify({'score': features}))


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

If running locally - e.g. by starting the web service using `python run api.py` - we would be able reach our function (or 'endpoint') at `http://localhost:5000/score`. This function takes data sent to it as JSON (that has been automatically de-serialised as a Python dict made available as the `request` variable in our function definition), and returns a response (automatically serialised as JSON).

In our example function, we expect an array of features, `X`, that we pass to a ML model, which in our example returns those same features back to the caller - i.e. our chosen ML model is the identity function, which we have chosen for purely demonstrative purposes. We could just as easily have loaded a pickled SciKit-Learn or Keras model and passed the data to the approproate `predict` method, returning a score for the feature-data as JSON - see [here](https://github.com/AlexIoannides/ml-workflow-automation/blob/master/deploy/py-sklearn-flask-ml-service/api.py) for an example of this in action.

### Defining the Docker Image with the `Dockerfile`

 A `Dockerfile` is essentially the configuration file used by Docker, that allows you to define the contents and configure the operation of a Docker container, when operational. This static data, when not executed as a container, is referred to as the 'image'. For reference, the `Dockerfile` is reproduced below,

```docker
FROM python:3.6-slim
WORKDIR /usr/src/app
COPY . .
RUN pip install pipenv
RUN pipenv install
EXPOSE 5000
CMD ["pipenv", "run", "python", "api.py"]
```

In our example `Dockerfile` we:

 - start by using a pre-configured Docker image (`python:3.6-slim`) that has a version of the [Alpine Linux](https://www.alpinelinux.org/community/) distribution with Python already installed;
 - then copy the contents of the `py-flask-ml-score-api` local directory to a directory on the image called `/usr/src/app`;
 - then use `pip` to install the [Pipenv](https://pipenv.readthedocs.io/en/latest/) package for Python dependency management (see the appendix at the bottom for more information on how we use Pipenv);
 - then use Pipenv to install the dependencies described in `Pipfile.lock` into a virtual environment on the image;
 - configure port 5000 to be exposed to the 'outside world' on the running container; and finally,
 - to start our Flask RESTful web service - `api.py`. Note, that here we are relying on Flask's internal [WSGI](https://en.wikipedia.org/wiki/Web_Server_Gateway_Interface) server, whereas in a production setting we would recommend on configuring a more robust option (e.g. Gunicorn), [as discussed here](https://pythonspeed.com/articles/gunicorn-in-docker/).

 Building this custom image and asking the Docker daemon to run it (remember that a running image is a 'container'), will expose our RESTful ML model scoring service on port 5000 as if it were running on a dedicated virtual machine. Refer to the official [Docker documentation](https://docs.docker.com/get-started/) for a more comprehensive discussion of these core concepts.

### Building a Docker Image for the ML Scoring Service

We assume that [Docker is running locally](https://www.docker.com) (both Docker client and daemon), that the client is logged into an account on [DockerHub](https://hub.docker.com) and that there is a terminal open in the this project's root directory. To build the image described in the `Dockerfile` run,

```bash
docker build --tag alexioannides/test-ml-score-api py-flask-ml-score-api
```

Where 'alexioannides' refers to the name of the DockerHub account that we will push the image to, once we have tested it. 

#### Testing

To test that the image can be used to create a Docker container that functions as we expect it to use,

```bash
docker run --rm --name test-api -p 5000:5000 -d alexioannides/test-ml-score-api
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

All our test model does is return the input data - i.e. it is the identity function. Only a few lines of additional code are required to modify this service to load a SciKit Learn model from disk and pass new data to it's 'predict' method for generating predictions - see [here](https://github.com/AlexIoannides/ml-workflow-automation/blob/master/deploy/py-sklearn-flask-ml-service/api.py) for an example. Now that the container has been confirmed as operational, we can stop it,

```bash
docker stop test-api
```

#### Pushing the Image to the DockerHub Registry

In order for a remote Docker host or Kubernetes cluster to have access to the image we've created, we need to publish it to an image registry. All cloud computing providers that offer managed Docker-based services will provide private image registries, but we will use the public image registry at DockerHub, for convenience. To push our new image to DockerHub (where my account ID is 'alexioannides') use,

```bash
docker push alexioannides/test-ml-score-api
```

Where we can now see that our chosen naming convention for the image is intrinsically linked to our target image registry (you will need to insert your own account ID where required). Once the upload is finished, log onto DockerHub to confirm that the upload has been successful via the [DockerHub UI](https://hub.docker.com/u/alexioannides).

## Installing Kubernetes for Local Development and Testing

There are two options for installing a single-node Kubernetes cluster that is suitable for local development and testing: via the [Docker Desktop](https://www.docker.com/products/docker-desktop) client, or via [Minikube](https://github.com/kubernetes/minikube).

### Installing Kubernetes via Docker Desktop

If you have been using Docker on a Mac, then the chances are that you will have been doing this via the Docker Desktop application. If not (e.g. if you installed Docker Engine via Homebrew), then Docker Desktop can be downloaded [here](https://www.docker.com/products/docker-desktop). Docker Desktop now comes bundled with Kubernetes, which can be activated by going to `Preferences -> Kubernetes` and selecting `Enable Kubernetes`. It will take a while for Docker Desktop to download the Docker images required to run Kubernetes, so be patient. After it has finished, go to `Preferences -> Advanced` and ensure that at least 2 CPUs and 4 GiB have been allocated to the Docker Engine, which are the the minimum resources required to deploy a single Seldon ML component.

To interact with the Kubernetes cluster you will need the `kubectl` Command Line Interface (CLI) tool, which will need to be downloaded separately. The easiest way to do this on a Mac is via Homebrew - i.e with `brew install kubernetes-cli`. Once you have `kubectl` installed and a Kubernetes cluster up-and-running, test that everything is working as expected by running,

```bash
kubectl cluster-info
```

Which ought to return something along the lines of,

```bash
Kubernetes master is running at https://kubernetes.docker.internal:6443
KubeDNS is running at https://kubernetes.docker.internal:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

### Installing Kubernetes via Minikube

On Mac OS X, the steps required to get up-and-running with Minikube are as follows:

- make sure the [Homebrew](https://brew.sh) package manager for OS X is installed; then,
- install VirtualBox using, `brew cask install virtualbox` (you may need to approve installation via OS X System Preferences); and then,
- install Minikube using, `brew cask install minikube`.

To start the test cluster run,

```bash
minikube start --memory 4096
```

Where we have specified the minimum amount of memory required to deploy a single Seldon ML component. Be patient - Minikube may take a while to start. To test that the cluster is operational run,

```bash
kubectl cluster-info
```

Where `kubectl` is the standard Command Line Interface (CLI) client for interacting with the Kubernetes API (which was installed as part of Minikube, but is also available separately).

### Deploying the Containerised ML Model Scoring Service to Kubernetes

To launch our test model scoring service on Kubernetes, we will start by deploying the containerised service within a Kubernetes [Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/), whose rollout is managed by a [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/), which in in-turn creates a [ReplicaSet](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/) - a Kubernetes resource that ensures a minimum number of pods (or replicas), running our service are operational at any given time. This is achieved with,

```bash
kubectl create deployment test-ml-score-api --image=alexioannides/test-ml-score-api:latest
```

To check on the status of the deployment run,

```bash
kubectl rollout status deployment test-ml-score-api
```

And to see the pods that is has created run,

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
kubectl expose deployment test-ml-score-api --port 5000 --type=LoadBalancer --name test-ml-score-api-lb
```

If you are using Docker Desktop, then this will automatically emulate a load balancer at `http://localhost:5000`. To find where Minikube has exposed its emulated load balancer run,

```bash
minikube service list
```

Now we test our new service - for example (with Docker Desktop),

```bash
curl http://localhost:5000/score \
    --request POST \
    --header "Content-Type: application/json" \
    --data '{"X": [1, 2]}'
```

Note, neither Docker Desktop or Minikube setup a real-life load balancer (which is what would happen if we made this request on a cloud platform). To tear-down the load balancer, deployment and pod, run the following commands in sequence,

```bash
kubectl delete deployment test-ml-score-api
kubectl delete service test-ml-score-api-lb
```

## Configuring a Multi-Node Cluster on Google Cloud Platform

In order to perform testing on a real-world Kubernetes cluster with far greater resources than those available on a laptop, the easiest way is to use a managed Kubernetes platform from a cloud provider. We will use Kubernetes Engine on [Google Cloud Platform (GCP)](https://cloud.google.com).

### Getting Up-and-Running with Google Cloud Platform

Before we can use Google Cloud Platform, sign-up for an account and create a project specifically for this work. Next, make sure that the GCP SDK is installed on your local machine - e.g.,

```bash
brew cask install google-cloud-sdk
```

Or by downloading an installation image [directly from GCP](https://cloud.google.com/sdk/docs/quickstart-macos). Note, that if you haven't already installed Kubectl, then you will need to do so now, which can be done using the GCP SDK,

```bash
gcloud components install kubectl
```

We then need to initialise the SDK,

```bash
gcloud init
```

Which will open a browser and guide you through the necessary authentication steps. Make sure you pick the project you created, together with a default zone and region (if this has not been set via Compute Engine -> Settings).

### Initialising a Kubernetes Cluster

Firstly, within the GCP UI visit the Kubernetes Engine page to trigger the Kubernetes API to start-up. From the command line we then start a cluster using,

```bash
gcloud container clusters create k8s-test-cluster --num-nodes 3 --machine-type g1-small
```

And then go make a cup of coffee while you wait for the cluster to be created. Note, that this will automatically switch your `kubectl` context to point to the cluster on GCP, as you will see if you run, `kubectl config get-contexts`. To switch back to the Docker Desktop client use `kubectl config use-context docker-desktop`.

### Launching the Containerised ML Model Scoring Service on GCP

This is largely the same as we did for running the test service locally - run the following commands in sequence,

```bash
kubectl create deployment test-ml-score-api --image=alexioannides/test-ml-score-api:latest
kubectl expose deployment test-ml-score-api --port 5000 --type=LoadBalancer --name test-ml-score-api-lb
```

But, to find the external IP address for the GCP cluster we will need to use,

```bash
kubectl get services
```

And then we can test our service on GCP - for example,

```bash
curl http://35.246.92.213:5000/score \
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
kubectl delete deployment test-ml-score-api
kubectl delete service test-ml-score-api-lb
```

## Switching Between Kubectl Contexts

If you are running both with Kubernetes locally and with a cluster on GCP, then you can switch Kubectl [context](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/) from one cluster to the other, as follows,

```bash
kubectl config use-context docker-desktop
```

Where the list of available contexts can be found using,

```bash
kubectl config get-contexts
```

## Using YAML Files to Define and Deploy the ML Model Scoring Service

Up to this point we have been using Kubectl commands to define and deploy a basic version of our ML model scoring service. This is fine for demonstrative purposes, but quickly becomes limiting, as well as unmanageable. In practice, the standard way of defining entire Kubernetes deployments is with YAML files,  posted to the Kubernetes API. The `py-flask-ml-score.yaml` file in the `py-flask-ml-score-api` directory is an example of how our ML model scoring service can be defined in a single YAML file. This can now be deployed using a single command,

```bash
kubectl apply -f py-flask-ml-score-api/py-flask-ml-score.yaml
```

Note, that we have defined three separate Kubernetes components in this single file: a [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/), a deployment and a load-balanced service - for all of these components (and their sub-components), using `---` to delimit the definition of each separate component. To see all components deployed into this namespace use,

```bash
kubectl get all --namespace test-ml-app
```

And likewise set the `--namespace` flag when using any `kubectl get` command to inspect the different components of our test app. Alternatively, we can set our new namespace as the default context,

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

## Using Helm Charts to Define and Deploy the ML Model Scoring Service

Writing YAML files for Kubernetes can get repetitive and hard to manage, especially if there is a lot of 'copy-paste' involved, when only a handful of parameters need to be changed from one deployment to the next,  but there is a 'wall of YAML' that needs to be modified. Enter [Helm](https://helm.sh//) - a framework for creating, executing and managing Kubernetes deployment templates. What follows is a very high-level demonstration of how Helm can be used to deploy our ML model scoring service - for a comprehensive discussion of Helm's full capabilities (and here are a lot of them), please refer to the [official documentation](https://docs.helm.sh). Seldon-Core can also be deployed using Helm and we will cover this in more detail later on.

### Installing Helm

As before, the easiest way to install Helm onto Mac OS X is to use the Homebrew package manager,

```bash
brew install kubernetes-helm
```

Helm relies on a dedicated deployment server, referred to as the 'Tiller', to be running within the same Kubernetes cluster we wish to deploy our applications to. Before we deploy Tiller we need to create a cluster-wide super-user role to assign to it, so that it can create and modify Kubernetes resources in any namespace. To achieve this, we start by creating a [Service Account](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) that is destined for our tiller. A Service Account is a means by which a pod (and any service running within it), when associated with a Service Accoutn, can authenticate itself to the Kubernetes API, to be able to view, create and modify resources. We create this in the `kube-system` namespace (a common convention) as follows,

```bash
kubectl --namespace kube-system create serviceaccount tiller
```

We then create a binding between this Service Account and the `cluster-admin` [Cluster Role](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), which as the name suggest grants cluster-wide admin rights,

```bash
kubectl create clusterrolebinding tiller \
    --clusterrole cluster-admin \
    --serviceaccount=kube-system:tiller
```

We can now deploy the Helm Tiller to a Kubernetes cluster, with the desired access rights using,

```bash
helm init --service-account tiller
```

### Deploying with Helm

To create a fresh Helm deployment definition - referred to as a 'chart' in Helm terminology - run,

```bash
helm create NAME-OF-YOUR-HELM-CHART
```

This creates a new directory - e.g. `helm-ml-score-app` as included with this repository - with the following high-level directory structure,

```bash
helm-ml-score-app/
 | -- charts/
 | -- templates/
 | Chart.yaml
 | values.yaml
```

Briefly, the `charts` directory contains other charts that our new chart will depend on (we will not make use of this), the `templates` directory contains our Helm templates, `Chart.yaml` contains core information for our chart (e.g. name and version information) and `values.yaml` contains default values to render our templates with (in the case that no values are set from the command line).

The next step is to delete all of the files in the `templates` directory (apart from `NOTES.txt`), and to replace them with our own. We start with `namespace.yaml` for declaring a namespace for our app,

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.app.namespace }}
```

Anyone familiar with HTML template frameworks (e.g. Jinja), will be familiar with the use of ``{{}}`` for defining values that will be injected into the rendered template. In this specific instance `.Values.app.namespace` injects the `app.namespace` variable, whose default value defined in `values.yaml`. Next we define a deployment of pods in `deployment.yaml`,

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: {{ .Values.app.name }}
    env: {{ .Values.app.env }}
  name: {{ .Values.app.name }}
  namespace: {{ .Values.app.namespace }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Values.app.name }}
  template:
    metadata:
      labels:
        app: {{ .Values.app.name }}
        env: {{ .Values.app.env }}
    spec:
      containers:
      - image: {{ .Values.app.image }}
        name: {{ .Values.app.name }}
        ports:
        - containerPort: {{ .Values.containerPort }}
          protocol: TCP
```

And the details of the load balancer service in `service.yaml`,

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.app.name }}-lb
  labels:
    app: {{ .Values.app.name }}
  namespace: {{ .Values.app.namespace }}
spec:
  type: LoadBalancer
  ports:
  - port: {{ .Values.containerPort }}
    targetPort: {{ .Values.targetPort }}
  selector:
    app: {{ .Values.app.name }}
```

What we have done, in essence, is to split-out each component of the deployment details from `py-flask-ml-score.yaml` into its own file and then define template variables for each parameter of the configuration that is most likely to change from one deployment to the next. To test and examine the rendered template, without having to attempt a deployment, run,

```bash
helm install helm-ml-score-app --debug --dry-run
```

If you are happy with the results of the 'dry run', then execute the deployment and generate a release from the chart using,

```bash
helm install helm-ml-score-app --name test-ml-app
```

This will automatically print the status of the release, together with the name that Helm has ascribed to it (e.g. 'willing-yak') and the contents of `NOTES.txt` rendered to the terminal. To list all available Helm releases and their names use,

```bash
helm list
```

And to the status of all their constituent components (e.g. pods, replication controllers, service, etc.) use for example,

```bash
helm status test-ml-app
```

The ML scoring service can now be tested in exactly the same way as we have done previously (above). Once you have convinced yourself that it's working as expected, the release can be deleted using,

```bash
helm delete test-ml-app
```

## Using Seldon to Deploy the ML Model Scoring Service to Kubernetes

Seldon's core mission is to simplify the repeated deployment and management of complex ML prediction pipelines on top of Kubernetes. In this demonstration we are going to focus on the simplest possible example - i.e. the simple ML model scoring API we have already been using.

### Building an ML Component for Seldon

To deploy a ML component using Seldon, we need to create Seldon-compatible Docker images. We start by following [these guidelines](https://docs.seldon.io/projects/seldon-core/en/latest/python/python_wrapping_docker.html) for defining a Python class that wraps an ML model targeted for deployment with Seldon. This is contained within the `seldon-ml-score-component` directory.

#### Building the Docker Image for use with Seldon

Seldon requires that the Docker image for the ML scoring service be structured in a particular way:

- the ML model has to be wrapped in a Python class with a `predict` method with a particular signature (or interface);
- the `seldon-core` Python package must be installed (we use `pipenv` to manage dependencies as discussed above and in the Appendix below); and,
- the container starts by running the Seldon service using the `seldon-core-microservice` entry-point provided by the `seldon-core` package.

For the precise details, see `MLScore.py` and `Dockefile` in the `seldon-ml-score-component` directory. Next, build this image,

```bash
docker build seldon-ml-score-component -t alexioannides/test-ml-score-seldon-api:latest
```

Before we push this image to our registry, we need to make sure that it's working as expected. Start the image on the local Docker daemon,

```bash
docker run --rm -p 5000:5000 -d alexioannides/test-ml-score-seldon-api:latest
```

And then send it a request (using a different request format to the ones we've used thus far),

```bash
curl -g http://localhost:5000/predict \
    --data-urlencode 'json={"data":{"names":["a","b"],"tensor":{"shape":[2,2],"values":[0,0,1,1]}}}'
```

If response is as expected (i.e. it contains the same payload as the request), then push the image,

```bash
docker push alexioannides/test-ml-score-seldon-api:latest
```

### Deploying a ML Component with Seldon Core

We now move on to deploying our Seldon compatible ML component to a Kubernetes cluster and creating a fault-tolerant and scalable service from it. To achieve this, we will [deploy Seldon-Core using Helm charts](https://docs.seldon.io/projects/seldon-core/en/latest/workflow/install.html). We start by creating a namespace that will contain the `seldon-core-operator`, a custom Kubernetes resource required to deploy any ML model using Seldon,

```bash
kubectl create namespace seldon-core
```

Then we deploy Seldon-Core using Helm and the official Seldon Helm chart repository hosted at `https://storage.googleapis.com/seldon-charts`,

```bash
helm install seldon-core-operator \
  --name seldon-core \
  --repo https://storage.googleapis.com/seldon-charts \
  --set usageMetrics.enabled=false \
  --namespace seldon-core
```

Next, we deploy the Ambassador API gateway for Kubernetes, that will act as a single point of entry into our Kubernetes cluster and will be able to route requests to any ML model we have deployed using Seldon. We will create a dedicate namespace for the Ambassador deployment,

```bash
kubectl create namespace ambassador
```

And then deploy Ambassador using the most recent charts in the official Helm repository,

```bash
helm install stable/ambassador \
  --name ambassador \
  --set crds.keep=false \
  --namespace ambassador
```

If we now run `helm list --namespace seldon-core` we should see that Seldon-Core has been deployed and is waiting for Seldon ML components to be deployed. To deploy our Seldon ML model scoring service we create a separate namespace for it,

```bash
kubectl create namespace test-ml-seldon-app
```

And then configure and deploy another official Seldon Helm chart as follows,

```bash
helm install seldon-single-model \
  --name test-ml-seldon-app \
  --repo https://storage.googleapis.com/seldon-charts \
  --set model.image.name=alexioannides/test-ml-score-seldon-api:latest \
  --namespace test-ml-seldon-app
```

Note, that multiple ML models can now be deployed using Seldon by repeating the last two steps and they will all be automatically reachable via the same Ambassador API gateway, which we will now use to test our Seldon ML model scoring service.

### Testing the API via the Ambassador Gateway API

To test the Seldon-based ML model scoring service, we follow the same general approach as we did for our first-principles Kubernetes deployments above, but we will route our requests via the Ambassador API gateway. To find the IP address for Ambassador service run,

```bash
kubectl -n ambassador get service ambassador
```

Which will be `localhost:80` if using Docker Desktop, or an IP address if running on GCP or Minikube (were you will need to remember to use `minikuke service list` in the latter case). Now test the prediction end-point - for example,

```bash
curl http://35.246.28.247:80/seldon/test-ml-seldon-app/test-ml-seldon-app/api/v0.1/predictions \
    --request POST \
    --header "Content-Type: application/json" \
    --data '{"data":{"names":["a","b"],"tensor":{"shape":[2,2],"values":[0,0,1,1]}}}'
```

If you want to understand the full logic behind the routing see the [Seldon documentation](https://docs.seldon.io/projects/seldon-core/en/latest/workflow/serving.html), but the URL is essentially assembled using,

```html
http://<ambassadorEndpoint>/seldon/<namespace>/<deploymentName>/api/v0.1/predictions
```

If your request has been successful, then you should see a response along the lines of,

```json
{
  "meta": {
    "puid": "hsu0j9c39a4avmeonhj2ugllh9",
    "tags": {
    },
    "routing": {
    },
    "requestPath": {
      "classifier": "alexioannides/test-ml-score-seldon-api:latest"
    },
    "metrics": []
  },
  "data": {
    "names": ["t:0", "t:1"],
    "tensor": {
      "shape": [2, 2],
      "values": [0.0, 0.0, 1.0, 1.0]
    }
  }
}
```

## Tear Down

To delete a single Seldon ML model and its namespace, deployed using the steps above, run,

```bash
helm delete test-ml-seldon-app --purge &&
  kubectl delete namespace test-ml-seldon-app
```

Follow the same pattern to remove the Seldon Core Operator and Ambassador,

```bash
helm delete seldon-core --purge && kubectl delete namespace seldon-core
helm delete ambassador --purge && kubectl delete namespace ambassador
```

If there is a GCP cluster that needs to be killed run,

```bash
gcloud container clusters delete k8s-test-cluster
```

And likewise if working with Minikube,

```bash
minikube stop
minikube delete
```

If running on Docker Desktop, navigate to `Preferences -> Reset` to reset the cluster.

## Where to go from Here

The following list of resources will help you dive deeply into the subjects we skimmed-over above:

- the full set of functionality provided by [Seldon](https://www.seldon.io/open-source/);
- running multi-stage containerised workflows (e.g. for data engineering and model training) using [Argo Workflows](https://argoproj.github.io/argo);
- the excellent '_Kubernetes in Action_' by Marko Lukša [available from Manning Publications](https://www.manning.com/books/kubernetes-in-action);
- '_Docker in Action_' by Jeff Nickoloff and Stephen Kuenzli [also available from Manning Publications](https://www.manning.com/books/docker-in-action-second-edition); and,
- _'Flask Web Development'_ by Miguel Grinberg [O'Reilly](http://shop.oreilly.com/product/0636920089056.do).

## Appendix - Using Pipenv for Managing Python Package Dependencies

We use [pipenv](https://docs.pipenv.org) for managing project dependencies and Python environments (i.e. virtual environments). All of the direct packages dependencies required to run the code (e.g. Flask or Seldon-Core), as well as any packages that could have been used during development (e.g. flake8 for code linting and IPython for interactive console sessions), are described in the `Pipfile`. Their **precise** downstream dependencies are described in `Pipfile.lock`.

### Installing Pipenv

To get started with Pipenv, first of all download it - assuming that there is a global version of Python available on your system and on the PATH, then this can be achieved by running the following command,

```bash
pip3 install pipenv
```

Pipenv is also available to install from many non-Python package managers. For example, on OS X it can be installed using the [Homebrew](https://brew.sh) package manager, with the following terminal command,

```bash
brew install pipenv
```

For more information, including advanced configuration options, see the [official pipenv documentation](https://docs.pipenv.org).

### Installing Projects Dependencies

If you want to experiment with the Python code in the `py-flask-ml-score-api` or `seldon-ml-score-component` directories, then make sure that you're in the appropriate directory and then run,

```bash
pipenv install
```

This will install all of the direct project dependencies.

### Running Python, IPython and JupyterLab from the Project's Virtual Environment

In order to continue development in a Python environment that precisely mimics the one the project was initially developed with, use Pipenv from the command line as follows,

```bash
pipenv run python3
```

The `python3` command could just as well be `seldon-core-microservice` or any other entry-point provided by the `seldon-core` package - for example, in the `Dockerfile` for the `seldon-ml-score-component` we start the Seldon-based ML model scoring service using,

```bash
pipenv run seldon-core-microservice ...
```

### Pipenv Shells

Prepending `pipenv` to every command you want to run within the context of your Pipenv-managed virtual environment, can get very tedious. This can be avoided by entering into a Pipenv-managed shell,

```bash
pipenv shell
```

which is equivalent to 'activating' the virtual environment. Any command will now be executed within the virtual environment. Use `exit` to leave the shell session.
