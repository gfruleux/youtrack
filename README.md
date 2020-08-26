# Script to add new Spent Time into YouTrack 

### PreRequisites
You need to have the following commands installed:
* [CURL](https://curl.haxx.se/) Transfert Data 
* [JQ](https://stedolan.github.io/jq/) a JSON Processor

### Configuration
1. You need a YouTrack API Token ([how to get one](https://www.jetbrains.com/help/youtrack/standalone/Manage-Permanent-Token.html#obtain-permanent-token))
2. Setup an environment variable called `YT_API_TOKEN` with your YouTrack API Token _(ex: `perm:dAIdindN=.9AnQ`)_
3. Setup an environment variable called `YT_API_URL` pointing to your YouTrack API URL _(ex: `https://you.track.com/youtrack/api`)_ 
4. Setup an environment variable called `YT_API_USERNAME`, this is your YouTrack user login name

### Usage
The script can be used with a formatted file, or by feeding the command line.

Whichever method you chose, the format the __must__ be respected is the following:

* Line: ``<Ticket Name> <Time Spent> <Date> <Text>``
* Time: `:h:m`
* Date: `yyyy-mm-dd`
* Comments: Start line with `#`


### Examples
* Command Line
``./youtrack.sh TKT-5 5h30m 2020-07-15 Spent time working on the Script``

Note: the order is important, as everything after the 3rd parameter will be treated as the `Text`.
This is also the reason why the double quotes aren't mandatory.

* File feed
``./youtrack.sh /path/to/time/tracking``
