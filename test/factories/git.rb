Factory.define(:blank_repository, class: GitRepository) do |f|
  f.after_create do |r|
    FileUtils.cp_r(File.join(Rails.root, 'test', 'fixtures', 'git', 'blank-repository', '_git', '.'), File.join(r.local_path, '.git'))
  end
end

Factory.define(:local_repository, class: GitRepository) do |f|
  f.resource { Factory(:workflow) }
  f.after_create do |r|
    FileUtils.cp_r(File.join(Rails.root, 'test', 'fixtures', 'git', 'local-fixture-workflow', '_git', '.'), File.join(r.local_path, '.git'))
  end
end

Factory.define(:unfetched_remote_repository, class: GitRepository) do |f|
  f.remote "https://github.com/seek4science/workflow-test-fixture.git"
end

Factory.define(:remote_repository, parent: :unfetched_remote_repository) do |f|
  f.after_create do |r|
    FileUtils.cp_r(File.join(Rails.root, 'test', 'fixtures', 'git', 'fixture-workflow', '_git', '.'), File.join(r.local_path, '.git'))
  end
end

# GitVersions
Factory.define(:git_version, class: GitVersion) do |f|
  f.git_repository { Factory(:local_repository) }
  f.resource { self.git_repository.resource }
  f.name 'version 1.0.0'
  f.ref 'refs/heads/master'
  f.mutable true
  end

Factory.define(:remote_git_version, class: GitVersion) do |f|
  f.git_repository { Factory(:remote_repository) }
  f.resource { Factory(:workflow) }
  f.name 'v0.01'
  f.ref 'refs/tags/v0.01'
  f.commit '3f2c23e92da3ccbc89d7893b4af6039e66bdaaaf'
  f.mutable false
end

