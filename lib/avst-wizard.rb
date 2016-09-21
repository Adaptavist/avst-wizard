# Copyright 2015 Adaptavist.com Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'net/http'
require 'net/https'
require 'uri'
require 'rubygems'
require 'nokogiri'
require 'colorize'

module AvstWizard
    class AvstWizard

        attr_writer :atl_token

        def initialize(url, required_config = {}, url_required_part=nil, host_url)
            @url = url
            @cookie = ""
            @current_url = ""
            @atl_token = ""
            @required_config = required_config
            @url_required_part = url_required_part
            @host_url = host_url
        end

        # Does GET requests to url, follows redirects, stores cookies and xsrf.token if present
        def get_stage_and_fetch_cookie(request_url = @url , limit = 10)
            # You should choose better exception.
            raise ArgumentError, 'HTTP redirect too deep' if limit <= 0
            puts "Trying to GET #{request_url}".yellow
            url = URI.parse(request_url)
            req = Net::HTTP::Get.new(url.request_uri)
            if @cookie != ""
                req['Cookie'] = get_cookie
            end
            if @host_url 
                req.add_field("Host", @host_url)
            end
            use_ssl = false
            if url.instance_of? URI::HTTPS
                use_ssl = true
            end
            begin
                response = Net::HTTP.start(url.host, url.port, use_ssl: use_ssl, verify_mode: OpenSSL::SSL::VERIFY_NONE) { |http| http.request(req) }
                if response['set-cookie']
                    @cookie = response['set-cookie'].split('; ')[0]
                    response['set-cookie'].split(';').each do |part|
                        if ((part and part.include? "atl.xsrf.token") and (part.match(/atl.xsrf.token=(.*)/)))
                            # parse only the token
                            @atl_token = part.match(/atl.xsrf.token=(.*)/).captures[0]
                            break
                        end
                    end
                    puts "Found new cookie #{get_cookie}".yellow
                end
                if response['location']
                    redirection_url = compose_redirection_url(response['location'])
                    puts "Redirected to: #{redirection_url}".yellow
                else
                    @current_url = url.request_uri
                    puts "Ended in: #{@current_url}".yellow
                end
                case response
                when Net::HTTPSuccess     then response.code.to_i
                when Net::HTTPRedirection then get_stage_and_fetch_cookie(redirection_url, limit - 1)
                else
                    puts response.body
                    puts response.code.to_s
                    response.code.to_i
                end
            rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Errno::ECONNREFUSED,
                    Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
                @current_url = request_url
                404
            end
        end

        def compose_redirection_url(location)
            
            # in case we do tomcat and the redirection returns http*://host_url/path 
            if @host_url and location.include? @host_url and location.start_with? "http"
                begin
                    uri = URI::parse(location)
                    location = uri.path
                rescue Exception => e
                    puts "Can not parse URI from #{location}"
                end
            end
            # in case response['location'] is not full url we need to compose it
            # if it does contain base_url we assume it is ok
            if location.include? @url
                location    
            # in case redirection contains the startup string, the system has not started yet
            elsif location.include? "startup.jsp?returnTo="
                puts "System starting up staying on #{@url}"
                sleep(10)
                @url
            else
                # in Jira 7.1.7 location is databaseSetup.jspa not secure/databaseSetup.jspa
                if @url_required_part and !location.include? "/#{@url_required_part}/"
                    "#{@url}/#{@url_required_part}/#{location}"
                else
                    # if required url part is present prepend url
                    # TODO: better check with regexp
                    "#{@url}#{location}"
                end
            end 
            
        end

        # add atl_token to cookie in case it is present
        def get_cookie
            resp = @cookie
            if @atl_token != ""
                resp = resp + "; atl.xsrf.token=#{@atl_token}"
            end
            puts "Using cookie: #{resp}".yellow
            resp
        end
        
        # get rid of params and other trash
        def get_current_url
            @current_url.split(";")[0].split("?")[0]
        end

        #  get the value from the page's element
        # 
        # element_identifier = "name=serverId"
        # attribute = "value"
        # will return value of attribute "value" from element with name "name=serverId"
        def parse_value(element_identifier, attribute, url)
            puts "Fetching #{url}".yellow
            url = URI.parse(url)
            req = Net::HTTP::Get.new(url.request_uri)
            req['Cookie'] = get_cookie
            use_ssl = false
            if url.instance_of? URI::HTTPS
                use_ssl = true
            end
            if @host_url 
                req.add_field("Host", @host_url)
            end
            
            counter = 0
            response = nil
            while (response == nil and counter < 20)
                begin
                    response = Net::HTTP.start(url.host, url.port, use_ssl: use_ssl, verify_mode: OpenSSL::SSL::VERIFY_NONE) { |http| http.request(req) }
                rescue Exception => e
                    # in case we have to wait for response so it wont timeout
                    puts "Exception thrown while trying to parse value: #{e.inspect} \n counter #{counter}/20".yellow
                    counter+=1
                end
            end
            if response.code.to_i != 200
                puts response.inspect.red
                puts response.body.inspect.red
                raise "There is a problem performing a GET on #{url}"
            end
            

            nok = Nokogiri::HTML.parse(response.body)
            res = nok.css("[#{element_identifier}]")
            if res.any?
                res.first.attribute("#{attribute}")
            else
                nil
            end
        end

        #  parses page and determins if the element is present, else returns nil
        #  Example: to_fetch = "name=serverId"
        def values_present?(to_fetch, url)
            puts "Checking presence of #{to_fetch} in #{url}".yellow
            parsed = parse_value(to_fetch, to_fetch.split('=')[0], url)
            puts "With result #{parsed!=nil}".yellow
            parsed != nil
        end

        # Validates that params are set to non empty value
        def validate_params(params, url)
            missing = []
            params.keys.each do |p|
                if @required_config[get_current_url] and @required_config[get_current_url].keys.include? p
                    if params[p] == ""
                        missing << @required_config[get_current_url][p]
                    end
                end
            end
            if missing.any?
                raise "Parameters #{missing.inspect} must be set to non empty value while posting to #{url}. Please provide."
            end
        end

        # form params to submit form to next checkpoint, will follow redirects after POST
        # wait_for_next_state - specifies number of retries, while waiting for next stage after post
        def post_form(params, url, wait_for_next_state=nil)
            validate_params(params, url)
            uri = URI.parse(url)
            req = Net::HTTP::Post.new(uri.request_uri)
            if @atl_token != ""
                params["atl_token"] = @atl_token
            end
            req.set_form_data(params)
            req['Cookie'] = get_cookie
            use_ssl = false
            if uri.instance_of? URI::HTTPS
                use_ssl = true
            end
            if @host_url 
                req.add_field("Host", @host_url)
            end
            Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl, verify_mode: OpenSSL::SSL::VERIFY_NONE, :read_timeout => 1000) do |http|
                response = http.request(req)
                puts "Response: #{response.inspect}".yellow
                puts "Location: #{response['location'].to_s}".yellow
                puts "Current : #{@url}#{@current_url}".yellow
                # puts "BODY: #{response.body}"
                redirected = true
                if response['location'] and !"#{@url}/#{@current_url}".include? response['location']
                    redirection_url = compose_redirection_url(response['location'])
                    @current_url = URI.parse(redirection_url).request_uri
                else
                    puts "Was not redirected, staying on page...".yellow
                    redirected = false
                end
                puts "Redirected to: #{@current_url.to_s}".yellow
                # future REST requests might use different response codes
                # For example a 201 might be returned where there is no content, but still a success
                # In case 200 is here there may be an error in the form, maybe add some checking
                if response.code.to_i != 302 and response.code.to_i != 200
                    puts response.inspect.red
                    puts response.body.inspect.red
                    raise "There is a problem while calling #{url} with params #{params}"
                end
                # follow redirects, if redirected
                if redirected and redirected == true
                    puts "Doing the redirection... #{redirected}".yellow
                    get_stage_and_fetch_cookie("#{@url}#{@current_url}")
                else
                    # in case the app is waiting for an event
                    if wait_for_next_state != nil
                        if wait_for_next_state.is_a? Integer
                            actual_url = @current_url
                            while wait_for_next_state > 0 and @current_url == actual_url
                                puts "Sleeping for 5, #{wait_for_next_state}".yellow
                                sleep(5)
                                # this will change current_url in case of redirection
                                get_stage_and_fetch_cookie("#{@url}")
                                wait_for_next_state = wait_for_next_state-1
                                if wait_for_next_state < 0
                                    abort "Waited too long, check the config..."
                                end
                            end
                        end
                    end
                end
                puts "Done posting #{url}".yellow
            end
        end

    end
end
