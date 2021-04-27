#!/bin/bash

######################################## ENVIRONMENT ###########################################
#YT_API_TOKEN=
#YT_API_URL=
#YT_API_USERNAME=

## Create an IO to use stdout with functions
exec 3>&1
function log() {
  printf "%s\n" "$1" 1>&3
}

######################################## ERR Exit codes ########################################
ERR_MISSING_API_TOKEN=1
ERR_MISSING_API_URL=2
ERR_MISSING_API_USERNAME=3
ERR_MISSING_JQ=4
ERR_MISSING_CURL=5

ERR_MISSING_PAYLOAD=10

if ! command -v jq &>/dev/null; then
  log "You must have jq installed"
  exit $ERR_MISSING_JQ
fi
if ! command -v curl &>/dev/null; then
  log "You must have curl installed"
  exit $ERR_MISSING_CURL
fi
if [[ -z "$YT_API_TOKEN" ]]; then
  log "You must define the env var YT_API_TOKEN"
  exit $ERR_MISSING_API_TOKEN
fi
if [[ -z "$YT_API_URL" ]]; then
  log "You must define the env var YT_API_URL"
  exit $ERR_MISSING_API_URL
fi
if [[ -z "$YT_API_USERNAME" ]]; then
  log "You must define the env var YT_API_USERNAME"
  exit $ERR_MISSING_API_USERNAME
fi

###############
# Global vars #
###############
AUTH="Authorization: Bearer $YT_API_TOKEN"
USER_LOGIN="$YT_API_USERNAME"
USER_ID=""

API_URL="$YT_API_URL"
API_ISSUES="$API_URL/issues"
API_ISSUES_QUERY="$API_ISSUES?fields=id,idReadable,project(id,name),summary&query="
API_WORK_ITEM_FIELDS="fields=id,text,author(id,name),creator(id,name),type(id,name),created,updated,duration(id,minutes,presentation),date,issue"
API_PROJECT_URL="$API_URL/admin/projects"
API_PROJECT_QUERY="?fields=id,name,shortName&query="
API_PROJECT_TIME_TYPES="/timeTrackingSettings/workItemTypes?fields=id,name"
API_USERS="$API_URL/users"
API_USERS_QUERY="$API_USERS?fields=id,login&query="

## Filed by the script
ISSUE_ID=
ISSUE_NAME=
ISSUE_URL=

WORK_ITEM_DATE=
WORK_ITEM_DURATION=
WORK_ITEM_TIMESTAMP=
WORK_ITEM_TEXT=
WORK_ITEM_TYPE=
WORK_ITEM_TYPE_RAW=
WORK_ITEM_URL=
WORK_ITEM_PAYLOAD=

declare -a POSTED_WORK_ITEM_ID_LIST

## Set Internal Field Separator
IFS=" "

#################################################
# Functions available through command line args #
#################################################

## Search for an Issue and print its information
function search_issue() {
  local query
  query="${API_ISSUES_QUERY}$1"
  curl -X GET -H "$AUTH" "$query" -s
}
#
## Search for a Project
#### and print its information
function search_project() {
  local query
  query="${API_PROJECT_URL}/${API_PROJECT_QUERY}$1"
  curl -X GET -H "$AUTH" "$query" -s
}
#
## Search for a Project and print its WorkItem Types
function search_project_work_item_types() {
  local query
  query="${API_PROJECT_URL}/$1${API_PROJECT_TIME_TYPES}"
  curl -X GET -H "$AUTH" "$query" -s
}

