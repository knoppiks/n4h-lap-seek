class Workflow < ApplicationRecord
  include Seek::Rdf::RdfGeneration
  include Seek::UploadHandling::ExamineUrl
  include Seek::BioSchema::Support
  include WorkflowExtraction

  belongs_to :workflow_class, optional: true
  has_filter workflow_type: Seek::Filtering::Filter.new(value_field: 'workflow_classes.key',
                                               label_field: 'workflow_classes.title',
                                               joins: [:workflow_class])

  acts_as_asset

  acts_as_doi_parent(child_accessor: :versions)

  validates :projects, presence: true, projects: { self: true }, unless: Proc.new {Seek::Config.is_virtualliver }

  #don't add a dependent=>:destroy, as the content_blob needs to remain to detect future duplicates
  has_one :content_blob, -> (r) { where('content_blobs.asset_version =?', r.version) }, :as => :asset, :foreign_key => :asset_id

  has_and_belongs_to_many :sops

  has_many :workflow_statuses, -> (w) { where(version: w.version) }

  explicit_versioning(version_column: 'version', sync_ignore_columns: ['doi']) do
    after_commit :submit_to_life_monitor, on: :create
    acts_as_doi_mintable(proxy: :parent, general_type: 'Workflow')
    acts_as_versioned_resource
    acts_as_favouritable

    has_one :content_blob, -> (r) { where('content_blobs.asset_version =? AND content_blobs.asset_type =?', r.version, r.parent.class.name) },
            :primary_key => :workflow_id, :foreign_key => :asset_id

    has_many :workflow_statuses, -> (wv) { where(version: wv.version) }, primary_key: :workflow_id, foreign_key: :workflow_id

    serialize :metadata

    belongs_to :workflow_class, optional: true
    include WorkflowExtraction

    def maturity_level
      Workflow::MATURITY_LEVELS[super]
    end

    def maturity_level= level
      super(Workflow::MATURITY_LEVELS_INV[level&.to_sym])
    end

    def source_link_url
      parent&.source_link&.url
    end

    def submit_to_life_monitor
      if Seek::Config.life_monitor_enabled && extractor.has_tests? && workflow.can_download?(nil)
        LifeMonitorSubmissionJob.perform_later(self)
      end
    end
  end

  def avatar_key
    workflow_class&.extractor&.present? ? "#{workflow_class.key.downcase}_workflow" : 'workflow'
  end

  def self.user_creatable?
    Seek::Config.workflows_enabled
  end

  def contributor_credited?
    false
  end

  MATURITY_LEVELS = {
      0 => :work_in_progress,
      1 => :released
  }
  MATURITY_LEVELS_INV = MATURITY_LEVELS.invert

  def maturity_level
    Workflow::MATURITY_LEVELS[super]
  end

  def maturity_level= level
    super(Workflow::MATURITY_LEVELS_INV[level&.to_sym])
  end

  has_filter maturity: Seek::Filtering::Filter.new(
      value_field: 'maturity_level',
      label_mapping: ->(values) {
        values.map do |value|
          I18n.translate("maturity_level.#{MATURITY_LEVELS[value]}")
        end
      }
  )
end
