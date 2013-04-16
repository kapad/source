include Chef::Mixin::ShellOut

# This prevents inline resources from being evaluated in the main run_context, instead we have a private run_context
# use_inline_resources also auto-sets updated_by_last_action if *any* converge_by block was called. It's expected to become the default behaviour in Chef 12 btw.
use_inline_resources

def whyrun_supported?
  true
end

def define_resource_requirements
  tool = tool_for_source_type
  requirements.assert(:all_actions) do |a|    
    a.assertion { shell_out("which #{tool}").exitstatus == 0 }
    a.failure_message "#{tool} binary cannot be found"
    a.whyrun "Can't find #{tool} binary, assuming it would have been installed"
  end
end

def load_current_resource

  @current_resource = ::Chef::Resource::SourcePackage.new(@new_resource.name)
  @current_resource.installed creates_files.all?{ |f| ::File.exists?(f) }
end

def creates_files
  if new_resource.creates.is_a?(Array) 
    new_resource.creates
  else
    [new_resource.creates]
  end
end

def initialize(*args)
  super(*args)
  @mode = :install
end

action :build do
  unless current_resource.installed
    get_sources
    define_build_command if new_resource.build_command
  end
end

action :install do
  run_action(:build)
end

action :rebuild do
  @mode = :upgrade
  get_sources
  define_build_command if new_resource.build_command
end

action :upgrade do
  run_action(:rebuild)
end

def get_sources
  build_dir = "/opt/fewbytes/build/#{new_resource.name}"
  directory build_dir do
    mode "0644"
    recursive true
  end
  send("get_source_from_#{new_resource.source_type}", build_dir)
end

def define_build_command
  build_environment = new_resource.environment
  current_build_dir = @current_build_dir
  mode = @mode
  if not current_resource.installed
    execute "build #{new_resource.name}" do
      command new_resource.build_command
      cwd current_build_dir
      env build_environment
      not_if { creates_files.all? {|f| ::File.exists? f }} unless mode == :upgrade
    end
  elsif mode == :upgrade
    execute "build #{new_resource.name}" do
      command new_resource.build_command
      cwd current_build_dir
      env build_environment
      action :nothing
    end  
  end  
end

def get_source_from_tarball(build_dir)
  tar_filename = ::File.join(build_dir, ::File.basename(new_resource.source))
  mode = @mode
  tar_comp = case tar_filename
           when /\.(tar\.|t)gz$/
             "z"
           when /\.(tar\.|t)bz2$/
             "j"
           else
             ""
           end
  @current_build_dir = current_build_dir = ::File.join(build_dir, "current")

  remote_file tar_filename do
    mode "0644"
    checksum new_resource.checksum if new_resource.checksum
    source new_resource.source
    action :create
    notifies :create, "ruby_block[extract and symlink #{new_resource.name}]", :immediately
  end
  ruby_block "extract and symlink #{new_resource.name}" do
    block do
      unless ::File.symlink?(current_build_dir) and ::File.exists?(current_build_dir)
        tar_t = shell_out!("tar -t#{tar_comp}f #{tar_filename}", :cwd => build_dir)
        new_dir = tar_t.stdout.lines.map{|l| l[/([^\/]+\/)/, 1]}.compact.first
        new_dir or raise RuntimeError, "No marker symlink and no new directories found, can't figure out the internal build dir"
        Chef::Log.info "Symlinking marker for current version of #{new_resource.name} source"
        ::FileUtils.ln_sf(new_dir, current_build_dir)
      else
        raise RuntimeError, "Can't find internal build dir" unless ::File.directory?(current_build_dir)
      end
    end
    action :nothing
    notifies :run, "execute[build #{new_resource.name}]", :immediately if mode == :upgrade
  end
end

def get_source_from_git(build_dir)
  @current_build_dir = ::File.join(build_dir, "git_source")
  mode = @mode
  git @current_build_dir do
    repository new_resource.source
    revision new_resource.ref
    depth 1
    enable_submodules true
    action :sync
    notifies :run, "execute[build #{new_resource.name}]", :immediately   if mode == :upgrade
  end
end

def tool_for_source_type
  case new_resource.source_type
  when :tarball, "tarball"
   "tar"
  when :git, "git"
   "git"
  end
end