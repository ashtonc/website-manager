#!/bin/bash

#------------
# Help
#------------

read -r -d '' HELP_TEXT <<- EOM
	\e[1mUSAGE\e[0m:
	    $PROGRAM_NAME (help | -h | --help)
	    $PROGRAM_NAME (version | --version)
	    $PROGRAM_NAME (build | -b | --build) \e[4mtarget\e[0m
	    $PROGRAM_NAME (deploy | -d | --deploy) \e[4mtarget\e[0m
	\n\e[1mSTATIC TARGETS\e[0m (build | deploy):
	    root             Site root
	    blog             Blog
	    debate           Debate resources
	    ta               Teaching assistant resources
	    taiwan           Taiwan blog
	\n\e[1mSERVICE TARGETS\e[0m (build | deploy):
	    nginx            NGINX
	    storage          File Storage
	    ttrss            Tiny Tiny RSS
	    books            Calibre Web
	    music            MPD Server
	\n\e[1mSEND TARGETS\e[0m:
	    manager          Entire website-manager folder
	    docker           Docker images
	    secrets          Secrets file
	\n\e[1mOPTIONS\e[0m:
	    -q --quiet       Quiet ouput
	    -v --verbose     Verbose output
EOM

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
#         - NGINX
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
#     - calendar.ashtonc.ca --> calendar.google.com
#     - mail.ashtonc.ca     --> mail.google.com
#     - docs.ashtonc.ca     --> drive.google.com
#     - repos.ashtonc.ca    --> source.cloud.google.com/repos
#     - plex.ashtonc.ca     --> app.plex.tv

#------------
# Variables
#------------

PROGRAM_NAME="deploy.sh"
VERSION="0.1.0-prerelease"

GOOGLE_CLOUD_PROJECT="ashtonc-home"
GOOGLE_CLOUD_BUCKET="ashtonc.ca"
SERVER_NAME="ac-serf"

USERNAME="ashton"
SERVER_USERNAME="ashtonc"

# Folders
MANAGER_DIRECTORY="/home/$USERNAME/website-manager"
SERVICES_DIRECTORY="$MANAGER_DIRECTORY/services"
STATIC_DIRECTORY="$MANAGER_DIRECTORY/static"
DOCKER_IMAGES_DIRECTORY="$MANAGER_DIRECTORY/docker-images"
SECRETS_DIRECTORY="$MANAGER_DIRECTORY/secrets"

SERVER_MANAGER_DIRECTORY="/home/$SERVER_USERNAME/website-manager"
SERVER_SERVICES_DIRECTORY="$SERVER_MANAGER_DIRECTORY/services"
SERVER_STATIC_DIRECTORY="$SERVER_MANAGER_DIRECTORY/static"
SERVER_DOCKER_IMAGES_DIRECTORY="$SERVER_MANAGER_DIRECTORY/docker-images"
SERVER_SECRETS_DIRECTORY="$SERVER_MANAGER_DIRECTORY/secrets"

SERVER_BACKUP_DIRECTORY="/home/$SERVER_USERNAME/backups"
SERVER_BACKUP_POSTGRES_DIRECTORY="$SERVER_BACKUP_DIRECTORY/postgres"
SERVER_BACKUP_VOLUMES_DIRECTORY="$SERVER_BACKUP_DIRECTORY/volumes"

# Static
ROOT_DIRECTORY="$STATIC_DIRECTORY/home"
BLOG_DIRECTORY="$STATIC_DIRECTORY/blog"
DEBATE_DIRECTORY="$STATIC_DIRECTORY/debate"
TA_DIRECTORY="$STATIC_DIRECTORY/ta"
TAIWAN_DIRECTORY="$STATIC_DIRECTORY/taiwan"

SERVER_ROOT_DIRECTORY="$SERVER_STATIC_DIRECTORY/home"
SERVER_BLOG_DIRECTORY="$SERVER_STATIC_DIRECTORY/blog"
SERVER_EBATE_DIRECTORY="$SERVER_STATIC_DIRECTORY/debate"
SERVER_TA_DIRECTORY="$SERVER_STATIC_DIRECTORY/ta"
SERVER_TAIWAN_DIRECTORY="$SERVER_STATIC_DIRECTORY/taiwan"

# Services
NGINX_DIRECTORY="$SERVICES_DIRECTORY/nginx"
STORAGE_DIRECTORY="$SERVICES_DIRECTORY/storage"
TTRSS_DIRECTORY="$SERVICES_DIRECTORY/ttrss"
BOOKS_DIRECTORY="$SERVICES_DIRECTORY/books"
MUSIC_DIRECTORY="$SERVICES_DIRECTORY/music"

SERVER_NGINX_DIRECTORY="$SERVER_SERVICES_DIRECTORY/nginx"
SERVER_STORAGE_DIRECTORY="$SERVER_SERVICES_DIRECTORY/storage"
SERVER_TTRSS_DIRECTORY="$SERVER_SERVICES_DIRECTORY/ttrss"
SERVER_BOOKS_DIRECTORY="$SERVER_SERVICES_DIRECTORY/books"
SERVER_MUSIC_DIRECTORY="$SERVER_SERVICES_DIRECTORY/music"

TTRSS_HOST_PORT=8777

# Docker
## Image Names
NGINX_DOCKER_IMAGE_NAME="ashtonc-nginx"
TTRSS_DOCKER_IMAGE_NAME="ashtonc-ttrss"
BOOKS_DOCKER_IMAGE_NAME="ashtonc-calibre-web"
MUSIC_DOCKER_IMAGE_NAME="ashtonc-mpd"
POSTGRES_DOCKER_IMAGE_NAME="ashtonc-postgres"

## Volume Names
POSTGRES_DOCKER_VOLUME_NAME="postgres-volume"

# Secrets
SECRETS_FILE="$SECRETS_DIRECTORY/secrets.json"
SERVER_SECRETS_FILE="$SECRETS_DIRECTORY/secrets.json"

#------------
# Arguments
#------------

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
			action_build=true
			action_build_target="$2"
			shift
			shift
		;;
		deploy|-d|--deploy)
			action_deploy=true
			action_deploy_target="$2"
			shift
			shift
		;;
		send|-s|--send)
			action_send=true
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

# Default action
if [ "$argument_count" = 0 ]; then
	action_help=true
fi

# Verbose takes precedence over quiet
if [ "$option_verbose" = "true" ]; then
	option_quiet=false
fi

#------------
# Targets
#------------


#         - Root (home)
#         - Blog
#         - Debate
#         - TA
#         - Taiwan blog

if [ "$action_build" = true ]; then
	case $action_build_target in
		static)
			action_build_root=true
			action_build_blog=true
			action_build_debate=true
			action_build_ta=true
			action_build_taiwan=true
		;;
		root) action_build_root=true;;
		blog) action_build_blog=true;;
		debate) action_build_debate=true;;
		ta) action_build_ta=true;;
		taiwan) action_build_taiwan=true;;
		nginx)
			action_verify_project=true
			action_build_nginx=true
		;;
		storage) action_build_storage=true;;
		rss|ttrss) action_build_ttrss=true;;
		books|calibre) action_build_books=true;;
		music|mpd) action_build_music=true;;
		*) echo -e "Invalid build target.";;
	esac
