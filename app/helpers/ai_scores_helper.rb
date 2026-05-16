module AiScoresHelper
  def ai_score_badge_classes(score)
    case score
    when 90..100 then "bg-green-600 text-white shadow-sm ring-1 ring-green-700/10"
    when 80..89  then "bg-green-50 text-green-700 ring-1 ring-green-600/20 dark:bg-green-950 dark:text-green-400 dark:ring-green-500/30"
    when 60..79  then "bg-yellow-50 text-yellow-700 ring-1 ring-yellow-600/20 dark:bg-yellow-950 dark:text-yellow-400 dark:ring-yellow-500/30"
    when 40..59  then "bg-orange-50 text-orange-700 ring-1 ring-orange-600/20 dark:bg-orange-950 dark:text-orange-400 dark:ring-orange-500/30"
    else              "bg-red-50 text-red-700 ring-1 ring-red-600/20 dark:bg-red-950 dark:text-red-400 dark:ring-red-500/30"
    end
  end

  def ai_score_fit_label(score)
    case score
    when 90..100 then "Excellent fit"
    when 80..89  then "Strong fit"
    when 60..79  then "Decent fit"
    when 40..59  then "Partial fit"
    else              "Poor fit"
    end
  end

  def display_current_title(candidate)
    raw = candidate.current_title.to_s.strip
    return "-" if raw.blank? || raw.match?(/\A(na|n\/a|none|null|-)\z/i)
    raw
  end
end
