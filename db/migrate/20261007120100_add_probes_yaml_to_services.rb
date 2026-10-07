class AddProbesYamlToServices < ActiveRecord::Migration[7.2]
  def change
    add_column :services, :probes_yaml, :jsonb
  end
end
