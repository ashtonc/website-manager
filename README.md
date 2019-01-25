This is the deployment process for my personal website. Some sections of the site are kept in separate repositories, but this script ties everything together.

The backbone of my deployment is NGINX. 

## Other Setup

I rely on Cloudflare for DNS and acting as a CDN.

## Services

- [NGINX](https://www.nginx.com/) as a reverse proxy for all other services and any static content.
- [Tiny Tiny RSS](https://tt-rss.org/) as a feed reader/aggregator.
- [Calibre Web](https://github.com/janeczku/calibre-web) for browsing and reading books.
- [MPD](https://www.musicpd.org/) to serve music.
- [Plex](https://www.plex.tv/) to serve video.
- Custom file storage application written in Go.

## Deployment Process

1. Set up a server with [Docker](https://www.docker.com/) and any other minor dependencies.
2. Use [Docker Compose](https://docs.docker.com/compose/) on that server to set up your services.
3. Deploy static files to a [Google Cloud Storage](https://cloud.google.com/storage/) bucket.
4. Enjoy!

