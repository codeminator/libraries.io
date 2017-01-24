class CreateRepositoryPermissions < ActiveRecord::Migration
  def change
    create_table :repository_permissions do |t|
      t.integer :user_id
      t.integer :repository_id
      t.boolean :admin
      t.boolean :push
      t.boolean :pull

      t.timestamps null: false
    end
  end
end
