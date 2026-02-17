FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    python3-pip \
    curl \
    wget \
    git \
    nano \
    vim \
    screen \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install flask

# Install Tailscale
RUN curl -fsSL https://tailscale.com/install.sh | sh

# Setup SSH
RUN mkdir /var/run/sshd
RUN echo 'root:yourpassword123' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Write keepalive server
RUN echo 'from flask import Flask\napp = Flask(__name__)\n\n@app.route("/")\ndef home():\n    return "alive", 200\n\nif __name__ == "__main__":\n    app.run(host="0.0.0.0", port=8080)' > /keepalive.py

# Write start script with Tailscale
RUN echo '#!/bin/bash\n\
service ssh start\n\
\n\
# Start Tailscale daemon\n\
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &\n\
sleep 3\n\
\n\
# Connect to Tailscale with your auth key\n\
tailscale up --authkey=tskey-auth-k7YWopQNyL11CNTRL-qpaK9gLLvH8oPQPyK8zBH8FmLKwJjp4Q5 --hostname=render-server\n\
\n\
# Show Tailscale IP\n\
echo "=== SERVER READY ==="\n\
tailscale ip -4\n\
echo "SSH Password: yourpassword123"\n\
echo "===================="\n\
\n\
# Keep alive web server\n\
python3 /keepalive.py' > /start.sh

RUN chmod +x /start.sh

EXPOSE 22 8080


CMD ["/start.sh"]
