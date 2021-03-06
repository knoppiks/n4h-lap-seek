class Node < ApplicationRecord

  include Seek::Rdf::RdfGeneration

  acts_as_asset

  acts_as_doi_parent(child_accessor: :versions)

  validates :projects, presence: true, projects: { self: true }, unless: Proc.new {Seek::Config.is_virtualliver }

  #don't add a dependent=>:destroy, as the content_blob needs to remain to detect future duplicates
  has_one :content_blob, -> (r) { where('content_blobs.asset_version =?', r.version) }, :as => :asset, :foreign_key => :asset_id
  explicit_versioning(version_column: 'version', sync_ignore_columns: ['doi']) do
    acts_as_doi_mintable(proxy: :parent, general_type: 'Software')
    acts_as_versioned_resource
    acts_as_favouritable

    has_one :content_blob, -> (r) { where('content_blobs.asset_version =? AND content_blobs.asset_type =?', r.version, r.parent.class.name) },
            :primary_key => :node_id, :foreign_key => :asset_id
  end

  def use_mime_type_for_avatar?
    true
  end

  def is_github_cwl?
    return (!content_blob.url.nil?) && (content_blob.url.include? 'github.com') && (content_blob.url.end_with? 'cwl')
  end

  def self.feature_enabled?
    Workflow.feature_enabled?
  end
end
