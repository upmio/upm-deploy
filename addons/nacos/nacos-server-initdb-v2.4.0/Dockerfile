FROM nacos/nacos-server:v2.4.0


# install mysql client
RUN yum install -y https://repo.mysql.com/mysql80-community-release-el7.rpm \
  && yum-config-manager --enable mysql80-server \
  && rpmkeys --import /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2022 \
  && yum install -y \
      "mysql-community-client" \
      "mysql-shell" \
  && yum clean all

COPY entrypoint /

ENTRYPOINT ["/entrypoint"]