########################
# Controller functions #
########################
#
## Function to build the SpendTime
#### Read a file line by line, with its fields delimited by a Space
#### If a line starts by #
######## Directly followed by setdate <Date>, the script will update its WORK_ITEM_DATE
######## Otherwise, the line will be discard as a comment
function work_from_file() {
  while read -r line; do
    line="${line//ir/ri}"
    if [[ ${#line} -le 0 ]]; then
      continue
    fi
    if [[ "$line" =~ ^#.* ]]; then
      if [[ "$line" =~ "#setdate" ]]; then
        local line_split
        read -ra line_split <<<"$line"
        WORK_ITEM_DATE=${line_split[1]}
      fi
      continue
    fi
    eval "args_to_issue $line"
    execute_work

  done <"$1"
}
#
## Function to build the SpendTime
#### Read the args from the command line
function work_from_cmd_line() {
  args_to_issue "$@"
  execute_work
}
#
## Function to execute the prepared work
#### Calls set_work_item_payload to generate the payload
#### Calls post_work with previous payload
function execute_work() {
  set_work_item_payload
  post_work
  # reset vars
  unset ISSUE_NAME ISSUE_ID ISSUE_URL
  unset WORK_ITEM_DURATION WORK_ITEM_TIMESTAMP WORK_ITEM_TYPE_RAW WORK_ITEM_TYPE WORK_ITEM_TEXT WORK_ITEM_PAYLOAD
}
#
## Function to submit the work
function post_work() {
  if [ -z "$WORK_ITEM_PAYLOAD" ]; then
    log "post_work need a payload."
    exit $ERR_MISSING_PAYLOAD
  fi

  local tracking_query work_item_id

  tracking_query="$ISSUE_URL/timeTracking/workItems?$API_WORK_ITEM_FIELDS"
  work_item_id=$(curl -X POST -H "Content-Type: application/json" -H "$AUTH" "$tracking_query" -d "$WORK_ITEM_PAYLOAD" -s | jq -r ".id")
  POSTED_WORK_ITEM_ID_LIST+=("$work_item_id")
  WORK_ITEM_URL="$ISSUE_URL/timeTracking/workItems/$work_item_id"

  log "WorkItem created with id $work_item_id $WORK_ITEM_URL"
}

####################
# Script functions #
####################
#
## Parse the args and fill vars
function args_to_issue() {
  local duration
  log "Parsing $*"

  ISSUE_NAME="$1" && shift
  set_issue_id
  set_issue_url

  duration="$1" && shift
  set_work_item_duration "$duration"
  if [[ -z $WORK_ITEM_DATE ]]; then
    WORK_ITEM_DATE="$1" && shift
  fi
  set_work_item_timestamp

  WORK_ITEM_TYPE_RAW="$1"
  set_work_item_type

  if [[ -n "$WORK_ITEM_TYPE" ]]; then
    shift
  fi

  if [[ -n "$*" ]]; then
    WORK_ITEM_TEXT="$*"
  fi
}
#
## Retrieve the USER_ID linked to the Username defined in YT_API_USERNAME
function set_user_id() {
  local query
  query="$API_USERS_QUERY$USER_LOGIN"
  USER_ID=$(curl -X GET -H "$AUTH" "$query" -s | jq -r ".[0].id")
}
#
## Set the ISSUE_ID by executing search_issue with ISSUE_NAME
function set_issue_id() {
  ISSUE_ID=$(search_issue "$ISSUE_NAME" | jq -c -r ".[0].id")
}
#
## Set the ISSUE_URL to "$API_ISSUES/$ISSUE_ID"
function set_issue_url() {
  ISSUE_URL="$API_ISSUES/$ISSUE_ID"
}
#
## Set the WORK_ITEM_TIMESTAMP
function set_work_item_timestamp() {
  WORK_ITEM_TIMESTAMP=$(($(date -d "$WORK_ITEM_DATE" "+%s") * 1000))
}
#
## Set the WORK_ITEM_TYPE matching the Project WorkItemTypes
#### Use NULL to unset the type
function set_work_item_type() {
  local issue_split
  unset WORK_ITEM_TYPE
  shopt -s nocasematch
  IFS='-'
  read -ra issue_split <<<"$ISSUE_NAME"
  IFS="
"
  for obj in $(search_project_work_item_types "${issue_split[0]}" | jq -r -c '.[]'); do
    if [[ $(echo "$obj" | jq -c -r ".name") == "$WORK_ITEM_TYPE_RAW" ]]; then
      WORK_ITEM_TYPE=$(echo "${obj}" | jq -c -r ".id")
      break
    fi
  done
  IFS=" "
  shopt -u nocasematch
}
#
## Transform :h:m duration into minutes
function set_work_item_duration() {
  local total accu
  total=0
  tmp=$(echo "$1" | grep -o .)
  readarray -t arr <<<"$tmp"
  for char in "${arr[@]}"; do
    if [[ "$char" =~ ^[0-9]+$ ]]; then
      if [[ -z $accu ]]; then
        accu=$char
      else
        accu=$((accu * 10))
      fi
    else
      case "$char" in
      h)
        total=$((total + accu * 60))
        unset accu
        ;;
      m)
        total=$((total + accu))
        break
        ;;
      esac
    fi
  done
  WORK_ITEM_DURATION=$total
}
#
## Function to build a SpendTime WorkItem payload
function set_work_item_payload() {
  basic="\"usesMarkdown\": true,"
  if [ -n "$WORK_ITEM_TEXT" ]; then
    basic+="
    \"text\": \"$WORK_ITEM_TEXT\","
  fi

  basic+="
    \"date\": $WORK_ITEM_TIMESTAMP,
    \"author\": {
      \"id\": \"$USER_ID\"
    },
    \"duration\": {
      \"minutes\": $WORK_ITEM_DURATION
    }"

  if [ -n "$WORK_ITEM_TYPE" ]; then
    basic+=",
    \"type\": {
      \"id\": \"$WORK_ITEM_TYPE\"
    }"
  fi
  WORK_ITEM_PAYLOAD="{
    $basic
}"
}

