#!/bin/bash

######################################## ENVIRONMENT ###########################################
#YT_API_TOKEN=
#YT_API_URL=
#YT_API_USERNAME=

######################################## ERR Exit codes ########################################
ERR_MISSING_API_TOKEN=1
ERR_MISSING_API_URL=2
ERR_MISSING_API_USERNAME=3
ERR_MISSING_JQ=4
ERR_MISSING_CURL=5

ERR_MISSING_PAYLOAD=10

if ! command -v jq &> /dev/null ; then
  log "You must have jq installed"
  exit $ERR_MISSING_JQ
fi
if ! command -v curl &> /dev/null ; then
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
WORK_ITEM_URL=
WORK_ITEM_PAYLOAD=

declare -a POSTED_WORK_ITEM_ID_LIST
declare -A WORK_ITEM_TYPES=( ["Key"]="WorkItemTypeID")

## Create an IO to use stdout with functions
exec 3>&1
function log() {
  printf "%s\n" "$1" 1>&3
}

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
function work_from_file() {
  while read -r line; do
    line="${line//ir/ri}"
    if [[ ${#line} -le 0 ]]; then
      continue
    fi
    if [[ "$line" =~ ^#.* ]]; then
      log "$line"
      continue
    fi

    line_to_issue "$line"
    execute_work

    log ""
  done <"$1"
}
#
## Function to build the SpendTime
#### Read the args from the command line
function work_from_cmd_line() {
  line_to_issue "$*"
  execute_work
}
#
## Function to execute the prepared work
#### Calls set_work_item_payload to generate the payload
#### Calls post_work with previous payload
function execute_work() {
  set_work_item_payload
  post_work
}
#
## Function to submit the work
function post_work() {
  if [ -n "$WORK_ITEM_PAYLOAD" ]; then
    log "post_work should receive the payload."
    exit $ERR_MISSING_PAYLOAD
  fi
  log "POSTing WorkItem . . ."

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
## Parse the work line and fill vars
function line_to_issue() {
  local line_split delete_array text_array duration

  log "Parsing $1"

  read -ra line_split <<<"$1"

  ISSUE_NAME=${line_split[0]}                                  # Retrieve readable ISSUE_ID
  ISSUE_ID=$(search_issue "$ISSUE_NAME" | jq -c -r ".[0].id")  # Retrieve real ISSUE_ID
  ISSUE_URL="$API_ISSUES/$ISSUE_ID"                                   # Build ISSUE_URL base on real ISSUE_ID

  duration=${line_split[1]}                                           # Build duration
  set_work_item_duration "$duration"
  WORK_ITEM_DATE=${line_split[2]}
  WORK_ITEM_TIMESTAMP=$(($(date -d "$WORK_ITEM_DATE" "+%s") * 1000))

  # Keep text by removing the previous data
  delete_array=("$ISSUE_NAME" "$duration" "$WORK_ITEM_DATE")
  text_array=("${line_split[@]}")
  for del in ${delete_array[*]}; do
    text_array=("${text_array[@]/$del/}")
  done
  WORK_ITEM_TEXT=$(echo "${text_array[*]}" | sed -e 's/^[[:space:]]*//') # join array and trim

  set_work_item_type

  log "Read entry $ISSUE_NAME, spent $duration (${WORK_ITEM_DURATION}m) on the $WORK_ITEM_DATE ($WORK_ITEM_TIMESTAMP) || Matched real ID $ISSUE_ID"
}
#
## Set the WORK_ITEM_TYPE matching the Project WorkItemTypes
#### Use NULL to unset the type
function set_work_item_type() {
  unset WORK_ITEM_TYPE # null
}
#
## Retrieve the USER_ID linked to the Username defined in YT_API_USERNAME
function set_user_id() {
  local query
  query="$API_USERS_QUERY$USER_LOGIN"
  USER_ID=$(curl -X GET -H "$AUTH" "$query" -s | jq -r ".[0].id")
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
  log "Usage: $0 <path> | <IssueName> <Time> <Date> [Text] | [-h] [-I IssueName] [-P ProjectName] [-T ProjectName]
Where:
  -h          Show this help
  -I          Search for an Issue to get its information
  -P          Search for a Project to get its information
  -T          Search for a Project to get its time tracking WorkItem Types

    To upload spent time you can either provide a path
  path        Path to the spent time to parse and upload

    or you can provide the following parameters
  IssueName   YouTrack idReadable name of the issue (Should be the last parameter of the URL of the issue)
  Time        Spent time on the issue, on the format of XhYm
  Date        The date of the time spent, on the format yyyy-mm-dd
  [Text]      Optional parameter, the text you want the spent time to be accompanied with

  Notice: The file provided should follow the same pattern as the <IssueName> <Time> <Date> [Text].
  Lines starting with # will only be logged as comments, not parsed to upload."
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
