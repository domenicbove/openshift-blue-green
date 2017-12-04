# OpenShift SSL Server

Step by step guide to doing a Blue/Green deployment with A/B Testing on OpenShift. This is entirely scriptable which makes it a perfect candidate to extend with a Jenkins pipeline

First lets deploy the "blue" version of the app. Run:
```
oc process -f templates/template.yaml | oc create -f -
```
This will automatically start a build and trigger a deployment with a secure route exposed. Hit the /secured endpoint on the route!

At this point our deployment is structured like this:

![alt text](https://raw.githubusercontent.com/domenicbove/openshift-blue-green/master/images/one.png)

Now lets create the "green" version. To do this we can patch the build config to push an image to the tag green:
```
oc patch bc ssl-server -p '{"spec":{"output":{"to":{"kind": "ImageStreamTag", "name": "ssl-server:green"}}}}'
```
And manually you can go and update the file src/main/java/com/example/sslserver/SslServerApplication.java to have:

```
@RequestMapping("/secured")
public String secured(){
   System.out.println("Inside secured()");
   return "Hello GREEN USER!!! : " + new Date();
}
```
Now lets build the new image:
```
mvn clean package
oc start-build ssl-server --from-file=target/ssl-server-1.0.0.jar
```
This will build a new image with the green tag. To deploy it run:
```
oc process -f templates/deploy-template.yaml -o yaml APPLICATION_NAME=ssl-server-green IMAGE_TAG=green | oc create -f -
```
Now our OpenShift Project looks like:

![alt text](https://raw.githubusercontent.com/domenicbove/openshift-blue-green/master/images/two.png)

We can now do a blue/green deployment by switching the route back and forth between the two services. To switch the route run:
```
oc patch route ssl-server -p '{"spec":{"to":{"kind": "Service", "name": "ssl-server-green"}}}}'
```
Hit the /secured endpoint on the route! You could switch back and forth between the two services all you would like, but lets do an A/B deployment as well.

You can split traffic on a route between two services. Lets update the route to have split traffic:
```
oc process -f templates/split-route-template.yaml MAJOR_SERVICE_NAME=ssl-server MINOR_SERVICE_NAME=ssl-server-green | oc apply -f -
```
At this point our deployment looks like so:

![alt text](https://raw.githubusercontent.com/domenicbove/openshift-blue-green/master/images/three.png)

Note that a split route doesn't seem to show up in Chrome, so try curling to check these percentages
```
curl -k ssl-server-<project>.<openshift cluster>/secured
```

Now you can update the percentages of traffic to the A/B deployments like so:
```
oc patch route ssl-server -p '{"spec":{"to":{"kind": "Service","name": "ssl-server","weight": 10},"alternateBackends": [{"kind": "Service","name": "ssl-server-green","weight": 90}]}}'
```

Now 90% of the traffic has been turned to the "green deployment"

![alt text](https://raw.githubusercontent.com/domenicbove/openshift-blue-green/master/images/four.png)

Now lets say it is time to rollout the green deployment, meaning it is ok to scale down the blue. First switch all traffic to the green.
```
oc patch route ssl-server -p '{"spec":{"to":{"kind": "Service","name": "ssl-server","weight": 0},"alternateBackends": [{"kind": "Service","name": "ssl-server-green","weight": 100}]}}'
```

And then update the image in the "blue" deployment to be the "green" image
```
oc process -f templates/deploy-template.yaml -o yaml IMAGE_TAG=green | oc apply -f -
```

![alt text](https://raw.githubusercontent.com/domenicbove/openshift-blue-green/master/images/five.png)

This will set both deployments to be the same. All thats left is to switch back the route and remove one of the deployments.

![alt text](https://raw.githubusercontent.com/domenicbove/openshift-blue-green/master/images/six.png)

To do this run:
```
oc process -f templates/route-template.yaml | oc apply -f -
oc delete svc ssl-server-green
oc delete dc ssl-server-green
```

And finally we are left right were we started:

![alt text](https://raw.githubusercontent.com/domenicbove/openshift-blue-green/master/images/one.png)



To cleanup
```
oc delete all -l app=ssl-server
```
