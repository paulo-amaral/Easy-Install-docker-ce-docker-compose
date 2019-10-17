FROM nvidia/cuda:10.1-base

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server && \
    rm -rf /var/lib/apt/lists/*
RUN echo 'root:passwd' | chpasswd &&\
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config &&\
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd &&\
    echo "export VISIBLE=now" >> /etc/profile

