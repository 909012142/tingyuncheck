#!/bin/bash
##########################################
# MAINTAINER by gaoyaohua
# MAIL: gaoyh@tingyun.com
# QQ:909012142
# BLOG: www.updn.cn/www.521478.com
########################################################################
# how to use?
# crontab -e
# */10 * * * * curl -fsSL http://192.168.2.88:18080/lens/static/downloads/tingyuncheck/tingyun_check_browser.sh | sh >/dev/null 2>&1
########################################################################
#warning: must change INIT
#warning: must run by tingyun user
# INIT
SERVICE_HOST=report
DB_HOST=db_conf
DB_USER=lens
DB_PASSWD=Nbs@2010
REDIS_PASSWD=Nbs@2010
REDIS_THRESHOLD=50
DISK_THRESHOLD=80
KAFKA_LAG=100000

# SYSTEM INIT
SERVICE=browser
TYPE=3
#0000001       公共     all             主机分区磁盘使用率超过阈值
#0001001       公共     mysql           mysql服务状态异常
#0001002       公共     mysql           mysql表分区创建异常
#0002001       公共     redis           redis服务状态异常
#0002002       公共     redis           redis内存使用率超过阈值
#0003001       公共     es              es服务状态异常
#0004001       公共     kafka           kafka服务状态异常
#0004002       公共     kafka           kafka积压数超过阈值
#0005001       公共     report          report服务状态异常
#0006001       公共     screen          report服务状态异常
#0101001       app      frontend        app产品frontend服务状态异常
#0102001       app      wrap            app产品wrap服务状态异常
#0103001       app      backend         app产品backend服务状态异常
#0104001       app      aggr            app产品aggr服务状态异常
#0105001       app      alarm           app产品alarm服务状态异常
#0106001       app      sensors         app产品sensors服务状态异常
#0107001       app      webviewindex    app产品webviewindex服务状态异常
#0108001       app      webviewsearch   app产品webviewsearch服务状态异常
#0109001       app      nbfs            app产品nbfs服务状态异常
#0110001       app      active          app产品active服务状态异常
#0201001       server   frontend        server产品frontend服务状态异常
#0202001       server   backend         server产品backend服务状态异常
#0203001       server   alarm           server产品alarm服务状态异常
#0204001       server   hotspot         server产品hotspot服务状态异常
#0301001       browser  nginx           browser产品nginx服务状态异常
#0302001       browser  flume           browser产品flume服务状态异常
#0303001       browser  wrap            browser产品wrap服务状态异常
#0304001       browser  alarm           browser产品alarm服务状态异常
#0305001       browser  baseline        browser产品baseline服务状态异常
#0306001       browser  aggr            browser产品aggr服务状态异常
#0401001       sys      frontend        sys产品frontend服务状态异常
#0402001       sys      backend         sys产品frontend服务状态异常

# GET INIT
source ~/.bashrc && INIT_LIST=(mysql redis es kafka report alarm baseline wrap aggr flume nginx screen)   #配置服务字段列表 service list
TINGYUN_PATH=`tingyun info|awk '{print $3}'`
[ -z $TINGYUN_PATH ] && echo "check tingyunpath" && exit
DATE=`date "+%Y-%m-%d %H:%M:%S"`
# 获取ip
GET_IP=`/sbin/ip addr | grep inet | grep -v inet6 | grep -v 127.0.0.* | awk '{print $2}' | awk -F '/' '{print $1}' | head -1`
# 获取机器唯一标识uuid
#UUID=`cat /proc/sys/kernel/random/uuid`
#echo $UUID
# 随机生成8位字符串函数randstr
randstr() {
  index=0
  str=""
  for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {1..8}; do str="$str${arr[$RANDOM%$index]}"; done
  echo ${str}
}
RANDSTR=`randstr`

# CONFIG
#TINGYUN_CONFIG=/tmp/tingyun/${RANDSTR}
TINGYUN_MYSQL_CLIENT=$TINGYUN_PATH/install/mysql
[ ! -d $TINGYUN_PATH/install ] && mkdir -p $TINGYUN_PATH/install
#curl -fsSL http://${SERVICE_HOST}/${SERVICE}/config -o $TINGYUN_CONFIG && source $TINGYUN_CONFIG
[ ! -f $TINGYUN_MYSQL_CLIENT ] && curl -fsSL http://${SERVICE_HOST}:18080/lens/static/downloads/tingyuncheck/mysql -o $TINGYUN_MYSQL_CLIENT 
[ ! -x $TINGYUN_MYSQL_CLIENT ] && chmod +x $TINGYUN_MYSQL_CLIENT

