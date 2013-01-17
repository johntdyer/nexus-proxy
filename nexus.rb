class NexusProxy < Sinatra::Base
  %w(sinatra httpi json yaml shotgun).each{|lib| require lib }

  HTTPI.log = false

  $config = YAML.load(File.open('nexus_config.yml'))

  get "/snapshots/:group/:artifact" do

    file = parse_and_validated_request( params[:artifact] )

    request_url = {
      'group'      =>  params[:group],
      'artifact'   =>  file[:base_name],
      'extension'  =>  file[:extension],
      'version'    =>  (params[:version] || "LATEST"),
      'repository' =>  'snapshots'
    }

    artifact = search_nexus(request_url)

    head = get_headers(artifact)

    headers 'Content-Type'        =>  head['Content-Type']
    headers 'Content-Length'      =>  head['Content-Length']
    headers 'Last-Modified'       =>  head['Last-Modified']
    headers 'Content-Disposition' =>  "attachment;filename=#{params[:artifact].split("/")[-1]}"

    stream do |out|
      request = HTTPI::Request.new(artifact)
      request.auth.basic($config['username'],$config['password'])
      request.on_body { |data| out << data; data.length }
      HTTPI.get(request)
    end
  end

  private

  def parse_and_validated_request(file)
    result = {}
    if file.include?("tar.gz")
      result = {
        :base_name => file.gsub(".tar.gz",""),
        :extension => "tar.gz"
      }
    elsif %w{rpm tgz gz zip sar war jar}.any?{|ext| file.include? ext}
      result = {
        :base_name => File.basename( file, ".*" ),
        :extension => file.split(".")[-1]
      }
    else
      throw(:halt, [500, "Unrecognized file extension\n"])
    end
    return result
  end

  def get_headers(url)
    request = HTTPI::Request.new(url)
    HTTPI.log       = false     # disable logging
    request.auth.basic($config['username'],$config['password'])
    return HTTPI.head(request).headers
  end

  def search_nexus(params)
    url = "#{$config['server']}/service/local/artifact/maven/redirect?r=#{params['repository']}&g=#{params['group']}&a=#{params['artifact']}&v=#{params['version']}&e=#{params['extension']}"
    request = HTTPI::Request.new(url)
    request.auth.basic($config['username'],$config['password'])
    response =  HTTPI.head(request)
    if response.code.to_s =~ /30/
      return response.headers["location"]
    else
      throw(:halt, [404, "File not found\n"])
    end

  end
end
