# Variables

home_bucket="ashtonc.ca"
home_app_engine="app-engine-ashtonc-home"
home_kubernetes="kubernetes-ashtonc-home"

deploy_static=true
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

	rsync -r "home/" "$home_app_engine/static"

	cd $home_app_engine
	gcloud app deploy --version 1 --project=ashtonc-home
	cd ..
fi

# Kubernetes

if [ "$deploy_kubernetes" = true ]; then
	echo "Deploying to Kubernetes..."

	
fi

