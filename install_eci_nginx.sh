#!/bin/bash

# Update the system and install Nginx, wget, and git
yum update -y
yum install -y nginx wget git

# Create web directory and clone the GitHub repository
mkdir -p /usr/share/nginx/html/
cd /usr/share/nginx/html/
git clone https://github.com/CY031102/Nginx.git temp_dir
cp -r temp_dir/* .
rm -rf temp_dir
rm -rf .git

# Configure Nginx
cat > /etc/nginx/conf.d/eci.conf <<EOF
server {
    listen       80;
    server_name  192.168.100.140;

    location / {
        root   /usr/share/nginx/html/eci;
        index  index.html;
    }
}
EOF

# Test Nginx configuration syntax
if ! nginx -t; then
    echo "Nginx configuration syntax error. Please check the configuration."
    exit 1
fi

# Set directory permissions
chown -R nginx:nginx /usr/share/nginx/html/eci
chmod -R 755 /usr/share/nginx/html/eci

# Enable and start Nginx service
systemctl enable nginx
systemctl start nginx

# Check Nginx service status
if ! systemctl is-active --quiet nginx; then
    echo "Nginx service failed to start. Please check."
    exit 1
fi

# Enable and start firewalld service
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Check firewalld configuration
if ! firewall-cmd --list-all | grep -q "services:.*http"; then
    echo "HTTP service not properly configured in firewalld."
    exit 1
fi

if ! firewall-cmd --list-all | grep -q "services:.*https"; then
    echo "HTTPS service not properly configured in firewalld."
    exit 1
fi

# Configure SELinux
yum install -y policycoreutils-python-utils
semanage fcontext -a -t httpd_sys_content_t "/usr/share/nginx/html/eci(/.*)?"
restorecon -R /usr/share/nginx/html/eci
setsebool -P httpd_can_network_connect 1
setsebool -P httpd_read_user_content 1

# Reload Nginx service to apply new SELinux context
systemctl reload nginx

# Check Nginx service status
if ! systemctl is-active --quiet nginx; then
    echo "Nginx service failed to start after reload. Please check."
    exit 1
fi

# Check SELinux configuration
if ! sestatus | grep -q "SELinux status:.*enabled"; then
    echo "SELinux is not enabled."
    exit 1
fi

if ! semanage fcontext -l | grep -q "/usr/share/nginx/html/eci"; then
    echo "/usr/share/nginx/html/eci is not properly configured with SELinux context."
    exit 1
fi

if ! getsebool httpd_can_network_connect | grep -q "on"; then
    echo "SELinux boolean httpd_can_network_connect is not enabled."
    exit 1
fi

if ! getsebool httpd_read_user_content | grep -q "on"; then
    echo "SELinux boolean httpd_read_user_content is not enabled."
    exit 1
fi

# Final check
echo "Checking Nginx installation status"
if ! rpm -q nginx; then
    echo "Nginx is not properly installed."
    exit 1
fi

echo "Checking firewalld installation status"
if ! rpm -q firewalld; then
    echo "firewalld is not properly installed."
    exit 1
fi

echo "Checking policycoreutils-python-utils installation status"
if ! rpm -q policycoreutils-python-utils; then
    echo "policycoreutils-python-utils is not properly installed."
    exit 1
fi

echo "Script successfully executed."
