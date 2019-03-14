FROM jasonrivers/nagios:latest

ENV LIVESTATUS      1.4.0p38
ENV WMIC            1.3.14-3
ENV WMIPLUS         1.64

RUN apt-get update && apt-get install -y \
    mc sudo \
    libnumber-format-perl  libconfig-inifiles-perl libdatetime-perl \
    graphviz \
    librrd-dev \
    libboost-all-dev && \
    apt-get clean && rm -Rf /var/lib/apt/lists/*

# MK live status
RUN cd /tmp && \
    wget -O mk-livestatus.tar.gz https://mathias-kettner.de/support/${LIVESTATUS}/mk-livestatus-${LIVESTATUS}.tar.gz && \
    tar zxf mk-livestatus.tar.gz && \
    rm -f mk-livestatus.tar.gz && \
    mv mk-livestatus* mk-livestatus && \
    cd mk-livestatus && \
    ./configure --with-nagios4 && \
    make && \
    make install && \
    rm -rf /tmp/mk-livestatus

# edit nagios.cfg
RUN sed -i 's!#broker_module=/somewhere/module1.o!broker_module=/usr/local/lib/mk-livestatus/livestatus.o /opt/nagios/var/rw/live debug=0!' /opt/nagios/etc/nagios.cfg

# WMIC
RUN cd /tmp && \
    wget -O wmic.deb https://github.com/cdrx/docker-wmic/raw/master/wmi-client_${WMIC}_amd64.deb && \
    dpkg -x wmic.deb wmic && \
    cp wmic/usr/bin/wmic /usr/local/bin && \
    rm -rf wmic*

# POSTFIX set mail from
RUN echo "sender_canonical_maps = hash:/etc/postfix/canonical" >> /etc/postfix/main.cf && \
    sed -i '3iif ! [ "${MAIL_FROM}" = "" ]; then\necho "root     ${MAIL_FROM}" > /etc/postfix/canonical\n/usr/sbin/postmap hash:/etc/postfix/canonical\nfi' /etc/sv/postfix/run

# check_wmi_plus
RUN mkdir /opt/Check_WMI_Plus && \
    cd /opt/Check_WMI_Plus && \
    wget -O check_wmi_plus.v${WMIPLUS}.tar.gz http://edcint.co.nz/checkwmiplus/sites/default/files/check_wmi_plus.v${WMIPLUS}.tar.gz && \
    tar zxvf check_wmi_plus.v${WMIPLUS}.tar.gz && \
    rm check_wmi_plus.v${WMIPLUS}.tar.gz && \
    cd /opt/Check_WMI_Plus/etc/check_wmi_plus && \
    cp check_wmi_plus.conf.sample check_wmi_plus.conf && \
    sed -i "s/^\$base_dir.*/\$base_dir=\'\/opt\/Check_WMI_Plus\';/" check_wmi_plus.conf && \
    sed -i "s/^\$wmic_command.*/\$wmic_command=\"\/usr\/local\/bin\/wmic\";/" check_wmi_plus.conf && \
    cd /opt/Check_WMI_Plus && \
    sed -i "s/^my \$conf_file.*$/my \$conf_file=\'\/opt\/Check_WMI_Plus\/etc\/check_wmi_plus\/check_wmi_plus.conf\';/" check_wmi_plus.pl