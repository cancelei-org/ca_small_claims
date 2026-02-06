module Analytics
  class SentimentAnalyzer
    attr_reader :start_date, :end_date, :form_definition_id

    def initialize(start_date: 30.days.ago, end_date: Time.current, form_definition_id: nil)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
      @form_definition_id = form_definition_id
    end

    # Overall sentiment score (0-100, where 100 is most positive)
    def overall_sentiment_score
      feedbacks = base_scope
      return 0 if feedbacks.empty?

      scores = feedbacks.map { |f| calculate_sentiment_score(f) }
      (scores.sum.to_f / scores.count).round(1)
    end

    # Sentiment distribution (positive, neutral, negative)
    def sentiment_distribution
      feedbacks = base_scope
      return { positive: 0, neutral: 0, negative: 0 } if feedbacks.empty?

      distribution = { positive: 0, neutral: 0, negative: 0 }

      feedbacks.each do |feedback|
        sentiment = determine_sentiment(feedback)
        distribution[sentiment] += 1
      end

      distribution
    end

    # Sentiment trend over time (daily)
    def sentiment_trends(interval: 1.day)
      trends = {}
      current_date = start_date

      while current_date <= end_date
        next_date = current_date + interval
        feedbacks = base_scope.where(created_at: current_date...next_date)

        if feedbacks.any?
          scores = feedbacks.map { |f| calculate_sentiment_score(f) }
          avg_score = (scores.sum.to_f / scores.count).round(1)

          trends[current_date.to_date] = {
            date: current_date.to_date,
            score: avg_score,
            count: feedbacks.count,
            sentiment: score_to_sentiment(avg_score)
          }
        end

        current_date = next_date
      end

      trends.values.sort_by { |t| t[:date] }
    end

    # Common themes/keywords from feedback comments
    def common_themes(limit: 10)
      feedbacks = base_scope.where.not(comment: [ nil, "" ])
      return [] if feedbacks.empty?

      # Extract keywords from comments
      word_frequency = Hash.new(0)

      feedbacks.each do |feedback|
        next if feedback.comment.blank?

        # Extract meaningful words (excluding common words)
        words = extract_keywords(feedback.comment.downcase)
        words.each { |word| word_frequency[word] += 1 }
      end

      # Return top keywords with sentiment context
      word_frequency.sort_by { |_, count| -count }
        .first(limit)
        .map do |word, count|
          {
            theme: word,
            count: count,
            sentiment: theme_sentiment(word, feedbacks)
          }
        end
    end

    # Issue type breakdown with sentiment
    def issues_by_sentiment
      feedbacks = base_scope
      return {} if feedbacks.empty?

      issue_stats = Hash.new { |h, k| h[k] = { positive: 0, neutral: 0, negative: 0, total: 0 } }

      feedbacks.each do |feedback|
        sentiment = determine_sentiment(feedback)
        feedback.issue_types.each do |issue_type|
          issue_stats[issue_type][sentiment] += 1
          issue_stats[issue_type][:total] += 1
        end
      end

      issue_stats.map do |issue_type, stats|
        {
          issue_type: issue_type,
          issue_label: FormFeedback::ISSUE_TYPES[issue_type],
          positive: stats[:positive],
          neutral: stats[:neutral],
          negative: stats[:negative],
          total: stats[:total],
          negative_percentage: stats[:total] > 0 ? ((stats[:negative].to_f / stats[:total]) * 100).round(1) : 0
        }
      end.sort_by { |i| -i[:negative_percentage] }
    end

    # Detect sentiment drops (comparing periods)
    def sentiment_alerts
      alerts = []

      # Compare last 7 days vs previous 7 days
      recent_score = sentiment_score_for_period(7.days.ago, end_date)
      previous_score = sentiment_score_for_period(14.days.ago, 7.days.ago)

      if recent_score < previous_score - 10 # 10+ point drop
        alerts << {
          type: "sentiment_drop",
          severity: recent_score < previous_score - 20 ? "high" : "medium",
          message: "Sentiment dropped #{(previous_score - recent_score).round(1)} points in the last 7 days",
          recent_score: recent_score,
          previous_score: previous_score
        }
      end

      # Check for sudden increase in negative feedback
      recent_negative = base_scope.where(created_at: 7.days.ago..end_date, rating: 1..2).count
      total_recent = base_scope.where(created_at: 7.days.ago..end_date).count

      if total_recent > 5 && recent_negative.to_f / total_recent > 0.5
        alerts << {
          type: "high_negative_feedback",
          severity: "high",
          message: "#{((recent_negative.to_f / total_recent) * 100).round}% of recent feedback is negative",
          negative_count: recent_negative,
          total_count: total_recent
        }
      end

      alerts
    end

    # Rating distribution
    def rating_distribution
      feedbacks = base_scope
      return {} if feedbacks.empty?

      (1..5).map do |rating|
        count = feedbacks.where(rating: rating).count
        {
          rating: rating,
          label: rating_label(rating),
          count: count,
          percentage: ((count.to_f / feedbacks.count) * 100).round(1)
        }
      end
    end

    # Summary statistics
    def summary_stats
      feedbacks = base_scope
      return default_stats if feedbacks.empty?

      distribution = sentiment_distribution

      {
        total_feedbacks: feedbacks.count,
        avg_rating: feedbacks.average(:rating)&.round(1) || 0,
        sentiment_score: overall_sentiment_score,
        positive_count: distribution[:positive],
        neutral_count: distribution[:neutral],
        negative_count: distribution[:negative],
        positive_percentage: feedbacks.count > 0 ? ((distribution[:positive].to_f / feedbacks.count) * 100).round(1) : 0,
        has_alerts: sentiment_alerts.any?
      }
    end

    private

    def base_scope
      scope = FormFeedback.where(created_at: start_date..end_date)
      scope = scope.where(form_definition_id: form_definition_id) if form_definition_id.present?
      scope
    end

    # Calculate sentiment score from rating and comment (0-100)
    def calculate_sentiment_score(feedback)
      # Base score from rating (1-5 stars mapped to 0-100)
      rating_score = ((feedback.rating - 1) / 4.0) * 100

      # Adjust based on comment sentiment if present
      if feedback.comment.present?
        comment_adjustment = analyze_comment_sentiment(feedback.comment)
        rating_score += comment_adjustment
      end

      # Clamp to 0-100
      [ [ rating_score, 0 ].max, 100 ].min.round(1)
    end

    # Determine overall sentiment (positive, neutral, negative)
    def determine_sentiment(feedback)
      score = calculate_sentiment_score(feedback)
      score_to_sentiment(score)
    end

    def score_to_sentiment(score)
      if score >= 60
        :positive
      elsif score >= 40
        :neutral
      else
        :negative
      end
    end

    # Analyze comment text for sentiment keywords
    def analyze_comment_sentiment(comment)
      text = comment.downcase

      positive_boost = positive_keywords.count { |word| text.include?(word) } * 5
      negative_penalty = negative_keywords.count { |word| text.include?(word) } * 5

      positive_boost - negative_penalty
    end

    def positive_keywords
      %w[
        great excellent amazing awesome wonderful fantastic perfect helpful
        easy simple clear intuitive useful love thank happy satisfied
        efficient quick fast smooth seamless works well done good better
      ]
    end

    def negative_keywords
      %w[
        bad terrible awful horrible poor confusing difficult hard frustrating
        broken error fail failed wrong incorrect missing unclear complicated
        slow buggy glitch crash problem issue difficult hate disappointed
      ]
    end

    # Extract meaningful keywords from text
    def extract_keywords(text)
      # Remove punctuation and split into words
      words = text.gsub(/[^\w\s]/, " ").split

      # Filter out common words and short words
      stopwords = %w[the a an and or but in on at to for of with is are was were been be have has had do does did can could would should may might will this that these those i you he she it we they me him her us them my your his its our their]

      words.select { |word| word.length > 3 && !stopwords.include?(word) }
        .uniq
    end

    # Determine sentiment for a specific theme/keyword
    def theme_sentiment(theme, feedbacks)
      theme_feedbacks = feedbacks.select { |f| f.comment&.downcase&.include?(theme) }
      return :neutral if theme_feedbacks.empty?

      scores = theme_feedbacks.map { |f| calculate_sentiment_score(f) }
      avg_score = scores.sum.to_f / scores.count
      score_to_sentiment(avg_score)
    end

    def sentiment_score_for_period(start_date, end_date)
      feedbacks = FormFeedback.where(created_at: start_date..end_date)
      feedbacks = feedbacks.where(form_definition_id: form_definition_id) if form_definition_id.present?

      return 50 if feedbacks.empty? # Neutral if no data

      scores = feedbacks.map { |f| calculate_sentiment_score(f) }
      (scores.sum.to_f / scores.count).round(1)
    end

    def rating_label(rating)
      case rating
      when 1 then "Very Poor"
      when 2 then "Poor"
      when 3 then "Average"
      when 4 then "Good"
      when 5 then "Excellent"
      end
    end

    def default_stats
      {
        total_feedbacks: 0,
        avg_rating: 0,
        sentiment_score: 0,
        positive_count: 0,
        neutral_count: 0,
        negative_count: 0,
        positive_percentage: 0,
        has_alerts: false
      }
    end
  end
end
