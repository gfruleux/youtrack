#!/bin/bash

######################################## ERR Exit codes ########################################
ERR_MISSING_API_TOKEN=1
ERR_MISSING_API_URL=2
ERR_MISSING_API_USERNAME=3
ERR_MISSING_JQ=4
ERR_MISSING_CURL=5

ERR_MISSING_PAYLOAD=10
######################################## ENVIRONMENT ###########################################
#YT_API_TOKEN=
#YT_API_URL=
#YT_API_USERNAME=

######################################## GLOBALS ###############################################
AUTH="Authorization: Bearer $YT_API_TOKEN"
USER_LOGIN="$YT_API_USERNAME"
USER_ID=""

API_URL="$YT_API_URL"
API_ISSUES="$API_URL/issues"
API_ISSUES_QUERY="$API_ISSUES?fields=id,idReadable,project(id,name),summary&query="
API_WORK_ITEMS="$API_URL/workItems"
API_WORK_ITEM_FIELDS="fields=id,text,author(id,name),creator(id,name),type(id,name),created,updated,duration(id,minutes,presentation),date,issue"
API_PROJECT_URL="$API_URL/admin/projects"
API_PROJECT_QUERY="?fields=id,name,shortName&query="
API_PROJECT_TIME_TYPES="/timeTrackingSettings/workItemTypes?fields=id,name"
API_USERS="$API_URL/users"
API_USERS_QUERY="$API_USERS?fields=id,login&query="

ISSUE_ID=
ISSUE_ID_READABLE=
ISSUE_URL=

WORK_ITEM_DATE=
WORK_ITEM_DURATION=
WORK_ITEM_TIMESTAMP=
WORK_ITEM_TEXT=
WORK_ITEM_TYPE=
WORK_ITEM_URL=

IFS=" "

declare -a POSTED

######################################## WorkItem Types
#################### As the WorkItem Types aren't fixed, you must define your own rules
declare -A WORK_ITEM_TYPES=( ["Key"]="WorkItemTypeID")

function apply_type() {
  unset WORK_ITEM_TYPE # null
}

######################################## FUNCTIONS #############################################
#################### [POST] Create a new WorkItem
function work_item_post() {
  if [ -z "$1" ]; then
    log "work_item_post should receive the payload."
    exit $ERR_MISSING_PAYLOAD
  fi
  log "POST WorkItem . . ."

  local tracking_query work_item_id

  tracking_query="$ISSUE_URL/timeTracking/workItems?$API_WORK_ITEM_FIELDS"
  work_item_id=$(curl -X POST -H "Content-Type: application/json" -H "$AUTH" "$tracking_query" -d "$1" -s | jq -r ".id")
  POSTED+=("$work_item_id")
  WORK_ITEM_URL="$ISSUE_URL/timeTracking/workItems/$work_item_id"

  log "WorkItem created with id $work_item_id $WORK_ITEM_URL"
}

#################### SpentTime from file parsing
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
#################### SpentTime from command line arguments parsing
function work_from_cmd_line() {
  line_to_issue "$*"
  execute_work
}

#################### Execute the prepared work
function execute_work() {
  work_item_post "$(work_item_payload)"
}

#################### Initialize Issue vars by parsing arguments
function line_to_issue() {
  local line_split delete_array text_array duration

  log "Parsing $1"

  read -ra line_split <<<"$1"

  ISSUE_ID_READABLE=${line_split[0]}
  ISSUE_ID=$(search_issue "$ISSUE_ID_READABLE" | jq -c -r ".[0].id")
  ISSUE_URL="$API_ISSUES/$ISSUE_ID"

  duration=${line_split[1]}
  WORK_ITEM_DURATION=$(get_duration "$duration")
  WORK_ITEM_DATE=${line_split[2]}
  WORK_ITEM_TIMESTAMP=$(($(date -d "$WORK_ITEM_DATE" "+%s") * 1000))

  # Keep text by removing the previous data
  delete_array=("$ISSUE_ID_READABLE" "$duration" "$WORK_ITEM_DATE")
  text_array=("${line_split[@]}")
  for del in ${delete_array[*]}; do
    text_array=("${text_array[@]/$del/}")
  done
  WORK_ITEM_TEXT=$(echo "${text_array[*]}" | sed -e 's/^[[:space:]]*//') # join array and trim

  apply_type

  log "Read entry $ISSUE_ID_READABLE, spent $duration (${WORK_ITEM_DURATION}m) on the $WORK_ITEM_DATE ($WORK_ITEM_TIMESTAMP) || Matched real ID $ISSUE_ID"
}

#################### Search for an Issue and print its information
function search_issue() {
  local query
  query="${API_ISSUES_QUERY}$1"
  curl -X GET -H "$AUTH" "$query" -s
}
#################### Search for a Project and print its information
function search_project() {
  local query
  query="${API_PROJECT_URL}/${API_PROJECT_QUERY}$1"
  curl -X GET -H "$AUTH" "$query" -s
}
#################### Search for a Project and print its WorkItem Types
function search_project_types() {
  local query
  query="${API_PROJECT_URL}/$1${API_PROJECT_TIME_TYPES}"
  curl -X GET -H "$AUTH" "$query" -s
}

#################### Retrieve the USER_ID linked to the Username defined in YT_API_USERNAME
function fill_user() {
  local query
  query="$API_USERS_QUERY$USER_LOGIN"
  USER_ID=$(curl -X GET -H "$AUTH" "$query" -s | jq -r ".[0].id")
}

########## Transform :h:m duration into minutes
function get_duration() {
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
  echo $total
}

########## [Payload] WorkItem
function work_item_payload() {
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
  echo "{
    $basic
}"
}

########## Create an IO to use stdout with functions
exec 3>&1
function log() {
  printf "%s\n" "$1" 1>&3
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

######################################## MAIN ##################################################
function main() {
  while getopts ":I:P:T:" opt; do
    case "${opt}" in
    I)
      fill_user
      search_issue "$OPTARG"
      exit 0
      log
      ;;
    P)
      fill_user
      search_project "$OPTARG"
      log
      exit 0
      ;;
    T)
      fill_user
      search_project_types "$OPTARG"
      log
      exit 0
      ;;
    *)
      usage
      ;;
    esac
  done

  fill_user

  if [[ -f "$1" ]]; then
    work_from_file "$1"
  else
    work_from_cmd_line "$@"
  fi

  log "${POSTED[*]}"
}

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

main "$@"

###################################### Old / Unused
########## [Payload] Only Date
function _payload_date() {
  echo "{\"date\": $WORK_ITEM_TIMESTAMP}"
}
########## Print a WorkItem
function _print_work_item() {
  local query
  query="$API_WORK_ITEMS/$1?$API_WORK_ITEM_FIELDS"
  log "$(curl -X GET -H "$AUTH" "$query" -s)"
}
#################### [DELETE] Delete the WorkItem using $WORK_ITEM_URL
function _work_item_delete() {
  log "DELETE WorkItem at $WORK_ITEM_URL"
  curl -X DELETE -H "$AUTH" "$WORK_ITEM_URL" -s
}

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
