# frozen_string_literal: true

module Forms
  class CategoryMapper
    # California Judicial Council form category definitions
    # Organized by topic with Small Claims prioritized first
    CATEGORIES = {
      # Priority: Small Claims (the main focus of this application)
      "SC" => {
        name: "Small Claims",
        description: "Small claims court forms for disputes up to $12,500",
        position: 1
      },

      # Fee Waivers (commonly needed across all case types)
      "FW" => {
        name: "Fee Waiver",
        description: "Court fee waiver request forms",
        position: 5
      },

      # Family Law
      "FL" => {
        name: "Family Law",
        description: "Divorce, custody, support, and other family matters",
        position: 10
      },
      "DV" => {
        name: "Domestic Violence",
        description: "Domestic violence restraining orders",
        position: 11
      },

      # Restraining Orders (Non-DV)
      "CH" => {
        name: "Civil Harassment",
        description: "Civil harassment restraining orders",
        position: 20
      },
      "EA" => {
        name: "Elder Abuse",
        description: "Elder or dependent adult abuse restraining orders",
        position: 21
      },
      "SV" => {
        name: "School Violence",
        description: "School violence prevention restraining orders",
        position: 22
      },
      "WV" => {
        name: "Workplace Violence",
        description: "Workplace violence restraining orders",
        position: 23
      },
      "GV" => {
        name: "Gun Violence",
        description: "Gun violence restraining orders",
        position: 24
      },

      # Juvenile
      "JV" => {
        name: "Juvenile",
        description: "Juvenile dependency and delinquency proceedings",
        position: 30
      },
      "ICWA" => {
        name: "Indian Child Welfare Act",
        description: "Forms for ICWA compliance in child welfare cases",
        position: 31
      },

      # Probate and Estate
      "GC" => {
        name: "Guardianship/Conservatorship",
        description: "Guardianship and conservatorship of persons and estates",
        position: 40
      },
      "DE" => {
        name: "Decedent Estate",
        description: "Probate and administration of decedent estates",
        position: 41
      },

      # Criminal
      "CR" => {
        name: "Criminal",
        description: "Criminal court forms and procedures",
        position: 50
      },

      # Civil Litigation
      "CIV" => {
        name: "Civil",
        description: "General civil litigation forms",
        position: 60
      },
      "MC" => {
        name: "Miscellaneous Civil",
        description: "Miscellaneous civil court forms",
        position: 61
      },
      "CM" => {
        name: "Case Management",
        description: "Civil case management conference forms",
        position: 62
      },
      "PLD" => {
        name: "Pleading",
        description: "General pleading forms",
        position: 63
      },
      "PLDC" => {
        name: "Pleading - Contract",
        description: "Contract dispute pleading forms",
        position: 64
      },
      "PLDPI" => {
        name: "Pleading - Personal Injury",
        description: "Personal injury pleading forms",
        position: 65
      },

      # Discovery
      "DISC" => {
        name: "Discovery",
        description: "Civil discovery request and response forms",
        position: 70
      },
      "INT" => {
        name: "Interrogatories",
        description: "Form interrogatories for civil cases",
        position: 71
      },
      "SUBP" => {
        name: "Subpoena",
        description: "Subpoena forms for witnesses and documents",
        position: 72
      },

      # Judgments and Collections
      "EJ" => {
        name: "Enforcement of Judgment",
        description: "Judgment enforcement and collection forms",
        position: 80
      },
      "EJT" => {
        name: "Enforcement of Judgment - Transition",
        description: "Transitional judgment enforcement forms",
        position: 81
      },
      "WG" => {
        name: "Wage Garnishment",
        description: "Wage garnishment and earnings withholding",
        position: 82
      },

      # Unlawful Detainer (Eviction)
      "UD" => {
        name: "Unlawful Detainer",
        description: "Eviction and unlawful detainer forms",
        position: 90
      },

      # Traffic
      "TR" => {
        name: "Traffic",
        description: "Traffic court forms",
        position: 100
      },

      # Name Change
      "NC" => {
        name: "Name Change",
        description: "Name and gender change petition forms",
        position: 110
      },

      # CARE Act
      "CARE" => {
        name: "CARE Act",
        description: "Community Assistance, Recovery, and Empowerment Act proceedings",
        position: 120
      },

      # Summons and Service
      "SUM" => {
        name: "Summons",
        description: "Summons and citation forms",
        position: 130
      },
      "POS" => {
        name: "Proof of Service",
        description: "Proof of service forms",
        position: 131
      },
      "SER" => {
        name: "Service",
        description: "Service of process forms",
        position: 132
      },

      # Appellate
      "RA" => {
        name: "Records on Appeal",
        description: "Appellate court record designation forms",
        position: 140
      },
      "RC" => {
        name: "Record Correction",
        description: "Court record correction forms",
        position: 141
      },
      "REC" => {
        name: "Reconsideration",
        description: "Motion for reconsideration forms",
        position: 142
      },

      # Mental Health
      "MIL" => {
        name: "Mental Illness",
        description: "Mental health proceedings forms",
        position: 150
      },

      # Habeas Corpus
      "HC" => {
        name: "Habeas Corpus",
        description: "Habeas corpus petition forms",
        position: 160
      },

      # Electronic Filing
      "EFS" => {
        name: "Electronic Filing",
        description: "Electronic filing system forms",
        position: 170
      },

      # Jury
      "JURY" => {
        name: "Jury",
        description: "Jury-related forms",
        position: 180
      },

      # Landlord/Tenant (other than UD)
      "LA" => {
        name: "Landlord Actions",
        description: "Landlord action forms",
        position: 190
      },

      # Emancipation
      "EM" => {
        name: "Emancipation",
        description: "Minor emancipation petition forms",
        position: 200
      },

      # Civil Dispute Resolution
      "CD" => {
        name: "Civil Dispute",
        description: "Civil dispute resolution forms",
        position: 210
      },

      # Tribal
      "TH" => {
        name: "Tribal",
        description: "Tribal court coordination forms",
        position: 220
      },

      # Safe Haven
      "SH" => {
        name: "Safe Haven",
        description: "Safe haven and safe surrender forms",
        position: 230
      },

      # Judgments
      "JUD" => {
        name: "Judgment",
        description: "Judgment forms",
        position: 240
      },

      # Emergency Protective Orders
      "EPO" => {
        name: "Emergency Protective Order",
        description: "Emergency protective order forms",
        position: 250
      },

      # Vexatious Litigant
      "VL" => {
        name: "Vexatious Litigant",
        description: "Vexatious litigant designation forms",
        position: 260
      },

      # CLETS
      "CLETS" => {
        name: "CLETS",
        description: "California Law Enforcement Telecommunications System forms",
        position: 270
      },

      # Court Reporter
      "RT" => {
        name: "Reporter Transcript",
        description: "Court reporter transcript forms",
        position: 280
      },

      # Guardian Ad Litem
      "GDC" => {
        name: "Guardian Ad Litem",
        description: "Guardian ad litem court forms",
        position: 290
      },

      # Miscellaneous
      "DAL" => {
        name: "Disability Accommodation",
        description: "Disability accommodation request forms",
        position: 300
      },
      "MD" => {
        name: "Miscellaneous Documents",
        description: "Miscellaneous court documents",
        position: 310
      },
      "CP" => {
        name: "Court Procedures",
        description: "General court procedure forms",
        position: 320
      },
      "TRINST" => {
        name: "Trial Instructions",
        description: "Jury trial instruction forms",
        position: 330
      }
    }.freeze

    class << self
      def create_all!
        CATEGORIES.each do |prefix, attrs|
          create_category(prefix, attrs)
        end
        Category.count
      end

      def create_category(prefix, attrs)
        Category.find_or_create_by!(slug: prefix.downcase) do |cat|
          cat.name = attrs[:name]
          cat.description = attrs[:description]
          cat.position = attrs[:position]
          cat.active = true
        end
      rescue ActiveRecord::RecordNotUnique
        # Handle race condition - another process created it
        Category.find_by!(slug: prefix.downcase)
      end

      def category_for_form(form_number)
        prefix = extract_prefix(form_number)
        return nil unless prefix

        Category.find_by(slug: prefix.downcase)
      end

      def category_for_prefix(prefix)
        return nil unless prefix

        Category.find_by(slug: prefix.downcase)
      end

      def known_prefix?(prefix)
        CATEGORIES.key?(prefix.to_s.upcase)
      end

      def all_prefixes
        CATEGORIES.keys
      end

      def category_name(prefix)
        CATEGORIES.dig(prefix.to_s.upcase, :name)
      end

      private

      def extract_prefix(form_number)
        return nil if form_number.blank?

        normalized = form_number.to_s.upcase
        match = normalized.match(/^([A-Z]+)/)
        match&.[](1)
      end
    end
  end
end
