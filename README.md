# Script to add new Spent Time into YouTrack 

### PreRequisites
You need to have the following commands installed:
* [CURL](https://curl.haxx.se/) Transfert Data 
* [JQ](https://stedolan.github.io/jq/) a JSON Processor

--------------------------------------------------

### Configuration
1. You need a YouTrack API Token ([how to get one](https://www.jetbrains.com/help/youtrack/standalone/Manage-Permanent-Token.html#obtain-permanent-token))
2. Setup an environment variable called `YT_API_TOKEN` with your YouTrack API Token _(ex: `perm:dAIdindN=.9AnQ`)_
3. Setup an environment variable called `YT_API_URL` pointing to your YouTrack API URL _(ex: `https://you.track.com/youtrack/api`)_ 
4. Setup an environment variable called `YT_API_USERNAME`, this is your YouTrack user login name

--------------------------------------------------

### Usage
The script can be used with a formatted file, or by feeding the command line.

Whichever method you chose, the format the __must__ follow its respective guideline:

##### From Command Line
* Line: `<Ticket Name> <Time Spent> <Date> <Text>` To log work
    * Time Spent format: `:h:m`
    * Date format: `yyyy-mm-dd`
    * Text format: _Markdown supported_

##### From a File
* Line: `<Ticket Name> <Time Spent> <Text>` To log work
    * Time Spent format: `:h:m`
    * Text format: _Markdown supported_
* Line: `#setdate <Date>` **To set the date of the following lines**
    * Date format: `yyyy-mm-dd`

--------------------------------------------------

### Examples

To log spent time of ...
* 5 hours and 30 minutes
* the 01/01/2020
* on the issue TKT-1
* with the comments `Spent time working on the Script`

##### From Command Line
You would need to run this command: 

`./youtrack.sh TKT-1 5h30m 2020-01-01 Spent time working on the Script`

##### From File feed
The file should be built as bellow:
```
#setdate 2020-01-01
TKT-1 5h30m Spent time working on the Script
```

You would need to run this command 

`./youtrack.sh /path/to/time/tracking/file`
