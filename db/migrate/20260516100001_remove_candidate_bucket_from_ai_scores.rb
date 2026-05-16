class RemoveCandidateBucketFromAiScores < ActiveRecord::Migration[7.1]
  def change
    remove_column :ai_scores, :candidate_bucket, :string
  end
end
