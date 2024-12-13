class UpdateAdminTypes < ActiveRecord::Migration[8.0]
  def up

    # Add the new `admin_type` column before making any updates
    add_column :admins, :admin_type, :string

    # Set default value for existing records
    Admin.where(admin_type: nil).update_all(admin_type: 'manager')

    # Remove old columns
    remove_column :admins, :is_manager, :boolean
    remove_column :admins, :is_super_admin, :boolean
    remove_column :admins, :is_director, :boolean
  end

  def down
    # Add back the old columns
    add_column :admins, :is_manager, :boolean
    add_column :admins, :is_super_admin, :boolean
    add_column :admins, :is_director, :boolean

    # Set default value for existing records
    Admin.where(admin_type: 'manager').update_all(admin_type: nil)

    # Remove the `admin_type` column
    remove_column :admins, :admin_type, :string
  end

end