# FUNCTION
mysql_driver () {
	${TINGYUN_MYSQL_CLIENT} -u${DB_USER} -p${DB_PASSWD} -h${DB_HOST} -e "$1"
}
check_list() {
	is_result=`mysql_driver "select count(*) from server_conf.NL_U_WATCH_COMPONENT where name='$1' and hostip='$GET_IP' and hostname='$HOSTNAME';"|awk 'NR>1'`
	if [ "a$is_result" == "a0" ];then
		mysql_driver "insert into server_conf.NL_U_WATCH_COMPONENT(name,hostip,hostname,status,mtime,ismonitor,type)values('$1','$GET_IP','$HOSTNAME','0',now(),'1','$TYPE');" && echo 1
	else
		result=`mysql_driver "select ismonitor from server_conf.NL_U_WATCH_COMPONENT where name='$1' and hostip='$GET_IP' and hostname='$HOSTNAME';"|awk 'NR>1'` && echo $result
	fi
}
check_log() {
	mysql_driver "update server_conf.NL_U_WATCH_COMPONENT set mtime=now() where name='$1' and hostip='$GET_IP' and hostname='$HOSTNAME';"
}
check_over() {
	componentId=`mysql_driver "select id from server_conf.NL_U_WATCH_COMPONENT where name='$1' and hostip='$GET_IP' and hostname='$HOSTNAME';"|awk 'NR>1'`
	mysql_driver "update server_conf.NL_U_WATCH_ALARM set close=1, mtime=now() where componentid='$componentId' and content='$2' and close=0;"
	mysql_driver "update server_conf.NL_U_WATCH_COMPONENT set status=0 where id='$componentId' and status=1;"
}
check_alert() {
	componentId=`mysql_driver "select id from server_conf.NL_U_WATCH_COMPONENT where name='$1' and hostip='$GET_IP' and hostname='$HOSTNAME';"|awk 'NR>1'`
	#is_result=`mysql_driver "select count(*) from server_conf.NL_U_WATCH_ALARM where content='$2' and componentId='$componentId' and close=0 and mtime >=CURRENT_TIMESTAMP - INTERVAL 10 MINUTE;"|awk 'NR>1'`
	is_result=`mysql_driver "select count(*) from server_conf.NL_U_WATCH_ALARM where content='$2' and componentId='$componentId' and close=0;"|awk 'NR>1'`
	if [ "a$is_result" == "a0" ];then	
		mysql_driver "insert into server_conf.NL_U_WATCH_ALARM(componentid,content,ctime,mtime,close,sendmessage,type)values('$componentId','$2',now(),now(),0,0,'$TYPE');"
	else
		mysql_driver "update server_conf.NL_U_WATCH_ALARM set mtime=now() where content='$2' and componentId='$componentId' and close=0;"
	fi
	mysql_driver "update server_conf.NL_U_WATCH_COMPONENT set status=1 where id='$componentId';"
}


