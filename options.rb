require 'optparse'
require 'ostruct'
require 'pp'

module Options
	$options = OpenStruct.new
	
	# Set defaults
	$options.usename = ""
	$options.password = ""
	$options.vault_client = "C:\\Program Files\\SourceGear\\Vault Client\\vault.exe"
	$options.logfile = "vault2git.log"
	
	OptionParser.new do |opts|
	  opts.banner = "Usage: vault2git.rb [options] $/source/folder dest/folder"
	  opts.separator ""
	  opts.separator "Specific options:"
	  
	  opts.on('-s', '--host host', 'The repository hostname/ip address') {|val| $options.host = val}
	  opts.on('-r', '--repo name', 'The repository name') {|val| $options.repository = val}
	  opts.on('-u', '--username [username]', 'The repository user') {|val| $options.username = val}
	  opts.on('-p', '--password [password]', 'The repository user\'s password') {|val| $options.password = val}
	  opts.on('--vault-client-path path-to-vault.exe', "Path to vault.exe, defaults to #{$options.vault_client}") {|val| $options.vault_client = val}
	  opts.on('--logfile filename', "File to log to (defaults to #{$options.logfile})") {|val| $options.logfile = val}

	  opts.on('-h', '--help', 'Display this help screen') do
		puts opts
		exit
	  end 
	  opts.parse!
	  if opts.default_argv.size != 2
		puts opts
		exit
	  end
	  $options.source, $options.dest = opts.default_argv
	end
end
