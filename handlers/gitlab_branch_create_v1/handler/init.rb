# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class GitlabBranchCreateV1

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
      "branch" => @parameters['branch'],
      "ref"    => @parameters['branch_source']
    }

    puts "Sending the POST object to Gitlab to create the branch '#{@parameters['branch']}'" if @enable_debug_logging
    # Build the project id based on the project group and project path
    project_id = @parameters['project_group'].empty? ? @parameters['project_path'] : "#{@parameters['project_group']}/#{@parameters['project_path']}"

    begin
      response = resource["projects/#{CGI.escape(project_id)}/repository/branches"].post(post_object.to_json)
    rescue RestClient::Exception => e
      puts "#{e.http_code}: #{e.http_body}"
      raise "#{e.http_code} #{RestClient::STATUSES[e.http_code]}: #{e.http_body}"
    end
    puts "Branch successfully created." if @enable_debug_logging

    return "<results/>"
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