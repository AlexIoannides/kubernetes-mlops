# Deploying Machine Learning Models on Kubernetes

A common pattern for deploying Machine Learning (ML) models into production environments - e.g. a ML model trained using the SciKit Learn package in Python and ready to provide predictions on new data, is to expose them as RESTful API microservices hosted from within [Docker](https://www.docker.com) containers, that are in-turn deployed to a cloud environment for handling everything required for maintaining continuous availability - e.g. fail-over, auto-scaling, load balancing and rolling service updates.

The configuration details for a continuously available cloud deployment are specific to the targeted cloud provider(s) - e.g. the deployment process and topology for Amazon Web Services is not the same as that for Microsoft Azure, which in-turn is not the same as that for Google Cloud Platform. This constitutes knowledge that needs to be acquired for every targeted cloud provider. Furthermore, it is difficult (some would say near impossible) to test entire deployment strategies locally, which makes issues such as networking hard to debug.

[Kubernetes](https://kubernetes.io) is a container orchestration platform that seeks to address these issues. Briefly, it provides a mechanism for defining **entire** microservice-based application deployment topologies and their service-level requirements for maintaining continuous availability. It is agnostic to the targeted cloud provider, can be run on-premises and even locally on your laptop - all that's required is a cluster of virtual machines running Kubernetes - i.e. a Kubernetes cluster.

This repository contains sample code, configuration files and Kubernetes instructions for demonstrating how a simple Python ML model can be turned into a production-grade RESTful model scoring (or prediction) API service, using Docker and Kubernetes - both locally and with Google Cloud Platform (GCP). It is not a comprehensive guide to Kubernetes, Docker or ML - think of it more as a 'ML on Kubernetes 101' for demonstrating capability and allowing newcomers to Kubernetes (e.g. data scientists who are more focused on building models as opposed to deploying them), to get up-and-running quickly and become familiar with the basic concepts.

We will demonstrate the ML model deployment using two different approaches: a first principles approach using Docker and Kubernetes; and then a deployment using the [Seldon-Core](https://www.seldon.io) framework for managing ML model pipelines on Kubernetes. The former will help to appreciate the latter, which constitutes a powerful framework for deploying and performance-monitoring many complex ML model pipelines.

## Containerising a Simple ML Model Scoring Service using Docker

We start by demonstrating how to achieve this basic competence using the simple Python ML model scoring REST API contained in the `py-flask-ml-score-api/api.py` module, together with the `Dockerfile` within the `py-flask-ml-score-api` directory. If you're already feeling lost then these files are discussed in the points below, otherwise feel free to skip to the next section.
 
 - `api.py` is a Python module that uses the [Flask](http://flask.pocoo.org) framework for defining a web service (`app`) with a function (`score`) that executes in response to a HTTP request to a specific URL (or 'route') - e.g. running locally by executing the web service using `python run api.py`), we would reach our function (or 'endpoint') at `http://localhost:5000/score`. This function takes data sent to it as JSON (that has been automatically de-serialised as a Python dict made available as the `request` variable in our function definition), and returns a response (automatically serialised as JSON). In our example function, we expect an array of features, `X`, that we pass to a ML model, which in our example returns those same features back to the caller - i.e. our ML model is the identity function, which we have chosen for demonstrative purposes. We could have loaded a pickled SciKit-Learn model and passed the data to its `predict` method, returning its score for the feature-data as JSON, just as easily - see [here](https://github.com/AlexIoannides/ml-workflow-automation/blob/master/deploy/py-sklearn-flask-ml-service/api.py) for an example of this in action.
 - `Dockerfile` is a [YAML](https://en.wikipedia.org/wiki/YAML) file that allows us to define the contents and configure the operation of our intended Docker container, when it is running. This static data, when not executed as a container, is referred to as the 'image'. In our example Dockerfile, we start by using a pre-configured Docker image (`python:3.6-slim`) that has a version of Linux with Python already installed; we then copy the contents of the `py-flask-ml-score-api` local directory to a directory on the image called `/usr/src/app`; then use `pip` to install the [Pipenv](https://pipenv.readthedocs.io/en/latest/) package for Python dependency management; use Pipenv to install the dependencies described in `Pipfile.lock` into a virtual environment on the image; configure port 5000 to be exposed to the 'outside world' on the running container; and finally, to start our Flask RESTful web service - `api.py`. Building this custom image and asking the Docker daemon to run it (remember that a running image is a 'container'), will expose our RESTful ML model scoring service on port 5000 as if it were running on a dedicated virtual machine. Refer to the official [Docker documentation](https://docs.docker.com/get-started/) for a more comprehensive discussion of these core concepts.

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

All our test model does is return the input data - i.e. it is the identity function. Only a few lines of additional code are required to modify this service to load a SciKit Learn model from disk and pass new data to it's 'predict' method for generating predictions - see [here](https://github.com/AlexIoannides/ml-workflow-automation/blob/master/deploy/py-sklearn-flask-ml-service/api.py) for an example. Now that the container has been confirmed as operational, we can stop and remove it,

```bash
docker stop test-api
docker rm test-api
```

### Pushing a Docker Image to DockerHub

In order for a remote Docker host or Kubernetes cluster to have access to the image we've created, we need to publish it to an image registry. All cloud computing providers that offer managed Docker-based services will provide private image registries, but we will use the public image registry at DockerHub, for convenience. To push our new image to DockerHub (where my account ID is 'alexioannides') use,

```bash
docker push alexioannides/test-ml-score-api
```

Where we can now see that our chosen naming convention for the image is intrinsically linked to our target image registry (you will need to insert your own account ID where necessary). Once the upload is finished, log onto DockerHub to confirm that the upload has been successful via the [DockerHub UI](https://hub.docker.com/u/alexioannides).

## Installing Minikube for Local Development and Testing

[Minikube](https://github.com/kubernetes/minikube) allows a single node Kubernetes cluster to run within a Virtual Machine (VM) within a local machine (i.e. on your laptop), for development purposes. On Mac OS X, the steps required to get up-and-running are as follows:

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

### Launching the Containerised ML Model Scoring Service on Minikube

To launch our test model scoring service on Kubernetes, start by running the container within a Kubernetes [pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) that is managed by a [replication controller](https://kubernetes.io/docs/concepts/workloads/controllers/replicationcontroller/), which is the device that ensures that at least one pod running our service is operational at any given time. This is achieved with, 

```bash
kubectl run test-ml-score-api --image=alexioannides/test-ml-score-api:latest --port=5000 --generator=run/v1
```

Where the `--generator=run/v1` flag triggers the construction of the replication controller to manage the pod. To check that it's running use,

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
kubectl expose replicationcontroller test-ml-score-api --type=LoadBalancer --name test-ml-score-api-http
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

Note that we need to use Minikube-specific commands as Minikube does not setup a real-life load balancer (which is what would happen if we made this request on a cloud platform). To tear-down the load balancer, replication controller, pod and Minikube cluster run the following commands in sequence,

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

Firstly, within the GCP UI visit the Kubernetes Engine page to trigger the Kubernetes API to start-up. From the command line we then start a cluster using,

```bash
gcloud container clusters create k8s-test-cluster --num-nodes 3 --machine-type g1-small
```

And then go make a cup of coffee while you wait for the cluster to be created.

### Launching the Containerised ML Model Scoring Service on the GCP

This is largely the same as we did for running the test service locally using Minikube - run the following commands in sequence,

```bash
kubectl run test-ml-score-api --image=alexioannides/test-ml-score-api:latest --port=5000 --generator=run/v1
kubectl expose replicationcontroller test-ml-score-api --type=LoadBalancer --name test-ml-score-api-http
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
kubectl delete replicationcontroller test-ml-score-api
kubectl delete service test-ml-score-api-http
```

## Switching Between Kubectl Contexts

If you are running both with Minikube locally and with a cluster on GCP, then you can switch Kubectl [context](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/) from one cluster to the other using, for example,

```bash
kubectl config use-context minikube
```

Where the list of available contexts can be found using,

```bash
kubectl config get-contexts
```

## Using YAML Files to Define and Deploy our ML Model Scoring Service

Up to this point we have been using Kubectl commands to define and deploy a basic version of our ML model scoring service. This is fine for demonstrative purposes, but quickly becomes limiting as well as unmanageable. In practice, the standard way of defining entire applications is with YAML files that are posted to the Kubernetes API. The `py-flask-ml-score.yaml` file in the `py-flask-ml-score-api` is an example of how our ML model scoring service can be defined in a single YAML file. This can now be deployed using a single command,

```bash
kubectl apply -f py-flask-ml-score-api/py-flask-ml-score.yaml
```

Note, that we have defined three separate Kubernetes components in this single file: a replication controller, a load-balancer service and a [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) for all of these components (and their sub-components) - using `---` to delimit the definition of each separate component. To see all components deployed into this namespace use,

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

## Using Helm Charts to Define and Deploy our ML Model Scoring Service

Writing YAML files for Kubernetes can get repetitive and hard to manage, especially if there is a lot of 'copy paste' involved when only a handful of parameters need to be changed from one deployment to the next and there is a 'wall of YAML' that needs to be modified. Enter [Helm](https://helm.sh//) - a framework for creating, executing and managing Kubernetes deployment templates. What follows is a very high-level demonstration of how Helm can be used to deploy our ML model scoring service - for a comprehensive discussion of Helm's full capabilities (there are a lot of them), please refer to the [official documentation](https://docs.helm.sh). Seldon-Core can also be deployed using Helm and we will cover this in more detail later on.

### Installing Helm

As before, the easiest way to install Helm onto Mac OS X is to use the Homebrew package manager,

```bash
brew install kubernetes-helm
```

Helm relies on a dedicated deployment server, referred to as the 'Tiller', to be running within the same Kubernetes cluster we wish to deploy our applications to. Before we deploy Tiller we need to create a cluster-wide super-user role to assign to it (via a dedicated service account),

```bash
kubectl --namespace kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller \
    --clusterrole cluster-admin \
    --serviceaccount=kube-system:tiller
```

We can now deploy the Helm Tiller to your Kubernetes cluster using,

```bash
helm init --service-account tiller
```

### Deploy our ML Model Scoring Service

To initiate a new deployment - referred to as a 'chart' in Helm terminology - run,

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

Briefly, the `charts` directory contains other charts that our new chart will depend on (we will not make use of this), the `templates` directory contains our Helm templates, `Chart.yaml` contains core information for our chart (e.g. name and version information) and `values.yaml` contains default values to render our templates with (in the case that no values are passed from the command line).

The next step is to delete all of the files in the `templates` directory (apart from `NOTES.txt`), and to replace them with our own. We start with `namespace.yaml` for declaring a namespace for our app,

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.app.namespace }}
```

Anyone familiar with HTML template frameworks (e.g. Jinja), will be familiar with the use of ``{{}}`` for defining values that will be injected into the rendered template. In this specific instance `.Values.app.namespace` injects the `app.namespace` variable, whose default value defined in `values.yaml`. Next we define the contents of our pod in `pod.yaml`,

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: {{ .Values.app.name }}-rc
  labels:
    app: {{ .Values.app.name }}
    env: {{ .Values.app.env }}
  namespace: {{ .Values.app.namespace }}
spec:
  replicas: {{ .Values.replicas }}
  template:
    metadata:
      labels:
        app: {{ .Values.app.name }}
        env: {{ .Values.app.env }}
      namespace: {{ .Values.app.namespace }}
    spec:
      containers:
      - image: {{ .Values.app.image }}
        name: {{ .Values.app.name }}-api
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
helm install helm-ml-score-app
```

This will automatically print the status of the release, together with the name that Helm has ascribed to it (e.g. 'willing-yak') and the contents of `NOTES.txt` rendered to the terminal. To list all available Helm releases and their names use,

```bash
helm list
```

And to the status of all their constituent components (e.g. pods, replication controllers, service, etc.) use for example,

```bash
helm status willing-yak
```

The ML scoring service can now be tested in exactly the same way as we have done previously (above). Once you have convinced yourself that it's working as expected, the release can be deleted using,

```bash
helm delete willing-way
```

## Using Ksonnet to Define and Deploy our ML Model Scoring Service

Another framework for templating the configuration of Kubernetes application deployments is [Ksonnet](https://ksonnet.io). Ksonnet allows you to compose Kubernetes application components using templated JSON-object configuration files, written in data templating language called [Jsonnet](https://jsonnet.org) (a superset of JSON). This alternative to Helm is also supported as a means of deploying Seldon-Core (demonstrated below).

### Installing Ksonnet

The easiest way to install Ksonnet (on Mac OS X) is to use Homebrew,

```bash
brew install ksonnet/tap/ks
```

Conform that the installation has been successful by running,

```bash
ks version
```

### Deploy our ML Model Scoring Service

The first step is to initialise a Ksonnet application and we will start by assuming that Minikube is running and is set to the current context,

```bash
ks init NAME-OF-YOUR-KSONNET-APP \
    --context minikube \
    --api-spec=version:v1.8.0
```

This creates a new directory - e.g. `ksonnet-ml-score-app` as included with this repository - with the following high-level directory structure,

```bash
ksonnet-ml-score-app/
 | -- components/
 | -- environments/
 | -- lib/
 | -- vendor/
 | app.yaml
```

Briefly, the `components` directory will contain the files that describe each individual component that is to be deployed as part of the application, while the `environments` directory will contain details of environment-specific deployment overrides. The `app.yaml` file contains the actual environment details - e.g. **Kubernetes cluster IPs and namespaces and will need to be modified if these core fields change**. In order to work with this Ksonnet application, we will need to make it the current directory.

```bash
cd ksonnet-ml-score-app
```

Ksonnet defines 'components' based on prototypes - i.e. Jsonnet templates for pre-configured deployments, where the required fields for the template are provided via command line arguments. To replicate the YAML deployment used above we can use the generic `deployed-service` prototype component. To add this component to our application use,

```bash
ks generate deployed-service test-ml-app \
  --image alexioannides/test-ml-score-api \
  --containerPort 5000 \
  --servicePort 8000 \
  --replicas 2 \
  --type ClusterIP
```

Where the configuration parameters we pass to this prototype component (or template) are self-explanatory. We can take a look at the implied deployment in YAML format using,

```bash
ks show default
```

Next, we want to specify some specific environments - in our case, one for Minikube and one for our GCP cluster, whose context names have been extracted by running `kubectl config get-contexts`. This is accomplished with,

```bash
ks env add test-local --context minikube
ks env add gcp --context gke_k8s-ml-ops_europe-west2-b_k8s-test-cluster
```

Deploying to each environment in-turn is as simple as running,

```bash
ks apply test-local
ks apply gcp
```

Which demonstrates the power of Ksonnet! Deploying new components is as simple as running the `ks generate` command with the appropriate prototype and re-applying (and similarly for modifying existing deployments).

## Using Seldon to Deploy a ML Model Scoring Service on Kubernetes

Seldon's core mission is to simplify the deployment of complex ML prediction pipelines on top of Kubernetes. In this demonstration we are going to focus on the simplest possible example - i.e. the simple ML model scoring API we have already been using.

### Installing Source-to-Image

Seldon-core depends heavily on [Source-to-Image](https://github.com/openshift/source-to-image) - a tool for automating the process of building code artifacts from source and injecting them into docker images. For Seldon, the artifacts are the different pieces of an ML pipeline. We use Homebrew to install Source-to-Image on Mac OS X,

```bash
brew install source-to-image
```

To confirm that it has been installed correctly run,

```bash
s2i version
```

### Install the Seldon-Core Python Package

We're using [Pipenv](https://pipenv.readthedocs.io/en/latest/) to manage the Python dependencies for this project. To install `seldon-core` into a virtual environment managed by Pipenv for use only by this project use,

```bash
pipenv install --python 3.6 seldon-core
```

Note, that we are specifying Python 3.6 explicitly, as at the time of writing Seldon-Core does not work with Python 3.7. If you don't wish to use `pipenv` you can install `seldon-core` using `pip` into whatever environment is most convenient and then drop the use of `pipenv run` when testing with Seldon-Core (below).

### Building an ML Component for Seldon

To deploy a ML component using Seldon, we need to create Seldon-compatible Docker images. We start by following [these guidelines](https://github.com/SeldonIO/seldon-core/blob/master/docs/wrappers/python.md) for defining a Python class that wraps an ML model targeted for deployment with Seldon. This is contained within the `seldon-ml-score-component` directory. Firstly, ensure that the docker daemon is running locally and then run,

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

### Configuring Kubernetes for Seldon-Core

Before we can proceed any further, we will need to grant a cluster-wide super-user role to our user, using Role-Based Access Control (RBAC). On GCP this is achieved with,

```bash
kubectl create clusterrolebinding kube-system-cluster-admin \
    --clusterrole cluster-admin \
    --serviceaccount kube-system:default \
    --user $(gcloud info --format="value(config.account)")
```

And for Minikube with,

```bash
kubectl create clusterrolebinding kube-system-cluster-admin \
    --clusterrole cluster-admin \
    --serviceaccount kube-system:default
```

Next, we create a Kubernetes namespace for all Seldon components that we will deploy,

```bash
kubectl create namespace seldon
```

And we then set it as a default for the current kubectl context,

```bash
kubectl config set-context $(kubectl config current-context) --namespace=seldon
```

So that whenever we run a kubectl command it will now explicitly reference the `seldon` namespace.

### Deploying a ML Component with Seldon-Core via Helm Charts

We now move on to deploying our Seldon compatible ML component and creating a service from it. To achieve this, we will start by demonstrating how to [deploy Seldon-Core using Helm charts](https://github.com/SeldonIO/seldon-core/blob/master/docs/install.md#with-helm). To deploy Seldon-Core using Helm and Helm charts, we start by deploying the Seldon Custom Resource Definitions (CRD), directly from the Seldon chart repository hosted at `https://storage.googleapis.com/seldon-charts`,

```bash
helm install seldon-core-crd \
    --name seldon-core-crd \
    --repo https://storage.googleapis.com/seldon-charts \
    --set usage_metrics.enabled=true
```

We then do the same for Seldon-Core,

```bash
helm install seldon-core \
    --name seldon-core \
    --repo https://storage.googleapis.com/seldon-charts \
    --set apife.enabled=false \
    --set rbac.enabled=true \
    --set ambassador.enabled=true \
    --set single_namespace=true \
    --set namespace=seldon
```

If we now run `helm list --namespace seldon` we should see that Seldon-Core has been deployed and is waiting for Seldon ML components to be deployed alongside it. To deploy our Seldon-compatible ML model score service we configure and deploy another Seldon chart as follows,

```bash
helm install seldon-single-model \
    --name test-seldon-ml-score-api \
    --repo https://storage.googleapis.com/seldon-charts \
    --set model.image.name=alexioannides/seldon-ml-score-component
```

### Deploying a ML Component with Seldon-Core via Ksonnet

We will define our Seldon ML deployment using Seldon's Ksonnet prototypes, using the same workflow as we did for the Ksonnet deployment of our simple ML model scoring service (above). We start by initialising a new Ksonnet application,

```bash
ks init NAME-OF-YOUR-SELDON-KSONNET-APP p --api-spec=version:v1.8.0
```

This will create a new directory - e.g. `seldon-ksonnet-ml-score-app` as bundled with this repository - containing all of the necessary base configuration files for a Ksonnet-based deployment. We start by changing our current directory accordingly,

```bash
cd seldon-ksonnet-ml-score-app
```

To be able to add the base Seldon-Core components to the application we first need to link to the Seldon Ksonnet registry (located on GitHub),

```bash
ks registry add seldon-core github.com/SeldonIO/seldon-core/tree/master/seldon-core
```

And then install the Seldon-Core Ksonnet package,

```bash
ks pkg install seldon-core/seldon-core@master
```

Then we can generate the Seldon-Core components from the Seldon-Core prototype deployment,

```bash
ks generate seldon-core seldon-core \
    --withApife=false \
    --withAmbassador=true \
    --withRbac=true \
    --singleNamespace=true \
    --namespace=seldon
```

We can now deploy Seldon-Core - **without** our ML component - to the default environment (extracted from the current kubectl context) using,

```bash
ks apply default
```

Finally, we deploy our model scoring API component on Seldon-Core by creating the new Ksonnet component that references the Seldon-Core Docker image containing the model scoring API and then applying it, as follows,

```bash
ks generate seldon-serve-simple-v1alpha2 test-seldon-ml-score-api --image alexioannides/seldon-ml-score-component
ks apply default -c test-seldon-ml-score-api
```

Note the similarities in the steps used for both Ksonnet and Helm deployments.

### Testing the API

Regardless of how we deployed Seldon-Core and our Seldon-compatible ML model scoring service, we will test it with the same approaches we have been using above.

#### Via Port Forwarding

We follow the same general approach as we did for our first-principles Kubernetes deployments above, but using embedded bash commands to find the Ambassador API gateway component we need to target for port-forwarding. Regardless of whether or not we working with GCP or Minikube use,

```bash
kubectl port-forward $(kubectl get pods -n seldon -l service=ambassador -o jsonpath='{.items[0].metadata.name}') -n seldon 8003:8080
```

We can then test the model scoring API deployed via Seldon-Core, using the API defined by Seldon-Core,

```bash
curl http://localhost:8003/seldon/test-seldon-ml-score-api/api/v0.1/predictions \
    --request POST \
    --header "Content-Type: application/json" \
    --data '{"data":{"names":["a","b"],"tensor":{"shape":[2,2],"values":[0,0,1,1]}}}'
```

#### Via the Public Internet

Firstly, we need to expose the service to the public internet. If working on GCP we can expose the service via the `ambassador` [API gateway](https://microservices.io/patterns/apigateway.html) component deployed as part of Seldon-Core,

```bash
kubectl expose deployment seldon-core-ambassador --type=LoadBalancer --name=seldon-core-ambassador-external
```

And then to retrieve the external IP for GCP use,

```bash
kubectl get services
```

And for Minikube use,

```bash
minikube service list
```

And then to test the pubic endpoint use, for example,

```bash
curl http://192.168.99.111:32074/seldon/test-seldon-ml-score-api/api/v0.1/predictions \
    --request POST \
    --header "Content-Type: application/json" \
    --data '{"data":{"names":["a","b"],"tensor":{"shape":[2,2],"values":[0,0,1,1]}}}'
```

### Tear Down

To delete a Ksonnet deployment from the Kubernetes cluster, make sure you are in the application directory and then use,

```bash
ks delete default
```

To delete a Helm deployment from the Kubernetes cluster, first retrieve a list of all the releases in the Seldon namespace,

```bash
helm list --namespace seldon
```

And then remove them using,

```bash
helm delete seldon-core --purge && \
helm delete seldon-core-crd --purge && \
helm delete test-seldon-ml-score-api --purge
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
