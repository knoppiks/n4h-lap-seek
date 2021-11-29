# frozen_string_literal: true

require 'rubygems'
require 'rake'


namespace :seek do
  # these are the tasks required for this version upgrade
  task upgrade_version_tasks: %i[
    environment
    db:seed:workflow_classes
    update_missing_publication_versions
  ]

  # these are the tasks that are executes for each upgrade as standard, and rarely change
  task standard_upgrade_tasks: %i[
    environment
    clear_filestore_tmp
    repopulate_auth_lookup_tables
  ]

  desc('upgrades SEEK from the last released version to the latest released version')
  task(upgrade: [:environment]) do
    puts "Starting upgrade ..."
    puts "... trimming old session data ..."
    Rake::Task['db:sessions:trim'].invoke
    puts "... migrating database ..."
    Rake::Task['db:migrate'].invoke
    Rake::Task['tmp:clear'].invoke

    solr = Seek::Config.solr_enabled
    Seek::Config.solr_enabled = false

    begin
      puts "... performing upgrade tasks ..."
      Rake::Task['seek:standard_upgrade_tasks'].invoke
      Rake::Task['seek:upgrade_version_tasks'].invoke

      Seek::Config.solr_enabled = solr
      puts "... queuing search reindexing jobs ..."
      Rake::Task['seek:reindex_all'].invoke if solr

      puts 'Upgrade completed successfully'
    ensure
      Seek::Config.solr_enabled = solr
    end
  end


  task(update_missing_publication_versions: :environment) do
    puts '... creating missing publications versions ...'
    create = 0
    disable_authorization_checks do
      Publication.find_each do |publication|
        # check if the publication has a version
        # then create one if missing
        if publication.latest_version.nil?
          publication.save_as_new_version 'Version for legacy entries'
          unless publication.latest_version.nil?
            create += 1
          end
        end
        # publication.save
      end
    end
    puts " ... finished creating missing publications versions for #{create.to_s} publications"
  end
end
