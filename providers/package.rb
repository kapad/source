action :build do
  unless ::File.exists? new_resource.creates
    build_dir = "/opt/fewbytes/build/#{new_resource.name}"
    directory build_dir do
      mode "0644"
      recursive true
      action :nothing
    end.run_action(:create)

    internal_build_dir = send("get_source_from_#{new_resource.source_type}", build_dir)
    raise RuntimeError, "Can't find internal build dir" if internal_build_dir.nil? or not ::File.directory?(internal_build_dir)

    execute new_resource.build_command do
      cwd internal_build_dir
      action :nothing
    end.run_action(:run)

    new_resource.updated_by_last_action true

  else
    Chef::Log.warn "Skipping build of #{new_resource.name} because #{new_resource.creates} exists"
  end
end

def get_source_from_tarball(build_dir)
  tar_filename = ::File.join(build_dir, ::File.basename(new_resource.source))
  remote_file tar_filename do
    mode "0644"
    checksum new_resource.checksum if new_resource.checksum
    action :nothing
  end.run_action(:create)
  dir_contents_before_extract = Dir.new(build_dir).entries
  tar_comp = case tar_filename
             when /\.(tar\.|t)gz$/
               "z"
             when /\.(tar\.|t)bz2$/
               "j"
             else
               ""
             end
  execute "tar -x#{tar_comp}f #{tar_filename}" do
    action :nothing
    cwd build_dir
  end.run_action(:run)
  (Dir.new(build_dir).entries - dir_contents_before_extract).first
end

def get_source_from_git(build_dir)
  git_dir = ::File.join(build_dir, "git_source") 
  git git_dir do
    repository new_resource.source
    revision new_resource.ref
    depth 1
    enable_submodules true
    action :nothing
  end.run_action(:sync)
  git_dir
end
