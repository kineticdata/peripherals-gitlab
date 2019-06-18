# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class GitlabWebhookCreateV1

  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Retrieve all of the handler info values and store them in a hash variable named @info_values.
    @info_values = {}
    REXML::XPath.each(@input_document, "/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end

    # Retrieve all of the handler parameters and store them in a hash variable named @parameters.
    @parameters = {}
    REXML::XPath.each(@input_document, "/handler/parameters/parameter") do |item|
      @parameters[item.attributes["name"]] = item.text.to_s.strip
    end

    @enable_debug_logging = @info_values['enable_debug_logging'].downcase == 'yes' ||
                            @info_values['enable_debug_logging'].downcase == 'true'
    puts "Parameters: #{@parameters.inspect}" if @enable_debug_logging
  end

  def execute
    resource = RestClient::Resource.new("#{@info_values['gitlab_location']}/api/v4", {:headers => {
      "PRIVATE-TOKEN" => @info_values["private_token"],
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }})

    puts "Building the POST object" if @enable_debug_logging
    post_object = {
      "url" => @parameters['url'],
      "token" => @parameters['secret_token'],
      "enable_ssl_verification" => @parameters["enable_ssl"].downcase == "true"
    }
    trigger_events = @parameters['trigger_events'].split(",").map {|e| e.strip}
    trigger_events.each do |event|
      post_object["#{event}_events"] = true
    end
    puts "Built POST object: #{post_object.to_json}" if @enable_debug_logging

    puts "Sending the POST object to Gitlab to create a webhook to '#{@parameters['url']}' with the following trigger events: #{trigger_events.join(", ")}" if @enable_debug_logging
    # Build the project id based on the project group and project path
    project_id = @parameters['project_group'].empty? ? @parameters['project_path'] : "#{@parameters['project_group']}/#{@parameters['project_path']}"
    begin
      response = resource["projects/#{CGI.escape(project_id)}/hooks"].post(post_object.to_json)
    rescue RestClient::Exception => e
      puts "#{e.http_code}: #{e.http_body}"
      raise "#{e.http_code} #{RestClient::STATUSES[e.http_code]}: #{e.http_body}"
    end
    id = JSON.parse(response)["id"]
    puts "Webhook successfully created with id '#{id}'." if @enable_debug_logging

    return <<-RESULTS
    <results>
      <result name="Webhook Id">#{escape(id)}</result>
    </results>
    RESULTS
  end


  ##############################################################################
  # General handler utility functions
  ##############################################################################
  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
      # Globally replace characters based on the ESCAPE_CHARACTERS constant
      string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}
end