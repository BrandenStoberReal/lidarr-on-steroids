log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1 2>&1 | tee -a "/scripts-config/logs/$logFileName"
}

logfileSetup () {
  logFileName="$scriptName-$(date +"%Y_%m_%d_%I_%M_%p").txt"

  # delete log files older than 5 days
  find "/scripts-config/logs" -type f -iname "$scriptName-*.txt" -mtime +5 -delete
  
  if [ ! -f "/scripts-config/logs/$logFileName" ]; then
    echo "" > "/scripts-config/logs/$logFileName"
    chmod 666 "/scripts-config/logs/$logFileName"
  fi
}

getArrAppInfo () {
  # Get Arr App information
  if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
    arrUrlBase="$(cat /scripts-config/config.xml | xq | jq -r .Config.UrlBase)"
    if [ "$arrUrlBase" == "null" ]; then
      arrUrlBase=""
    else
      arrUrlBase="/$(echo "$arrUrlBase" | sed "s/\///")"
    fi
    arrName="$(cat /scripts-config/config.xml | xq | jq -r .Config.InstanceName)"
    arrApiKey="$(cat /scripts-config/config.xml | xq | jq -r .Config.ApiKey)"
    arrPort="$(cat /scripts-config/config.xml | xq | jq -r .Config.Port)"
    arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
  fi
}

verifyApiAccess () {
  until false
  do
    arrApiTest=""
    arrApiVersion=""
    if [ "$arrPort" == "8989" ] || [ "$arrPort" == "7878" ]; then
      arrApiVersion="v3"
    elif [ "$arrPort" == "8686" ] || [ "$arrPort" == "8787" ]; then
      arrApiVersion="v1"
    fi
    arrApiTest=$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r .instanceName)
    if [ "$arrApiTest" == "$arrName" ]; then
      break
    else
      log "$arrName is not ready, sleeping until valid response..."
      sleep 1
    fi
  done
}

ConfValidationCheck () {
  if [ ! -f "/scripts-config/extended.conf" ]; then
    log "ERROR :: \"extended.conf\" file is missing..."
    log "ERROR :: Download the extended.conf config file and place it into \"/config\" folder..."
    log "ERROR :: Exiting..."
    exit
  fi
  if [ -z "$enableAutoConfig" ]; then
    log "ERROR :: \"extended.conf\" file is unreadable..."
    log "ERROR :: Likely caused by editing with a non unix/linux compatible editor, to fix, replace the file with a valid one or correct the line endings..."
    log "ERROR :: Exiting..."
    exit
  fi
}

logfileSetup
ConfValidationCheck
