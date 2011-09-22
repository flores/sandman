#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'rack'
require 'haml'
require 'base64'
require 'yaml'
require 'net/http'
require 'net/https'

# If the user has authenticated via Kerberos 5 on the frontend server, 
# this header is coming over
def authenticate()
	user_env = @env["Authorization"] || @env["HTTP_AUTHORIZATION"]
        if user_env
                user = Base64.decode64(user_env[6,user_env.length-6])[/\w+/]
		return user
        else
        	return nil
	end
end

def check(property)
	fqdn = SITES[property]["site"]
	puts "#{fqdn} is the web property value"
	if ( SITES[property]["ssl"] )
		puts "this site is SSL"
		http = Net::HTTP.new(fqdn, 443)
		http.use_ssl = true
	else
		http = Net::HTTP.new(fqdn, 80)
	end
	http.read_timeout = 200
	if ( SITES[property]["uri"] )
		uri="/#{SITES[property]["uri"]}"
	else
		uri='/'
	end
	puts "uri is #{uri}"
	res = http.start.get(uri)
	puts "response is #{res.code}"
	if ( res.code =~ /^(2|3)/ )
		return 'UP'
	else
		return 'DOWN'
	end
end

def logallofit()
	File.open("variables.yaml", "w") do |file|
  		file.write VARIABLES.to_yaml
	end
end
	
	
SITES = YAML.load_file 'config.yaml'
VARIABLES = YAML.load_file 'variables.yaml'

set :environment, :production
set :bind, 'localhost'

get '/' do
	redirect '/status'
end

get '/unauthenticated' do
	haml :unauthenticated
end

get '/status' do
	@user=authenticate()
	unless @user =~ /jhhm|dlockhart|cflores|dprats|llakey|dyoder|jgonzalez|dhengeveld/
		redirect '/unauthenticated'
	end
	@status = Hash.new
	SITES.each do |property,value|
		@status[property] = check(property)
	end
	haml :status
end

post '/flip/:property/down' do
	property = params[:property]
	persist  = params["persist"]

	VARIABLES = YAML.load_file 'variables.yaml'
	
	VARIABLES[property]["last_activity"] = "down"
	VARIABLES[property]["last_activity_who"] = authenticate()
	VARIABLES[property]["last_activity_when"] = DateTime.now

	if ( persist )
		VARIABLES[property]["persist"] = "yes"
	else
		VARIABLES[property]["persist"] = "no"
	end

	logallofit()

	require 'net/ssh'
	e_id   = SITES["#{params[:property]}"]["environment_id"]
	shared = SITES["#{params[:property]}"]["shared"]

	# lets find out if the shared servers are up
	if ( shared )
		shared.each do |sharedproperty|
			if ( check(sharedproperty) == 'UP' )
				skipservers = 'true'
				break
			else
				skipservers = 'false'
			end
		end
	else
		skipservers = 'true'
	end

	if (e_id)
		command="cd distopia; ruby -e \"require 'distopia'; Environment[#{e_id}].suspend(:prompt => false, :skip_shared_servers => #{skipservers})\""
		@message = "we are now stopping #{params[:property]}"
		Thread.new {
			Net::SSH.start( "distopia.writeonglass.com", "root") do|ssh|
	 			ssh.exec(command)
			end
		}
	else 	
		@message = "I do not know how to start or stop #{params[:property]}.  Please bother Carlo."
	end
	haml :flip
end

post '/flip/:property/up' do

	property = params[:property]
	persist  = params["persist"]

	VARIABLES = YAML.load_file 'variables.yaml'
	VARIABLES[property]["last_activity"] = "up"
	VARIABLES[property]["last_activity_who"] = authenticate()
	VARIABLES[property]["last_activity_when"] = DateTime.now

	if ( persist )
		VARIABLES[property]["persist"] = "yes"
	else
		VARIABLES[property][persist] = "no"
	end

	logallofit()

	require 'net/ssh'
	
	e_id=SITES[property]["environment_id"]
	if (e_id)
		command="cd distopia; ruby -e \"require 'distopia'; Environment[#{e_id}].start\""
		@message = "we are now spinning #{params[:property]} up.  this will take several minutes."
		Thread.new {
			Net::SSH.start( "distopia.writeonglass.com", "root") do|ssh|
 				ssh.exec(command)
			end
		}
	else 	
		@message = "I do not know how to start or stop #{params[:property]}.  Please bother Carlo."
	end
	haml :flip
end

get '/flip/:property/up' do
	property = params[:property]
	persist  = params["persist"]
	
		
	fqdn = SITES[property]["site"]
	puts "#{fqdn} is the web property value"
	if ( SITES[property]["ssl"] )
		puts "this site is SSL"
		http = Net::HTTP.new(fqdn, 443)
		http.use_ssl = true
	else
		http = Net::HTTP.new(fqdn, 80)
	end
	if ( SITES[property]["uri"] )
		res = http.start.head2("/api")
	else
		res = http.start.head2("/")
	end
	if ( res.code == "200" )
		redirect '/status'
	else
		haml :flip
	end
end

get '/flip/:property/down' do
	property = params[:property]
	
	VARIABLES[property][last_activity] = "down"
	VARIABLES[property][last_activity_who] = authenticate()
	VARIABLES[property][last_activity_when] = DateTime.now

	if ( persist )
		VARIABLES[property][persist] = "yes"
	else
		VARIABLES[property][persist] = "no"
	end
	
	fqdn = SITES[property]["site"]
	puts "#{fqdn} is the web property value"
	if ( SITES[property]["ssl"] )
		puts "this site is SSL"
		http = Net::HTTP.new(fqdn, 443)
		http.use_ssl = true
	else
		http = Net::HTTP.new(fqdn, 80)
	end
	if ( SITES[property]["uri"] )
		res = http.start.head2("/api")
	else
		res = http.start.head2("/")
	end
	if ( res.code == "200" )
		haml :flip
	else
		redirect '/status'
	end
end

get '/sandman.css' do
	File.read(File.join('public', 'sandman.css'))
end