fi

if [ "$action_deploy" = true ]; then
	case $action_deploy_target in
		static)
			action_deploy_root=true
			action_deploy_blog=true
			action_deploy_debate=true
			action_deploy_ta=true
			action_deploy_taiwan=true
		;;
		root) action_deploy_root=true;;
		blog) action_deploy_blog=true;;
		debate) action_deploy_debate=true;;
		ta) action_deploy_ta=true;;
		taiwan) action_deploy_taiwan=true;;
		nginx) action_deploy_nginx=true;;
		storage) action_deploy_storage=true;;
		rss|ttrss) action_deploy_ttrss=true;;
		books|calibre) action_deploy_books=true;;
		music|mpd) action_deploy_music=true;;
		*) echo -e "Invalid deploy target.";;
	esac
fi

if [ "$action_send" = true ]; then
	case $action_send_target in
		manager) action_send_manager=true;;
		docker|images) action_send_images=true;;
		secrets|secret) action_send_secrets=true;;
		*) echo -e "Invalid send target.";;
	esac
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
	echo -e "$HELP_TEXT"
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

# Setup (bad/unsafe version for now)
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

# Send
if [ "$action_send_manager" = "true" ]; then
	echo_quiet "\e[1mSending manager to the server...\e[0m"
	rsync -v -azP --delete --rsh=ssh --exclude ".git/" $MANAGER_DIRECTORY/ $SERVER_NAME:$SERVER_MANAGER_DIRECTORY
