#!/bin/bash

#------------
# Program
#------------

# Goals
# - Deploy any of my web services simply
# - Make it easy to redeploy any of my web services in case of failure

# Todo
# - Silence shell commands with -q flag
# - Proper WAL backups of postgres db with barman or wal-e or something
# - Graceful handling of unexpected build/deploy targets

# Notes
# - Services List
#     - Static
#         - Root (home)
#         - Blog
#         - Debate
#         - TA
#         - Taiwan blog
#     - Dynamic
#         - Tiny Tiny RSS
#         - Storage
#         - Calibre Web
#         - MPD
#         - UniFi controller
#     - Backend
#         - Postgres
# - Domains
#     - ashtonc.ca (static gcloud files)
#     - rss.ashtonc.ca (Tiny Tiny RSS)
#     - storage.ashtonc.ca (file storage)
#     - books.ashtonc.ca (Calibre Web)
#     - music.ashtonc.ca (MPD)
#     - unifi.ashtonc.ca (UniFi Controller)
# - Redirects
#     - ashtonc.com         --> ashtonc.ca
#     - *.ashtonc.com       --> *.ashtonc.ca
#     - *.ashtonc.ca        --> ashtonc.ca
#     - calendar.ashtonc.ca --> CNAME to google calendar
#     - mail.ashtonc.ca     --> CNAME to google mail
#     - docs.ashtonc.ca     --> drive.google.com
#     - repos.ashtonc.ca    --> source.cloud.google.com/repos
#     - plex.ashtonc.ca     --> app.plex.tv

#------------
# Settings
#------------

#------------
# Variables
#------------

PROGRAM_NAME="deploy.sh"
VERSION="0.1.0-prerelease"

GOOGLE_CLOUD_PROJECT="ashtonc-home"
GOOGLE_CLOUD_BUCKET="ashtonc.ca"
SERVER_NAME="ac-serf"
SERVER_USERNAME="ashtonc"

# Folders
MANAGER_DIRECTORY="/home/ashton/website-manager"
SERVICES_DIRECTORY="$MANAGER_DIRECTORY/services"
STATIC_DIRECTORY="$MANAGER_DIRECTORY/static"
DOCKER_IMAGES_DIRECTORY="$MANAGER_DIRECTORY/docker-images"
SECRETS_DIRECTORY="$MANAGER_DIRECTORY/secrets"

# Static
ROOT_DIRECTORY="$STATIC_DIRECTORY/home"
BLOG_DIRECTORY="$STATIC_DIRECTORY/blog"
DEBATE_DIRECTORY="$STATIC_DIRECTORY/debate"
TA_DIRECTORY="$STATIC_DIRECTORY/ta"
TAIWAN_DIRECTORY="$STATIC_DIRECTORY/taiwan"

# Services
NGINX_DIRECTORY="$SERVICES_DIRECTORY/nginx"
STORAGE_DIRECTORY="$SERVICES_DIRECTORY/storage"
TTRSS_DIRECTORY="$SERVICES_DIRECTORY/ttrss"
BOOKS_DIRECTORY="$SERVICES_DIRECTORY/books"
MUSIC_DIRECTORY="$SERVICES_DIRECTORY/music"

# Docker Images
NGINX_DOCKER_IMAGE_NAME="ashtonc-nginx"
TTRSS_DOCKER_IMAGE_NAME="ashtonc-ttrss"
BOOKS_DOCKER_IMAGE_NAME="ashtonc-calibre-web"
MUSIC_DOCKER_IMAGE_NAME="ashtonc-mpd"
POSTGRES_DOCKER_IMAGE_NAME="ashtonc-postgres"

# Secrets
SECRETS_FILE="$SECRETS_DIRECTORY/secrets-template.json"

#------------
# Arguments
#------------

# Action flags
action_help=false
action_version=false

action_verify_project=false
action_build_target=""
action_deploy_target=""

## Static
action_build_root=false
action_build_blog=false
action_build_debate=false
action_build_ta=false
action_build_taiwan=false

action_deploy_root=false
action_deploy_blog=false
action_deploy_debate=false
action_deploy_ta=false
action_deploy_taiwan=false

## Services
action_build_nginx=false
action_build_storage=false
action_build_ttrss=false
action_build_books=false
action_build_music=false

action_deploy_nginx=false
action_deploy_storage=false
action_deploy_ttrss=false
action_deploy_books=false
action_deploy_music=false

action_deploy_postgres=false
action_backup_postgres=false
action_restore_postgres=false

action_test_nginx=false

## Other
action_send_images=false
action_send_secrets=false

# Options flags
option_verbose=false
option_quiet=false

