#! /bin/bash


# system=(amd64|386)
system='amd64'
# 系统启动用户 用#注释或者为空默认为root账户
user='lxh'
#临时文件夹
tmp_path='/tmp/gogs'
# gogs 路径
gog_path='/home/lxh/gogs'
# gogs git库
gog_git_url='https://github.com/gogs/gogs/releases'
# 备份目录
gog_backup_path="${gog_path}/backup"

nowtime=`date +'%Y%m%d_%s'`

function start_service() {
	if [[ `ps aux|grep gogs|grep -v 'grep'|grep 'web'|awk '{print $2}'` != '' ]];then
		echo "检测到服务正在运行中...跳过启动"
	else
		sudo -u ${user} nohup $gog_path/gogs/gogs web >$gog_path/gogs.log 2>&1 &
		if [[ $? != '0' ]];then
			echo "启动失败"
		else
	    	echo "Gogs启动完成"
	    fi
	fi
}


function stop_service() {
	pid=`ps aux|grep gogs|grep -v 'grep'|grep 'web'|awk '{print $2}'`
    if [[ $pid == '' ]];then
        echo "Gogs服务未启动"
    else
        kill -9 $pid
		if [[ $? != '0' ]];then
			echo "停止失败"
		else
	    	echo "停止完成"
	    fi
    fi
}

function backup() {

	if [[ `ps aux|grep gogs|grep -v 'grep'|grep 'web'|awk '{print $2}'` != '' ]];then
		echo "检测到服务正在运行中. 开始停止"
		stop_service
	fi

	rm -rf $gog_backup_path

	if [ ! -d $gog_backup_path ];then
		mkdir $gog_backup_path -p
	else 
		echo "无法删除备份目录."
	fi

	cp -R $gog_path/gogs $gog_backup_path/gog_${nowtime}
	if [[ $? != '0' ]];then
		echo "备份出错.请检查日志"
		exit 1
	fi

}


function download() {
	# 获取路径并下载
	if [ ! -f "${tmp_path}/${remote_version}.tar.gz" ];then

		remote_file=`curl -s $gog_git_url |grep $remote_version|grep $system.tar.gz|awk -F'"' '{print $2}'`
		if [[ $remote_file == '' ]];then
			echo "未获取到下载路径"
			exit 1
		fi
		if [ ! -d $tmp_path ];then
			mkdir $tmp_path -p
		fi
		echo "https://github.com/${remote_file} -O ${tmp_path}/${remote_version}.tar.gz"
		wget -T 10 https://github.com/${remote_file} -O ${tmp_path}/${remote_version}.tar.gz
		if [[ $? != '0' ]];then
			echo "下载出错.重新下载"
			download
		fi
	fi


}

function update(){
	download
	stop_service
	backup
	rm -rf $gog_path/gogs
	if [ ! -d $gog_path ];then
		mkdir $gog_path -p
	fi
	tar zxvf ${tmp_path}/${remote_version}.tar.gz -C $gog_path
	if [[ $? != '0' ]];then
		echo "解压出错.重新下载远端压缩包"
		rm -f ${tmp_path}/${remote_version}.tar.gz
		download
	fi

	 cp -R $gog_backup_path/gog_${nowtime}/custom $gog_path/gogs/
	 cp -R $gog_backup_path/gog_${nowtime}/data $gog_path/gogs/
	 cp -R $gog_backup_path/gog_${nowtime}/log $gog_path/gogs/
	start_service
}

function check_update() {

	# 获取本地版本号
	local_version=`$gog_path/gogs/gogs -v|awk '{print $3}'`
	if [[ $local_version == '' ]];then
		echo "未获取到本地版本号"
		exit 1
	fi

	# 获取远端版本号
	remote_version=`curl -s $gog_git_url |grep releases/tag|awk -F'[<|>]' '{print $3}'|head -n1`
	if [[ $remote_version == '' ]];then
		echo "未获取到远端最新版本号"
		exit 1
	fi

	# 对比版本号
	if [[ $remote_version > $local_version ]];then
		echo "有版本更新"
		echo "本地版本:$local_version 远端版本: $remote_version"
		update
	else
		echo "不需要更新"
		echo "本地版本:$local_version 远端版本: $remote_version"
	fi
	
}


function install(){
	remote_version=`curl -s $gog_git_url |grep releases/tag|awk -F'[<|>]' '{print $3}'|head -n1`
	if [[ $remote_version == '' ]];then
		echo "未获取到远端最新版本号"
		exit 1
	fi

	download
	tar zxvf ${tmp_path}/${remote_version}.tar.gz -C $gog_path
	if [[ $? != '0' ]];then
		echo "解压出错.重新下载远端压缩包"
		rm -f ${tmp_path}/${remote_version}.tar.gz
		download
	fi
	start_service
}


# 指定用户执行，判断用户是否正确
if [[ "$user" == '' ]];then
	user='root'
fi
if [[ `id|awk -F '[(|)]' '{print $2}'` != "$user" ]];then
	echo "请在$user账户下执行此脚本"
	exit
fi


case $1 in 
	install )
		echo "安装Gogs服务"
		install
		;;
	update )
		echo "检测Gogs更新"
		check_update
		;;
	start )
		echo "启动Gogs服务"
		start_service
		;;
	stop )
		echo "停止Gogs服务"
		stop_service
		;;
	restart )
		echo "重启Gogs服务"
		stop_service
		start_server
		;;
	* )
		echo "请使用参数: update | start | stop | restart"
		exit
		;;
esac

