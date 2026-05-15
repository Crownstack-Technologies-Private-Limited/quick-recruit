class CreateAiScores < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_scores do |t|
      t.references :candidate, null: false, foreign_key: true, index: true
      t.references :opening,   null: false, foreign_key: true, index: true

      t.integer :score, null: false              # 0..100
      t.text    :reasoning, null: false
      t.jsonb   :matched_skills, default: {}, null: false
      t.jsonb   :gaps,           default: {}, null: false
      t.text    :strengths
      t.text    :concerns

      t.string  :provider, null: false           # 'chatgpt' for v1
      t.string  :model,    null: false           # 'gpt-4o-mini' for v1

      t.integer :input_tokens,  default: 0, null: false
      t.integer :output_tokens, default: 0, null: false
      t.decimal :cost, precision: 10, scale: 6, default: 0, null: false

      # Versioning + invalidation
      t.string   :resume_version_hash             # Active Storage blob.checksum at scoring time
      t.string   :jd_version_hash                 # SHA256 of normalized JD text at scoring time
      t.boolean  :is_valid, default: true, null: false
      t.string   :invalidation_reason             # 'resume_updated' | 'jd_updated' | 'expired' | 'superseded'

      t.datetime :processed_at
      t.datetime :expires_at
      t.datetime :invalidated_at

      t.timestamps
    end

    add_index :ai_scores, [:opening_id, :score],   name: 'index_ai_scores_on_opening_and_score'
    add_index :ai_scores, [:candidate_id, :opening_id, :is_valid],
      unique: true, where: 'is_valid = true',
      name: 'index_ai_scores_one_valid_per_pair'
    add_index :ai_scores, :provider
    add_index :ai_scores, :processed_at
    add_index :ai_scores, [:candidate_id, :is_valid]
    add_index :ai_scores, [:resume_version_hash, :jd_version_hash], name: 'index_ai_scores_dedup'
  end
end
