# CentOS7 Minimal
FROM centos:7
# Set the local timezone
ENV TIMEZONE="America/New_York" \
    TELNET_PORT="8081" 
ARG TELNET_PW
ENV TELNET_PW=$TELNET_PW
ARG INSTALL_DIR
ENV INSTALL_DIR=$INSTALL_DIR
ENV WEB_PORT=80    
  
# Install daemon packages# Install base packages
RUN yum -y install epel-release && yum -y install supervisor vim-enhanced glibc.i686 libstdc++.i686 telnet expect unzip \
    python wget net-tools rsync sudo git logrotate which mlocate gcc-c++ p7zip p7zip-plugins sqlite3 sysvinit-tools svn cronie
    
#    yum -y install ImageMagick ImageMagick-devel ImageMagick-perl && \

#RUN yum -y install syslog-ng && \
# Configure Syslog-NG for use in a Docker container
#    sed -i 's|system();|unix-stream("/dev/log");|g' /etc/syslog-ng/syslog-ng.conf

# Install newest stable MariaDB: 10.3 
#RUN printf '[mariadb]\nname = MariaDB\nbaseurl = http://yum.mariadb.org/10.3/centos7-amd64\n\
#gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB\ngpgcheck=1' > /etc/yum.repos.d/MariaDB-10.3.repo && \
#    yum -y install MariaDB-server MariaDB-client
# Create MySQL Start Script
#RUN echo $'#!/bin/bash\n\
#[[ `pidof /usr/sbin/mysqld` == "" ]] && /usr/bin/mysqld_safe &\n\
#sleep 5\nexport SQL_TO_LOAD="/mysql_load_on_first_boot.sql"\n\
#while true; do\n\
#  if [[ -e "$SQL_TO_LOAD" ]]; then /usr/bin/mysql -u root --password=\'\' < $SQL_TO_LOAD && mv $SQL_TO_LOAD $SQL_TO_LOAD.loaded; fi\n\
#  sleep 10\n\
#done\n' > /start_mysqld.sh   

# Install Webtatic YUM REPO + Webtatic PHP7, # Install Apache & Webtatic mod_php support 
RUN yum -y localinstall https://mirror.webtatic.com/yum/el7/webtatic-release.rpm && \
    yum -y install php72w-cli httpd mod_php72w php72w-opcache php72w-curl php72w-sqlite3 php72w-gd && \
    rm -rf /etc/httpd/conf.d/welcome.conf
#RUN yum -y php72w-mysqli

# Set the Apache WEB_PORT
RUN sed -i "s/Listen 80/Listen $WEB_PORT/g" /etc/httpd/conf/httpd.conf
    
# rar, unrar
RUN wget https://www.rarlab.com/rar/rarlinux-x64-5.5.0.tar.gz && tar -zxf rarlinux-*.tar.gz && cp rar/rar rar/unrar /usr/local/bin/

# Create beginning of supervisord.conf file
RUN printf '[supervisord]\nnodaemon=true\nuser=root\nlogfile=/var/log/supervisord\n' > /etc/supervisord.conf && \
# Create start_httpd.sh script
    printf '#!/bin/bash\nrm -rf /run/httpd/httpd.pid\nwhile true; do\n/usr/sbin/httpd -DFOREGROUND\nsleep 10\ndone' > /start_httpd.sh && \
# Create start_supervisor.sh script
    printf '#!/bin/bash\n/usr/bin/supervisord -c /etc/supervisord.conf' > /start_supervisor.sh && \
# Create syslog-ng start script    
#    printf '#!/bin/bash\n/usr/sbin/syslog-ng --no-caps -F -p /var/run/syslogd.pid' > /start_syslog-ng.sh && \
# Create Cron start script    
    printf '#!/bin/bash\n/usr/sbin/crond -n\n' > /start_crond.sh && \
# Create script to add more supervisor boot-time entries
    echo $'#!/bin/bash \necho "[program:$1]";\necho "process_name  = $1";\n\
echo "autostart     = true";\necho "autorestart   = false";\necho "directory     = /";\n\
echo "command       = $2";\necho "startsecs     = 3";\necho "priority      = 1";\n\n' > /gen_sup.sh

# STEAMCMD
RUN useradd steam && cd /home/steam && wget http://media.steampowered.com/installer/steamcmd_linux.tar.gz && \
    tar zxf steamcmd_linux.tar.gz

