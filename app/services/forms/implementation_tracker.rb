# frozen_string_literal: true

module Forms
  class ImplementationTracker
    TRACKING_FILE = Rails.root.join("db", "form_implementation_status.json")
    MANUAL_REVIEW_FILE = Rails.root.join("db", "manual_review_queue.json")

    # PDF prefixes by category
    CATEGORY_PREFIXES = {
      "Small Claims" => %w[SC],
      "Domestic Violence" => %w[DV],
      "Civil Harassment" => %w[CH],
      "Elder Abuse" => %w[EA],
      "Gun Violence" => %w[GV],
      "Workplace Violence" => %w[WV],
      "School Violence" => %w[SV],
      "Family Law" => %w[FL],
      "Guardianship" => %w[GC],
      "Juvenile" => %w[JV],
      "Criminal" => %w[CR],
      "Probate/Estate" => %w[DE],
      "Traffic" => %w[TR],
      "Name Change" => %w[NC],
      "Enforcement" => %w[EJ EJT],
      "Civil General" => %w[CIV MC PLD PLDC PLDPI],
      "Discovery" => %w[DISC INT SUBP],
      "Fee Waiver" => %w[FW],
      "Service" => %w[POS SUM SER],
      "Other" => %w[APP CARE HC MIL WG]
    }.freeze

    def initialize
      @pdf_dir = Rails.root.join("lib", "pdf_templates")
      @schema_dir = Rails.root.join("config", "form_schemas")
      @html_dir = Rails.root.join("app", "views", "pdf_templates")
    end

    def status_for(form_code)
      normalized_code = normalize_code(form_code)
      pdf_filename = "#{normalized_code.downcase.delete('-')}.pdf"

      {
        code: form_code,
        pdf_exists: pdf_exists?(pdf_filename),
        schema_exists: schema_exists?(normalized_code),
        schema_valid: schema_valid?(normalized_code),
        in_database: in_database?(normalized_code),
        field_count: field_count(normalized_code),
        shared_keys_count: shared_keys_count(normalized_code),
        html_template_exists: html_template_exists?(normalized_code),
        fillable: fillable?(normalized_code)
      }
    end

    def category_report(prefix)
      prefixes = [ prefix ].flatten.map(&:upcase)
      forms = find_pdfs_by_prefixes(prefixes)

      total = forms.size
      with_schema = forms.count { |f| schema_exists?(extract_code(f)) }
      in_db = forms.count { |f| in_database?(extract_code(f)) }
      with_html = forms.count { |f| html_template_exists?(extract_code(f)) }

      {
        prefix: prefix,
        total: total,
        with_schema: with_schema,
        in_database: in_db,
        with_html_template: with_html,
        schema_percent: total.positive? ? ((with_schema.to_f / total) * 100).round(1) : 0,
        db_percent: total.positive? ? ((in_db.to_f / total) * 100).round(1) : 0,
        forms: forms.map { |f| status_for(extract_code(f)) }
      }
    end

    def overall_progress
      all_pdfs = Dir.glob(@pdf_dir.join("*.pdf"))
      total = all_pdfs.size

      with_schema = all_pdfs.count { |f| schema_exists?(extract_code(f)) }
      in_db = FormDefinition.count
      fillable_count = FormDefinition.where(fillable: true).count
      non_fillable_count = FormDefinition.where(fillable: false).count

      {
        total_pdfs: total,
        with_schema: with_schema,
        in_database: in_db,
        fillable: fillable_count,
        non_fillable: non_fillable_count,
        schema_percent: total.positive? ? ((with_schema.to_f / total) * 100).round(1) : 0,
        db_percent: total.positive? ? ((in_db.to_f / total) * 100).round(1) : 0
      }
    end

    def by_category
      CATEGORY_PREFIXES.map do |category_name, prefixes|
        report = category_report(prefixes)
        {
          category: category_name,
          prefixes: prefixes,
          total: report[:total],
          with_schema: report[:with_schema],
          in_database: report[:in_database],
          schema_percent: report[:schema_percent]
        }
      end.sort_by { |r| -r[:total] }
    end

    def missing_schemas
      all_pdfs = Dir.glob(@pdf_dir.join("*.pdf"))

      all_pdfs.reject { |f| schema_exists?(extract_code(f)) }
              .map { |f| extract_code(f) }
              .sort
    end

    def missing_html_templates
      FormDefinition.where(fillable: false).reject do |form|
        html_template_exists?(form.code)
      end.map(&:code).sort
    end

    def add_to_manual_review(form_code, reason)
      queue = load_manual_review_queue
      queue[form_code] = {
        reason: reason,
        added_at: Time.current.iso8601,
        status: "pending"
      }
      save_manual_review_queue(queue)
    end

    def manual_review_queue
      load_manual_review_queue
    end

    def resolve_manual_review(form_code)
      queue = load_manual_review_queue
      return unless queue[form_code]
        queue[form_code]["status"] = "resolved"
        queue[form_code]["resolved_at"] = Time.current.iso8601
        save_manual_review_queue(queue)
    end

    def save_progress
      progress = {
        generated_at: Time.current.iso8601,
        overall: overall_progress,
        by_category: by_category
      }

      File.write(TRACKING_FILE, JSON.pretty_generate(progress))
      Rails.logger.info "Saved progress to #{TRACKING_FILE}"
    end

    def load_progress
      return nil unless File.exist?(TRACKING_FILE)

      JSON.parse(File.read(TRACKING_FILE))
    rescue JSON::ParserError
      nil
    end

    def print_summary
      progress = overall_progress
      categories = by_category

      puts "\n" + "=" * 60
      puts "FORM IMPLEMENTATION PROGRESS"
      puts "=" * 60
      puts
      puts "Overall:"
      puts "  Total PDFs:      #{progress[:total_pdfs]}"
      puts "  With Schema:     #{progress[:with_schema]} (#{progress[:schema_percent]}%)"
      puts "  In Database:     #{progress[:in_database]} (#{progress[:db_percent]}%)"
      puts "    Fillable:      #{progress[:fillable]}"
      puts "    Non-fillable:  #{progress[:non_fillable]}"
      puts
      puts "By Category:"
      puts "-" * 60

      categories.each do |cat|
        bar = progress_bar(cat[:schema_percent])
        puts format(
          "  %-20s %4d forms | %s %5.1f%%",
          cat[:category],
          cat[:total],
          bar,
          cat[:schema_percent]
        )
      end

      puts
      puts "Manual Review Queue: #{manual_review_queue.count { |_k, v| v['status'] == 'pending' }} pending"
      puts "=" * 60
    end

    private

    def normalize_code(code)
      Utilities::FormCodeNormalizer.normalize(code)
    end

    def extract_code(pdf_path)
      Utilities::FormCodeNormalizer.from_filename(pdf_path)
    end

    def find_pdfs_by_prefixes(prefixes)
      Dir.glob(@pdf_dir.join("*.pdf")).select do |pdf|
        basename = File.basename(pdf, ".pdf").downcase
        prefixes.any? { |p| basename.start_with?(p.downcase) }
      end
    end

    def pdf_exists?(filename)
      File.exist?(@pdf_dir.join(filename))
    end

    def schema_exists?(code)
      normalized = code.to_s.downcase.delete("-")
      Dir.glob(@schema_dir.join("**", "#{normalized}.yml")).any?
    end

    def schema_valid?(code)
      return false unless schema_exists?(code)

      # Use existing validator if available
      true # Placeholder - integrate with Forms::SchemaValidator
    end

    def in_database?(code)
      FormDefinition.exists?(code: code)
    end

    def field_count(code)
      form = FormDefinition.find_by(code: code)
      form&.field_definitions&.count || 0
    end

    def shared_keys_count(code)
      form = FormDefinition.find_by(code: code)
      return 0 unless form

      form.field_definitions.where.not(shared_field_key: [ nil, "" ]).count
    end

    def html_template_exists?(code)
      normalized = code.to_s.downcase.delete("-")
      Dir.glob(@html_dir.join("**", "#{normalized}.html.erb")).any?
    end

    def fillable?(code)
      form = FormDefinition.find_by(code: code)
      form&.fillable?
    end

    def load_manual_review_queue
      return {} unless File.exist?(MANUAL_REVIEW_FILE)

      JSON.parse(File.read(MANUAL_REVIEW_FILE))
    rescue JSON::ParserError
      {}
    end

    def save_manual_review_queue(queue)
      File.write(MANUAL_REVIEW_FILE, JSON.pretty_generate(queue))
    end

    def progress_bar(percent, width = 20)
      filled = (percent / 100.0 * width).round
      empty = width - filled
      "[#{'#' * filled}#{'-' * empty}]"
    end
  end
end