fi

if [ "$action_send_images" = "true" ]; then
	echo_quiet "\e[1mSending Docker images to the server...\e[0m"
	rsync -v -azP --delete --rsh=ssh $DOCKER_IMAGES_DIRECTORY/ $SERVER_NAME:$SERVER_DOCKER_IMAGES_DIRECTORY
fi

if [ "$action_send_secrets" = "true" ]; then
	echo_quiet "\e[1mSending secrets to the server...\e[0m"
	rsync -v -azP --delete --rsh=ssh $SECRETS_DIRECTORY/ $SERVER_NAME:$SERVER_SECRETS_DIRECTORY
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

	#echo_verbose "> Uploading configuration to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	#gsutil -m rsync -r -x "Dockerfile|certificates/" "$NGINX_DIRECTORY" "gs://$GOOGLE_CLOUD_BUCKET/deploy/nginx"

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

	echo_verbose "> Checking whether NGINX is running..."
	if [ $(docker inspect -f '{{.State.Running}}' $NGINX_DOCKER_IMAGE_NAME) = true ]; then
		echo_verbose "> Stopping NGINX..."
		docker stop $NGINX_DOCKER_IMAGE_NAME
		docker rm $NGINX_DOCKER_IMAGE_NAME
	fi

	echo_verbose "> Starting NGINX..."
	docker run -d \
		--name $NGINX_DOCKER_IMAGE_NAME \
		-p 443:443 \
		"gcr.io/$GOOGLE_CLOUD_PROJECT/$NGINX_DOCKER_IMAGE_NAME:latest" \
		nginx -g 'daemon off;'
fi

# PostgreSQL
if [ "$action_deploy_postgres" = "true" ]; then
	echo_quiet "\e[1mDeploying PostgreSQL image...\e[0m"

	echo_verbose "> Pulling postgres image..."
	docker pull postgres:latest

	echo_verbose "> Reading secrets..."
	POSTGRES_PASSWORD=$(jq -r '.postgres.password' $SERVER_SECRETS_FILE)

	echo_verbose "> Checking whether postgres is running..."
	if [ $(docker inspect -f '{{.State.Running}}' $POSTGRES_DOCKER_IMAGE_NAME) = true ]; then
		echo_verbose "> Stopping postgres..."
		docker stop $POSTGRES_DOCKER_IMAGE_NAME
		docker rm $POSTGRES_DOCKER_IMAGE_NAME
	fi
	
	echo_verbose "> Starting postgres..."
	docker run -d \
		--name $POSTGRES_DOCKER_IMAGE_NAME \
		--volume $POSTGRES_DOCKER_VOLUME_NAME:/var/lib/postgresql/data \
		-p 5432:5432 \
		-e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
		postgres:latest
fi

