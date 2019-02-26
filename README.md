This is the deployment process for my personal website. Some sections of the site are kept in separate repositories, but this script ties everything together.

I previously had my site hosted on [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/), which is an absolute pleasure to work with in terms of convenience. Once the setup was finished, it was easy to write scripts to update and manage the server. However, I was a bit unhappy with the price/performance ratio I was getting and ended up renting a server. I'll be able to host more services at a lower cost this way, though I will likely have a bit more downtime.

## Other Setup

I use Cloudflare for their excellent DNS and CDN service. The only extra feature on my wishlist with Cloudflare is the ability to proxy wildcard DNS entries on the free plan, but I can live without that.

## Current Services

- [NGINX](https://www.nginx.com/) as a reverse proxy for all other services and any static content.
- [Tiny Tiny RSS](https://tt-rss.org/) as a feed reader/aggregator.
- [Gitea](https://gitea.io/) for git repos.
- [PostgreSQL](https://www.postgresql.org/) as my database engine of choice.

## Services In Progress

- [Calibre Web](https://github.com/janeczku/calibre-web) for browsing and reading books.
- [MPD](https://www.musicpd.org/) to serve music.
- [Plex](https://www.plex.tv/) to serve video.
- Custom file storage application written in Go.

## Deployment Process

1. Set up a server with [Docker](https://www.docker.com/) and any other quality-of-life tools you would like.
2. Build the docker images you would like to deploy and transfer them to the server.
3. SSH into the server and deploy those images.
4. Transfer any static files you would like to serve to the server.

