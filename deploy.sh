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

	# 1. Place your static files inside a bucket
	gsutil -m rsync -d "$kubernetes_dir/nginx" "gs://$test_bucket/deploy"
	gsutil -m rsync -d -r -x ".git/" "home" "gs://$test_bucket/static"

	# 2. Create a cluster (online for now)

	# 3. Initialize the cluster locally
	gcloud container clusters get-credentials ashtonc-home

	# 4. Install Helm on your cluster
	kubectl create serviceaccount --namespace kube-system tiller
	kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
	kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'      
	helm init --service-account tiller --upgrade

	# 5. Use Helm to install nginx-ingress
	helm install stable/nginx-ingress --name nginx-ingress --namespace kube-system --set rbac.create=true #--set controller.hostNetwork=true,controller.kind=DaemonSet

	# 5.1 Configure DNS to point to the nginx ingress load balancer

	# 6. Use Helm to install cert-manager
	helm install stable/cert-manager --name cert-manager --namespace kube-system --set ingressShim.defaultIssuerName=letsencrypt-staging --set ingressShim.defaultIssuerKind=ClusterIssuer
	kubectl apply -f $kubernetes_dir/cert-manager/letsencrypt-staging.yaml

	# 7. Initialize your deployment
	kubectl apply -f $kubernetes_dir/k8s/deployment.yaml

	# 8. Initialize your service
	kubectl apply -f $kubernetes_dir/k8s/service.yaml

	# 9. Initialize your ingress
	kubectl apply -f $kubernetes_dir/k8s/ingress.yaml

fi

