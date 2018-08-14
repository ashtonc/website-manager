# Variables

home_bucket="www.ashtonc.ca"
home_app_engine="ashtonc-home-app"

deploy_static=false
deploy_app_engine=true

# Static Site Bucket

if [ "$deploy_static" = true ]; then
	echo "Deploying to static bucket."

	echo "Syncing local files with bucket $home_bucket."

	## Base home directory
	echo "> Root..."
	gsutil -m rsync -r -x ".git/" "ashtonc" "gs://$home_bucket"

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
	echo "Deploying to app engine."

	gcloud config set project ashtonc-home

	rsync -r home/ $home_app_engine/static
	#rsync /ta/public /$home_app_engine/static/ta

	cd $home_app_engine
	gcloud app deploy -v 1
	cd ..
fi
