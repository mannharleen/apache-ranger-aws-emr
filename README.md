# Configuring Apache Ranger to Authorize EMR applications

1. Ranger runs on EC2
2. Ranger plugins are installed on EMR

## Note

If you use hdfs for audit logs, don't get worried if you don't see the logs on the hdfs files. The way it works is as follows:
1. logs are streamed to the hdfs log file
2. log files on hdfs are closed only once a day (so until the files close dfs -cat wont show anything)
3. to verify you can manually trigger the files to be close by stoppin the hive-server2 service (sudo stop hive-server2)