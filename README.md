# OpenShift SSL Server

Step by step guide to doing a Blue/Green deployment with A/B Testing on OpenShift. This is entirely scriptable which makes it a perfect candidate to extend with a Jenkins pipeline

First lets deploy the "blue" version of the app. Run:
```
oc process -f https://raw.githubusercontent.com/domenicbove/blue-green/master/templates/template.yaml | oc create -f -
```
This will automatically start a build and trigger a deployment with a secure route exposed. Hit the /secured endpoint on the route!

At this point our deployment is structured like this:
![alt text](https://raw.githubusercontent.com/domenicbove/blue-green/master/images/one.png)

Now lets create the "green" version. To do this we can patch the build config to push to a new image tag:
```
oc patch bc ssl-server -p '{"spec":{"output":{"to":{"kind": "ImageStreamTag", "name": "ssl-server:green"}}}}'
""
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
oc process -f deploy-template.yaml -o yaml APPLICATION_NAME=ssl-server-green IMAGE_TAG=green | oc create -f -
```
We are now at the start of a blue/green deployment! It is very easy to switch the route back and forth between the two services. To switch the route run:
```
oc path route ssl-server -p '{"spec":{"to":{"kind": "Service", "name": "ssl-server-green"}}}}'
```
Hit the /secured endpoint on the route! You could switch back and forth between the two services all you would like, but lets do an A/B deployment as well




To cleanup
```
oc delete all -l app=ssl-server
```
