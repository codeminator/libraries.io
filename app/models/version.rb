class Version < ApplicationRecord
  include Releaseable

  validates_presence_of :project_id, :number
  validates_uniqueness_of :number, scope: :project_id

  belongs_to :project
  counter_culture :project
  has_many :dependencies, dependent: :delete_all

  after_commit :send_notifications_async, on: :create
  after_commit :update_github_repo_async, on: :create
  after_commit :save_project

  scope :newest_first, -> { order('versions.published_at DESC') }

  def as_json(options = nil)
    super({ only: [:number, :published_at] }.merge(options || {}))
  end

  def save_project
    project.try(:forced_save)
    project.try(:update_github_repo_async)
  end

  def platform
    project.try(:platform)
  end

  def notify_subscribers
    subscriptions = project.subscriptions
    subscriptions = subscriptions.include_prereleases if prerelease?

    subscriptions.group_by(&:notification_user).each do |user, _user_subscriptions|
      next if user.nil?
      next if user.muted?(project)
      next if !user.emails_enabled?
      VersionsMailer.new_version(user, project, self).deliver_later
    end
  end

  def notify_firehose
    Firehose.new_version(project, project.platform, self)
  end

  def notify_web_hooks
    repos = project.subscriptions.map(&:repository).compact.uniq
    repos.each do |repo|
      requirements = repo.repository_dependencies.select{|rd| rd.project == project }.map(&:requirements)
      repo.web_hooks.each do |web_hook|
        web_hook.send_new_version(project, project.platform, self, requirements)
      end
    end
  end

  def send_notifications_async
    return if published_at && published_at < 1.week.ago
    VersionNotificationsWorker.perform_async(self.id)
  end

  def update_github_repo_async
    return unless project.repository
    GithubDownloadWorker.perform_async(project.github_repository_id)
  end

  def send_notifications
    notify_subscribers
    notify_firehose
    notify_web_hooks
  end

  def published_at
    @published_at ||= read_attribute(:published_at).presence || created_at
  end

  def <=>(other)
    if parsed_number.is_a?(String) || other.parsed_number.is_a?(String)
      other.published_at <=> published_at
    else
      other.parsed_number <=> parsed_number
    end
  end

  def prerelease?
    if semantic_version
      !!semantic_version.pre
    elsif platform.try(:downcase) == 'rubygems'
      !!(number =~ /[a-zA-Z]/)
    else
      false
    end
  end

  def any_outdated_dependencies?
    @any_outdated_dependencies ||= dependencies.kind('runtime').any?(&:outdated?)
  end

  def to_param
    project.to_param.merge(number: number)
  end

  def load_dependencies_tree(kind, date = nil)
    TreeResolver.new(self, kind, date).load_dependencies_tree
  end
end
