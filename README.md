This is the deployment process for my personal website. Other sections of the site are kept in separate repositories and this ties them together. This repository contains the files necessary to set up an identical Kubernetes cluster if necessary.

The site is a Kubernetes cluster running NGINX hosted on [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/). For the primary website, it reverse proxies static files hosted in a [Google Cloud Storage](https://cloud.google.com/storage/) bucket. The site has a TLS certificate issued by Let's Encrypt, automatically created and managed by [cert-manager](https://github.com/jetstack/cert-manager).

## Deployment Process

1. Set up a cluster on Kubernetes Engine.
2. Install Helm/Tiller on the cluster.
3. Install cert-manager and create a ClusterIssuer for Let's Encrypt.
4. Download the private key for your Compute Engine service account and add it to a secret (if you're using Cloud DNS to verify the ACME challenge).
5. Install nginx-ingress and point your DNS at the external IP of the service.
6. Use Cloud Build to generate an image for your deployment using your NGINX config.
7. Initialize the ingress, deployment, and service for the site.
8. Upload the files to be proxied into a storage bucket.

## Inspiration

The initial idea for this deployment was inspired by [a blog post by Zihao Zhang](https://zihao.me/post/hosting-static-website-with-kubernetes-and-google-cloud-storage/). Though the post made it seem simple, there was a fair bit more work that needed to be done than described. Other posts by [Dan Ludke](https://danrl.com/blog/2017/my-blog-on-kubernetes/), [Dan Wilkin](https://medium.com/google-cloud/kubernetes-w-lets-encrypt-cloud-dns-c888b2ff8c0e), [Craig Mulligan](https://medium.com/@hobochild/installing-cert-manager-on-a-gcloud-k8s-cluster-d379223f43ff), [Alen Komljen](https://akomljen.com/get-automatic-https-with-lets-encrypt-and-kubernetes-ingress/), [Dries De Smet](https://medium.com/google-cloud/setting-up-google-cloud-with-kubernetes-nginx-ingress-and-lets-encrypt-certmanager-bf134b7e406e), [Uday Tatiraju](https://dzone.com/articles/secure-your-kubernetes-services-using-cert-manager), and [Ivan Khramov](https://medium.com/containerum/how-to-launch-nginx-ingress-and-cert-manager-in-kubernetes-55b182a80c8f) were helpful with figuring out the sticky bits. The official documentation was also a big help.

## Todo

- Remove the load balancer and set up NGINX-ingress as a Daemonset. The minimum load balancer pricing is a bit high for a personal website, though it is free for now. See [this](https://akomljen.com/aws-cost-savings-by-utilizing-kubernetes-ingress-with-classic-elb/) and [this](https://medium.com/containerum/how-to-launch-nginx-ingress-and-cert-manager-in-kubernetes-55b182a80c8f).
- Set up the sites that some of the subdomains are intended for.
- Hide everything behind a CDN.
- Simplify the gcs_proxy.conf file.

