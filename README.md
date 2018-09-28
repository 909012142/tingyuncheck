# tingyuncheck
# 听云自监控脚本
# 作者：高耀华
# qq联系方式：909012142
# 个人博客 www.updn.cn
# 上传时间：20180928

一、进入对应位置（报表位置）
cd /opt/tingyun/report/webapps/lens/webapp_console/static/downloads/tingyuncheck
选择要监控的产品类型对应的脚本

二、打开对应产品脚本（app）
vim tingyun_check_server.sh
SERVICE_HOST=192.168.2.88    报表平台地址
DB_HOST=192.168.2.38         数据库地址
DB_USER=lens                 数据库用户名
DB_PASSWD=Nbs@2010			 数据库密码
REDIS_PASSWD=Nbs@2010		 redis密码
REDIS_THRESHOLD=50			 redis内存告警阈值百分比
DISK_THRESHOLD=80			 硬盘告警阈值百分比
KAFKA_LAG=1					 kafka总积压数阈值数


三、使用自建用户，添加计划：
crontab -e
*/1 * * * * curl -fsSL http://192.168.2.199:18080/lens/static/downloads/tingyuncheck/tingyun_check_app.sh | sh >/dev/null 2>&1 （注意 192.168.2.88 改为报表平台地址）


备注：
/etc/init.d/crond restart 