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
	    postgres         PostgreSQL
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
# - Disable gravatar on Gitea
# - Customize the Gitea home page/favicon
# - New database users for TTRSS and Gitea
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

SERVER_STATIC_SERVE_DIRECTORY="/home/$SERVER_USERNAME/static"

LOGO_DIRECTORY="$MANAGER_DIRECTORY/logo"
FAVICON_DIRECTORY="$LOGO_DIRECTORY/favicon"
FAVICON_SITEROOT_DIRECTORY="$FAVICON_DIRECTORY/siteroot"

# Static
ROOT_DIRECTORY="$STATIC_DIRECTORY/home"
BLOG_DIRECTORY="$STATIC_DIRECTORY/blog"
DEBATE_DIRECTORY="$STATIC_DIRECTORY/debate"
TA_DIRECTORY="$STATIC_DIRECTORY/ta"
TAIWAN_DIRECTORY="$STATIC_DIRECTORY/taiwan"

SERVER_ROOT_DIRECTORY="$SERVER_STATIC_DIRECTORY/home"
SERVER_BLOG_DIRECTORY="$SERVER_STATIC_DIRECTORY/blog"
SERVER_DEBATE_DIRECTORY="$SERVER_STATIC_DIRECTORY/debate"
SERVER_TA_DIRECTORY="$SERVER_STATIC_DIRECTORY/ta"
SERVER_TAIWAN_DIRECTORY="$SERVER_STATIC_DIRECTORY/taiwan"

# Services
NGINX_DIRECTORY="$SERVICES_DIRECTORY/nginx"
STORAGE_DIRECTORY="$SERVICES_DIRECTORY/storage"
TTRSS_DIRECTORY="$SERVICES_DIRECTORY/ttrss"
GITEA_DIRECTORY="$SERVICES_DIRECTORY/gitea"
BOOKS_DIRECTORY="$SERVICES_DIRECTORY/books"
MUSIC_DIRECTORY="$SERVICES_DIRECTORY/music"

SERVER_NGINX_DIRECTORY="$SERVER_SERVICES_DIRECTORY/nginx"
SERVER_STORAGE_DIRECTORY="$SERVER_SERVICES_DIRECTORY/storage"
SERVER_TTRSS_DIRECTORY="$SERVER_SERVICES_DIRECTORY/ttrss"
SERVER_GITEA_DIRECTORY="$SERVER_SERVICES_DIRECTORY/gitea"
SERVER_BOOKS_DIRECTORY="$SERVER_SERVICES_DIRECTORY/books"
SERVER_MUSIC_DIRECTORY="$SERVER_SERVICES_DIRECTORY/music"

TTRSS_HOST_PORT=8777
TTRSS_DOCKER_NETWORK=ttrss-network

GITEA_HOST_PORT=3000
GITEA_DOCKER_NETWORK=gitea-network

# Docker
## Image Names
NGINX_DOCKER_IMAGE_NAME="ashtonc-nginx"
TTRSS_DOCKER_IMAGE_NAME="ashtonc-ttrss"
BOOKS_DOCKER_IMAGE_NAME="ashtonc-calibre-web"
MUSIC_DOCKER_IMAGE_NAME="ashtonc-mpd"
POSTGRES_DOCKER_IMAGE_NAME="ashtonc-postgres"
GITEA_DOCKER_IMAGE_NAME="ashtonc-gitea"

## Volume Names
POSTGRES_DOCKER_VOLUME_NAME="postgres-volume"
TTRSS_DOCKER_VOLUME_NAME="ttrss-volume"
GITEA_DOCKER_VOLUME_NAME="gitea-volume"

