module AiScoresHelper
  def ai_score_badge_classes(score)
    case score
    when 80..100 then "bg-green-100 text-green-800"
    when 60..79  then "bg-yellow-100 text-yellow-800"
    when 40..59  then "bg-orange-100 text-orange-800"
    else              "bg-red-100 text-red-800"
    end
  end

  def ai_score_fit_label(score)
    case score
    when 80..100 then "Strong fit"
    when 60..79  then "Decent fit"
    when 40..59  then "Partial fit"
    else              "Poor fit"
    end
  end
end