# Arguments collection loop
positional_args=()
argument_count=0
while [[ $# -gt 0 ]]; do
	argument="$1"
	case $argument in
		help|-h|--help)
			action_help=true
			shift
		;;
		version|--version)
			action_version=true
			shift
		;;
		build|-b|--build)
			action_build_target="$2"
			shift
			shift
		;;
		deploy|-d|--deploy)
			action_deploy_target="$2"
			shift
			shift
		;;
		send|-s|--send)
			action_send_target="$2"
			shift
			shift
		;;
		-q|--quiet)
			option_quiet=true
			shift
		;;
		-v|--verbose)
			option_verbose=true
			shift
		;;
		*)
			positional_args+=("$1")
			shift
		;;
	esac
	((argument_count++))
done
set -- "${positional_args[@]}"


case $action_build_target in
	nginx) action_build_nginx=true;;
	storage) action_build_storage=true;;
	rss|ttrss) action_build_ttrss=true;;
	books|calibre) action_build_books=true;;
	music|mpd) action_build_music=true;;
	*) echo -e "Invalid build target.";;
esac

case $action_deploy_target in
	nginx) action_deploy_nginx=true;;
	storage) action_deploy_storage=true;;
	rss|ttrss) action_deploy_ttrss=true;;
	books|calibre) action_deploy_books=true;;
	music|mpd) action_deploy_music=true;;
	*) echo -e "Invalid deploy target.";;
esac

case $action_send_target in
	docker|images) action_send_images=true;;
	secrets|secret) action_send_secrets=true;;
	manager) action_send_manager=true;;
	*) echo -e "Invalid send target.";;
esac

# Default action
if [ "$argument_count" = 0 ]; then
	action_help=true
fi

# Verbose takes precedence over quiet
if [ "$option_verbose" = "true" ]; then
	option_quiet=false
fi

#------------
# Functions
#------------

echo_quiet()
{
	if [ "$option_quiet" != true ]; then
		echo -e "$1"
	fi
}

echo_verbose()
{
	if [ "$option_verbose" = true ]; then
		echo -e "$1"
	fi
}

#------------
# Script
#------------

# Print usage/help information
if [ "$action_help" = "true" ]; then
	echo -e "\e[1mUSAGE\e[0m:"
	echo -e "    $PROGRAM_NAME (help | -h | --help)"
	echo -e "    $PROGRAM_NAME (version | --version)"
	echo -e "    $PROGRAM_NAME (build | -b | --build) \e[4mtarget\e[0m"
	echo -e "    $PROGRAM_NAME (deploy | -d | --deploy) \e[4mtarget\e[0m"
	echo -e "\n\e[1mSTATIC TARGETS\e[0m:"
	echo -e "    root             Site root"
	echo -e "    blog             Blog"
	echo -e "    debate           Debate resources"
	echo -e "    ta               Teaching assistant resources"
	echo -e "    taiwan           Taiwan blog"
	echo -e "\n\e[1mSERVICE TARGETS\e[0m:"
	echo -e "    nginx            NGINX"
	echo -e "    storage          File Storage"
	echo -e "    ttrss            Tiny Tiny RSS"
	echo -e "    books            Calibre Web"
	echo -e "    music            MPD Server"
	echo -e "\n\e[1mOPTIONS\e[0m:"
	echo -e "    -q --quiet       Quiet ouput"
	echo -e "    -v --verbose     Verbose output"
fi

# Print version information
if [ "$action_version" = "true" ]; then
	echo -e "\e[1mVersion\e[0m: $VERSION"
fi

# Verifying correct Google Cloud Project
if [ "$action_verify_project" = "true" ]; then
	current_google_cloud_project=$(gcloud config get-value project 2>/dev/null)

	if [ "$current_google_cloud_project" = "$GOOGLE_CLOUD_PROJECT" ]; then
		echo_verbose "Correctly using Google Cloud Project \e[1m$current_google_cloud_project\e[0m."
	else
		echo -e "Currently using Google Cloud Project \e[1m$current_google_cloud_project\e[0m, which does not match the expected project \e[1m$GOOGLE_CLOUD_PROJECT\e[0m."
		exit 1
	fi
fi

# Setup
if [ "$action_server_setup" = "true" ]; then
	# Basic utilities
	apt-get install sudo git tree

	# Set to vim
	update-alternatives --config editor

	# New user
	adduser $SERVER_USERNAME
	usermod -aG sudo $SERVER_USERNAME
	#su $SERVER_USERNAME
	#whoami; sudo whoami; exit

	# Get website-manager
	su $SERVER_USERNAME
	git clone https://github.com/ashtonc/website-manager

	# Get docker
	sudo apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common
	curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
	#sudo apt-key fingerprint 0EBFCD88
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
	sudo apt-get update
	sudo apt-get install docker-ce
	#docker run hello-world
	#docker ps
