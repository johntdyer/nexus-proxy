%w(sinatra bundler httpi json logger yaml shotgun).each{|lib| require lib }

Bundler.require

class ::Logger
  alias_method :write, :<<
end

root    = ::File.dirname(__FILE__)
logfile = ::File.join(root,'log','requests.log')
logger  = ::Logger.new(logfile,'weekly')

use Rack::CommonLogger, logger


enable :logging, :dump_errors
set :raise_errors, true

require ::File.join(root,'nexus')

run NexusProxy
