require 'rubygems'
require 'bundler'
require 'nokogiri'
require 'optparse'
require 'fileutils'
require 'time'
require 'pp'

DEFAULT_VAULT_CLIENT_PATH = "C:\\Program Files\\SourceGear\\Vault Client\\vault.exe"
GITIGNORE = <<-EOF
_sgbak/
EOF

$options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: vault2git.rb [$options] $/source/folder dest/folder"
  
  $options[:username] = ''
  opts.on('-u', '--username [username]', 'The repository user') {|val| $options[:username] = val}
  
  $options[:password] = ''
  opts.on('-p', '--password [password]', 'The repository user\'s password') {|val| $options[:password] = val}
  
  $options[:host] = ''
  opts.on('-s', '--host host', 'The repository hostname/ip address') {|val| $options[:host] = val}
  
  $options[:repository] = ''
  opts.on('-r', '--repo name', 'The repository name') {|val| $options[:repository] = val}
  
  $options[:vault_client] = DEFAULT_VAULT_CLIENT_PATH
  opts.on('', '--vault-client-path path-to-vault.exe', "Path to vault.exe, defaults to #{DEFAULT_VAULT_CLIENT_PATH}") {|val| $options[:vault_client] = val}
  
  opts.on('-h', '--help', 'Display this help screen') do
	puts opts
	exit
  end
  
  opts.parse!
  if opts.default_argv.size != 2
    puts opts
	exit
  end
  $options[:source], $options[:dest] = opts.default_argv
end

#pp $options

def vault_command(command, options = [], args = [])
	parts = []
	parts << quote_param(:vault_client)
	parts << command
	%w(host username password repository).each{|param| parts << "-#{param} #{quote_param(param)}"}
	[*options].each{|param| parts << param}
	parts << quote_param(:source)
	[*args].each{|param| parts << quote_value(param)}
	cmd = parts.join(' ')
	#puts "Invoking vault: #{cmd}"
	xml = IO.popen(cmd).readlines
	doc = Nokogiri::XML(xml.join('')) do |config|
	  config.strict.noblanks
	end
	raise "Error processing command '#{command}': #{(doc % :error).text}" if (doc % :result)[:success] == 'no'
	doc
end

def quote_param(param)
  value = $options[param.to_sym]
  quote_value value
end

def quote_value(value)
  return '' unless value
  value.include?(' ') ? '"' + value + '"' : value
end

def git_command(command, *options)
	parts = %w(git)
	parts << command
	[*options].each{|param| parts << param}
	cmd = parts.join(' ')
	#puts "Invoking git: #{cmd}"
	output = IO.popen(cmd).readlines
	#raise "Error processing command '#{command}'
end

FileUtils.rm_rf $options[:dest]
git_command 'init', $options[:dest]
Dir.chdir $options[:dest]
File.open(".gitignore", 'w') {|f| f.write(GITIGNORE)}

versions = vault_command('versionhistory') % :history
versions = versions.children.map do |item|
  hash = {}
  item.attributes.each do |attr|
    hash[attr[0].to_sym] = attr[1].value
  end
  hash
end
versions.sort_by {|v| v[:version].to_i}.each_with_index do |version, i|
	puts "Processing version #{i+1} of #{versions.size}"
	vault_command 'getversion', version[:version], $options[:dest]
	git_command 'add', '.'
	comments = [version[:comment], "Original Vault commit: version #{version[:version]} on #{version[:date]} by #{version[:user]} (txid=#{version[:txid]})"].
	  compact.map{|c| "-m \"#{c}\""}
	date = Time.parse(version[:date])
	git_command 'commit', "--date=\"#{date.strftime('%Y-%m-%dT%H:%M:%S')}\"", *comments
end
