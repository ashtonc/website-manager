# Variables

home_bucket="ashtonc.ca"
test_bucket="ashtonc.com"
cloud_project="ashtonc-home"
app_engine_dir="app-engine-ashtonc-home"
kubernetes_dir="kubernetes-ashtonc-home"

deploy_static=false
deploy_app_engine=false
deploy_kubernetes=true

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

	gsutil -m rsync -d "$kubernetes_dir/nginx" "gs://$test_bucket/deploy"
	gsutil -m rsync -d -r -x ".git/" "home" "gs://$test_bucket/static"

	cd $kubernetes_dir
		kubectl apply -f k8s.yaml
	cd ..
fi