# 7DTD START/STOP/SENDCMD
RUN echo $'#!/bin/sh\nexport INSTALL_DIR=/data/7DTD\nexport LD_LIBRARY_PATH=.\ncd $INSTALL_DIR\nif [[ `ps awwux | grep -v grep | grep loop_start_7dtd | wc -l` > 2 ]]; then exit; fi\n' > /loop_start_7dtd.sh && \
    echo $'while true; do if [ -f /7dtd.initialized ]; then break; fi; sleep 6; done \n' >> /loop_start_7dtd.sh && \
    echo $'rm -rf $INSTALL_DIR/core.*;' >> /loop_start_7dtd.sh && \
    echo $'while true; do \nif [[ -f $INSTALL_DIR/7DaysToDieServer.x86_64 ]] && [[ `cat $INSTALL_DIR/server.expected_status` == "start" ]]; then \n' >> /loop_start_7dtd.sh && \
    echo $'SERVER_PID=`ps awwux | grep -v grep | grep 7DaysToDieServer.x86_64`; \n' >> /loop_start_7dtd.sh && \
    echo $'[[ -z $SERVER_PID ]] && $INSTALL_DIR/7DaysToDieServer.x86_64 -configfile=$INSTALL_DIR/serverconfig.xml -logfile $INSTALL_DIR/7dtd.log -quit -batchmode -nographics -dedicated; \n' >> /loop_start_7dtd.sh && \
    echo $'fi \nsleep 2 \ndone' >> /loop_start_7dtd.sh
RUN su - steam -c "(/usr/bin/crontab -l 2>/dev/null; echo '* * * * * /loop_start_7dtd.sh') | /usr/bin/crontab -"
RUN printf 'echo "start" > /data/7DTD/server.expected_status\n' > /start_7dtd.sh
RUN printf 'echo "stop" > /data/7DTD/server.expected_status\n' > /stop_7dtd.sh
RUN echo $'#!/usr/bin/expect\nset timeout 5\nset command [lindex $argv 0]\n' > /7dtd-sendcmd.sh && \
    printf "spawn telnet 127.0.0.1 $TELNET_PORT\nexpect \"Please enter password:\"\n" >> /7dtd-sendcmd.sh && \
    printf "send \"$TELNET_PW\\\r\"; sleep 1;\n" >> /7dtd-sendcmd.sh && \
    printf 'send "$command\\r"\nsend "exit\\r";\nexpect eof;\n' >> /7dtd-sendcmd.sh && \
    printf 'send_user "Sent command to 7DTD: $command\\n"' >> /7dtd-sendcmd.sh
RUN printf '#!/usr/bin/php -q\n<?php\n' > /7dtd-sendcmd.php && \
    printf '$ip=exec("/sbin/ifconfig | grep broad"); $ipParts=array_Filter(explode(" ", $ip)); $cnt=0;' >> /7dtd-sendcmd.php && \
    printf 'foreach($ipParts as $part) { $cnt++; if($cnt==2) $ip=$part; }' >> /7dtd-sendcmd.php && \
    printf 'echo file_get_contents("http://$ip:8082/api/executeconsolecommand?adminuser=admin&admintoken=adm1n&raw=true&command=$argv[1]"); ?>' >> /7dtd-sendcmd.php

# Reconfigure Apache to run under steam username, to retain ability to modify steam's files
RUN sed -i 's|User apache|User steam|g' /etc/httpd/conf/httpd.conf && \
    sed -i 's|Group apache|Group steam|g' /etc/httpd/conf/httpd.conf && \
    chown steam /var/lib/php -R && \
    chown steam:steam /var/www/html -R && \
    echo $'Alias "/7dtd" "/data/7DTD/html"\n<Directory "/data/7DTD">\n\tRequire all granted\n\tOptions all\n\tAllowOverride all\n</Directory>\n' > /etc/httpd/conf.d/7dtd.conf

COPY install_7dtd.sh /install_7dtd.sh
COPY 7dtd-daemon.php /7dtd-daemon.php

# Ensure all packages are up-to-date, then fully clean out all cache
RUN chmod a+x /*.sh /*.php && yum clean all && rm -rf /tmp/* && rm -rf /var/tmp/* 

# Create different supervisor entries
#RUN /gen_sup.sh syslog-ng "/start_syslog-ng.sh" >> /etc/supervisord.conf && \
RUN /gen_sup.sh crond "/start_crond.sh" >> /etc/supervisord.conf && \
/gen_sup.sh httpd "/start_httpd.sh" >> /etc/supervisord.conf && \
/gen_sup.sh 7dtd-daemon "/7dtd-daemon.php /data/7DTD" >> /etc/supervisord.conf
#    /gen_sup.sh mysqld "/start_mysqld.sh" >> /etc/supervisord.conf && \

VOLUME ["/data"]

# Set to start the supervisor daemon on bootup
ENTRYPOINT ["/start_supervisor.sh"]