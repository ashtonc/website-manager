# Variables

home_bucket="ashtonc.ca"
test_bucket="ashtonc.com"
cloud_project="ashtonc-home"
app_engine_dir="app-engine-ashtonc-home"
kubernetes_dir="kubernetes-ashtonc-home"

deploy_static=false
deploy_app_engine=false
deploy_kubernetes=false

# Cloud Storage Bucket

if [ "$deploy_static" = true ]; then
	echo "Deploying to static bucket..."

	echo "Syncing local files with bucket $home_bucket."

	## Base home directory
	echo "> Home..."
	gsutil -m rsync -r -x ".git/" "home" "gs://$home_bucket"

	## TA content
	echo "> TA..."
	cd ta; hugo; cd ..
	gsutil -m rsync -r -x ".git/" "ta/public" "gs://$home_bucket/ta"

	## Debate content
	echo "> Debate..."
	cd debate; hugo; cd ..
	gsutil -m rsync -r -x ".git/" "debate/public" "gs://$home_bucket/debate"

	## Blog content
	#cd blog; hugo; cd ..
	#gsutil -m rsync -r -x ".git/" "blog/public" "gs://$home_bucket/blog"
fi

# App Engine

if [ "$deploy_app_engine" = true ]; then
	echo "Deploying to app engine..."

	rsync -r "home/" "$app_engine_dir/static"

	cd $app_engine_dir
	gcloud app deploy --version 1 --project=ashtonc-home
	cd ..
fi

# Kubernetes

if [ "$deploy_kubernetes" = true ]; then
	echo "Deploying to Kubernetes..."

	export kubernetes_dir=kubernetes-ashtonc-home
	export test_bucket=ashtonc.com

	# 1. Place your static files inside a bucket
	gsutil -m rsync -d "$kubernetes_dir/nginx" "gs://$test_bucket/deploy"
	gsutil -m rsync -d -r -x ".git/" "home" "gs://$test_bucket/static"

	# 2. Create a cluster (online for now)
	#- Zonal (us-central)
	#- 3 nodes (micro)
	#- Enable auto-upgrade
	#- Allow GCE service account full access to cloud APIs

	# 3. Initialize the cluster locally
	gcloud container clusters get-credentials ashtonc-home

	# 4. Install Helm on your cluster
	kubectl apply -f $kubernetes_dir/helm/tiller.yaml
	helm init --service-account tiller --upgrade
 
	# 6. Use Helm to install cert-manager and add a cluster issuer
	helm install stable/cert-manager --name cert-manager --set ingressShim.defaultIssuerName=letsencrypt-production --set ingressShim.defaultIssuerKind=ClusterIssuer --set ingressShim.defaultACMEChallengeType=dns01 --set ingressShim.defaultACMEDNS01ChallengeProvider=clouddns --namespace kube-system
	kubectl apply -f $kubernetes_dir/tls/letsencrypt-production.yaml

	# ?. Download the google compute engine service account secret and create a secret with it
	kubectl create secret generic clouddns-service-account --from-file=$kubernetes_dir/tls/gce-service-account-key.json --namespace kube-system

	# 5. Use Helm to install nginx-ingress
	helm install stable/nginx-ingress --name ashtonc-home-ingress --set rbac.create=true --namespace kube-system

	# 6. Configure DNS to point to your nginx ingress controller (wait for this to propagate)
	kubectl get service -l app=nginx-ingress,component=controller -o=jsonpath='{$.items[*].status.loadBalancer.ingress[].ip}' -n kube-system | cut -d '=' -f 2 | sed 's/;$//'

	# 8. Initialize your ingress
	kubectl apply -f $kubernetes_dir/k8s/ingress.yaml

	# 9. Initialize your deployment
	kubectl apply -f $kubernetes_dir/k8s/deployment.yaml

	# 10. Initialize your service
	kubectl apply -f $kubernetes_dir/k8s/service.yaml

fi

