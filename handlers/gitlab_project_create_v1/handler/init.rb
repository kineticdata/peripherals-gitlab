# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class GitlabProjectCreateV1

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

    # Parameter validation
    if !['public','internal','private',''].include?(@parameters['visibility'])
      raise "'#{@parameters['visibility']}' is not a valid input for the visibility field. Must be 'public','internal',or 'private'"
    end

    if @parameters['name'].empty? && @parameters['path'].empty?
      raise "At least one of 'name' or 'path' must be provided in the inputs"
    end
  end

  def execute
    resource = RestClient::Resource.new("#{@info_values['gitlab_location']}/api/v4", {:headers => {
      "PRIVATE-TOKEN" => @info_values["private_token"],
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }})

    # Get the id for the group if it was provided
    if !@parameters['group'].empty?
      puts "Attempting to retrieve the id for the group/namespace '#{@parameters['group']}'" if @enable_debug_logging
      response = resource["namespaces?search=#{@parameters['group']}"].get
      json = JSON.parse(response)
      # Do a sanity check and make sure that the id pulled back is going to be the group/namespace
      # that completely equals the whole path and not just part of the path
      group_id = nil
      json.each do |namespace|
        if namespace['path'] == @parameters['group']
          group_id = namespace['id']
        end
      end
      puts "Id '#{group_id}' found for the Group '#{@parameters['group']}'" if @enable_debug_logging
    end

    puts "Building the POST object" if @enable_debug_logging
    post_object = {}
    post_object["name"]           = @parameters['name']           if !@parameters['name'].empty?
    post_object["path"]           = @parameters['path']           if !@parameters['path'].empty?
    post_object["description"]    = @parameters['description']
    post_object["default_branch"] = @parameters['default_branch'] if !@parameters['default_branch'].empty?
    post_object["visibility"]     = @parameters['visibility']     if !@parameters['visibility'].empty?
    post_object["namespace_id"]   = group_id                      if !@parameters['group'].empty?

    puts "Sending the POST object to Gitlab to create project" if @enable_debug_logging
    begin
      response = resource["projects"].post(post_object.to_json)
    rescue RestClient::Exception => e
      puts "#{e.http_code}: #{e.http_body}"
      raise "#{e.http_code} #{RestClient::STATUSES[e.http_code]}: #{e.http_body}"
    end
    puts "Project successfully created. Attempting to parse id from results." if @enable_debug_logging

    project_id = JSON.parse(response)["id"]
    return <<-RESULTS
    <results>
      <result name="Project Id">#{project_id}</result>
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