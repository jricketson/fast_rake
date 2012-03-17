# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require 'fast_rake/version'
 
Gem::Specification.new do |s|
  s.name              = 'fast_rake'
  s.version           = FastRake::VERSION
  s.platform          = Gem::Platform::RUBY
  s.authors           = ['Jonathan Ricketson']
  s.email             = ['jonathan.ricketson@lonelyplanet.com.au']
  s.homepage          = 'https://github.com/jricketson/fast_rake'
  s.summary           = %q{Makes developer pre-commit builds really fast. Runs a small number of setup tasks, followed by a bunch of expensive tasks in parallel. }
  s.description       = %q{
    Runs a small number of setup tasks, followed by a bunch of expensive tasks in parallel.
    This manages the number of running tasks and keeps the visible output to a small and useful amount.
    It was created to make developer pre-commit builds really fast, but still able to cover a lot of tests.
  }

  s.rubyforge_project = 'fast_rake'

  #s.add_runtime_dependency '...', '~> x.y.z'
  s.add_development_dependency 'gemma', '~> 2.1.0'

  s.files       = Dir.glob('lib/**/*.rb')

  s.rdoc_options = [
    "--title",   "#{s.full_name} Documentation"]
end