fi

# Site Root
if [ "$action_build_root" = "true" ]; then
	echo_quiet "\e[1mBuilding root...\e[0m"

	echo_verbose "> Minifying assets..."
	minify $ROOT_DIRECTORY/assets/css/default.css -o $ROOT_DIRECTORY/assets/css/default.min.css
fi

if [ "$action_deploy_root" = "true" ]; then
	echo_quiet "\e[1mDeploying root...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$ROOT_DIRECTORY" "gs://$GOOGLE_CLOUD_BUCKET/static"
fi

# Blog
if [ "$action_build_blog" = "true" ]; then
	echo_quiet "\e[1mBuilding blog...\e[0m"

	echo_verbose "> Running Hugo..."
	hugo --source $BLOG_DIRECTORY
fi

if [ "$action_deploy_blog" = "true" ]; then
	echo_quiet "\e[1mDeploying blog...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$BLOG_DIRECTORY/public" "gs://$GOOGLE_CLOUD_BUCKET/static/blog"
fi

# Debate Resources
if [ "$action_build_debate" = "true" ]; then
	echo_quiet "\e[1mBuilding debate...\e[0m"

	echo_verbose "> Running Hugo..."
	hugo --source $DEBATE_DIRECTORY
fi

if [ "$action_deploy_debate" = "true" ]; then
	echo_quiet "\e[1mDeploying debate...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$DEBATE_DIRECTORY/public" "gs://$GOOGLE_CLOUD_BUCKET/static/debate"
fi

# Teaching Assistant Resources
if [ "$action_build_ta" = "true" ]; then
	echo_quiet "\e[1mBuilding TA...\e[0m"

	echo_verbose "> Running Hugo..."
	hugo --source $TA_DIRECTORY
fi

if [ "$action_deploy_ta" = "true" ]; then
	echo_quiet "\e[1mDeploying TA...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$TA_DIRECTORY/public" "gs://$GOOGLE_CLOUD_BUCKET/static/ta"
fi

# Taiwan Blog
if [ "$action_build_taiwan" = "true" ]; then
	echo_quiet "\e[1mBuilding Taiwan blog...\e[0m"

	echo_verbose "> Running Jekyll..."
	# jekyll
fi

if [ "$action_deploy_taiwan" = "true" ]; then
	echo_quiet "\e[1mDeploying taiwan blog...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$TAIWAN_DIRECTORY/_site" "gs://$GOOGLE_CLOUD_BUCKET/static/taiwan"
fi

# NGINX
if [ "$action_build_nginx" = "true" ]; then
	echo_quiet "\e[1mBuilding NGINX image...\e[0m"

	echo_verbose "> Uploading configuration to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x "Dockerfile|certificates/" "$NGINX_DIRECTORY" "gs://$GOOGLE_CLOUD_BUCKET/deploy/nginx"

	echo_verbose "> Building NGINX image from Dockerfile..."
	gcloud builds submit --tag "gcr.io/$GOOGLE_CLOUD_PROJECT/$NGINX_DOCKER_IMAGE_NAME" "$NGINX_DIRECTORY"

	echo_verbose "> Pulling NGINX image from Google Container Registry..."
	docker pull "gcr.io/$GOOGLE_CLOUD_PROJECT/$NGINX_DOCKER_IMAGE_NAME:latest"

	echo_verbose "> Removing old NGINX image..."
	rm "$DOCKER_IMAGES_DIRECTORY/$NGINX_DOCKER_IMAGE_NAME.tar"

	echo_verbose "> Saving NGINX image to disk..."
	docker save "gcr.io/$GOOGLE_CLOUD_PROJECT/$NGINX_DOCKER_IMAGE_NAME:latest" -o "$DOCKER_IMAGES_DIRECTORY/$NGINX_DOCKER_IMAGE_NAME.tar"
fi

if [ "$action_deploy_nginx" = "true" ]; then
	echo_quiet "\e[1mDeploying NGINX image...\e[0m"

	echo_verbose "> Loading NGINX image from disk..."
	docker load -i "/home/$SERVER_USERNAME/website-manager/docker-images/$NGINX_DOCKER_IMAGE_NAME.tar"

	echo_verbose "> Stopping current NGINX image..."
	docker stop $NGINX_DOCKER_IMAGE_NAME
	docker rm $NGINX_DOCKER_IMAGE_NAME

	echo_verbose "> Starting NGINX..."
	docker run -d --name ashtonc-nginx -p 443:443 "gcr.io/$GOOGLE_CLOUD_PROJECT/$NGINX_DOCKER_IMAGE_NAME:latest" nginx -g 'daemon off;'
