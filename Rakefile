require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'
require 'rspec/core'
require 'rspec/core/rake_task'
require 'rake/extensiontask'
require 'rake/javaextensiontask'

GEMSPEC = Gem::Specification.load("bel.gemspec")
UNIT = FileList['spec/unit/**/*_spec.rb']
INTEGRATION = FileList['spec/integration/**/*_spec.rb']

# unit tests
RSpec::Core::RakeTask.new(:unit) do |r|
  r.ruby_opts = '-Ilib/'
  r.rspec_opts = "--format documentation"
  r.pattern = (not UNIT.empty? and UNIT) or fail "No unit tests"
end

# integration tests
RSpec::Core::RakeTask.new(:integration) do |r|
  r.ruby_opts = '-Ilib/'
  r.rspec_opts = "--format documentation"
  r.pattern = (not INTEGRATION.empty? and INTEGRATION) or fail "No integration tests"
end

if RUBY_PLATFORM =~ /java/
  Rake::JavaExtensionTask.new('bel_ext', GEMSPEC) do |ext|
    ext.ext_dir = 'ext/jruby'
  end  
else
  Rake::ExtensionTask.new("bel_ext", GEMSPEC) do |ext|
    ext.ext_dir = 'ext/mri'
    ext.cross_compile = true 
    ext.cross_platform = ['x86-mingw32', 'x64-mingw32']
  end

  ENV['RUBY_CC_VERSION'].to_s.split(':').each do |ruby_version|
    platforms = {
      "x86-mingw32" => "i686-w64-mingw32",                                                                                             
      "x64-mingw32" => "x86_64-w64-mingw32"
    }    
    platforms.each do |platform, prefix|
      task "copy:bel_ext:#{platform}:#{ruby_version}" do |t|
        %w[lib tmp/#{platform}/stage/lib].each do |dir|
          so_file = "#{dir}/#{ruby_version[/^\d+\.\d+/]}/bel_ext.so"
          if File.exists?(so_file)
            sh "#{prefix}-strip -S #{so_file}"
          end
        end
      end
    end
  end
end


task :default => :unit

require 'yard'
YARD::Rake::YardocTask.new
# vim: ts=2 sw=2:
# encoding: utf-8
