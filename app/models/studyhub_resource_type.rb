class StudyhubResourceType < ApplicationRecord

  has_many :studyhub_resources, inverse_of: :studyhub_resource_type

  STUDY_TYPES = %w[study substudy].freeze

  def is_studytype?
    self.key == 'study' || self.key == 'substudy'
  end

end