function usage() {
  log "Usage: $0 <IssueName> <Time> <Date> [Type] [Text] | <path> | [-h] [-I IssueName] [-P ProjectName] [-T ProjectName]
Where:
  -h          Show this help
  -I          Search for an Issue to get its information
  -P          Search for a Project to get its information
  -T          Search for a Project to get its time tracking WorkItem Types


  Used by command line, the script expects the following arguments:
    IssueName   Required  YouTrack idReadable name of the issue
    Time        Required  Spent time on the issue, on the format of XhYm
    Date        Required  The date of the time spent, on the format yyyy-mm-dd
    [Type]      Optional  Type of work to log. See -T option to get the full name of the wanted type
                          If the Type contains spaces, it must be encapsulated by quotes
    [Text]      Optional  Comments to be added to the logged work item
                          If the Comments contains spaces, it must be encapsulated by quotes


  To upload several spend time at once, you can feed the script with a path to a file:
    path        Path to the spent time to parse and upload

  As the file allows to upload lot of work, the date is managed differently and thus the format of the file differs from the command line args:
    IssueName   Required  YouTrack idReadable name of the issue
    Time        Required  Spent time on the issue, on the format of XhYm
    [Type]      Optional  Type of work to log. See -T option to get the full name of the wanted type
                          If the Type contains spaces, it must be encapsulated by quotes
    [Text]      Optional  Comments to be added to the logged work item
                          If the Comments contains spaces, it must be encapsulated by quotes

  You must use a specific comment-function to set the dates, which will be effective for lines bellow it
    #setdate <Date>
  Other lines starting with # will be discard as comments."
  exit 0
}

function main() {
  while getopts ":I:P:T:" opt; do
    case "${opt}" in
    I)
      set_user_id
      search_issue "$OPTARG"
      exit 0
      log
      ;;
    P)
      set_user_id
      search_project "$OPTARG"
      log
      exit 0
      ;;
    T)
      set_user_id
      search_project_work_item_types "$OPTARG"
      log
      exit 0
      ;;
    *)
      usage
      ;;
    esac
  done

  set_user_id

  if [[ -f "$1" ]]; then
    work_from_file "$1"
  else
    work_from_cmd_line "$@"
  fi

  log "${POSTED_WORK_ITEM_ID_LIST[*]}"
}

main "$@"

####### WorkItem Payload
#{
#    usesMarkdown: true,
#    text: "",
#    date: 1539000000000,
#    author: {
#      id: ""
#    },
#    duration: {
#      minutes:
#    },
#    type: {
#      id: ""
#    }
#}
