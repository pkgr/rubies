#!/usr/bin/env ruby

require 'tmpdir'
require 'fileutils'
require 'uri'

def pipe(command)
  output = ""
  IO.popen(command) do |io|
    until io.eof?
      buffer = io.gets
      output << buffer
      puts buffer
    end
  end

  raise("command failed: #{command}") unless $?.success?
  output
end

class Patcher
  class << self
    attr_accessor :patches_dir
    def osfamily
      return "redhat" if File.exists?("/etc/redhat-release")
      return "debian" if File.exists?("/etc/debian_version")
      raise "unknown osfamily"
    end

    def apply!(*args)
      new(osfamily, *args).apply!
    end
  end

  attr_reader :osfamily, :ruby_version
  def initialize(osfamily, ruby_version)
    @osfamily, @ruby_version = osfamily, ruby_version
  end

  def major_ruby_version
    ruby_version.match(/\d\.\d/)[0]
  end

  def debian?
    osfamily == "debian"
  end

  def redhat?
    osfamily == "redhat"
  end

  def patch_path(name)
    File.join(self.class.patches_dir, name)
  end

  def apply!
    # on centos, apply openssl patch
    if redhat? && ["1.8.7", "1.9.2"].include?(ruby_version)
      puts "Applying OpenSSL patch for old versions of Ruby: #{ruby_version}"
      pipe "patch ext/openssl/ossl_pkey_ec.c #{patch_path("ruby-ossl-patch")}"
    elsif debian? && File.read("/etc/debian_version").chomp == "jessie/sid"
      patch_name = case major_ruby_version
      when "2.0"
        # looks like it was already patched
        # "ruby-readline-patch-20"
      when "2.1"
        "ruby-readline-patch-21" if ruby_version < "2.1.2"
      end
      unless patch_name.nil?
        puts "Applying Readline patch for 2.x versions of Ruby: #{ruby_version}"
        pipe "patch -p0 -u < #{patch_path(patch_name)}"
      end
    end
  end
end

class Compiler
  class << self
    attr_accessor :output_dir, :cache_dir, :dependencies_dir
    def compile!(*args)
      new(*args).compile!
    end
  end

  attr_reader :recipe, :name, :version, :env
  def initialize(recipe, name, version, env = {})
    @recipe, @name, @version, @env = recipe, name, version, {"VERSION" => version}.merge(env)
  end

  def tgz_name
    "#{name}-#{version}.tgz"
  end

  def compile!
    unless File.exists?(File.join(self.class.cache_dir, tgz_name))  
      puts "Compiling #{tgz_name}..."
      input, output = Dir.mktmpdir, Dir.mktmpdir  
      env_string = env.map{|k,v| [k,v].join("=")}.join(" ")
      pipe("cd #{input} && #{env_string} #{self.class.dependencies_dir}/#{recipe}/build #{input} #{output} && tar czf #{self.class.cache_dir}/#{tgz_name} -C #{output} .") 
    end
    self
  end

  def copy_to(dir)
    src = File.join(self.class.cache_dir, tgz_name)
    FileUtils.rm_f(File.join(dir, tgz_name))
    FileUtils.cp(src, dir, :verbose => true) 
  end
end

def fetch(url)
  uri    = URI.parse(url)
  binary = uri.to_s.split("/").last
  if File.exists?(binary)
    puts "Using #{binary}"
  else
    puts "Fetching #{binary}"
    pipe "curl #{uri} -s -O"
  end
end

workspace_dir = ARGV[0]
output_dir    = ARGV[1]
cache_dir     = ARGV[2]

LIBYAML_VERSION = "0.1.6"
LIBFFI_VERSION  = "3.0.10"
LIBJEMALLOC_VERSION = "3.6.0"

vendor_url   = "https://s3.amazonaws.com/#{ENV['S3_BUCKET_NAME'] ? ENV['S3_BUCKET_NAME'] : 'heroku-buildpack-ruby'}"
full_version = ENV['VERSION']
full_name    = "ruby-#{full_version}"
version      = full_version.split('-').first
name         = "ruby-#{version}"
major_ruby   = version.match(/\d\.\d/)[0]
build        = false
build        = true if ENV["BUILD"]
debug        = nil
debug        = true if ENV['DEBUG']
jobs         = ENV['JOBS'] || 2
rubygems     = ENV['RUBYGEMS_VERSION'] ? ENV['RUBYGEMS_VERSION'] : nil
git_url      = ENV["GIT_URL"]
svn_url      = ENV["SVN_URL"]
relname      = ENV["RELNAME"]
stack        = "cedar"
treeish      = nil

filename = "#{name}.tgz"
filename = filename.sub("ruby-", "ruby-build-") if build

# create cache dir if it doesn't exist
FileUtils.mkdir_p(cache_dir)

