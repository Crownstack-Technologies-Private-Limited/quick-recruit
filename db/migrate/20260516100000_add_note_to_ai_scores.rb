class AddNoteToAiScores < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_scores, :note, :text
  end
end
