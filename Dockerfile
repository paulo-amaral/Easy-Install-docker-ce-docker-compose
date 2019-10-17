FROM nvidia/cuda:10.1-base


RUN apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common\
        openssh-server         
RUN add-apt-repository ppa:deadsnakes/ppa &&  \
        apt-get install -y --no-install-recommends python3.7  \
        python3-pip python-dev && \
        rm -rf /var/lib/apt/lists/*
        
RUN mkdir /var/run/sshd
RUN echo 'root:cloud' | chpasswd

RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config &&\
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd &&\
    echo "export VISIBLE=now" >> /etc/profile

CMD    ["/usr/sbin/sshd", "-D"]

