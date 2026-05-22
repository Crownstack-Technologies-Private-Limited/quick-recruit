class AddPerformanceIndexesForAiScoresListing < ActiveRecord::Migration[8.1]
  def change
    # Used in JOIN filter: WHERE candidates.bucket IN (...) on every listing load
    add_index :candidates, :bucket, name: "index_candidates_on_bucket"

    # Replace the generic (opening_id, score) index with a partial one covering
    # is_valid. The listing query is always: WHERE opening_id = X AND is_valid = true
    # ORDER BY score DESC — this index satisfies it without a post-filter pass.
    remove_index :ai_scores, name: "index_ai_scores_on_opening_and_score", if_exists: true
    add_index :ai_scores, [:opening_id, :score],
              order: { score: :desc },
              where: "is_valid = true",
              name: "index_ai_scores_on_opening_score_valid"
  end
end
