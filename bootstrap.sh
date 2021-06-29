#!/bin/bash
sudo yum install go nginx -y
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io -y

systemctl enable docker && systemctl start docker

cat <<EOT > /home/ec2-user/go.go
package main

import (
    "fmt"
    "net/http"
)

func main() {
    http.HandleFunc("/", HelloServer)
    http.ListenAndServe(":81", nil)
}

func HelloServer(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hello golang World !", r.URL.Path[1:])
}
EOT

cat <<EOT > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;

        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
        
        location /go {
        proxy_pass "http://127.0.0.1:81";
        }

        location /python {
        proxy_pass "http://localhost:82" ;
        proxy_set_header Host "localhost";
        }

    }
}
EOT

cat <<EOT > web.py
from flask import Flask
app = Flask(__name__)

@app.route("/")
def index():
    return "Hello python world!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=82)
EOT

cat <<EOT > flask_python.dockerfile
FROM python:latest
RUN mkdir -p /app/
WORKDIR /app
RUN pip3 install flask
COPY . .
ENTRYPOINT [ "python3", "/app/web.py"]
EOT

docker build -f flask_python.dockerfile -t flask_python .
docker run -d -p 82:82 flask_python --name flask_python --network="host"
setsebool -P httpd_can_network_connect 1
systemctl enable nginx && systemctl start nginx
sudo go run /home/ec2-user/go.go &