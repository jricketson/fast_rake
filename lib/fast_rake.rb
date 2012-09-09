require 'fast_rake/version'
require 'fast_rake/fast_runner'

module FastRake
  extend Rake::DSL

  def self.fast_runner_task(name, setup_tasks, run_tasks, fail_fast=true, processes=nil)
    desc "Fast test runner for #{name.to_s}"
    task name, [:count, :list] => setup_tasks do |t, args|
      tasks_to_run = if !args[:list].nil?
        args[:list].split(' ')
      else
        run_tasks
      end
      if !args[:count].nil? and args[:count].to_i != 0
        processes = args[:count].to_i
      elsif processes.nil?
        processes = _processor_count 
        puts "#{processes} processors detected" 
      end
      FastRunner.new(tasks_to_run, processes, fail_fast).run
    end
  end

  #stolen from https://github.com/grosser/parallel
  def self._processor_count
    case RbConfig::CONFIG['host_os']
    when /darwin9/
      `hwprefs cpu_count`.to_i
    when /darwin/
      (hwprefs_available? ? `hwprefs thread_count` : `sysctl -n hw.ncpu`).to_i
    when /linux|cygwin/
      `grep -c processor /proc/cpuinfo`.to_i
    when /(open|free)bsd/
      `sysctl -n hw.ncpu`.to_i
    when /mswin|mingw/
      require 'win32ole'
      wmi = WIN32OLE.connect("winmgmts://")
      cpu = wmi.ExecQuery("select NumberOfLogicalProcessors from Win32_Processor")
      cpu.to_enum.first.NumberOfLogicalProcessors
    when /solaris2/
      `psrinfo -p`.to_i # this is physical cpus afaik
    else
      $stderr.puts "Unknown architecture ( #{RbConfig::CONFIG["host_os"]} ) assuming one processor."
      1
    end
  end
end
