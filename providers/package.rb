include Chef::Mixin::ShellOut

def whyrun_supported?
  true
end

def load_current_resource
  creates_files =  if new_resource.creates.is_a?(Array) 
                     new_resource.creates
                   else
                     [new_resource.creates]
                   end
  @current_resource = ::Chef::Resource::SourcePackage.new(@new_resource.name)
  @current_resource.installed creates_files.reduce(true) { |s, f| s and ::File.exists?(f) }
end

action :build do
  build_dir = "/opt/fewbytes/build/#{new_resource.name}"
  converge_by("create directory #{build_dir}") do
    directory build_dir do
      mode "0644"
      recursive true
      action :nothing
    end.run_action(:create)
  end
  source_updated = send("get_source_from_#{new_resource.source_type}", build_dir)
  source_updated = true unless new_resource.checksum  #assume update, unless we know better

  if new_resource.build_command
    if source_updated
      build
    else
      Chef::Log.warn "Skipping build of #{new_resource.name} because sources have not changed since last build"
    end
  end
end

def build
  if current_resource.installed
    Chef::Log.warn "Skipping build of #{new_resource.name} is already installed"
  else
    converge_by("build #{new_resource.name} using command: #{new_resource.build_command}") do
      Chef::Log.info "Building #{new_resource.name} using command: #{new_resource.build_command}"
      shell_out!(new_resource.build_command, :cwd => @current_build_dir, :env => new_resource.environment)
    end
  end
end

def get_source_from_tarball(build_dir)
  tar_filename = ::File.join(build_dir, ::File.basename(new_resource.source))
  r = remote_file tar_filename do
    mode "0644"
    checksum new_resource.checksum if new_resource.checksum
    source new_resource.source
    action :nothing
  end
  converge_by("download #{tar_filename} from #{new_resource.source}") do  
    r.run_action(:create)
  end
  tar_comp = case tar_filename
             when /\.(tar\.|t)gz$/
               "z"
             when /\.(tar\.|t)bz2$/
               "j"
             else
               ""
             end
  @current_build_dir = ::File.join(build_dir, "current")
  converge_by("extract #{tar_filename}") do
    shell_out!("tar -x#{tar_comp}f #{tar_filename}", :cwd => build_dir, :umask => "0022") if r.updated_by_last_action?
    unless ::File.symlink?(@current_build_dir) and ::File.exists?(@current_build_dir)
      tar_t = shell_out!("tar -t#{tar_comp}f #{tar_filename}", :cwd => build_dir)
      new_dir = tar_t.stdout.lines.map{|l| l[/([^\/]+\/)/, 1]}.compact.first
      new_dir or raise RuntimeError, "No marker symlink and no new directories found, can't figure out the internal build dir"
      Chef::Log.info "Symlinking marker for current version of #{new_resource.name} source"
      ::FileUtils.ln_sf(new_dir, @current_build_dir)
    end
    raise RuntimeError, "Can't find internal build dir" unless ::File.directory?(@current_build_dir)
  end
  r.updated_by_last_action?
end

def get_source_from_git(build_dir)
  @current_build_dir = ::File.join(build_dir, "git_source") 
  g = git @current_build_dir do
    repository new_resource.source
    revision new_resource.ref
    depth 1
    enable_submodules true
    action :nothing
  end
  converge_by("sync git from #{new_resource.source}") do
    g.run_action(:sync)
  end
  g.updated_by_last_action?
end
