# Build the latest tagged image
oc process -f build-template.yaml | oc create -f -
# Create the "Blue deployment" using latest tagged image
oc process -f deploy-template.yaml | oc create -f -
# Create a route for the service
oc process -f route-template.yaml | oc apply -f -

#build the green image...
# create the green deployment
oc process -f deploy-template.yaml -o yaml APPLICATION_NAME=ssl-server-green IMAGE_TAG=green | oc create -f -
# split the route for ab testing
oc process -f split-route-template.yaml MAJOR_SERVICE_NAME=ssl-server MINOR_SERVICE_NAME=ssl-server-green | oc apply -f -
# Run this a few times
curl -k https://ssl-server-blue-green.snapshot.mservices.fismobile.net/secured
# Redirect traffic entirely
oc patch route ssl-server -p '{"spec":{"to":{"kind": "Service","name": "ssl-server","weight": 0},"alternateBackends": [{"kind": "Service","name": "ssl-server-green","weight": 100}]}}'
# Run this a few times
curl -k https://ssl-server-blue-green.snapshot.mservices.fismobile.net/secured

#OK to scale down old?
# patch ssl-server dc with correct tag
oc process -f deploy-template.yaml -o yaml IMAGE_TAG=green | oc apply -f -
#oc patch dc ssl-server -p '{"spec": {"triggers": [{"type": "ImageChange", "imageChangeParams": {"automatic": true, "containerNames": ["ssl-server"], "from": {"kind": "ImageStreamTag", "namespace": "blue-green", "name": "ssl-server:green"}}}]}}'
# triggers a redeploy of ssl-server dc w correct image

# switch back to singe route w the simple dc name
oc process -f route-template.yaml | oc apply -f -

#delete the extra green deployment and service
oc delete svc ssl-server-green
oc delete dc ssl-server-green
