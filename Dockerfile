FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    python3-pip \
    curl wget git nano vim screen bash unzip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install flask

# Install ngrok
RUN curl -Lo /tmp/ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip \
    && unzip /tmp/ngrok.zip -d /usr/local/bin \
    && rm /tmp/ngrok.zip

# Setup SSH
RUN mkdir -p /var/run/sshd
RUN echo 'root:yourpassword123' | chpasswd
RUN chsh -s /bin/bash root
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
RUN echo "ClientAliveCountMax 1000" >> /etc/ssh/sshd_config
RUN echo "UsePAM no" >> /etc/ssh/sshd_config

RUN printf 'from flask import Flask\napp = Flask(__name__)\n\n@app.route("/")\ndef home():\n    return "alive", 200\n\nif __name__ == "__main__":\n    app.run(host="0.0.0.0", port=8080)\n' > /keepalive.py

RUN printf '#!/bin/bash\n\
service ssh start\n\
\n\
# Start ngrok tunnel\n\
ngrok config add-authtoken $NGROK_TOKEN\n\
ngrok tcp 22 --log=stdout &\n\
sleep 5\n\
\n\
# Get ngrok address\n\
TUNNEL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "import sys,json; t=json.load(sys.stdin)[\"tunnels\"][0][\"public_url\"]; print(t.replace(\"tcp://\",\"\"))")\n\
\n\
echo "=== SERVER READY ==="\n\
echo "Connect: ssh root@$TUNNEL"\n\
echo "Password: yourpassword123"\n\
echo "===================="\n\
\n\
python3 /keepalive.py\n' > /start.sh

RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
