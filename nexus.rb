class NexusProxy < Sinatra::Base
  %w(sinatra httpi json yaml shotgun).each{|lib| require lib }

  HTTPI.log       = false     # disable logging

  $config = YAML.load(File.open('nexus_config.yml'))

  get "/snapshots/:group/:artifact" do
    request_url = {
      'group'      =>  params[:group],
      'artifact'   =>  File.basename( params[:artifact], ".*" ),
      'extension'  =>  params[:artifact].split(".")[-1],
      'version'    =>  params[:version] || "LATEST",
      'repository' =>  "snapshots"
    }

    is_valid_file_extension?(request_url['extension'])
    artifact = search_nexus(request_url)

    head = get_headers(artifact)

    headers 'Content-Type'    =>  head['Content-Type']
    headers 'Content-Length'  =>  head['Content-Length']
    headers 'Last-Modified'   =>  head['Last-Modified']
    headers 'Content-Disposition' => "attachment;filename=#{params[:artifact].split("/")[-1]}"


    stream do |out|
      request = HTTPI::Request.new(artifact)
      request.auth.basic($config['username'],$config['password'])
      request.on_body { |data| out << data; data.length }
      HTTPI.get(request)
    end
  end

  private

  def is_valid_file_extension?(file)
    unless %w{rpm tgz tar.gz zip sar war jar}.include?(file)
      status 500
      body "Unknown file extension"
    end
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
      status 404
      body "File not found"
    end

  end
end