# check
all() {
	date=`date +%F' '%T`
	df -h | awk 'NF>3&&NR>1{sub(/%/,"",$(NF-1));print $NF,$(NF-1)}' | while read line
	do
		if [ "`echo $line | awk '{print $2}'`" -gt "$DISK_THRESHOLD" ];then
			check_alert all 0000001
		fi
	done
}
nginx() {
	nginx_pr=`ps ax | grep nginx | grep master | egrep -v "grep"`
	[ -z "$nginx_pr" ] && check_alert nginx 0301001 || check_over nginx 0301001
}
flume() {
	flume_pr=`ps ax | grep "flume" | egrep -v "grep"`
	[ -z "$flume_pr" ] && check_alert flume 0302001 || check_over flume 0302001
}
redis() {
	redis_pr=`ps ax | grep "redis-server" | egrep -v "grep"`
	[ -z "$redis_pr" ] && check_alert redis 0002001 || check_over redis 0002001
	REDIS_CLI="$TINGYUN_PATH/redis/bin/redis-cli"
	if [ ! -z "$redis_pr" ];then
		used_memory=`$REDIS_CLI -h localhost -p 6379 -a $REDIS_PASSWD info | grep -w "used_memory" | awk -F':' '{print $2}'`
		total_system_memory=`$REDIS_CLI -h localhost -p 6379 -a $REDIS_PASSWD info | grep -w "total_system_memory" | awk -F':' '{print $2}'`
		percent=`awk 'BEGIN{printf "%d\n",('$used_memory'/'$total_system_memory')*100}'`
		if [ "$percent" -gt "$REDIS_THRESHOLD" ];then
			check_alert redis 0002002
		fi
	fi
}
es() {
	es_pr=`ps ax | grep java | grep "elasticsearch.pid"| egrep -v "grep"`
	[ -z "$es_pr" ] && check_alert es 0003001 || check_over es 0003001
}
kafka() {
	zookeeper_pr=`ps -ef|grep "zookeeper-gc.log" | egrep -v "grep"`
	kafka_pr=`ps -ef|grep "kafkaServer-gc.log" | egrep -v "grep"`
	[ -z "$zookeeper_pr" ] || [ -z "$kafka_pr" ] && check_alert kafka 0004001 || check_over kafka 0004001
	CONSUMER_GROUP=$(${TINGYUN_PATH}/kafka/bin/kafka-consumer-groups.sh --zookeeper localhost:2181 --list)
	> $TINGYUN_PATH/install/kafka.info
	for GROUP in ${CONSUMER_GROUP}
	do
		${TINGYUN_PATH}/kafka/bin/kafka-consumer-groups.sh --zookeeper localhost:2181 --describe --group $GROUP 2>/dev/null >> $TINGYUN_PATH/install/kafka.info
	done
	KAFKA_LAG_info=`cat $TINGYUN_PATH/install/kafka.info  | awk -F ", " '{if($(NF-1)!="LAG") sum+=$(NF-1)} END{print sum}'`
	[ $KAFKA_LAG_info -gt $KAFKA_LAG ] && check_alert kafka 0004002 || check_over kafka 0004002

}
wrap() {
	wrap_pr=`ps ax | grep "DappName=dc-browser-wrapping" | egrep -v "grep"`
	[ -z "$wrap_pr" ] && check_alert wrap 0303001 || check_over wrap 0303001
}
aggr() {
	aggr_pr=`ps ax | grep "DappName=dc-aggr" | grep -v "DappName=dc-aggr-hourly" | grep -v "DappName=dc-aggr-daily" | egrep -v "grep"`
	aggr_pr_hourly=`ps ax | grep "DappName=dc-aggr-hourly" | egrep -v "grep"`
	aggr_pr_daily=`ps ax | grep "DappName=dc-aggr-daily" | egrep -v "grep"`
	[ -z "$aggr_pr" ] || [ -z "$aggr_pr_hourly" ] || [ -z "$aggr_pr_daily" ] && check_alert aggr 0306001 || check_over aggr 0306001
}
alarm() {
	alarm_pr=`ps ax | grep "DappName=dc-browser-alarm" | egrep -v "grep"`
	[ -z "$alarm_pr" ] && check_alert alarm 0304001 || check_over alarm 0304001
}
baseline() {
	baseline_pr=`ps ax | grep "DappName=dc-browser-baseline" | egrep -v "grep"`
	[ -z "$baseline_pr" ] && check_alert baseline 0305001 || check_over baseline 0305001 

}
report() {
	report_pr=`ps ax | grep java | grep report | egrep -v "grep"`
	[ -z "$report_pr" ] &&  check_alert report 0005001 || check_over report 0005001
}
screen() {
        screen_pr=`ps ax | grep java | grep screen | egrep -v "grep"`
        [ -z "$screen_pr" ] &&  check_alert screen 0006001 || check_over screen 0006001
}
mysql() {
	mysql_pr=`ps aux | grep mysqld | egrep -v "grep"  | wc -l`
	[ "$mysql_pr" != "2" ] && check_alert  mysql 0001001 || check_over mysql 0001001
	event_scheduler=`mysql_driver "SHOW VARIABLES LIKE 'event_scheduler';" | awk 'NR>1 {print $2}'`
	[ "$event_scheduler" == "OFF" ] && check_alert mysql 0001002
}

# main
ismonitor=$(check_list all)
[ "$ismonitor" == "1" ] && all
check_log all
# for
for list in ${INIT_LIST[*]}
do
	if [ -d ${TINGYUN_PATH}/${list} ];then
		ismonitor=$(check_list ${list})
		[ "$ismonitor" == "1" ] && ${list}
		check_log ${list}
	fi
done
#rm -rf $TINGYUN_CONFIG
