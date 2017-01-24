class CreateGithubContributions < ActiveRecord::Migration
  def change
    create_table :github_contributions do |t|
      t.integer :repository_id
      t.integer :github_user_id
      t.integer :count

      t.timestamps null: false
    end
  end
end
