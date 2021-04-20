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

### Note
* A `project` is compose of a **name**, and **id** and a **short name**
    * ex: Project named `Youtrack Globals` shorted to `YTG`, with id `0-1`
    
    
* An `issue name`, also called `id readable`, is a jointure of its project's **short name** and an ID
    * ex: First issue from project `Youtrack Globals` would be `YTG-1`

* Issue types must match their projects types. You can use the `-T <Project>` option to list the available types for a project.

### Usage
The script can be used with a formatted file, or by feeding the command line.

Whichever method you chose, the format the __must__ follow its respective guideline:

##### From Command Line
* Line: `<Issue Name> <Time Spent> <Date> [Type] [Text]`
    * **Issue Name**
        * Required
    * **Time Spent**
        * Required
        * Format: `:h:m`
    * **Date**
        * Required
        * Format: `yyyy-mm-dd`
    * **Type**
        * Optional
    * **Text** 
        * Optional

##### From a File
* Line: `#setdate <Date>` **To set the date of the following lines**
    * Date format: `yyyy-mm-dd`
    
    
* Line: `<Issue Name> <Time Spent> [Type] [Text]`
    * **Issue Name**
        * Required
    * **Time Spent**
        * Required
        * Format: `:h:m`
    * **Type**
        * Optional
    * **Text**
        * Optional

--------------------------------------------------

### Examples

To log spent time of ...
* 5 hours and 30 minutes
* the 01/01/2020
* on the issue YouTrack Globals `YTG-1`
    * (optional) with type `Daily Meeting`
    * (optional) with the comments `New script meeting !`

##### From Command Line
Bellow are some exemples varying the optional parameters 

| Desired work log | Command to run |
--- | ---
| Only the date and duration | `./youtrack.sh YTG-1 5h30m 2020-01-01` |
| With type | `./youtrack.sh YTG-1 5h30m 2020-01-01 "Daily Meeting"` |
| Without type but comments<br/>**Safe method** | `./youtrack.sh YTG-1 5h30m 2020-01-01 "" "New script meeting !"` |
| Without type but comments<br/>**Start of the comments might be interpreted as Type** | `./youtrack.sh YTG-1 5h30m 2020-01-01 "New script meeting !"` |
| With type and comments | `./youtrack.sh YTG-1 5h30m 2020-01-01 "Daily Meeting" "New script meeting !"` |


##### From File feed
* The command line to run for the file is pretty straight forward
`./youtrack.sh /path/to/file`
* The `#setdate <Date>` line is not impact by the optional parameters

The file would be composed of date setters follow by work-load for that date
`#setdate 2020-01-01` with one of the line bellow

| Desired work log | File line format |
--- | ---
| Only the date and duration | `YTG-1 5h30m` |
| With type | `YTG-1 5h30m "Daily Meeting"` |
| Without type but comments<br>**Safe method** | `YTG-1 5h30m "" "New script meeting !"` |
| Without type but comments<br>**Start of the comments might be interpreted as Type** | `YTG-1 5h30m "New script meeting !"` |
| With type and comments | `YTG-1 5h30m "Daily Meeting" "New script meeting !"` |
