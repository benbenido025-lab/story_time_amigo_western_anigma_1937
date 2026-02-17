FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    python3-pip \
    curl wget git nano vim screen bash unzip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install flask

# Install playit binary directly
RUN curl -SsL https://github.com/playit-cloud/playit-agent/releases/download/v0.17.0/playit-linux-amd64 -o /usr/local/bin/playit \
    && chmod +x /usr/local/bin/playit

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
# Start playit agent with secret\n\
PLAYIT_SECRET=$PLAYIT_SECRET playit &\n\
\n\
echo "=== SERVER READY ==="\n\
echo "Check playit.gg dashboard for tunnel address"\n\
echo "Password: yourpassword123"\n\
echo "===================="\n\
\n\
python3 /keepalive.py\n' > /start.sh

RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
