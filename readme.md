# Ruby Crawler

## Created by Evan McCullough

### Dependencies
* mongo
..* Datebase
* optparse
..* Command line option arguments
* net/http
..* Used to parse URLs and get HTML and HTTP code
* nokogiri
..* Used to parse HTML
* digest
..* Used to create hash of HTML to find duplicates

### Commands
* -s or --starturl -> Start URL (Including http(s)://)
* -i or --id -> Crawler ID
* -d or --debug -> Debug (enter 1 for yes, 0 for no)