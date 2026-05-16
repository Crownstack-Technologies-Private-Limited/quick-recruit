class CreateAiScoringLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_scoring_logs do |t|
      t.references :opening, null: false, foreign_key: true, index: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }, index: true
      t.string :batch_id, null: false                # UUID, unique

      t.integer :total_candidates,    default: 0, null: false
      t.integer :successfully_scored, default: 0, null: false
      t.integer :failed_count,        default: 0, null: false

      t.string :provider, null: false
      t.string :model,    null: false

      t.bigint :total_input_tokens,  default: 0, null: false
      t.bigint :total_output_tokens, default: 0, null: false
      t.decimal :total_cost, precision: 12, scale: 6, default: 0, null: false

      t.string :status, default: 'pending', null: false  # pending|processing|completed|failed
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_details

      t.timestamps
    end

    add_index :ai_scoring_logs, :batch_id, unique: true
    add_index :ai_scoring_logs, [:opening_id, :created_at], name: 'index_logs_on_opening_and_date'
  end
end
