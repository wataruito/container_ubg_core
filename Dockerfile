FROM nvidia/cuda:9.0-cudnn7-devel
# The navidia/cuda:9.0-cudnn7-devel is ubuntu:16.04 base

ENV SHELL /bin/bash
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH

# Set timezone EST
ENV TZ 'America/New_York'
RUN echo $TZ > /etc/timezone && \
apt-get update && apt-get install -y tzdata && \
rm /etc/localtime && \
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
dpkg-reconfigure -f noninteractive tzdata && \
apt-get clean

# Install packages
RUN apt-get update --fix-missing && apt-get install -y wget bzip2 ca-certificates \
    libglib2.0-0 libxext6 libsm6 libxrender1 \
    git mercurial subversion \
    openssh-server 

# Install tini
RUN apt-get install -y curl grep sed dpkg && \
    TINI_VERSION=`curl https://github.com/krallin/tini/releases/latest | grep -o "/v.*\"" | sed 's:^..\(.*\).$:\1:'` && \
    curl -L "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}.deb" > tini.deb && \
    dpkg -i tini.deb && \
    rm tini.deb && \
    apt-get clean

# Install Anaconda3 into /opt/conda
RUN wget --quiet https://repo.anaconda.com/archive/Anaconda3-2018.12-Linux-x86_64.sh -O ~/anaconda.sh && \
    /bin/bash ~/anaconda.sh -b -p /opt/conda && \
    rm ~/anaconda.sh && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc
RUN conda install python=3.6.8
# ENTRYPOINT [ "/usr/bin/tini", "--" ]
# CMD [ "/bin/bash" ]

#################################################################################
# Enabling login to the docker with non-root account
#################################################################################
# 1. modify /etc/sudoers
# 2. install gosu
# 3. copy entrypoint.sh and set as the ENTRYPOINT
# 4. set up jupyter env. copy jupyter_notebook_config.py
#################################################################################
# Enable passwordless sudo for all users
RUN echo '%sudo ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers
# Setup gosu (https://github.com/tianon/gosu)
# gosu is an improved version of su which behaves better inside docker
# we use it to dynamically switch to the desired user in the entrypoint
# (see below)
ENV GOSU_VERSION 1.10
# Use unsecure HTTP via Port 80 to fetch key due to firewall in CIN.
RUN set -x \
 && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
 && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
 && chmod +x /usr/local/bin/gosu \
 && gosu nobody true

COPY entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Set up Jupyer env
RUN mkdir /usr/.jupyter
ENV JUPYTER_CONFIG_DIR /usr/.jupyter
COPY jupyter_notebook_config.py /usr/.jupyter/
# Jupyter has issues with being run directly:
#   https://github.com/ipython/ipython/issues/7062
# We just add a little wrapper script.
COPY run_jupyter.sh /usr/local/bin
COPY run_jupyterlab.sh /usr/local/bin
RUN chmod +x /usr/local/bin/run_jupyter.sh \
 && chmod +x /usr/local/bin/run_jupyterlab.sh \
 && chmod -R a+rwx /usr/.jupyter

# Change user to start Jupyter
USER $NB_USER
CMD ["/usr/local/bin/run_jupyter.sh"]
# CMD ["/usr/local/bin/run_jupyterlab.sh"]
