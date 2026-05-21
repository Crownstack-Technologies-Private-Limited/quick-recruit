class AddFailureBreakdownToAiScoringLogs < ActiveRecord::Migration[8.0]
  def change
    # failed_count stays as the grand total; these split it by cause so the UI
    # can tell unreadable-resume failures apart from AI-provider failures.
    add_column :ai_scoring_logs, :extraction_failed_count, :integer, default: 0, null: false
    add_column :ai_scoring_logs, :provider_failed_count, :integer, default: 0, null: false
  end
end
