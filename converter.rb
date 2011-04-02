require 'nokogiri'
require 'fileutils'
require 'time'
require 'log4r'
require 'pp'

GITIGNORE = <<-EOF
_sgbak/
*.tmp
EOF

class Converter
	# Configure logging
	include Log4r
	$logger = Logger.new('vault2git')
	stdout_log = StdoutOutputter.new('console')
	stdout_log.level = INFO
	file_log = FileOutputter.new('file', :filename => $options.logfile, :trunc => true)
	file_log.level = DEBUG
	$logger.add(stdout_log, file_log)
	%w(debug info warn error fatal).map(&:to_sym).each do |level|
		(class << self; self; end).instance_eval do
			define_method level do |msg|
				$logger.send level, msg
			end
		end
	end

	debug $options.inspect

	def self.quote_param(param)
	  value = $options.send(param)
	  quote_value value
	end

	def self.quote_value(value)
	  return '' unless value
	  value.include?(' ') ? '"' + value + '"' : value
	end

	def self.vault_command(command, options = [], args = [], append_source_folder = true)
		parts = []
		parts << quote_param(:vault_client)
		parts << command
		%w(host username password repository).each{|param| parts << "-#{param} #{quote_param(param)}"}
		[*options].each{|param| parts << param}
		parts << quote_param(:source) if append_source_folder
		[*args].each{|param| parts << quote_value(param)}
		cmd = parts.join(' ')
		debug "Invoking vault: #{cmd}"
		retryable do
			begin
				xml = `#{cmd}`
				doc = Nokogiri::XML(xml) do |config|
				  config.strict.noblanks
				end
				raise "Unsuccessful command '#{command}': #{(doc % :error).text}" if (doc % :result)[:success] == 'no'
				doc
			rescue Exception => e
				raise #"Error processing command '#{cmd}'", e
			end
		end
	end

	def self.git_command(command, *options)
		parts = %w(git)
		parts << command
		[*options].each{|param| parts << param}
		cmd = parts.join(' ')
		debug "Invoking git: #{cmd}"
		begin
		  debug output = retryable{`#{cmd}`}
		rescue Exception => e
		  raise "Error processing command '#{command}'", e
		end
	end

	def self.git_commit(comments, *options)
	  git_command 'add', '.'
	  params = [*comments].map{|c| "-m \"#{c}\""} << options
	  git_command 'commit', *(params.flatten)
	end

	def self.retryable(max_times = 5, &block)
		tries = 0
	  begin
		yield block
	  rescue
		tries += 1
		if tries <= max_times
			warn "Retrying command, take #{tries} of #{max_times}"
			retry
		end
		error "Giving up retrying"
		raise
	  end
	end
	
	def self.clear_working_folder
		Dir[$options.dest + "/*"].each{|d| FileUtils.rm_rf d}
	end

	def self.convert
		info "Starting at #{Time.now}"
		debug "Parameters: " + $options.inspect
		info "Prepare destination folder"
		FileUtils.rm_rf $options.dest
		git_command 'init', $options.dest
		Dir.chdir $options.dest
		File.open(".gitignore", 'w') {|f| f.write(GITIGNORE)}
		git_commit 'Starting Vault repository import'
		
		info "Set Vault working folder"
		vault_command 'setworkingfolder', $options.source, $options.dest, false

		info "Fetch version history"
		versions = vault_command('versionhistory') % :history
		versions = versions.children.map do |item|
		  hash = {}
		  item.attributes.each do |attr|
			hash[attr[0].to_sym] = attr[1].value
		  end
		  hash
		end

		count = 0
		versions.sort_by {|v| v[:version].to_i}.each_with_index do |version, i|
			count += 1
			info "Processing version #{count} of #{versions.size}"
			vault_command 'getversion', ["-backup no", "-merge overwrite", "-setfiletime checkin", "-performdeletions removeworkingcopy", version[:version]]#, $options.dest
			comments = [version[:comment], "Original Vault commit: version #{version[:version]} on #{version[:date]} by #{version[:user]} (txid=#{version[:txid]})"].compact
			date = Time.parse(version[:date])
			git_commit comments, "--date=\"#{date.strftime('%Y-%m-%dT%H:%M:%S')}\""
			git_command 'gc' if count % 20 == 0 || count == versions.size
			clear_working_folder
			GC.start if count % 20 == 0 # Force Ruby GC (might speed things up?)
		end
		
		info "Ended at #{Time.now}"
	end
end

