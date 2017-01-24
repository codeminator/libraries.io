require 'rails_helper'

describe RepositoryPermission, type: :model do
  it { should belong_to(:repository).with_foreign_key('github_repository_id') }
  it { should belong_to(:user) }

  it { should validate_uniqueness_of(:github_repository_id).scoped_to(:user_id) }
end
