require 'mongo' #database
Mongo::Logger.logger.level = ::Logger::FATAL # only ebug on fatal error
require 'optparse' #command line arguments
require 'net/http' #get html
require 'nokogiri' #scrape html for things
require 'digest' # hashing

PROGRAM_NAME = "Crawler"
PROGRAM_AUTHOR = "Evan McCullough"
PROGRAM_VERSION = "0.1.0.0"


########################
## start of functions ##
########################

#scrapes url for crawl results and queue
def scrapePage(url, domain, projectid, db)
	# set results array
	puts "\nPage Start: #{url} - #{Time.now.getutc}\n"
	@pageresult = {
		:_projectid => projectid,
		:title => "",
		:h1 => "",
		:page_hash => "",
		:http_code => ""
	}

	if URI(url).host == domain
		html = fetch_html(url, 1)
		@pageresult[:http_code] = html[:http_code]

		#page hash
		page_hash = Digest::MD5.new
		page_hash.update html[:body]
		@pageresult[:page_hash] = page_hash.hexdigest


		#parse page
		parser = Nokogiri::HTML(html[:body])
		@pageresult[:title] = parser.css("title")[0].text if parser.css("title")[0].nil? == false
		@pageresult[:h1] = parser.css("h1")[0].text if parser.css("h1")[0].nil? == false

		@links = {}
		for link in parser.css("a")
			href = link['href']
			if URI(href).host.nil? == false
				if domain == URI(href).host
					@links[href] = 1 #onsite
				else
					@links[href] = 0 #offsite
				end
			end
		end
		if @links.count > 0
			puts "\t#{@links.count} links to found- #{Time.now.getutc}\n"
			insertQueueLinks(url, @links, projectid, db)
		end
		
	end

	@pageresult[:created_at] = Time.now.getutc
	puts "Page End: #{url} - #{Time.now.getutc}\n"
	return @pageresult
end
# adds links to queue
def insertQueueLinks(page_found, links, projectid, db)
	linksarray  = []
	queuearray  = []
	counter = 0
	links.each do |key, value|
		# if db[:queue].count({ :link => key, _projectid: projectid }) == 0
			linksarray << {
				_projectid: projectid,
				onsite: value,
				link: key,
				page_found: page_found.to_s,
				created_at: Time.now.getutc,
				updated_at: Time.now.getutc,
			}
			queuearray << {
				_projectid: projectid,
				onsite: value,
				link: key,
				created_at: Time.now.getutc,
				# updated_at: Time.now.getutc,
				crawled: 0,
			}
			counter += 1
		# end
	end

	begin
		insertlinks = db[:links].insert_many(linksarray)
		insertqueue = db[:queue].insert_many(queuearray,{ordered:false})
	rescue => ex
		p ex
	end
	puts "\t#{links.count} links to found - #{Time.now.getutc}\n"

end
# get data from url
def fetch_html(uri_str, limit = 10)
	# You should choose a better exception.
	raise ArgumentError, 'too many HTTP redirects' if limit == 0

	response = Net::HTTP.get(URI(uri_str))

	case response
	when Net::HTTPSuccess then
		@return = {
			:body=>response.body,
			:http_code=>response.code,
		}
		return @return
	when Net::HTTPRedirection then
		location = response['location']
		warn "redirected to #{location}"
		fetch(location, limit - 1)
	else
		response.value
	end
end
# gets the next auto increment from database
def getNextSequence(table,db)
	if db[table].count == 0
		return 1
	else
		db[table].find().sort(_id: -1).limit(1).each do |document|
			return document[:_id]+1
		end
	end
end

######################
## end of functions ##
######################


######################
## start of program ##
######################

options = {}
options[:debug] = 0
optparse = OptionParser.new do |opts|
	opts.banner = "Usage: crawler.rb [options]"

	opts.on('-s', '--starturl NAME', 'Start URL (Including http(s)://)') { |v| options[:start_url] = v }
	opts.on('-i', '--id ID', 'Crawler ID') { |v| options[:id] = v }
	opts.on('-d', '--debug DEBUG', 'Debug (enter 1 for yes, 0 for no') { |v| options[:debug] = v }
	opts.on("-v", "--version", "Show version information about this program and quit.") do
		puts "#{PROGRAM_NAME}\nv#{PROGRAM_VERSION}\nby: #{PROGRAM_AUTHOR}"
		exit
	end
end.parse!

options[:debug] = options[:debug].to_i
if (defined?(options[:start_url])).nil? || (defined?(options[:id])).nil?
	abort("**Error: A start url or project id was not supplied\n\n")
else
	db = Mongo::Client.new([ 'ds033153.mongolab.com:33153' ], :database => 'crawl', :user => 'crawler', :password => 'evan6992')
	projectdb = db[:project]
	resultsdb = db[:results]

	if options[:id].nil? == false
		# if id is defined
		projectid = options[:id].to_i
		puts "Selecting project with id of '#{projectid}'\n" if options[:debug] == 1
		abort("**Error: project '#{projectid}' does not exist") if projectdb.count(_id: projectid) == 0
	elsif options[:start_url].nil? == false
		# if start_url is defined
		puts "Creating project with start url '#{options[:start_url]}'\n" if options[:debug] == 1
		domain = URI(options[:start_url]).host
		projectid = getNextSequence("project", db)
		insert = projectdb.insert_one({
			_id: projectid,
			_version: PROGRAM_VERSION,
			start_url: options[:start_url],
			domain: domain,
		})


		db[:queue].insert_one({
			_projectid: projectid,
			onsite: 1,
			link: options[:start_url],
			created_at: Time.now.getutc,
			# updated_at: Time.now.getutc,
			crawled: 0,
		})
		@pageresults = scrapePage(options[:start_url], domain, projectid, db)
		insert = resultsdb.insert_one(@pageresult)
		db[:queue].update_one({ :link => options[:start_url], _projectid: projectid }, { :$inc => { :crawled => 1 } }, { :upsert => true })
	end


	# loop through queue until there is nothing left
	counter = db[:queue].distinct(:link, {_projectid: projectid, onsite: 1, crawled: 0}).count
	while counter > 0
		puts "#{counter} Links in queue - #{Time.now}\n"
		@links = db[:queue].distinct(:link, {_projectid: projectid, onsite: 1, crawled: 0}, {:limit => 100})
		@links.each do |document|
			@pageresults = scrapePage(document, domain, projectid, db)
			insert = resultsdb.insert_one(@pageresult)
			db[:queue].update_one({ :link => options[:start_url], _projectid: projectid }, { :$inc => { :crawled => 1 } }, { :upsert => true })
		end
		counter = db[:queue].distinct(:link, {_projectid: projectid, onsite: 1, crawled: 0}).count
	end

end


abort("*****COMPLETE*****")
####################
## end of program ##
####################



