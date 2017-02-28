#!/usr/bin/env ruby
Dir[File.dirname(File.absolute_path(__FILE__)) + '/**/*_tests.rb'].each {|file| require file }
