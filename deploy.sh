# Variables

home_bucket="ashtonc.ca"
test_bucket="ashtonc.com"
cloud_project="ashtonc-home"
kubernetes_dir="kubernetes-ashtonc-home"

hugo_build=true
upload_static=true
update_kubernetes_image=false

deploy_kubernetes=false

if [ "$1" == "--silent" ]; then
	silent=true
else
	silent=false
fi

if [ "$hugo_build" = true ]; then
	echo "Building sites with Hugo."

	echo "> TA..."; hugo --source ta > /dev/null 2>&1
	echo "> Debate..."; hugo --source debate > /dev/null 2>&1
#	echo "> Blog..."; hugo --source blog > /dev/null 2>&1
fi

if [ "$upload_static" = true ]; then
	echo "Uploading static files to bucket $home_bucket."

	echo "> Home..."; gsutil -m rsync -r -x ".git/" "home" "gs://$home_bucket/static" > /dev/null 2>&1
	echo "> TA..."; gsutil -m rsync -r -x ".git/" "ta/public" "gs://$home_bucket/static/ta" > /dev/null 2>&1
	echo "> Debate..."; gsutil -m rsync -r -x ".git/" "debate/public" "gs://$home_bucket/static/debate" > /dev/null 2>&1
#	echo "> Blog..."; gsutil -m rsync -r -x ".git/" "blog/public" "gs://$home_bucket/blog" > /dev/null 2>&1
fi

if [ "$update_kubernetes_image" = true ]; then
	echo "Updating Kubernetes image."

	echo "> Syncing..."; gsutil -m rsync -d "$kubernetes_dir/nginx" "gs://$home_bucket/deploy" > /dev/null 2>&1
	echo "> Building..."; gcloud builds submit --tag "gcr.io/ashtonc-home/ashtonc-home:master" $kubernetes_dir > /dev/null 2>&1
	echo "> Delete pods to update."; # Find better mechanism to update image (rolling update)
fi

# Kubernetes deployment instructions

if [ "$deploy_kubernetes" = true ]; then
	echo "Deploying to Kubernetes..."

	#export home_bucket=ashtonc.ca
	#export kubernetes_dir=kubernetes-ashtonc-home

	# 1. Place your static files inside a bucket
	gsutil -m rsync -d "$kubernetes_dir/nginx" "gs://$home_bucket/deploy" # Push to master to update Dockerfile or trigger the build manually
	gsutil -m rsync -d -r -x ".git/" "home" "gs://$home_bucket/static"

	# 2. Create a cluster (online for now)
	#- Zonal (us-central)
	#- 3 nodes (micro)
	#- Enable auto-upgrade
	#- Allow GCE service account full access to cloud APIs
	#- Boot disk size 10gb

	# 3. Initialize the cluster locally
	gcloud container clusters get-credentials ashtonc-home

	# 4. Install Helm on your cluster
	kubectl apply -f $kubernetes_dir/helm/tiller.yaml
	helm init --service-account tiller --upgrade
 
	# 5. Use Helm to install cert-manager and add a cluster issuer
	helm install stable/cert-manager --name cert-manager --set ingressShim.defaultIssuerName=letsencrypt-production --set ingressShim.defaultIssuerKind=ClusterIssuer --set ingressShim.defaultACMEChallengeType=dns01 --set ingressShim.defaultACMEDNS01ChallengeProvider=clouddns --namespace kube-system
	kubectl apply -f $kubernetes_dir/tls/letsencrypt-production.yaml

	# 6. Download the google compute engine service account secret and create a secret with it
	kubectl create secret generic clouddns-service-account --from-file=$kubernetes_dir/tls/gce-service-account-key.json --namespace kube-system

	# 7. Use Helm to install nginx-ingress
	helm install stable/nginx-ingress --name ashtonc-home-ingress --set rbac.create=true --namespace kube-system

	# 8. Configure DNS to point to your nginx ingress controller, one A record for root and one for www (wait for this to propagate)
	kubectl get service -l app=nginx-ingress,component=controller -o=jsonpath='{$.items[*].status.loadBalancer.ingress[].ip}' -n kube-system | cut -d '=' -f 2 | sed 's/;$//'

	# 9. Initialize your ingress (wait for the certificate to generate)
	kubectl apply -f $kubernetes_dir/k8s/ingress.yaml

	# 10. Initialize your deployment and service
	kubectl apply -f $kubernetes_dir/k8s/deployment.yaml
	kubectl apply -f $kubernetes_dir/k8s/service.yaml
fi

