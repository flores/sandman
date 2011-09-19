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
	
SITES = YAML.load_file 'config.yaml'

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
	unless @user =~ /jhhm|dlockhart|cflores|dprats|llakey|dyoder/
		redirect '/unauthenticated'
	end
	@status = Hash.new
	SITES.each do |property,value|
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
			uri=SITES[property]["uri"]
		else
			uri='/'
		end
		res = http.start.head2(uri)
		@status[property] = 'DOWN';
		if ( res.code == "200" )
			@status[property] = 'UP';
		else
			@status[property] = 'DOWN';
		end
	end
	haml :status
end

post '/flip/:property/down' do
	require 'net/ssh'
	e_id=SITES["#{params[:property]}"]["environment_id"]
	if (e_id)
		command="cd distopia; ruby -e \"require 'distopia'; Environment[#{e_id}].suspend(:prompt => false, :skip_mysql_servers => false)\""
		@message = "we are now stopping #{params[:property]}"
		Thread.new {
			Net::SSH.start( "distopia.writeonglass.com", "root") do|ssh|
	 			ssh.exec(command)
			end
		}
	else 	
		message = "I do not know how to start or stop #{params[:property]}.  Please bother Carlo."
	end
	haml :flip
end

post '/flip/:property/up' do
	require 'net/ssh'
	e_id=SITES["#{params[:property]}"]["environment_id"]
	if (e_id)
		command="cd distopia; ruby -e \"require 'distopia'; Environment[#{e_id}].start\""
		@message = "we are now spinning #{params[:property]} up.  this will take several minutes."
		Thread.new {
			Net::SSH.start( "distopia.writeonglass.com", "root") do|ssh|
 				ssh.exec(command)
			end
		}
	else 	
		message = "I do not know how to start or stop #{params[:property]}.  Please bother Carlo."
	end
	haml :flip
end

get '/flip/:property/up' do
	property = params[:property]
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
