class AddNoteAndBucketToAiScores < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_scores, :note, :text
    add_column :ai_scores, :candidate_bucket, :string
  end
end
