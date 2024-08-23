#!/bin/bash

re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }

USERNAME=$(whoami)
HOSTNAME=$(hostname)

BASH_SOURCE="$0"
appname="singbox"
LOGS_DIR="/usr/home/$USER/logs"
[ -d "$LOGS_DIR" ] || (mkdir -p "$LOGS_DIR" && chmod 755 "$LOGS_DIR")


SERVER_TYPE=$(echo $HOSTNAME | awk -F'.' '{print $2}')

if [ $SERVER_TYPE == "ct8" ];then
    DOMAIN=$USER.ct8.pl
elif [ $SERVER_TYPE == "serv00" ];then
    DOMAIN=$USER.serv00.net
else
    DOMAIN="unknown-domain"
fi

WORKDIR="/usr/home/$USER/domains/$DOMAIN/logs"



printLog(){
    local time=$(date "+%Y-%m-%d %H:%M:%S")
    local log_str="[${time}]:$1"    
    local FILE=$BASH_SOURCE
    local filename=$(basename $FILE .sh)
    echo "$log_str" >> $LOGS_DIR/$filename.log
}


printStatus(){
  printLog "$appname status: $1 "
}
declare -A FILE_MAP
load_map(){

    if [[ -f app_map.json ]]; then
        FILE_MAP["bot"]="$(jq -r '.bot' app_map.json)"
        FILE_MAP["web"]="$(jq -r '.web' app_map.json)"
        FILE_MAP["npm"]="$(jq -r '.npm' app_map.json)"    
        ARGO_AUTH="$(jq -r '.argo_auth' app_map.json)"  
        exe_bot="$(basename ${FILE_MAP[bot]})"
        exe_web="$(basename ${FILE_MAP[web]})"
        exe_npm="$(basename ${FILE_MAP[npm]})"       
        green "bot: $exe_bot"
        green "web: $exe_web"
        green "npm: $exe_npm"
        green "ARGO_AUTH: ${ARGO_AUTH}" 
    else
        red "app_map.json 文件不存在或格式错误。"
        exit 1
    fi  
}

check_web()
{
    local result=$(pgrep -x "$exe_web" 2> /dev/null)

run_web(){
    if [ -e "${FILE_MAP[web]}" ] && [ -e "config.json" ]; then
        nohup "${FILE_MAP[web]}" run -c config.json >/dev/null 2>&1 &
        sleep 2  
    else
        red "${FILE_MAP[web]} or config.json doesn't exit "     
        exit 1
    fi    
}

    if [ -z ${result} ]; then
      red "web is not running, restarting..."
      pkill $exe_web
      run_web       
      pgrep -x "$exe_web"  >/dev/null && { green "web restart ok"; printLog "web restart ok" ;} || { red "web restart failed";  printLog "web restart failed"; }     
    else
      green "web is running"
      printLog "web is running" 
    fi;    


}

check_bot(){
    local result=$(pgrep -x "$exe_bot" 2> /dev/null)
run_bot(){
    if [ -e "${FILE_MAP[bot]}" ]; then
        if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
        args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
        elif [[ $ARGO_AUTH =~ TunnelSecret ]]; then
            if [ -e "./tunnel.yml" ];then
                args="tunnel --edge-ip-version auto --config tunnel.yml run"
            else
                red "tunnel.yml doesn't exit"
                exit 1
            fi
        else
        args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile boot.log --loglevel info --url http://localhost:$vmess_port"
        fi
        nohup "${FILE_MAP[bot]}" $args >/dev/null 2>&1 &
        sleep 2        
    fi
}

    if [ -z ${result} ]; then
      red "bot is not running, restarting..."
      pkill "$exe_bot"
      run_bot 
      sleep 2
      pgrep -x "$exe_bot" >/dev/null && { green "bot restart ok"; printLog "bot restart ok" ;} || { red "bot restart failed";  printLog "bot restart failed"; }
    else
      green "bot is running"
      printLog "bot is running" 
    fi;   

}

        
main(){
    cd $WORKDIR
    load_map
    check_web
    check_bot
}

main
