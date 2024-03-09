# /etc/nginx/sites-available/ssh-reverse-proxy

server {
    listen 22;
    server_name server.sshserver.com;

    location / {
        proxy_pass ssh://127.0.0.1:22;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 143;
    server_name server.sshserver.com;

    location / {
        proxy_pass ssh://127.0.0.1:143;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 109;
    server_name server.sshserver.com;

    location / {
        proxy_pass ssh://127.0.0.1:109;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 110;
    server_name server.sshserver.com;

    location / {
        proxy_pass ssh://127.0.0.1:110;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 443 ssl;
    server_name server.sshserver.com;

    # Add SSL configuration here (ssl_certificate, ssl_certificate_key, etc.)

    location / {
        proxy_pass ssh://127.0.0.1:443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