Patcher.patches_dir = File.join(workspace_dir, "patches")
Compiler.dependencies_dir = File.join(workspace_dir, "dependencies")
Compiler.output_dir = output_dir
Compiler.cache_dir = cache_dir
Compiler.compile!("libjemalloc", "libjemalloc", LIBJEMALLOC_VERSION).copy_to(output_dir)
Compiler.compile!("libffi", "libffi", LIBFFI_VERSION).copy_to(output_dir)
Compiler.compile!("libyaml", "libyaml", LIBYAML_VERSION).copy_to(output_dir)
Compiler.compile!("node", "node", "0.6.8").copy_to(output_dir)
Compiler.compile!("gem", "bundler", "1.6.3", {"GEM" => "bundler"}).copy_to(output_dir)
Compiler.compile!("gem", "bundler", "1.5.2", {"GEM" => "bundler"}).copy_to(output_dir)
Compiler.compile!("gem", "bundler", "1.5.0.rc.1", {"GEM" => "bundler"}).copy_to(output_dir)

if File.exists?(File.join(output_dir, filename))
  puts "#{filename} already exists. not rebuilding."
  exit 0
end

# fetch deps
Dir.chdir(cache_dir) do
  tarball = "#{full_name}.tar.gz"

  if git_url
    uri          = URI.parse(git_url)
    treeish      = uri.fragment
    uri.fragment = nil
    full_name    = uri.to_s.split('/').last.sub(".git", "")

    if File.exists?(full_name)
      Dir.chdir(full_name) do
        puts "Updating git repo"
        pipe "git pull"
      end
    else
      puts "Fetching #{git_url}"
      pipe "git clone #{uri}"
    end

  elsif svn_url
    uri = URI.parse(svn_url)

    if File.exists?(full_name)
      puts "Using existing svn checkout: #{full_name}"
      pipe "svn update"
    else
      pipe "svn co #{svn_url} #{full_name}"
    end

    Dir.chdir(full_name) do
      cmd = "ruby tool/make-snapshot -archname=#{full_name} build #{relname}"
      puts cmd
      pipe cmd
    end

    FileUtils.mv("#{full_name}/build/#{tarball}", ".")
  else
    fetch("http://ftp.ruby-lang.org/pub/ruby/#{major_ruby}/#{tarball}")
  end
  if rubygems
    rubygems_binary = "rubygems-#{rubygems}"
    fetch("http://production.cf.rubygems.org/rubygems/#{rubygems_binary}.tgz")
  end
end

Dir.mktmpdir("ruby-vendor-") do |vendor_dir|
  if git_url
    FileUtils.cp_r("#{cache_dir}/#{full_name}", ".")
  else
    pipe "tar zxf #{cache_dir}/#{full_name}.tar.gz"
  end
  Dir.chdir(vendor_dir) do
    pipe "tar zxf #{cache_dir}/libyaml-#{LIBYAML_VERSION}.tgz"
    pipe "tar zxf #{cache_dir}/libffi-#{LIBFFI_VERSION}.tgz"
    pipe "tar zxf #{cache_dir}/libjemalloc-#{LIBJEMALLOC_VERSION}.tgz"
    pipe "tar zxf #{cache_dir}/rubygems-#{rubygems}.tgz" if rubygems
  end

  # prefix is not important, since we're using --enable-load-relative
  prefix = "/tmp/#{name}"

  Dir.chdir(full_name) do
    pipe "git checkout #{treeish}" if treeish

    Patcher.apply!(version)

    if debug
      configure_env = "debugflags=\"-ggdb3\""
    else
      configure_env = "debugflags=\"-g\""
    end
    configure_env += " LDFLAGS=\"-L/#{vendor_dir}/lib\" LIBRARY_PATH=#{vendor_dir}/lib:\\$LIBRARY_PATH"

    configure_opts = "--disable-install-doc --prefix #{prefix}"
    configure_opts += " --enable-load-relative" if major_ruby != "1.8" && version != "1.9.2"
    configure_opts += %{ LIBS="-ljemalloc -pthread"}
    puts "configure env:  #{configure_env}"
    puts "configure opts: #{configure_opts}"
    cmds = [
      "#{configure_env} ./configure #{configure_opts}",
      "env CPATH=#{vendor_dir}/include:\\$CPATH CPPATH=#{vendor_dir}/include:\\$CPPATH LIBRARY_PATH=#{vendor_dir}/lib:\\$LIBRARY_PATH make -j#{jobs}",
      "make install"
    ]
    cmds.unshift("#{configure_env} autoconf") if git_url
    cmds.unshift("chmod +x ./tool/*") if git_url
    pipe(cmds.join(" && "))
  end
  if rubygems
    Dir.chdir("#{vendor_dir}/rubygems-#{rubygems}") do
      pipe("#{prefix}/bin/ruby setup.rb")
    end
    gem_bin_file = "#{prefix}/bin/gem"
    gem = File.read(gem_bin_file)
    File.open(gem_bin_file, 'w') do |file|
      file.puts "#!/usr/bin/env ruby"
      lines = gem.split("\n")
      lines.shift
      lines.each {|line| file.puts line }
    end
  end
  Dir.chdir(prefix) do
    puts "Writing #{filename}"
    pipe("tar czf #{output_dir}/#{filename} *")
  end
end