if [ "$action_backup_postgres" = "true" ]; then
	echo_quiet "\e[1mBacking up PostgreSQL database...\e[0m"
	
	CURRENT_TIME=$(date +%Y-%m-%d-%H-%M-%S)
	POSTGRES_DUMP_FILE="${CURRENT_TIME}_pg-dump.sql.gz"
	POSTGRES_VOLUME_FILE="${CURRENT_TIME}_pg-volume.tar.bz2"

	echo_verbose "> Dumping PostgreSQL databases..."
	docker exec -t $POSTGRES_DOCKER_IMAGE_NAME pg_dumpall -c -U postgres | gzip > $SERVER_BACKUP_POSTGRES_DIRECTORY/$POSTGRES_DUMP_FILE

	echo_verbose "> Backing up Docker volume $POSTGRES_DOCKER_VOLUME_NAME..."
	docker run --rm \
		--volumes-from $POSTGRES_DOCKER_VOLUME_NAME \
		-v $SERVER_BACKUP_POSTGRES_DIRECTORY:/backup \
		ubuntu \
		tar cjf /backup/$POSTGRES_VOLUME_FILE /$POSTGRES_DOCKER_VOLUME_NAME
fi

if [ "$action_restore_postgres" = "true" ]; then
	echo_quiet "\e[1mRestoring PostgreSQL database...\e[0m"
	exit 0

	echo_verbose "> Restoring PostgreSQL databases from $dump_file..."
	#cat $dump_file | docker exec -i $POSTGRES_DOCKER_IMAGE_NAME psql -U postgres
	#gunzip $dump_file | docker exec -i $POSTGRES_DOCKER_IMAGE_NAME psql -U postgres

	echo_verbose "> Restoring PostgreSQL volume from $dump_file..."
	#docker run -v /dbdata --name dbstore2 ubuntu /bin/bash
	#docker run --rm --volumes-from dbstore2 -v $(pwd):/backup ubuntu bash -c "cd /dbdata && tar xvf /backup/backup.tar --strip 1"
fi

# Tiny Tiny RSS
if [ "$action_build_ttrss" = "true" ]; then
	echo_quiet "\e[1mBuilding Tiny Tiny RSS image...\e[0m"

	echo_verbose "> Building Tiny Tiny RSS image from Dockerfile..."
	gcloud builds submit --tag "gcr.io/$GOOGLE_CLOUD_PROJECT/$TTRSS_DOCKER_IMAGE_NAME" "$TTRSS_DIRECTORY"

	echo_verbose "> Pulling Tiny Tiny RSS image from Google Container Registry..."
	docker pull "gcr.io/$GOOGLE_CLOUD_PROJECT/$TTRSS_DOCKER_IMAGE_NAME:latest"

	echo_verbose "> Removing old Tiny Tiny RSS image..."
	rm "$DOCKER_IMAGES_DIRECTORY/$TTRSS_DOCKER_IMAGE_NAME.tar"

	echo_verbose "> Saving Tiny Tiny RSS image to disk..."
	docker save "gcr.io/$GOOGLE_CLOUD_PROJECT/$TTRSS_DOCKER_IMAGE_NAME:latest" -o "$DOCKER_IMAGES_DIRECTORY/$TTRSS_DOCKER_IMAGE_NAME.tar"
fi

if [ "$action_deploy_ttrss" = "true" ]; then
	echo_quiet "\e[1mDeploying Tiny Tiny RSS image...\e[0m"

	echo_verbose "> Loading Tiny Tiny RSS image from disk..."
	docker load -i "/home/$SERVER_USERNAME/website-manager/docker-images/$TTRSS_DOCKER_IMAGE_NAME.tar"

	echo_verbose "> Checking whether Tiny Tiny RSS is running..."
	if [ $(docker inspect -f '{{.State.Running}}' $TTRSS_DOCKER_IMAGE_NAME) = true ]; then
		echo_verbose "> Stopping Tiny Tiny RSS..."
		docker stop $TTRSS_DOCKER_IMAGE_NAME
		docker rm $TTRSS_DOCKER_IMAGE_NAME
	fi

	echo_verbose "> Starting Tiny Tiny RSS..."
	docker run -d \
		--name $TTRSS_DOCKER_IMAGE_NAME \
		-p $TTRSS_HOST_PORT:80 \
		"gcr.io/$GOOGLE_CLOUD_PROJECT/$TTRSS_DOCKER_IMAGE_NAME:latest" \
		echo "started"
fi

# Exit with success
exit 0

