FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    python3-pip \
    curl wget git nano vim screen bash \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install flask

RUN curl -fsSL https://tailscale.com/install.sh | sh

# Setup SSH on port 2222
RUN mkdir -p /var/run/sshd
RUN echo 'root:yourpassword123' | chpasswd
RUN chsh -s /bin/bash root

RUN echo "Port 2222" >> /etc/ssh/sshd_config
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
RUN echo "ClientAliveCountMax 1000" >> /etc/ssh/sshd_config

RUN printf 'from flask import Flask\napp = Flask(__name__)\n\n@app.route("/")\ndef home():\n    return "alive", 200\n\nif __name__ == "__main__":\n    app.run(host="0.0.0.0", port=8080)\n' > /keepalive.py

RUN printf '#!/bin/bash\n\
service ssh start\n\
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &\n\
sleep 3\n\
tailscale up --authkey=tskey-auth-k7YWopQNyL11CNTRL-qpaK9gLLvH8oPQPyK8zBH8FmLKwJjp4Q5 --hostname=render-server\n\
echo "=== SERVER READY ==="\n\
tailscale ip -4\n\
echo "SSH Password: yourpassword123"\n\
echo "Port: 2222"\n\
echo "===================="\n\
python3 /keepalive.py\n' > /start.sh

RUN chmod +x /start.sh

EXPOSE 2222 8080

CMD ["/start.sh"]
