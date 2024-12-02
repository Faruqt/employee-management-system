class AddDefaultToIsDeletedInAdmins < ActiveRecord::Migration[8.0]
  def change
    change_column_default :admins, :is_deleted, from: nil, to: false
    change_column_default :admins, :is_manager, from: nil, to: false
    change_column_default :admins, :is_director, from: nil, to: false
    change_column_default :admins, :is_super_admin, from: nil, to: false
  end
end
