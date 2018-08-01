#!/bin/bash
##
## usage: 
##          for solr audit loging: ./script <ranger_fqdn> solr
##          for hdfs audit loging: ./script <ranger_fqdn>
##          eg. install-hive-hdfs-ranger-plugin.sh <ranger-ip>
##
set -euo pipefail
set -x
#Variables
hostname=`hostname -I | xargs`
export JAVA_HOME=/usr/lib/jvm/java-openjdk
sudo -E bash -c 'echo $JAVA_HOME'
installpath=/usr/lib/ranger
ranger_fqdn=$1
#ranger_fqdn=10.201.97.111
mysql_jar_location=http://central.maven.org/maven2/mysql/mysql-connector-java/5.1.39/mysql-connector-java-5.1.39.jar
mysql_jar=mysql-connector-java-5.1.39.jar
s3bucket=https://s3.amazonaws.com/aws-bigdata-blog/artifacts/aws-blog-emr-ranger
#
ranger_s3bucket=$s3bucket/ranger/ranger-0.7.1
ranger_hdfs_plugin=ranger-0.7.1-hdfs-plugin
ranger_hive_plugin=ranger-0.7.1-hive-plugin
#Setup
sudo rm -rf $installpath
sudo mkdir -p $installpath/hadoop
sudo chmod -R 777 $installpath
cd $installpath
wget $mysql_jar_location
#aws s3 cp $ranger_s3bucket/$ranger_hdfs_plugin.tar.gz . --region us-east-1
#aws s3 cp $ranger_s3bucket/$ranger_hive_plugin.tar.gz . --region us-east-1
wget $ranger_s3bucket/$ranger_hdfs_plugin.tar.gz
wget $ranger_s3bucket/$ranger_hive_plugin.tar.gz
tar -xvf $ranger_hdfs_plugin.tar.gz
cd $installpath/$ranger_hdfs_plugin
ln -s /etc/hadoop/conf $installpath/hadoop/conf
ln -s /usr/lib/hadoop $installpath/hadoop/lib
#Update Ranger URL in HDFS conf
cp install.properties install.properties_original
sudo sed -i "s|POLICY_MGR_URL=.*|POLICY_MGR_URL=http://$ranger_fqdn:6080|g" install.properties
sudo sed -i "s|XAAUDIT.DB.HOSTNAME=.*|XAAUDIT.DB.HOSTNAME=localhost|g" install.properties
sudo sed -i "s|XAAUDIT.DB.DATABASE_NAME=.*|XAAUDIT.DB.DATABASE_NAME=ranger_audit|g" install.properties
sudo sed -i "s|XAAUDIT.DB.USER_NAME=.*|XAAUDIT.DB.USER_NAME=rangerlogger|g" install.properties
sudo sed -i "s|XAAUDIT.DB.PASSWORD=.*|XAAUDIT.DB.PASSWORD=rangerlogger|g" install.properties
sudo sed -i "s|SQL_CONNECTOR_JAR=.*|SQL_CONNECTOR_JAR=$installpath/$mysql_jar|g" install.properties
sudo sed -i "s|REPOSITORY_NAME=.*|REPOSITORY_NAME=hadoopdev|g" install.properties
sudo sed -i "s|XAAUDIT.SOLR.URL=.*|XAAUDIT.SOLR.URL=http://$ranger_fqdn:8983/solr/ranger_audits|g" install.properties
sudo sed -i "s|XAAUDIT.SOLR.SOLR_URL=.*|XAAUDIT.SOLR.SOLR_URL=http://$ranger_fqdn:8983/solr/ranger_audits|g" install.properties
sudo sed -i "s|XAAUDIT.SOLR.ENABLE=.*|XAAUDIT.SOLR.ENABLE=true|g" install.properties
sudo sed -i "s|XAAUDIT.DB.IS_ENABLED=.*|XAAUDIT.DB.IS_ENABLED=true|g" install.properties
sudo sed -i "s|XAAUDIT.DB.HOSTNAME=.*|XAAUDIT.DB.HOSTNAME=$ranger_fqdn|g" install.properties
sudo -E bash enable-hdfs-plugin.sh
#Update Ranger URL in Hive Conf
mkdir -p $installpath/hive/lib
cd $installpath
tar -xvf $ranger_hive_plugin.tar.gz
cd $installpath/$ranger_hive_plugin
ln -s /etc/hive/conf $installpath/hive/conf
#ln -s /usr/lib/hive $installpath/hive/lib
#export CLASSPATH=$CLASSPATH:/usr/lib/ranger/$ranger_hive_plugin/lib/ranger-*.jar
sudo -E bash -c 'echo $CLASSPATH'
cp install.properties install.properties_original
sudo sed -i "s|POLICY_MGR_URL=.*|POLICY_MGR_URL=http://$ranger_fqdn:6080|g" install.properties
sudo sed -i "s|XAAUDIT.DB.HOSTNAME=.*|XAAUDIT.DB.HOSTNAME=localhost|g" install.properties
sudo sed -i "s|XAAUDIT.DB.DATABASE_NAME=.*|XAAUDIT.DB.DATABASE_NAME=ranger_audit|g" install.properties
sudo sed -i "s|XAAUDIT.DB.USER_NAME=.*|XAAUDIT.DB.USER_NAME=rangerlogger|g" install.properties
sudo sed -i "s|XAAUDIT.DB.PASSWORD=.*|XAAUDIT.DB.PASSWORD=rangerlogger|g" install.properties
sudo sed -i "s|SQL_CONNECTOR_JAR=.*|SQL_CONNECTOR_JAR=/usr/lib/ranger/$mysql_jar|g" install.properties
sudo sed -i "s|REPOSITORY_NAME=.*|REPOSITORY_NAME=hivedev|g" install.properties
if [ "$2" == "solr" ]; then
   sudo sed -i "s|XAAUDIT.SOLR.URL=.*|XAAUDIT.SOLR.URL=http://$ranger_fqdn:8983/solr/ranger_audits|g" install.properties
   sudo sed -i "s|XAAUDIT.SOLR.ENABLE=.*|XAAUDIT.SOLR.ENABLE=true|g" install.properties
