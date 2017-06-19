---
layout: post
title: Kubernetes, How Do I Do That?
date: 2017-03-06 18:30:00 -08:00
---

_This post is a re-post of my blog post in the [Runnable Blog](http://runnable.com/blog), as part of my work for [Runnable](http://www.runnable.com). [Check out the original post](https://runnable.com/blog/kubernetes-how-do-i-do-that)._

Kubernetes (lovingly referred to as “K8s”, “K8”, or even “the Kubes”) is becoming the most widely adopted container cluster manager out there. At a very basic level, Kubernetes provides an abstraction layer over containers that allows developers to organize all the different layers of their application through Kubernetes configurations. The challenge with Kubernetes is that you need to understand when and how to correctly use the abstractions it provides.

In this post, we’ll set up an app, database, and secrets while learning the basic concepts behind Kubernetes: Pods, Deployments, and Services. The files for this post can be accessed in the [GitHub repo](https://github.com/thejsj/kubernetes-blog-post) and have been tested using [minikube](https://kubernetes.io/docs/getting-started-guides/minikube/), which we’ll use to explain how some of these concepts are applied. If you want to set up this sample application in your Kubernetes cluster, be sure to check out the [README in the Github repo](https://github.com/thejsj/kubernetes-blog-post#kubernetes-how-do-i-do-that), for detailed instructions on how to do so.

### How do I deploy my app?
When you want to run an application on Kubernetes, you should use a Deployment. Deployments run your containers (in what’s called a Pod), restart your container when it fails, and let you specify the number of replicas for those Pods (a replica set). Kubernetes is different from solutions like Docker Compose in that it only understands images. For you to deploy your application, you’ll need to first create an image and push it to a registry reachable by your Kubernetes cluster. The easiest way is to create an account at [Docker Hub](https://hub.docker.com/) and push your images there (the following deployment file works because the image is publicly available on Docker Hub). It’s important to specify the labels in the metadata section of your Deployment, because that’s how we’ll identify the container we expose outside our cluster.

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: kubernetes.demo.app
spec:
  replicas: 3 # Number of pods running with the same image at any point in time
  template:
    metadata:
      labels:
        app: kubernetes_demo_app # Label we’ll use to access app later on
    spec:
      containers:
        - name: kubernetes-demo-app
          image: hiphipjorge/kubernetes-demo-app:latest # Name of the image. This image is accessible through Docker hub
          ports:
            - containerPort: 80 # Port exposed by the container
          env:
          - name: PORT
            value: "8000"
```

### How do I talk to my app?
After setting up our application, we can go to the dashboard and confirm that it’s running. Because we created a Deployment for it, we’ll have a running Deployment, a replica set, and 3 Pods (specified through the replicas property). Even though our application is running, we can’t access our application externally. That’s the default behavior in Kubernetes—Pods are not accessible unless a “Service” is created for them which allow access to the container through the use of labels.

```
apiVersion: v1
kind: Service
metadata:
  name: "kubernetes-demo-app-service"
spec:
  selector:
    app: "kubernetes_demo_app" # Label to query pods by
  type: NodePort # Important! This will expose a node port over your Kubernetes IP
  ports:
  - protocol: "TCP"
    port: 8000
    nodePort: 32222 # Port you’ll use to access app through the Kubernetes IP
    targetPort: 8000
```
Now when we access `curl $(minikube ip):32222` (if you’re using minikube), Kubernetes will automatically route your traffic to any container with the label `kubernetes_demo_app`. In minikube, this is done through the Kubernetes DNS add-on. By using the `NodePort` type for our service, we expose the `NodePort` port through our Kubernetes IP. Two other ways of doing this are using a `LoadBalancer` type, which assigns a new IP address for the Service, or using an Ingress controller, which you can use to map a host to a Service name and port (similar to what you could do with an NGINX config). That looks something like this:

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: "kubernetes-demo-app-ingress-service"
spec:
  rules:
  - host: kubernetes-demo-app.local # Must be added to /etc/hosts
    http:
      paths:
      - path: /
        backend:
          serviceName: "kubernetes-demo-app-service"
          servicePort: 8000
```

###  How do I deploy my database?
To create a database that we can use with our application, we first have to create a Deployment for it. Like our app, we want to run our database from an image with a predefined number of replicas and we want our Pod to auto-restart in case of failure. The only difference from our app Deployment is that we’re going to pass a volume to the container, so our data persists in case of a container restart. If we wanted to persist this volume across Pods then we could use a persistent volume.

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    db: rethinkdb
  name: rethinkdb
spec:
  template:
    metadata:
      labels:
        db: rethinkdb
    spec:
      containers:
      - image: rethinkdb
        args:
          - "rethinkdb" # Main command to run
          - "--bind" # Args passed to that main command
          - "all"
        name: rethinkdb
        ports:
        - containerPort: 8080 # Exposed port for dashboard/UI
          name: admin
        - containerPort: 28015 # Exposed port for
          name: driver
        volumeMounts:
        - mountPath: /data/rethinkdb_data
          name: rethinkdb-storage
      volumes:
      - name: rethinkdb-storage
        emptyDir: {}
```

### How can my database talk to my app?
Now that we have an application and a database running, we can have our application talk to our database to make queries. In order to do that, we’ll also be creating a Service (like we did with our application). The Service will make our Deployment available inside our Kubernetes cluster, but unreachable outside the cluster (which is actually the default behavior for Services). This service is almost identical to our application’s service, except for the lack of `NodePort` and `type` properties.

```
apiVersion: v1
kind: Service
metadata:
  name: "rethinkdb-db-access"
spec:
  selector:
    db: rethinkdb
  ports:
  - protocol: "TCP"
    port: 28015
    targetPort: 28015
```

After doing this, we can specify the database host using an environment variable. We could hard-code the host into our code, but using an environment variable is a much better practice and follows the principles of twelve-factor apps.

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata: # Removed ...
spec:
  replicas: 3
  template:
    metadata: # Removed ...
    spec:
      containers:
        - # Removed ...
          env:
          # Removed ...
          - name: RETHINKDB_HOST # Add the name of the ENV
            value: rethinkdb-db-access # Add name of new host
```

###  How do I store and use secrets?

Kubernetes provides its own ways to store secrets at a cluster and namespace level. The first way is to declare a secret using a yaml or json file which follows a structure similar to how we declare Deployments and Services:

```
apiVersion: v1
kind: Secret
metadata:
  name: github
type: Opaque
data:
  token: ZjdjYmVhZTJmODdiZWU5ODA5NmVjOWNmYTVjMzA3ZjViNTVjYmM2Ygo= # base64 encoding (Don’t worry, I already deleted it)
```

Keep in mind that the token has to be encoded into a base64 string, and it’ll be decoded back to a normal string when passed to your application.

The second way to do this is to create the secret with kubectl, using the following command for the same effect:

```
kubectl create secret generic github --from-literal=token=f7cbeae2f87bee98096ec9cfa5c307f5b55cbc6b
```

Now that the secret has been created, you can add an environment variable directly from the secret. After you do this, you can delete the replica set for the deployment in order to bring up a new series of Pods with an updated secret.

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata: # Removed…
spec:
  replicas: 3
  template:
    metadata: # Removed…
    spec:
      containers:
        - # Removed…
          env:
          # Removed…
          - name: GITHUB_TOKEN
            valueFrom:
              secretKeyRef:
                name: github
                key: token
```

### Conclusion

Kubernetes provides a great way to abstract away the orchestration of your application. Its ability to create a declarative way to setup your application through code is a great win for developers and DevOps teams. Learning its concepts of Pods, Deployments, and Services, will take you a long way toward setting up your application in this platform. After gaining some experience with Kubernetes, you’ll find that its concepts and level of abstraction are perfect for many uses cases. And if you wake up one morning and decided to switch up cloud providers on a whim, your Kubernetes yaml files will help a lot with that too!


