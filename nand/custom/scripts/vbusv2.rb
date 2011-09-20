#!/usr/bin/ruby 
require 'optparse'

progdir = File.dirname(File.expand_path($PROGRAM_NAME))
$LOAD_PATH.unshift progdir

require "vbusutil.rb"


# Create a Hash containing option default values.
# Specified options will replace these.
options = {:hostname=> ENV['HOME'] == '/root' ? 'localhost' :
  '192.168.1.100', :port=>'7053', :monitor=>false,
  :debug=>false, :verbose=>false, :dest=>0x4221}

#puts options[:hostname]
class Symbol
  include Comparable

  def <=>(other)
    self.to_s <=> other.to_s
  end
end


# Configure an OptionParser.
parser = OptionParser.new
parser.banner = "Usage: vbusv2.rb [options] [PARAM [VALUE]...]\n"\
"\tWhere PARAM is the index of a controller parameter and VALUE is the target setting.\n"\
"\tIf VALUE is omitted, the parameter is read and printed out.\n"\
"\tVALUE should be given in the native scaling, that is, the same scaling as the\n"\
"\tvalue that is read.\n"\
"\tPARAM can either be a hexadecimal index of a parameter or one of the following\n"\
"\tsymbolic settings of the BS Plus:\n"\
"\t#{Vbus::Syms.keys.sort.join(", ")}\n"

parser.on('-h', '--help',
  'displays usage information') do
  puts parser
  exit
end

parser.on('-H=host', '--hostname=host',
  'DL2 hostname. Default is localhost') do |v|
  options[:hostname] = v
end
parser.on('-D=dest', '--destination=controller_hex',OptionParser::OctalInteger,
  'Hex VBUS address for the target controller. Default is 0x4221 for BS plus') do |v|
  options[:dest] = v
end
parser.on('-m', '--monitor', TrueClass,
  'Monitor the vbus continuously') do |v|
  options[:monitor] = true
end
parser.on('-d', '--debug', TrueClass,
  'print debugging information') do |v|
  options[:debug] = true
end
parser.on('-v', '--verbose', TrueClass,
  'print verbose monitor information') do |v|
  options[:verbose] = true
end

# Parse command-line options.
begin
  parser.parse!($*)
rescue OptionParser::ParseError
  puts $!
  exit
end


begin
  vbus = Vbus.new(options[:hostname], options[:port], options[:dest], options[:debug])
rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, RuntimeError => e
  vbus.close if vbus
  puts e
  exit
end



if ( options[:monitor])
  stty_save = `stty -g`.chomp
  begin
    loop do
      vbus.getmsg(Vbus::Monitor,2.0)
    end
  rescue Interrupt => e
    system('stty', stty_save) # Restore
    exit
  rescue RuntimeError => e
    puts e
    retry
  ensure
    vbus.release
    vbus.close
  end
end


begin
  while( param = ARGV.shift ) do
    outstr = vbus.writeval(Vbus::Readrequest,param.to_sym,0)
    result = `date`.chomp + " #{param} #{ARGV[0]? "former ": ""}value: " + outstr.to_s

    if (val=ARGV.shift)
      outstr = vbus.writeval(Vbus::Writerequest,param.to_sym, val)
      result += ", New value: " + outstr.to_s
    end
    puts result
  end
rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, RuntimeError => e
  puts e
ensure
  vbus.release
  vbus.close               # Close the socket when done  
end



