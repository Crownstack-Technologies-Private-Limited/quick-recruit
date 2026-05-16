class AddExperienceRangeToOpenings < ActiveRecord::Migration[8.0]
  def change
    add_column :openings, :min_experience, :integer
    add_column :openings, :max_experience, :integer
  end
end
