module Analytics
  class GeographicAnalyzer
    attr_reader :start_date, :end_date

    def initialize(start_date: 30.days.ago, end_date: Time.current)
      @start_date = start_date.to_date.beginning_of_day
      @end_date = end_date.to_date.end_of_day
    end

    # Get usage statistics by county
    def usage_by_county
      county_stats = Hash.new { |h, k| h[k] = { submissions: 0, users: Set.new, completions: 0 } }

      # Get submissions in date range with user info
      Submission.includes(:user)
        .where(created_at: start_date..end_date)
        .find_each do |submission|
          county = determine_county(submission.user)
          next if county.nil?

          county_stats[county][:submissions] += 1
          county_stats[county][:users] << (submission.user_id || submission.session_id)
          county_stats[county][:completions] += 1 if submission.completed_at.present?
        end

      # Convert to array of hashes with completion rates
      county_stats.map do |county, stats|
        {
          county: county,
          submissions: stats[:submissions],
          unique_users: stats[:users].size,
          completions: stats[:completions],
          completion_rate: stats[:submissions] > 0 ? ((stats[:completions].to_f / stats[:submissions]) * 100).round(1) : 0
        }
      end.sort_by { |c| -c[:submissions] }
    end

    # Get top counties by usage
    def top_counties(limit: 10)
      usage_by_county.first(limit)
    end

    # Get underserved counties (low usage)
    def underserved_counties(threshold: 5)
      all_counties = usage_by_county
      # rubocop:disable Rails/Pluck - operating on array of hashes, not AR relation
      active_county_names = all_counties.select { |c| c[:submissions] >= threshold }.map { |c| c[:county] }
      # rubocop:enable Rails/Pluck

      # Return counties with usage below threshold
      all_counties.select { |c| c[:submissions] < threshold && c[:submissions] > 0 }
    end

    # Get counties with zero usage
    def zero_usage_counties
      # rubocop:disable Rails/Pluck - operating on array of hashes, not AR relation
      active_counties = usage_by_county.map { |c| c[:county] }
      # rubocop:enable Rails/Pluck
      all_california_counties - active_counties
    end

    # Get total coverage (percentage of counties with activity)
    def coverage_percentage
      active_count = usage_by_county.count
      total_count = all_california_counties.count
      return 0 if total_count.zero?

      ((active_count.to_f / total_count) * 100).round(1)
    end

    # Get summary stats
    def summary_stats
      counties = usage_by_county

      {
        total_counties: all_california_counties.count,
        active_counties: counties.count,
        coverage_percentage: coverage_percentage,
        total_submissions: counties.sum { |c| c[:submissions] },
        total_users: counties.sum { |c| c[:unique_users] },
        avg_submissions_per_county: counties.any? ? (counties.sum { |c| c[:submissions] }.to_f / counties.count).round(1) : 0
      }
    end

    # Regional breakdown (Northern, Central, Southern California)
    def regional_breakdown
      counties = usage_by_county
      regions = {
        "Northern California" => { submissions: 0, users: 0, counties: [] },
        "Central California" => { submissions: 0, users: 0, counties: [] },
        "Southern California" => { submissions: 0, users: 0, counties: [] },
        "Unknown" => { submissions: 0, users: 0, counties: [] }
      }

      counties.each do |county_data|
        region = get_region(county_data[:county])
        regions[region][:submissions] += county_data[:submissions]
        regions[region][:users] += county_data[:unique_users]
        regions[region][:counties] << county_data[:county]
      end

      regions.map do |region, data|
        {
          region: region,
          submissions: data[:submissions],
          users: data[:users],
          county_count: data[:counties].uniq.count,
          avg_per_county: data[:counties].uniq.count > 0 ? (data[:submissions].to_f / data[:counties].uniq.count).round(1) : 0
        }
      end.reject { |r| r[:submissions].zero? }
    end

    private

    # Determine county from user data (city, zip)
    def determine_county(user)
      return nil unless user.present?

      # Try to map city to county
      city = user.city&.strip&.downcase
      return city_to_county_map[city] if city.present? && city_to_county_map[city]

      # Try to map zip code to county (first 3 digits)
      zip = user.zip_code&.strip
      return zip_to_county_map[zip[0..2]] if zip.present? && zip.length >= 3 && zip_to_county_map[zip[0..2]]

      nil
    end

    # Map of California cities to counties (major cities)
    def city_to_county_map
      @city_to_county_map ||= {
        # Major Cities - Los Angeles County
        "los angeles" => "Los Angeles",
        "long beach" => "Los Angeles",
        "glendale" => "Los Angeles",
        "santa clarita" => "Los Angeles",
        "pasadena" => "Los Angeles",
        "torrance" => "Los Angeles",
        "pomona" => "Los Angeles",
        "lancaster" => "Los Angeles",
        "el monte" => "Los Angeles",
        "downey" => "Los Angeles",
        "inglewood" => "Los Angeles",
        "west covina" => "Los Angeles",

        # San Diego County
        "san diego" => "San Diego",
        "chula vista" => "San Diego",
        "oceanside" => "San Diego",
        "escondido" => "San Diego",
        "carlsbad" => "San Diego",
        "el cajon" => "San Diego",

        # Orange County
        "anaheim" => "Orange",
        "santa ana" => "Orange",
        "irvine" => "Orange",
        "huntington beach" => "Orange",
        "garden grove" => "Orange",
        "orange" => "Orange",
        "fullerton" => "Orange",
        "costa mesa" => "Orange",
        "mission viejo" => "Orange",
        "westminster" => "Orange",

        # Riverside County
        "riverside" => "Riverside",
        "corona" => "Riverside",
        "murrieta" => "Riverside",
        "temecula" => "Riverside",
        "menifee" => "Riverside",
        "moreno valley" => "Riverside",

        # San Bernardino County
        "san bernardino" => "San Bernardino",
        "fontana" => "San Bernardino",
        "rancho cucamonga" => "San Bernardino",
        "ontario" => "San Bernardino",
        "victorville" => "San Bernardino",
        "hesperia" => "San Bernardino",

        # Alameda County
        "oakland" => "Alameda",
        "fremont" => "Alameda",
        "hayward" => "Alameda",
        "berkeley" => "Alameda",
        "san leandro" => "Alameda",
        "alameda" => "Alameda",

        # Sacramento County
        "sacramento" => "Sacramento",
        "elk grove" => "Sacramento",
        "citrus heights" => "Sacramento",

        # Contra Costa County
        "concord" => "Contra Costa",
        "antioch" => "Contra Costa",
        "richmond" => "Contra Costa",
        "walnut creek" => "Contra Costa",

        # Fresno County
        "fresno" => "Fresno",
        "clovis" => "Fresno",

        # Ventura County
        "oxnard" => "Ventura",
        "thousand oaks" => "Ventura",
        "simi valley" => "Ventura",
        "ventura" => "Ventura",

        # San Mateo County
        "daly city" => "San Mateo",
        "san mateo" => "San Mateo",
        "redwood city" => "San Mateo",

        # Kern County
        "bakersfield" => "Kern",

        # San Francisco (City/County)
        "san francisco" => "San Francisco",

        # Santa Clara County
        "san jose" => "Santa Clara",
        "sunnyvale" => "Santa Clara",
        "santa clara" => "Santa Clara",
        "mountain view" => "Santa Clara",
        "palo alto" => "Santa Clara",
        "milpitas" => "Santa Clara",
        "cupertino" => "Santa Clara",

        # Sonoma County
        "santa rosa" => "Sonoma",

        # San Joaquin County
        "stockton" => "San Joaquin",

        # Stanislaus County
        "modesto" => "Stanislaus",

        # Monterey County
        "salinas" => "Monterey",

        # Santa Barbara County
        "santa barbara" => "Santa Barbara",
        "santa maria" => "Santa Barbara",

        # Solano County
        "vallejo" => "Solano",
        "fairfield" => "Solano"
      }
    end

    # Map of ZIP code prefixes to counties (simplified)
    def zip_to_county_map
      @zip_to_county_map ||= {
        "900" => "Los Angeles",
        "901" => "Los Angeles",
        "902" => "Los Angeles",
        "903" => "Los Angeles",
        "904" => "Los Angeles",
        "905" => "Los Angeles",
        "906" => "Los Angeles",
        "907" => "Los Angeles",
        "908" => "Los Angeles",
        "910" => "Los Angeles",
        "911" => "Los Angeles",
        "912" => "Orange",
        "913" => "Los Angeles",
        "914" => "Orange",
        "915" => "San Bernardino",
        "916" => "Sacramento",
        "917" => "Fresno",
        "918" => "Ventura",
        "919" => "San Diego",
        "920" => "San Diego",
        "921" => "San Diego",
        "922" => "San Bernardino",
        "923" => "Riverside",
        "924" => "San Bernardino",
        "925" => "Riverside",
        "926" => "Orange",
        "927" => "Orange",
        "928" => "Orange",
        "930" => "Ventura",
        "931" => "Santa Barbara",
        "932" => "Kern",
        "933" => "Riverside",
        "934" => "San Bernardino",
        "935" => "San Bernardino",
        "936" => "Inyo",
        "939" => "San Luis Obispo",
        "940" => "San Francisco",
        "941" => "San Francisco",
        "942" => "Sacramento",
        "943" => "San Mateo",
        "944" => "San Mateo",
        "945" => "Alameda",
        "946" => "Alameda",
        "947" => "Alameda",
        "948" => "Contra Costa",
        "949" => "Contra Costa",
        "950" => "San Joaquin",
        "951" => "Santa Clara",
        "952" => "Stanislaus",
        "953" => "Fresno",
        "954" => "Santa Clara",
        "955" => "Santa Clara",
        "956" => "Monterey",
        "959" => "Sonoma",
        "960" => "Yolo"
      }
    end

    # All California counties (58 total)
    def all_california_counties
      [
        "Alameda", "Alpine", "Amador", "Butte", "Calaveras", "Colusa", "Contra Costa",
        "Del Norte", "El Dorado", "Fresno", "Glenn", "Humboldt", "Imperial", "Inyo",
        "Kern", "Kings", "Lake", "Lassen", "Los Angeles", "Madera", "Marin", "Mariposa",
        "Mendocino", "Merced", "Modoc", "Mono", "Monterey", "Napa", "Nevada", "Orange",
        "Placer", "Plumas", "Riverside", "Sacramento", "San Benito", "San Bernardino",
        "San Diego", "San Francisco", "San Joaquin", "San Luis Obispo", "San Mateo",
        "Santa Barbara", "Santa Clara", "Santa Cruz", "Shasta", "Sierra", "Siskiyou",
        "Solano", "Sonoma", "Stanislaus", "Sutter", "Tehama", "Trinity", "Tulare",
        "Tuolumne", "Ventura", "Yolo", "Yuba"
      ]
    end

    # Determine region for a county
    def get_region(county)
      northern = [
        "Alameda", "Alpine", "Amador", "Butte", "Calaveras", "Colusa", "Contra Costa",
        "Del Norte", "El Dorado", "Glenn", "Humboldt", "Lake", "Lassen", "Marin",
        "Mendocino", "Modoc", "Napa", "Nevada", "Placer", "Plumas", "Sacramento",
        "San Francisco", "San Joaquin", "San Mateo", "Santa Clara", "Santa Cruz",
        "Shasta", "Sierra", "Siskiyou", "Solano", "Sonoma", "Sutter", "Tehama",
        "Trinity", "Yolo", "Yuba"
      ]

      central = [
        "Fresno", "Inyo", "Kern", "Kings", "Madera", "Mariposa", "Merced", "Mono",
        "Monterey", "San Benito", "San Luis Obispo", "Santa Barbara", "Stanislaus",
        "Tulare", "Tuolumne"
      ]

      southern = [
        "Imperial", "Los Angeles", "Orange", "Riverside", "San Bernardino", "San Diego",
        "Ventura"
      ]

      return "Northern California" if northern.include?(county)
      return "Central California" if central.include?(county)
      return "Southern California" if southern.include?(county)
      "Unknown"
    end
  end
end
