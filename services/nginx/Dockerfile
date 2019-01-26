FROM nginx:latest

# Server configurations
ADD conf.d/redirects.conf /etc/nginx/conf.d/redirects.conf
ADD conf.d/ashtonc.ca.conf /etc/nginx/conf.d/ashtonc.ca.conf
ADD conf.d/rss.ashtonc.ca.conf /etc/nginx/conf.d/rss.ashtonc.ca.conf
ADD conf.d/storage.ashtonc.ca.conf /etc/nginx/conf.d/storage.ashtonc.ca.conf
ADD conf.d/books.ashtonc.ca.conf /etc/nginx/conf.d/books.ashtonc.ca.conf
ADD conf.d/music.ashtonc.ca.conf /etc/nginx/conf.d/music.ashtonc.ca.conf

# Additional parameters
ADD gcs_proxy_parameters /etc/nginx/gcs_proxy_parameters

# Origin and client certificates
ADD certificates/origin.pem /etc/nginx/certificates/origin.pem
ADD certificates/origin.key /etc/nginx/certificates/origin.key
ADD https://support.cloudflare.com/hc/en-us/article_attachments/201243967/origin-pull-ca.pem /etc/nginx/certificates/cloudflare.pem

