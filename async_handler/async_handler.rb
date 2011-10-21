require "chef/handler"

module Mycorp
  class Summarize < Chef::Handler
    attr_accessor :conf, :conffile

    def initialize(args)
      self.conffile = args[:configfile]
    end

    def report
      self.conf = YAML.load_file(self.conffile)
      begin
        require "rubygems"
        require "stomp"
        require "base64"

        ignored_resources = [ "/etc/chef/ohai_plugins", "/var/cache/chef/handlers", "/var/cache/chef/backup/handlers" ]
        report_resources= []
        updated_resources.each do |r|
          if !ignored_resources.include?(r.name) then
            report_resources.push r.name
          end
        end

        diffs = {}
        require 'find'
        report_resources.each do |r|
          # does it look like a diff-able file ?
          if r.match(/.conf/) then
            # find the latest backup
            bkps = Dir.glob(Chef::Config[:file_backup_path]+r+".chef-*")
            # found !
            unless bkps.empty?
              last_bkp = bkps[-1]
              diff_cmd = "diff -Nru #{last_bkp} #{r}"
              diffs[r] = %x(#{diff_cmd})
            end
          end
        end

        summary = { :nodename => node.name.dup,
                    :elapsed_time => elapsed_time,
                    :start_time => start_time,
                    :end_time => end_time,
                    :updated_resources => report_resources,
                    :diffs => diffs.to_a
                  }

        cnx=Stomp::Client.new(self.conf[:stomp_user], self.conf[:stomp_password], self.conf[:stomp_server], self.conf[:stomp_port], true)
        msg=Base64.encode64(Marshal.dump(summary))
        cnx.publish(self.conf[:stomp_queue], msg, {:persistent => false})
        cnx.close
      rescue Exception => e
        Chef::Log.error("Could not summarize and send back data for this run ! (#{e})")
      end
    end

  end # end of class Summarize
end
