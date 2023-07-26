# 编译阶段
FROM ubuntu:20.04 AS build

# 安装ffmpeg
COPY --from=mwader/static-ffmpeg:5.1.1 /ffmpeg /usr/local/bin/
COPY --from=mwader/static-ffmpeg:5.1.1 /ffprobe /usr/local/bin/

# 修改源
RUN sed -i "s@http://archive.ubuntu.com@http://mirrors.aliyun.com@g" /etc/apt/sources.list && \
        sed -i "s@http://security.ubuntu.com@http://mirrors.aliyun.com@g" /etc/apt/sources.list

# 安装依赖
RUN export DEBIAN_FRONTEND=noninteractive && \
        apt-get update -y && \
        apt-get install -y --no-install-recommends openjdk-11-jre git maven nodejs npm build-essential cmake ca-certificates openssl && \
        mkdir -p /opt/wvp/config /opt/wvp/heapdump /opt/assist/config /opt/assist/heapdump /opt/media/www/record /home/wvp-GB28181-pro

# 下载maven文件
RUN cd /home && \
        git clone "https://gitee.com/pan648540858/maven.git" && \
        cp maven/settings.xml /usr/share/maven/conf/

# copy wvp工程到容器内
COPY . /home/wvp-GB28181-pro/

# 编译前端项目
RUN npm config set registry https://registry.npmmirror.com
RUN cd /home/wvp-GB28181-pro/web_src && \
        npm install && \
        npm run build

# 处理wvp-pro项目
RUN cd /home/wvp-GB28181-pro && \
        mvn clean package -Dmaven.test.skip=true && \
        cp /home/wvp-GB28181-pro/target/*.jar /opt/wvp/

# 处理wvp-pro-assist项目
COPY ./wvp-pro-assist.tar.gz /home/
RUN cd /home && tar -xvf wvp-pro-assist.tar.gz
RUN cd /home/wvp-pro-assist && mvn clean package -Dmaven.test.skip=true && cp /home/wvp-pro-assist/target/*.jar /opt/assist/

RUN cd /opt/wvp && \
        echo '#!/bin/bash' > run.sh && \
        echo 'echo ${WVP_IP}' >> run.sh && \
        echo 'echo ${WVP_CONFIG}' >> run.sh && \
        echo 'cd /opt/assist' >> run.sh && \
        echo 'nohup java ${ASSIST_JVM_CONFIG_XMS} ${ASSIST_JVM_CONFIG_XMX} -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/assist/heapdump/ -jar *.jar --spring.config.location=/opt/assist/config/application.yml --userSettings.record=/opt/media/www/record/  --media.record-assist-port=18081 ${ASSIST_CONFIG} &' >> run.sh && \
        echo 'cd /opt/wvp' >> run.sh && \
        echo 'java ${WVP_JVM_CONFIG_XMS} ${WVP_JVM_CONFIG_XMX} -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/wvp/heapdump/ -jar *.jar --spring.config.location=/opt/wvp/config/application.yml --media.record-assist-port=18081 ${WVP_CONFIG}' >> run.sh && \
        chmod +x run.sh

# release镜像构建
FROM ubuntu:20.04 

EXPOSE 18080/tcp
EXPOSE 5060/tcp
EXPOSE 5060/udp
EXPOSE 6379/tcp
EXPOSE 18081/tcp
EXPOSE 80/tcp
EXPOSE 1935/tcp
EXPOSE 554/tcp
EXPOSE 554/udp
EXPOSE 30000-30500/tcp
EXPOSE 30000-30500/udp

ENV LC_ALL zh_CN.UTF-8

# 修改源
RUN sed -i "s@http://archive.ubuntu.com@http://mirrors.aliyun.com@g" /etc/apt/sources.list && \
        sed -i "s@http://security.ubuntu.com@http://mirrors.aliyun.com@g" /etc/apt/sources.list

RUN export DEBIAN_FRONTEND=noninteractive &&\
        apt-get update -y && \
        apt-get install -y --no-install-recommends openjdk-11-jre ca-certificates language-pack-zh-hans && \
        apt-get autoremove -y && \
        apt-get clean -y && \
        rm -rf /var/lib/apt/lists/*dic
# 安装ffmpeg
COPY --from=mwader/static-ffmpeg:5.1.1 /ffmpeg /usr/local/bin/
COPY --from=mwader/static-ffmpeg:5.1.1 /ffprobe /usr/local/bin/

COPY --from=build /opt /opt
WORKDIR /opt/wvp
CMD ["sh", "run.sh"]