#!/bin/bash

#------------
# Program
#------------

# Goals
# - Deploy any of my web services simply
# - Make it easy to redeploy any of my web services in case of failure

# Todo
# - Silence shell commands with -q flag

# Notes
# - Services List
#     - Static
#         - Root (home)
#         - Blog
#         - Debate
#         - TA
#     - Dynamic
#         - Tiny Tiny RSS
#         - Storage
#         - Calibre Web
#         - MPD
# - Domains
#     - ashtonc.ca (static)
#     - rss.ashtonc.ca (tiny tiny rss)
#     - storage.ashtonc.ca (file storage)
#     - books.ashtonc.ca (calibre web)
#     - music.ashtonc.ca (MPD)
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

MANAGER_DIRECTORY="/home/ashtonc/website-manager"
SERVICES_DIRECTORY="$MANAGER_DIRECTORY/services"
STATIC_DIRECTORY="$MANAGER_DIRECTORY/static"

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

#------------
# Arguments
#------------

# Action flags
action_help=false
action_version=false

action_verify_project=false

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
action_deploy_nginx=false
action_deploy_storage=false
action_deploy_ttrss=false
action_deploy_books=false
action_deploy_music=false

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

# Build root
if [ "$action_build_root" = "true" ]; then
	echo_quiet "\e[1mBuilding root...\e[0m"

	echo_verbose "> Minifying assets..."
	minify $ROOT_DIRECTORY/assets/css/default.css -o $ROOT_DIRECTORY/assets/css/default.min.css
fi

# Build blog
if [ "$action_build_blog" = "true" ]; then
	echo_quiet "\e[1mBuilding blog...\e[0m"

	echo_verbose "> Running Hugo..."
	hugo --source $BLOG_DIRECTORY
fi

# Build debate
if [ "$action_build_debate" = "true" ]; then
	echo_quiet "\e[1mBuilding debate...\e[0m"

	echo_verbose "> Running Hugo..."
	hugo --source $DEBATE_DIRECTORY
fi

# Build TA
if [ "$action_build_ta" = "true" ]; then
	echo_quiet "\e[1mBuilding TA...\e[0m"

	echo_verbose "> Running Hugo..."
	hugo --source $TA_DIRECTORY
fi

# Build taiwan blog
if [ "$action_build_taiwan" = "true" ]; then
	echo_quiet "\e[1mBuilding Taiwan blog...\e[0m"

	echo_verbose "> Running Jekyll..."
	# jekyll
fi

# Deploy root
if [ "$action_deploy_root" = "true" ]; then
	echo_quiet "\e[1mDeploying root...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$ROOT_DIRECTORY" "gs://$GOOGLE_CLOUD_BUCKET/static"
fi

# Deploy blog
if [ "$action_deploy_blog" = "true" ]; then
	echo_quiet "\e[1mDeploying blog...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$BLOG_DIRECTORY/public" "gs://$GOOGLE_CLOUD_BUCKET/static/blog"
fi

# Deploy debate
if [ "$action_deploy_debate" = "true" ]; then
	echo_quiet "\e[1mDeploying debate...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$DEBATE_DIRECTORY/public" "gs://$GOOGLE_CLOUD_BUCKET/static/debate"
fi

# Deploy TA
if [ "$action_deploy_ta" = "true" ]; then
	echo_quiet "\e[1mDeploying TA...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$TA_DIRECTORY/public" "gs://$GOOGLE_CLOUD_BUCKET/static/ta"
fi

# Deploy taiwan blog
if [ "$action_deploy_taiwan" = "true" ]; then
	echo_quiet "\e[1mDeploying taiwan blog...\e[0m"

	echo_verbose "> Uploading to Google Cloud Storage bucket $GOOGLE_CLOUD_BUCKET..."
	gsutil -m rsync -r -x ".git/" "$TAIWAN_DIRECTORY/_site" "gs://$GOOGLE_CLOUD_BUCKET/static/taiwan"
fi

# Exit with success
exit 0