else
   sudo sed -i "s|XAAUDIT.HDFS.HDFS_DIR=.*|XAAUDIT.HDFS.HDFS_DIR=hdfs://$hostname:8020|g" install.properties
   sudo sed -i "s|XAAUDIT.HDFS.ENABLE=.*|XAAUDIT.HDFS.ENABLE=true|g" install.properties
   hdfs dfs -mkdir -p /ranger/audit/hiveServer2
   HIVE_USER_GROUP=hive:hive
   hdfs dfs -chown $HIVE_USER_GROUP /ranger/audit/hiveServer2
fi
sudo sed -i "s|XAAUDIT.DB.IS_ENABLED=.*|XAAUDIT.DB.IS_ENABLED=true|g" install.properties
sudo sed -i "s|XAAUDIT.DB.HOSTNAME=.*|XAAUDIT.DB.HOSTNAME=$ranger_fqdn|g" install.properties
sudo -E bash enable-hive-plugin.sh
#sudo cp /usr/lib/hive/ranger-*.jar /usr/lib/hive/lib/
sudo cp $installpath/$ranger_hive_plugin/lib/ranger-hive-plugin-impl/*.jar /usr/lib/hive/
sudo cp $installpath/$ranger_hive_plugin/lib/ranger-hive-plugin-impl/*.jar /usr/lib/hive/lib/
#Restart Namenode
# sudo puppet apply -e 'service { "hadoop-hdfs-namenode": ensure => false, }'
# sudo puppet apply -e 'service { "hadoop-hdfs-namenode": ensure => true, }'
# #Restart HiveServer2
# sudo puppet apply -e 'service { "hive-server2": ensure => false, }'
# sudo puppet apply -e 'service { "hive-server2": ensure => true, }'
# sudo sed -i '/hive.server2.logging.operation.verbose/s/kwargs/#kwargs/g' /usr/lib/hue/apps/beeswax/src/beeswax/server/hive_server2_lib.py
# sudo puppet apply -e 'service { "hue": ensure => false, }'
# sudo puppet apply -e 'service { "hue": ensure => true, }'
sudo stop hadoop-hdfs-namenode
sudo start hadoop-hdfs-namenode
sudo stop hive-server2
sudo start hive-server2
#sudo hive --service metastore
#sudo /usr/lib/spark/sbin/start-thriftserver.sh



