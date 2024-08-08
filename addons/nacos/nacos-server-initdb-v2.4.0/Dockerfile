FROM nacos/nacos-server:v2.4.0 as nacos-server

FROM bitnami/mysql:8.0.36-debian-12-r10

COPY --from=nacos-server /home/nacos/conf/mysql-schema.sql /home/nacos/conf/mysql-schema.sql

COPY entrypoint /

ENTRYPOINT ["/entrypoint"]