#FROM ubuntu:20.04

#FROM scratch
#ADD ubuntu-focal-oci-amd64-root.tar.gz /

FROM scratch
ADD tofino-sde-970-ub20.tar.gz /

#RUN apt-get update
#RUN apt-get install -y apt-utils vim
# ADD command already extracts the file
#RUN mkdir -p /mysde
#ADD bf-sde-9.7.0.tgz /mysde

#WORKDIR /mysde/bf-sde-9.7.0/p4studio/
#RUN ./install-p4studio-dependencies.sh

#RUN ./p4studio profile apply ./profiles/all-tofino.yaml

#RUN echo "export SDE=/mysde/bf-sde-9.7.0" >> /root/.bashrc
#RUN echo "export SDE_INSTALL=/mysde/bf-sde-9.7.0/install" >> /root/.bashrc

CMD ["bash"]
