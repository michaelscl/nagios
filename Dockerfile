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
COPY src/mk-livestatus-${LIVESTATUS}.tar.gz /tmp/mk-livestatus.tar.gz
RUN cd /tmp && \
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
COPY src/wmi-client_${WMIC}_amd64.deb /tmp/wmic.deb
RUN cd /tmp && \
    dpkg -x wmic.deb wmic && \
    cp wmic/usr/bin/wmic /usr/local/bin && \
    rm -rf wmic*

# POSTFIX set mail from
RUN echo "sender_canonical_maps = hash:/etc/postfix/canonical" >> /etc/postfix/main.cf && \
    sed -i '3iif ! [ "${MAIL_FROM}" = "" ]; then\necho "root     ${MAIL_FROM}" > /etc/postfix/canonical\n/usr/sbin/postmap hash:/etc/postfix/canonical\nfi' /etc/sv/postfix/run

### CHEK_WMI_PLUS
# copy to dest
COPY src/check_wmi_plus.v${WMIPLUS}.tar.gz /opt/Check_WMI_Plus/check_wmi_plus.v${WMIPLUS}.tar.gz
# install and config
RUN cd /opt/Check_WMI_Plus && \
    tar zxvf check_wmi_plus.v${WMIPLUS}.tar.gz && \
    rm check_wmi_plus.v${WMIPLUS}.tar.gz && \
    cd /opt/Check_WMI_Plus/etc/check_wmi_plus && \
    cp check_wmi_plus.conf.sample check_wmi_plus.conf && \
    sed -i "s/^\$base_dir.*/\$base_dir=\'\/opt\/Check_WMI_Plus\';/" check_wmi_plus.conf && \
    sed -i "s/^\$wmic_command.*/\$wmic_command=\"\/usr\/local\/bin\/wmic\";/" check_wmi_plus.conf && \
    cd /opt/Check_WMI_Plus && \
    sed -i "s/^my \$conf_file.*$/my \$conf_file=\'\/opt\/Check_WMI_Plus\/etc\/check_wmi_plus\/check_wmi_plus.conf\';/" check_wmi_plus.pl