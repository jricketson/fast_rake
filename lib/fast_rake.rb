require 'fast_rake/version'
require 'fast_rake/fast_runner'

module FastRake

  def self.fast_runner(setup_tasks, run_tasks)
    fast_runner_task(:two, 2, setup_tasks, run_tasks)
    fast_runner_task(:four, 4, setup_tasks, run_tasks)
    fast_runner_task(:eight, 8, setup_tasks, run_tasks)
  end

  def self.fast_runner_task(name, processes, setup_tasks, run_tasks)

    desc "Fast test runner for #{processes} cpus"
    task name, [:list] => setup_tasks do |t, args|
      tasks_to_run = if !args[:list].nil?
        args[:list].split(' ')
      else
        run_tasks
      end
      #puts %{\n\e[33mTo rerun: ber "fast:#{name}[#{tasks_to_run.join(' ')}]"\033[0m\n\n}
      FastRunner.new(tasks_to_run, processes).run
    end
  end


end
