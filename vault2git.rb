require 'rubygems'
require 'bundler'
require 'nokogiri'
require 'optparse'
require 'pp'

DEFAULT_VAULT_CLIENT_PATH = "C:\\Program Files\\SourceGear\\Vault Client\\vault.exe"

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: vault2git.rb [options] $/source/folder dest/folder"
  
  options[:username] = ''
  opts.on('-u', '--username [username]', 'The repository user') {|val| options[:username] = val}
  
  options[:password] = ''
  opts.on('-p', '--password [password]', 'The repository user\'s password') {|val| options[:password] = val}
  
  options[:host] = ''
  opts.on('-s', '--host host', 'The repository hostname/ip address') {|val| options[:host] = val}
  
  options[:repo] = ''
  opts.on('-r', '--repo name', 'The repository name') {|val| options[:repo] = val}
  
  options[:vault_client] = DEFAULT_VAULT_CLIENT_PATH
  opts.on('', '--vault-client-path path-to-vault.exe', "Path to vault.exe, defaults to #{DEFAULT_VAULT_CLIENT_PATH}") {|val| options[:vault_client] = val}
  
  opts.on('-h', '--help', 'Display this help screen') do
	puts opts
	exit
  end
  
  opts.parse!
  if opts.default_argv.size != 2
    puts opts
	exit
  end
  options[:source], options[:dest] = opts.default_argv
end

pp options

