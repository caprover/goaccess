#!/bin/sh

# This script is a simpler version of the processLogs script
# It loops over log files matching the environment variable $FILE_PREFIX
# which limits it to one app and domain and creates a
# GoAccess report for it with a consistent name so it will be overwritten
# next time this runs.

# The --restore and --persist flags let GoAccess process the logs incrementally
# so it doesn't have to process the whole log file from scratch each time

echo "Starting Catchup for $FILE_PREFIX"
for logFile in /var/log/nginx-shared/$FILE_PREFIX*access.log; do


  filename=$(basename "$logFile")
  appName=${filename%%--*}
  appPath="/var/log/nginx-shared/$appName"
  dbPath="$appPath/$filename-db"

  # Make directory for all the reports to live in, and the GoAccess db
  mkdir -p $appPath
  mkdir -p $dbPath

  report="$appPath/$filename--Live.html"

  echo "Processing catchup $report"

  # If anonymization is enabled, check if database exists and was created without anonymization
  # If so, delete it to ensure it's recreated with anonymization
  if [ "$ANONYMIZE_IP" = "true" ]; then
    # Check if database exists and doesn't have anonymization marker
    if [ -d "$dbPath" ] && [ ! -f "$appPath/.anonymize-ip" ]; then
      echo "Database exists without anonymization, removing to recreate with anonymization"
      rm -rf "$dbPath"
      mkdir -p "$dbPath"
    fi
    # Create marker file to indicate database was created with anonymization
    touch "$appPath/.anonymize-ip"
    
    echo "Anonymizing IP addresses for $report"
    goaccess "$logFile" -a -o "$report" --log-format=COMBINED --restore --persist --db-path "$dbPath" --anonymize-ip
  else
    # If anonymization is disabled but database has anonymization marker, remove it
    if [ -d "$dbPath" ] && [ -f "$appPath/.anonymize-ip" ]; then
      echo "Anonymization disabled but database was created with anonymization, removing to recreate"
      rm -rf "$dbPath"
      rm "$appPath/.anonymize-ip"
      mkdir -p "$dbPath"
    fi
    
    goaccess "$logFile" -a -o "$report" --log-format=COMBINED --restore --persist --db-path "$dbPath"
  fi

done