fi

if [ "$action_test_nginx" = "true" ]; then
	echo_quiet "\e[1mTesting NGINX image...\e[0m"

	#nginx -c "$NGINX_DIRECTORY/conf.d/ashtonc.ca.conf" -t
	#nginx -c "$NGINX_DIRECTORY/conf.d/redirects.conf" -t
	#nginx -c "$NGINX_DIRECTORY/conf.d/books.ashtonc.ca.conf" -t
	#nginx -c "$NGINX_DIRECTORY/conf.d/music.ashtonc.ca.conf" -t
	#nginx -c "$NGINX_DIRECTORY/conf.d/rss.ashtonc.ca.conf" -t
	#nginx -c "$NGINX_DIRECTORY/conf.d/storage.ashtonc.ca.conf" -t

	#echo_verbose "> Uploading configuration to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	#gsutil -m rsync -r -x "Dockerfile|certificates/" "$NGINX_DIRECTORY" "gs://$GOOGLE_CLOUD_BUCKET/deploy/nginx"

	echo_verbose "> Building NGINX image from Dockerfile..."
	#gcloud builds submit --tag "gcr.io/$GOOGLE_CLOUD_PROJECT/$NGINX_DOCKER_IMAGE_NAME" "$NGINX_DIRECTORY"

	echo_verbose "> Pulling NGINX image from Google Container Registry..."
	#docker pull "gcr.io/$GOOGLE_CLOUD_PROJECT/$NGINX_DOCKER_IMAGE_NAME:latest"

	echo_verbose "> Running NGINX image..."
	docker run ---name ashtonc-nginx -p 443:443 "gcr.io/$GOOGLE_CLOUD_PROJECT/$NGINX_DOCKER_IMAGE_NAME:latest" nginx -g 'daemon off;'
fi

# PostgreSQL
if [ "$action_deploy_postgres" = "true" ]; then
	echo_quiet "\e[1mDeploying PostgreSQL image...\e[0m"

	echo_verbose "> Pulling postgres image..."
	docker pull postgres:latest

	echo_verbose "> Reading secrets..."
	POSTGRES_PASSWORD=$(jq -r '.postgres.password' $SECRETS_FILE)

	echo_verbose "> Starting postgres..."
	docker run --name $POSTGRES_DOCKER_IMAGE_NAME -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD -d postgres

fi

if [ "$action_backup_postgres" = "true" ]; then
	echo_quiet "\e[1mBacking up PostgreSQL database...\e[0m"

	echo_verbose "> Backing up PostgreSQL database..."
	#docker exec -t $POSTGRES_DOCKER_IMAGE_NAME pg_dumpall -c -U postgres > dump_`date +%d-%m-%Y"_"%H_%M_%S`.sql
	#docker exec -t $POSTGRES_DOCKER_IMAGE_NAME pg_dumpall -c -U postgres | gzip > dump_`date +%d-%m-%Y"_"%H_%M_%S`.sql.gz
fi

if [ "$action_restore_postgres" = "true" ]; then
	echo_quiet "\e[1mRestoring PostgreSQL database...\e[0m"

	dump_file="dump.sql"
	dump_file_compressed="dump.sql.gz"

	echo_verbose "> Restoring PostgreSQL database from $dump_file..."
	#cat $dump_file | docker exec -i your-db-container psql -U postgres
	#gunzip $dump_file | docker exec -i your-db-container psql -U postgres
fi

# Send files
if [ "$action_send_images" = "true" ]; then
	echo_quiet "\e[1mSending Docker images to the server...\e[0m"
	rsync -v -azP --delete --rsh=ssh $DOCKER_IMAGES_DIRECTORY/ $SERVER_NAME:/home/$SERVER_USERNAME/website-manager/docker-images
fi

if [ "$action_send_secrets" = "true" ]; then
	echo_quiet "\e[1mSending secrets to the server...\e[0m"
	rsync -v -azP --delete --rsh=ssh $SECRETS_DIRECTORY/ $SERVER_NAME:/home/$SERVER_USERNAME/website-manager/secrets
fi

if [ "$action_send_manager" = "true" ]; then
	echo_quiet "\e[1mSending manager to the server...\e[0m"
	rsync -v -azP --delete --rsh=ssh --exclude ".git/" $MANAGER_DIRECTORY/ $SERVER_NAME:/home/$SERVER_USERNAME/website-manager
fi

# Exit with success
exit 0

