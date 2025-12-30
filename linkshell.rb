# Buffalo LinkStation SSH Enabler
require "optparse"
require "shellwords"
require "io/console"
require "open3"
require "digest"

options = {}

parse =
  OptionParser.new do |opts|
    opts.banner = "Usage: linkshell.rb [options]"

    opts.on("-t", "--target TARGET", "Your LinkStation's IP address") do |v|
      options[:target] = v
    end
    opts.on(
      "-p",
      "--password PASSWORD",
      "Your LinkStation's admin password"
    ) { |v| options[:password] = v }
    opts.on("-i", "--interval SECONDS", "Interval between commands") do |v|
      options[:interval] = v.to_f
    end
    opts.on(
      "-T",
      "--tries N",
      Integer,
      "Number of tries for each command"
    ) { |v| options[:tries] = v }
    opts.on("--stop", "Stop the LinkShell if already running") do
      options[:stop] = true
    end
    opts.on("-v", "--verbose", "Run verbosely") { |v| options[:verbose] = v }
    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end

parse.parse!
unless options[:target]
  raise OptionParser::MissingArgument, "Target IP address is required"
end

unless options[:password]
  print "Enter admin password of your LinkStation: "
  options[:password] = STDIN.noecho(&:gets).chomp
  puts
end

commands = []

shell_port = 11_511
payload = <<~PAYLOAD
  PORT=#{shell_port}

  case "$1" in
    run)
      echo "$$" > /tmp/nc_shell_pid

      while true; do
        busybox nc -lp $PORT -e /bin/sh -c 'echo Successfully connected to LinkShell!; PS1="\\u@\\h:\\w\\$ " ; export PS1; exec /bin/sh -i'
      done
      ;;
    stop)
      if [ -f /tmp/nc_shell_pid ]; then
        kill "$(cat /tmp/nc_shell_pid)" && rm -f /tmp/nc_shell_pid
        echo "LinkShell stopped."
      else
        echo "LinkShell is not running."
      fi
      ;;
    *)
      echo "Usage: $0 {run|stop}"
      ;;
  esac
PAYLOAD

shellname = "/tmp/linkshell_#{Digest::MD5.hexdigest(payload)}.sh"
puts "Shell Path: #{shellname}"

commands << "rm -f #{shellname}.tmp"
commands << "rm -f /tmp/linkshell_*"
payload.lines.each do |line|
  line
    .chars
    .each_slice(90) do |chunk|
      if chunk[-1] == "\n"
        commands << "echo #{chunk.join.shellescape} >> #{shellname}.tmp"
      else
        commands << "echo -n #{chunk.join.shellescape} >> #{shellname}.tmp"
      end
    end
end
commands << "chmod +x #{shellname}.tmp"
commands << "mv #{shellname}.tmp #{shellname}"

# as interactive mode does not run more than one command, we spam the `-c` option
real_commands =
  commands.map do |command|
    raise "Command too long: #{command}" if command.size >= 200
    "java -jar ./external/acp-commander/acp_commander.jar -t #{options[:target]} -ip #{options[:target]} -pw #{options[:password]} -c #{command.shellescape}"
  end
is_installed =
  `java -jar ./external/acp-commander/acp_commander.jar -t #{options[:target]} -ip #{options[:target]} -pw #{options[:password]} -c "echo -n __shellcheck:; if [ -f #{shellname} ]; then echo exists; else echo missing; fi"`.chomp
if is_installed.include?("__shellcheck:exists")
  puts "Remote shell already installed."
elsif is_installed.include?("__shellcheck:missing")
  puts "Installing remote shell..."
  real_commands.each do |command|
    remaining_tries = options[:tries] || 3
    remaining_tries.times do |attempt|
      puts "Executing: #{command} (Attempt #{attempt + 1}/#{remaining_tries})"
      if options[:verbose]
        system command
      else
        system command, out: File::NULL, err: File::NULL
      end
      if $?.exitstatus == 0
        break
      else
        puts "Command failed."
      end
      if attempt + 1 == remaining_tries
        raise "Command failed after #{remaining_tries} attempts: #{command}"
      end
    end
    sleep options[:interval] if options[:interval]
  end
else
  puts is_installed
  raise "Failed to check if remote shell is installed"
end
if options[:stop]
  puts "Stopping remote shell..."
else
  puts "Starting remote shell..."
  start_command =
    "java -jar ./external/acp-commander/acp_commander.jar -t #{options[:target]} -ip #{options[:target]} -pw #{options[:password]} -c #{("nohup sh " + shellname + " run &").shellescape}"
  if options[:verbose]
    system start_command
  else
    system start_command, out: File::NULL, err: File::NULL
  end
  if $?.exitstatus == 0
    puts "Remote shell started."
  else
    raise "Failed to start remote shell."
  end
  sleep 2
  puts "Connect to the remote shell using netcat:"
  puts "  nc #{options[:target]} #{shell_port}"
  puts "Press enter to stop the remote shell..."
  STDIN.gets
  puts "Stopping remote shell..."
end
stop_command =
  "java -jar ./external/acp-commander/acp_commander.jar -t #{options[:target]} -ip #{options[:target]} -pw #{options[:password]} -c #{("sh " + shellname + " stop").shellescape}"
if options[:verbose]
  system stop_command
else
  system stop_command, out: File::NULL, err: File::NULL
end
if $?.exitstatus == 0
  puts "Remote shell stopped."
else
  raise "Failed to stop remote shell."
end
