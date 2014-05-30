require "rake"
require 'timeout'

class FastRake::FastRunner

  GREEN = "\033[32m"
  RED = "\033[31;7m" # sets inverse text (white on red) to make it stand out more
  YELLOW = "\e[33m"
  RESET = "\033[0m"

  def initialize(tasks, process_count, fail_fast)
    @tasks = get_task_commands(tasks)
    @process_count = process_count
    @fail_fast = fail_fast
    @children = {}
    @parent = true
    @env_number = 0
    @failed=false
    @failed_tasks=[]
    #put_w_time "Parent PID is: #{Process.pid}"
  end

  def run
    clean_previous_results
    @start = Time.now

    put_w_time %{Started at #{Time.now.strftime("%H:%M:%S")}, (will run #{@process_count} parallel processes)}
    at_exit { kill_remaining_children }

    start_some_children

    wait_for_tasks_to_finish
    put_w_time "#{@failed ? RED : GREEN}Elapsed time: #{distance_of_time_to_now(@start)}#{RESET}"
    if @failed
      if @fail_fast
        raise 'failed fast'
      else
        puts_failed
        raise 'failed after all'
      end
    end
  end

  private

  def get_task_commands(tasks)
    tasks.map { |task| task.is_a?(Hash) ? task[:cmd] : task.to_s }
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
        put_w_time "Sending SIGINT to #{pid} (#{task[:display_name]})"
        Process.kill("INT", pid)
        Process.kill("INT", pid) # Twice - cbr / rspec ignore the first one for some reason...
      rescue Exception
        nil
      end
    end
    @children.each do |pid, task|
      put_w_time "Waiting for #{pid} (#{task[:display_name]})"
      wait_for_task_with_timeout(pid)
    end
    @children={}
  end

  def put_w_time(thing)
    puts %{[#{distance_of_time_to_now(@start)}] #{thing}}
  end

  def run_in_new_env(task)
    @parent = false
    ENV['TEST_ENV_NUMBER'] = task[:env_number].to_s

    `mkdir -p '#{task[:output_path]}'`
    STDOUT.reopen(task[:output_path].join('stdout'), 'w')
    STDERR.reopen(task[:output_path].join('stderr'), 'w')

    setup_database
    task_match = task[:name].match(/([^\[]*)(?:\[([^\]]*)\])?/)
    task_name = task_match[1]
    task_args = (task_match[2] || '').split(',')
    Rake::Task[task_name].invoke(*task_args)
  end

  def setup_database
    puts "RAILS_ENV is #{ENV["RAILS_ENV"]} and TEST_ENV_NUMBER is #{ENV["TEST_ENV_NUMBER"]}"
    Rake::Task['db:structure:test:load'].reenable
    %w{db:load_config db:create db:test:prepare}.each do |task_name|
      Rake::Task[task_name].reenable
      Rake::Task[task_name].invoke
    end
  end

  def start_some_children
    while @children.length < @process_count && @tasks.length > 0
      task_name = @tasks.shift
      if !task_name.nil?
        name, display_name = task_name.split('%')
        @env_number += 1
        task = {
          :name => name,
          :display_name => display_name || name,
          :start => Time.now,
          :env_number => @env_number
        }
        task[:output_path] = calc_output_path(task[:display_name], @env_number)
        pid = Process.fork { @parent=false; sleep(@env_number / 10); run_in_new_env(task) }
        put_w_time "[#{task[:display_name]}] started (pid #{pid}); #{@tasks.length} jobs left to start."
        @children[pid] = task
      end
    end
  end

  def calc_output_path(display_name, env_number)
    results_folder.join("#{task_string(display_name)}_#{env_number}")
  end

  def task_string(task_name)
    task_name.to_s.gsub(':', '_')
  end

  def puts_still_running
    return if @children.length == 0
    put_w_time "#{YELLOW}Still running: #{@children.values.collect{|v|v[:display_name]}.join(' ')}#{RESET}"
    put_w_time "#{YELLOW}Remaining: #{@tasks.collect{|t| t.split('%').last }.join(' ')}#{RESET}"
  end

  def puts_rerun(current_task)
    return if @children.length == 0
    child_names = @children.values.collect { |v| v[:name] }
    outstanding = [current_task[:name], child_names, @tasks].flatten
    put_w_time "#{YELLOW}Rerun only the remaining tasks with: [,'#{outstanding.join(' ')}']#{RESET}"
  end

  def puts_failed
    put_w_time "#{RED}Rerun only the failed tasks with: [,'#{@failed_tasks.join(' ')}']#{RESET}"
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
        if status.success?
          put_w_time "#{GREEN}[#{task[:display_name]}] finished. Elapsed time was #{distance_of_time_to_now(task[:start])}.#{RESET}"
          put_w_time "#{GREEN}[#{task[:display_name]}] Output is in #{task[:output_path]}#{RESET}"
          puts_still_running
          start_some_children
        elsif @fail_fast
          if !@failed
            put_w_time "#{RED}[#{task[:display_name]}] failed. Elapsed time was #{distance_of_time_to_now(task[:start])}.#{RESET}"
            put_w_time "#{RED}[#{task[:display_name]}] Output is in #{task[:output_path]}#{RESET}"
            puts_rerun(task)
            @failed = true
            #killing the remaining children will also trigger this block
            kill_remaining_children
          end
        elsif !@fail_fast
          put_w_time "#{RED}[#{task[:display_name]}] failed. Elapsed time was #{distance_of_time_to_now(task[:start])}.#{RESET}"
          put_w_time "#{RED}[#{task[:display_name]}] Output is in #{task[:output_path]}#{RESET}"
          @failed_tasks << task[:name]
          @failed = true
          puts_still_running
          start_some_children
        end
      end
    rescue Errno::ECHILD
      # Errno::ECHILD indicates you have no child process to wait on.
    end
  end

end
