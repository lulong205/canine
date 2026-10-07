class AddNeedSslToDomains < ActiveRecord::Migration[7.2]
  def change
    add_column :domains, :need_ssl, :boolean, default: true, null: false
  end
end
