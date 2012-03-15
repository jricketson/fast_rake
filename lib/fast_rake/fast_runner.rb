require "rake"
require 'timeout'

class FastRake::FastRunner

  GREEN = "\033[32m"
  RED = "\033[31m"
  YELLOW = "\e[33m"
  RESET = "\033[0m"

  def initialize(tasks, process_count)
    @tasks = tasks
    @process_count = process_count
    @children = {}
    @parent = true
    @env_number = 0
    @failed=false
    #put_w_time "Parent PID is: #{Process.pid}"
  end

  def run
    clean_previous_results
    check_if_previous_processes_really_finished
    @start = Time.now

    put_w_time %{Started at #{Time.now.strftime("%H:%M:%S")}}
    at_exit { kill_remaining_children }

    start_some_children

    wait_for_tasks_to_finish
    put_w_time "#{@failed ? RED : GREEN}Elapsed time: #{distance_of_time_to_now(@start)}#{RESET}"
    raise 'failed fast' if @failed
  end

  private

  def check_if_previous_processes_really_finished
    process = `ps aux | grep -E "ruby|selenium" | grep -vE "grep|foreman|script\/worker|guard|memcached|growl_notify_buildlight|gem server|#{Process.pid}"`
    lines = process.split("\n")
    if lines.length > 0
      puts lines
      prompt = "#{YELLOW}These ruby|selenium processes were found to be running. Do you want to continue (Y)? (ctrl-c to stop)#{RESET}"
      puts prompt
      STDIN.each_line do |line|
        return if line.downcase.chomp == 'y'
        puts prompt
      end
    end
  end

  def results_folder
    Rails.root.join('tmp', 'build')
  end

  def clean_previous_results
    `rm -rf "#{results_folder}"`
  end

  def distance_of_time_to_now(time)
    seconds = Time.now - time
    total_minutes = (seconds / 1.minutes).floor
    seconds_in_last_minute = (seconds - total_minutes.minutes.seconds).floor
    "%02dm %02ds" % [total_minutes, seconds_in_last_minute]
  end

  def kill_remaining_children
    return unless @parent

    @children.each do |pid, task|
      begin
        put_w_time "Sending SIGINT to #{pid} (#{task[:name]})"
        Process.kill("INT", pid)
        Process.kill("INT", pid) # Twice - cbr / rspec ignore the first one for some reason...
      rescue Exception
        nil
      end
    end
    @children.each do |pid, task|
      put_w_time "Waiting for #{pid} (#{task[:name]})"
      wait_for_task_with_timeout(pid)
    end
    @children={}
  end

  def put_w_time(thing)
    puts %{[#{distance_of_time_to_now(@start)}] #{thing}}
  end

  def run_in_new_env(task_name, env_number)
    @parent = false
    ENV['TEST_ENV_NUMBER'] = env_number.to_s

    output_path = results_folder.join(task_string(task_name))
    `mkdir -p #{output_path}`
    STDOUT.reopen(output_path.join('stdout'), 'w')
    STDERR.reopen(output_path.join('stderr'), 'w')

    setup_database(task_name)
    Rake::Task[task_name].invoke
  end

  def setup_database(task_name)
    ENV["TEST_DB_NAME"] = "test_#{task_string(task_name)}"
    Rake::Task["db:create"].reenable
    Rake::Task["db:create"].invoke
    Rake::Task["db:test:prepare"].reenable
    Rake::Task["db:test:prepare"].invoke
  end

  def start_some_children
    while @children.length < @process_count && @tasks.length > 0
      task_name = @tasks.shift
      if !task_name.nil?
        @env_number += 1
        pid = Process.fork { @parent=false; sleep(@env_number / 10); run_in_new_env(task_name, @env_number) }
        put_w_time "[#{task_name}] started (pid #{pid}); #{@tasks.length} jobs left to start."
        @children[pid] = {:name => task_name, :start => Time.now}
      end
    end
  end

  def task_string(task_name)
    task_name.to_s.gsub(':', '_')
  end

  def puts_still_running
    return if @children.length == 0
    put_w_time "#{YELLOW}Still running: #{@children.values.collect{|v|v[:name]}.join(' ')}#{RESET}"
    put_w_time "#{YELLOW}Remaining: #{@tasks.join(' ')}#{RESET}"
  end

  def wait_for_task_with_timeout(pid, timeout=5)
    begin
      Timeout::timeout(timeout) {
        Process.wait(pid) rescue nil
      }
    rescue Timeout::Error
      begin
        Process.kill("KILL",pid)
      rescue
      end
    end
  end

  def wait_for_tasks_to_finish
    begin
      while true do # When there are no more child processes wait2 raises Errno::ECHILD
        pid, status = Process.wait2
        task = @children.delete(pid)
        next if task.nil?
        output_path = results_folder.join(task_string(task[:name]))
        if status.success?
          put_w_time "#{GREEN}[#{task[:name]}] finished. Elapsed time was #{distance_of_time_to_now(task[:start])}.#{RESET}"
          put_w_time "#{GREEN}[#{task[:name]}] Output is in #{output_path}#{RESET}"
          puts_still_running
          start_some_children
        else
          if !@failed
            put_w_time "#{RED}[#{task[:name]}] Build failed. Output can be found in #{output_path}#{RESET}"
            puts_still_running
            @failed=true
            kill_remaining_children
          end
        end
      end
    rescue Errno::ECHILD
      # Errno::ECHILD indicates you have no child process to wait on.
    end
  end

end
