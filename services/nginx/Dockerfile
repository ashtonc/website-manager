FROM nginx:latest

# Clear existing configurations
RUN rm /etc/nginx/conf.d/*

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
ADD certificates/ashtonc.ca-origin.pem /etc/nginx/certificates/ashtonc.ca-origin.pem
ADD certificates/ashtonc.ca-origin.key /etc/nginx/certificates/ashtonc.ca-origin.key
ADD certificates/ashtonc.com-origin.pem /etc/nginx/certificates/ashtonc.com-origin.pem
ADD certificates/ashtonc.com-origin.key /etc/nginx/certificates/ashtonc.com-origin.key
ADD https://support.cloudflare.com/hc/en-us/article_attachments/201243967/origin-pull-ca.pem /etc/nginx/certificates/cloudflare-origin.pem

