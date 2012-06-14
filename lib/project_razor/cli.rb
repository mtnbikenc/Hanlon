require 'rubygems' if RUBY_VERSION < '1.9'

require 'colored'
require 'json'
require 'optparse'
require 'project_razor'

module ProjectRazor
  class Cli
    attr_reader :namespace
    attr_reader :action
    attr_reader :args
    attr_reader :options

    SLICE_PREFIX = "ProjectRazor::Slice::"

    def self.run(args)
      exit(new(args, $stdout).run)
    end

    def initialize(args=[], output=$stdout)
      @obj     = ProjectRazor::Object.new
      @version = @obj.get_razor_version
      @logger  = @obj.get_logger

      @args    = args
      @output  = output
      @options = {
        :colorize   => STDOUT.tty?,
        :verbose    => false,
        :debug      => false,
        :webcommand => false,
      }
      @exit_code = 0
    end

    def opts
      opts_parser = OptionParser.new do |opts|
        opts.banner = "\nRazor - #{@version}".bold.green
        opts.separator "Usage: "+"razor [global options] [slice] [command] [slice options] ...".red
        opts.separator ""
        opts.separator "Global Options:".yellow

        opts.on('-v', '--verbose', 'Enable object verbose output.') { @options[:verbose]    = true }
        opts.on('-d', '--debug', 'Enable Ruby stack trace output.') { @options[:debug]      = true }
        opts.on('-w', '--webcommand', 'Accept web commands.')       { @options[:webcommand] = true }
        opts.on('-n', '--no-color', 'Disable console color.')       { @options[:colorize]   = false; require 'project_razor/cli/colored' }

        opts.on_tail('-h', '--help', 'This help message.') { display_help; @exit_code=129; exit(@exit_code) }
      end
    end

    def parse_options!
      @args = opts.order!(@args)
      self
    end

    def parse_slice!
      slice = @args.shift
      @namespace = slice
    end

    def display_usage
      puts opts
    end

    def display_help
      display_usage
      puts "\n"
      puts "Available Slices:"
      puts "\t" + available_slices.keys.collect { |x| "[#{x}]".white }.join(' ')
    end

    def puts(*val)
      @output.puts val
    end

    def available_slices
      slices = Hash[ ProjectRazor::Slice.class_children.map{|s| [s.to_s.gsub(SLICE_PREFIX,'').downcase, s] } ]
      slices.delete_if { |k, v| v.new([]).hidden }
    end

    def run
      trap('TERM') { print "\nTerminated\n"; exit(1) }

      parse_options!

      # TODO: this does not suppress color for parse_options exceptions
      require 'project_razor/cli/colored' unless @options[:colorize]

      parse_slice!

      if @namespace && available_slices.has_key?(@namespace)
        slice = available_slices[@namespace].new(@args)
        slice.web_command = @options[:webcommand]
        slice.verbose = @options[:verbose]
        slice.debug= @options[:debug]
        slice.slice_call
      else
        if @options[:webcommand]
          puts JSON.dump({"slice" => "ProjectRazor::Slice", "result" => "InvalidSlice", "http_err_code" => 404})
          @exit_code = 1
        else
          puts "[#{@namespace}]".red + " <- Invalid Slice".yellow if @namespace
          display_help
          @exit_code = 1
        end
      end
    rescue OptionParser::InvalidOption => e
      puts(e.message.red) unless @options[:webcommand]
      @exit_code = 129
    rescue Exception => e
      puts(e.backtrace) if @options[:debug]
      puts(e.message.red) unless @options[:webcommand]
      @exit_code = 1
      #raise e unless @options[:webcommand]
    ensure
      return @exit_code
    end
  end
end