# Secrets
SECRETS_FILE="$SECRETS_DIRECTORY/secrets.json"
SERVER_SECRETS_FILE="$SERVER_SECRETS_DIRECTORY/secrets.json"

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
		git|gitea) action_build_gitea=true;;
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
		postgres|postgresql) action_deploy_postgres=true;;
		storage) action_deploy_storage=true;;
		rss|ttrss) action_deploy_ttrss=true;;
		books|calibre) action_deploy_books=true;;
		music|mpd) action_deploy_music=true;;
		git|gitea) action_deploy_gitea=true;;
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
	apt-get install sudo git tree jq

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

	echo_verbose "> Updating date in humans.txt..."
	cat $ROOT_DIRECTORY/humans.txt | sed -r "s/[0-9]{4}-[0-9]{2}-[0-9]{2}/$(date '+%F')/g" > $ROOT_DIRECTORY/humans.txt

	echo_verbose "> Copying favicons from logo project..."
	cp $FAVICON_SITEROOT_DIRECTORY/* $ROOT_DIRECTORY/

	echo_verbose "> Linting CSS..."
	for file in $ROOT_DIRECTORY/assets/css/*.css; do
		if [ $(basename "$file" | cut -d. -f2) != "min" ]; then
			echo_verbose ">   $(basename $file)..."
			stylelint "$file" --fix
		fi
	done

	echo_verbose "> Minifying assets..."
	for file in $ROOT_DIRECTORY/assets/css/*.css; do
		if [ $(basename $file | cut -d. -f2) != "min" ]; then
			echo_verbose ">   $(basename $file)..."
			cssnano "$file" "$(echo "$file" | head --bytes -5).min.css"
		fi
	done
fi

if [ "$action_deploy_root" = "true" ]; then
	echo_quiet "\e[1mDeploying root...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$ROOT_DIRECTORY" "gs://$GOOGLE_CLOUD_BUCKET/static"

	echo_verbose "> Uploading content to the static serve directory on the server..."
	rsync -v -azP --rsh=ssh --exclude ".git" "$ROOT_DIRECTORY/" $SERVER_NAME:$SERVER_STATIC_SERVE_DIRECTORY
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

	echo_verbose "> Uploading content to the static serve directory on the server..."
	rsync --dry-run -v -azP --rsh=ssh --exclude ".git" "$BLOG_DIRECTORY/public/" $SERVER_NAME:$SERVER_STATIC_SERVE_DIRECTORY/blog
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

	echo_verbose "> Uploading content to the static serve directory on the server..."
	rsync -v -azP --delete --rsh=ssh --exclude ".git" "$DEBATE_DIRECTORY/public/" $SERVER_NAME:$SERVER_STATIC_SERVE_DIRECTORY/debate
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

	echo_verbose "> Uploading content to the static serve directory on the server..."
	rsync -v -azP --delete --rsh=ssh --exclude ".git" "$TA_DIRECTORY/public/" $SERVER_NAME:$SERVER_STATIC_SERVE_DIRECTORY/ta
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

	echo_verbose "> Uploading content to the static serve directory on the server..."
	rsync -v -azP --delete --rsh=ssh --exclude ".git" "$TAIWAN_DIRECTORY/public/" $SERVER_NAME:$SERVER_STATIC_SERVE_DIRECTORY/taiwan
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
		--volume $SERVER_STATIC_SERVE_DIRECTORY:/var/static \
		--volumes-from $TTRSS_DOCKER_IMAGE_NAME \
		--restart unless-stopped \
		-p 443:443 \
		"gcr.io/$GOOGLE_CLOUD_PROJECT/$NGINX_DOCKER_IMAGE_NAME:latest" \
		nginx -g 'daemon off;'

	echo_verbose "> Connecting NGINX to TTRSS..."
	docker network connect $TTRSS_DOCKER_NETWORK $NGINX_DOCKER_IMAGE_NAME

	echo_verbose "> Connecting NGINX to Gitea..."
	docker network connect $GITEA_DOCKER_NETWORK $NGINX_DOCKER_IMAGE_NAME
fi

# PostgreSQL
if [ "$action_deploy_postgres" = "true" ]; then
	echo_quiet "\e[1mDeploying PostgreSQL image...\e[0m"

	echo_verbose "> Pulling postgres image..."
	docker pull postgres:latest

	echo_verbose "> Reading secrets..."
	POSTGRES_PASSWORD=$(jq -r '.postgres.password' $SERVER_SECRETS_FILE)

	echo_verbose "> Checking whether postgres is running..."
	if [ $(docker inspect -f '{{.State.Running}}' ${POSTGRES_DOCKER_IMAGE_NAME}) = true ]; then
		echo_verbose "> Stopping postgres..."
		docker stop $POSTGRES_DOCKER_IMAGE_NAME
		docker rm $POSTGRES_DOCKER_IMAGE_NAME
	fi
	
	echo_verbose "> Starting postgres..."
	docker run -d \
		--name $POSTGRES_DOCKER_IMAGE_NAME \
		--restart unless-stopped \
		--volume $POSTGRES_DOCKER_VOLUME_NAME:/var/lib/postgresql/data \
		-e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
		-e DB_EXTENSION=pg_trgm \
		postgres:latest

	echo_verbose "> Connecting Postgres to TTRSS..."
	docker network connect $TTRSS_DOCKER_NETWORK $POSTGRES_DOCKER_IMAGE_NAME

	echo_verbose "> Connecting Postgres to Gitea..."
	docker network connect $GITEA_DOCKER_NETWORK $POSTGRES_DOCKER_IMAGE_NAME
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
	echo_quiet "\e[1mDeploying Tiny Tiny RSS...\e[0m"

	echo_verbose "> Checking whether Tiny Tiny RSS network exists..."
	if [ $(docker network ls --filter name=$TTRSS_DOCKER_NETWORK --format='{{.Name}}') = "" ]; then
		echo_verbose "> Creating Tiny Tiny RSS network..."
		docker network create $TTRSS_DOCKER_NETWORK
	fi

	echo_verbose "> Connecting postgres and nginx to Tiny Tiny RSS network..."
	docker network connect $TTRSS_DOCKER_NETWORK $POSTGRES_DOCKER_IMAGE_NAME
	docker network connect $TTRSS_DOCKER_NETWORK $NGINX_DOCKER_IMAGE_NAME

	echo_verbose "> Loading Tiny Tiny RSS image from disk..."
	docker load -i "/home/$SERVER_USERNAME/website-manager/docker-images/$TTRSS_DOCKER_IMAGE_NAME.tar"

	echo_verbose "> Checking whether Tiny Tiny RSS image is running or exists..."
	if [ $(docker inspect -f '{{.State.Running}}' ${TTRSS_DOCKER_IMAGE_NAME}) = true ]; then
		echo_verbose "> Stopping Tiny Tiny RSS..."
		docker stop $TTRSS_DOCKER_IMAGE_NAME
	fi
	if [ $(docker inspect -f '{{.State.Running}}' ${TTRSS_DOCKER_IMAGE_NAME}) = false ]; then
		echo_verbose "> Removing Tiny Tiny RSS..."
		docker rm $TTRSS_DOCKER_IMAGE_NAME
	fi

	echo_verbose "> Reading secrets..."
	POSTGRES_PASSWORD=$(jq -r '.postgres.password' $SERVER_SECRETS_FILE)

	echo_verbose "> Starting Tiny Tiny RSS..."
	docker run -dit \
		--name $TTRSS_DOCKER_IMAGE_NAME \
		--network $TTRSS_DOCKER_NETWORK \
		-e DB_TYPE=pgsql \
		-e DB_HOST=$POSTGRES_DOCKER_IMAGE_NAME \
		-e DB_PORT=5432 \
		-e DB_NAME=ttrss \
		-e DB_USER=postgres \
		-e DB_PASS=$POSTGRES_PASSWORD \
		-e SELF_URL_PATH=https://rss.ashtonc.ca \
		"gcr.io/$GOOGLE_CLOUD_PROJECT/$TTRSS_DOCKER_IMAGE_NAME:latest"
fi

# Gitea
if [ "$action_build_gitea" = "true" ]; then
	echo_quiet "\e[1mBuilding Gitea image...\e[0m"

	echo_verbose "> Building Gitea image from Dockerfile..."
	gcloud builds submit --tag "gcr.io/$GOOGLE_CLOUD_PROJECT/$GITEA_DOCKER_IMAGE_NAME" "$GITEA_DIRECTORY"

	echo_verbose "> Pulling Gitea image from Google Container Registry..."
	docker pull "gcr.io/$GOOGLE_CLOUD_PROJECT/$GITEA_DOCKER_IMAGE_NAME:latest"
	
	echo_verbose "> Removing old Gitea image..."
	rm "$DOCKER_IMAGES_DIRECTORY/$GITEA_DOCKER_IMAGE_NAME.tar"

	echo_verbose "> Saving Gitea image to disk..."
	docker save "gcr.io/$GOOGLE_CLOUD_PROJECT/$GITEA_DOCKER_IMAGE_NAME:latest" -o "$DOCKER_IMAGES_DIRECTORY/$GITEA_DOCKER_IMAGE_NAME.tar"
fi

if [ "$action_deploy_gitea" = "true" ]; then
	echo_quiet "\e[1mDeploying Gitea image...\e[0m"

	echo_verbose "> Loading Gitea image from disk..."
	docker load -i "/home/$SERVER_USERNAME/website-manager/docker-images/$GITEA_DOCKER_IMAGE_NAME.tar"

	echo_verbose "> Checking whether Gitea network exists..."
	if [ $(docker network ls --filter name=$GITEA_DOCKER_NETWORK --format='{{.Name}}') = "" ]; then
		echo_verbose "> Creating Gitea network..."
		docker network create $GITEA_DOCKER_NETWORK
	fi

	echo_verbose "> Connecting Postgres and NGINX to Gitea network..."
	docker network connect $GITEA_DOCKER_NETWORK $POSTGRES_DOCKER_IMAGE_NAME
	docker network connect $GITEA_DOCKER_NETWORK $NGINX_DOCKER_IMAGE_NAME

	echo_verbose "> Checking whether Gitea image is running or exists..."
	if [ $(docker inspect -f '{{.State.Running}}' ${GITEA_DOCKER_IMAGE_NAME}) = true ]; then
		echo_verbose "> Stopping Gitea..."
		docker stop $GITEA_DOCKER_IMAGE_NAME
	fi
	if [ $(docker inspect -f '{{.State.Running}}' ${GITEA_DOCKER_IMAGE_NAME}) = false ]; then
		echo_verbose "> Removing Gitea..."
		docker rm $GITEA_DOCKER_IMAGE_NAME
	fi

	echo_verbose "> Reading secrets..."
	POSTGRES_PASSWORD=$(jq -r '.postgres.password' $SERVER_SECRETS_FILE)
	INSTALL_LOCK=$(jq -r '.gitea.installlock' $SERVER_SECRETS_FILE)

	echo_verbose "> Starting Gitea..."
	docker run -dit \
		--name $GITEA_DOCKER_IMAGE_NAME \
		--network $GITEA_DOCKER_NETWORK \
		--volume $GITEA_DOCKER_VOLUME_NAME:/data \
		--restart unless-stopped \
		-e APP_NAME="Gitea" \
		-e RUN_MODE=prod \
		-e DISABLE_SSH=true \
		-e ROOT_URL="https://git.ashtonc.ca" \
		-e DB_TYPE=postgres \
		-e DB_HOST=$POSTGRES_DOCKER_IMAGE_NAME:5432 \
		-e DB_NAME=gitea \
		-e DB_USER=postgres \
		-e DB_PASSWD=$POSTGRES_PASSWORD \
		-e SECRET_KEY=$INSTALL_LOCK \
		-e DISABLE_REGISTRATION=true \
		"gcr.io/$GOOGLE_CLOUD_PROJECT/$GITEA_DOCKER_IMAGE_NAME:latest"
fi

# Exit with success
exit 0

