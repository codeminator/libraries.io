class Project < ActiveRecord::Base
  validates_presence_of :name, :platform

  # TODO validate homepage format

  def to_param
    "#{id}-#{name.parameterize}"
  end

  has_many :versions

  scope :platform, ->(platform) { where platform: platform }

  ## relations
  # versions => dependencies
  # repository
  # licenses
  # users
end
