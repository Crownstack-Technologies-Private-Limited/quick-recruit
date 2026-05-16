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

  def bucket_badge_classes(bucket)
    colors = {
      "recent"   => "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-300",
      "hot"      => "bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300",
      "pipeline" => "bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300",
      "leads"    => "bg-purple-100 text-purple-700 dark:bg-purple-900 dark:text-purple-300",
      "inbound"  => "bg-indigo-100 text-indigo-700 dark:bg-indigo-900 dark:text-indigo-300",
      "nurture"  => "bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300"
    }
    colors.fetch(bucket.to_s, "bg-gray-100 text-gray-500")
  end
end
