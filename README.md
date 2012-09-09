fast_rake
=========

### SYNOPSIS

This is a spinoff from making our local developer build faster. The intention is to run a whole bunch of independant tests in parallel
without overloading the computer by spinning them all up at once. We were able to reduce our total build time from about 40 mins to about 10 mins, and our total frustration by more than 100 times!

### Usage
For example, in lib/tasks/fast.rake
    require 'fast_rake'

    namespace :fast do
      
      setup_tasks = [
        "environment:testing",
        "clean_and_package",
        "db:migrate"
      ]

      tests = [
        "spec:covered",
        "cucumber:firefox_g1",
        "cucumber:firefox_g2",
        "cucumber:firefox_g2",
        "cucumber:firefox_ungrouped",
        "cucumber:firefox_offline_g1",
        "cucumber:firefox_offline_g2",
        "cucumber:firefox_offline_g2",
        "cucumber:firefox_offline_ungrouped",
        "jasmine:integration",
        "jasmine:chrome_integration",
        "jasmine:phantom",
        "quality"
      ]
      
      FastRake::fast_runner(setup_tasks, tests, true)
    end
    task :fast,[:list] => "fast:two"
  
Then tasks fast:two, fast:four and fast:eight will have been created, which when run will run the full set of your tests.
The last parameter specifies whether it should fail fast (stop after the first failure) or instead execute every task (and show all failures). 
These tasks can also be executed with a specific list of tasks:

    rake fast:four['task1 task2']"

Or you can use:
    FastRake::fast_runner_task(:smaller_set, 6, setup_tasks, a_smaller_subset, false)
to create a single task named fast:smaller_set that runs a specific subset of tasks.

### Databases
A database is created for each task by the name of the task, to use these you should modify your database.yml to contain something like:

    test:
      adapter: postgresql
      host: localhost
      database: <%= ENV["TEST_DB_NAME"] %>
      username: <%= ENV['USER'] %>
      min_messages: WARNING

### Environment variables
Some environment variables are setup for your use.

TEST_DB_NAME: this is the name of the database that has been created

TEST_ENV_NUMBER: this is an incrementing number for each task that is started. Useful for ensuring unique resources for running tests (ports etc)



### INSTALLATION
Include in your Gemfile

    gem 'fast_rake'


### LICENSE

(The MIT License)

Copyright (c) 2012 Jonathan Ricketson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

