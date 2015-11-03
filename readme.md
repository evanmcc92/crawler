# Ruby Crawler

## Created by Evan McCullough

### Dependencies
* gem mongo
  * Datebase
* gem optparse
  * Command line option arguments
* gem net/http
  * Used to parse URLs and get HTML and HTTP code
* gem nokogiri
  * Used to parse HTML
* gem digest
  * Used to create hash of HTML to find duplicates
* yml crawler config
  * mongo database information

### Commands
> -s or -i is required

* -s or --starturl -> Start URL (Including http(s)://)
* -i or --id -> Crawler ID
* -d or --debug -> Debug (enter 1 for yes, 0 for no)