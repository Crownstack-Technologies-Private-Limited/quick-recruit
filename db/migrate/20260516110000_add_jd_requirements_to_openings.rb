class AddJdRequirementsToOpenings < ActiveRecord::Migration[7.1]
  def change
    add_column :openings, :must_have,            :jsonb,  default: []
    add_column :openings, :good_to_have,         :jsonb,  default: []
    add_column :openings, :jd_requirements_hash, :string
  end
end
