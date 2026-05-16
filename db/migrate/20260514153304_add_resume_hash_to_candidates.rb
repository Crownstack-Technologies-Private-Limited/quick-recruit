class AddResumeHashToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :resume_hash, :string
    add_index  :candidates, :resume_hash
  end
end
