# This file seeds the database with initial form definitions and workflows

puts "Seeding database..."

# =============================================================================
# STEP 1: Load Categories
# =============================================================================
puts "\n--- Loading Categories ---"

categories_file = Rails.root.join("config", "seeds", "categories.yml")
if File.exist?(categories_file)
  categories_data = YAML.load_file(categories_file)

  categories_data["categories"].each do |parent_data|
    parent = Category.find_or_initialize_by(slug: parent_data["slug"])
    parent.assign_attributes(
      name: parent_data["name"],
      description: parent_data["description"],
      icon: parent_data["icon"],
      position: parent_data["position"] || 0,
      active: parent_data.fetch("active", true)
    )
    parent.save!
    puts "  Created/Updated category: #{parent.name}"

    # Create child categories
    (parent_data["children"] || []).each do |child_data|
      child = Category.find_or_initialize_by(slug: child_data["slug"])
      child.assign_attributes(
        name: child_data["name"],
        description: child_data["description"],
        icon: child_data["icon"],
        position: child_data["position"] || 0,
        parent: parent,
        active: child_data.fetch("active", true)
      )
      child.save!
      puts "    - #{child.name}"
    end
  end
end

# Helper to find category by legacy string (maps old category strings to new slugs)
CATEGORY_SLUG_MAP = {
  "plaintiff" => "plaintiff",
  "defendant" => "defendant",
  "service" => "service",
  "pre_trial" => "pre-trial",
  "judgment" => "judgment",
  "post_judgment" => "enforcement",
  "enforcement" => "enforcement",
  "appeal" => "appeal",
  "fee_waiver" => "fee-waiver",
  "collections" => "collections",
  "informational" => "informational",
  "filing" => "plaintiff",
  "special" => "plaintiff",
  "info" => "informational"
}.freeze

def find_category_by_legacy(legacy_category)
  return nil if legacy_category.blank?

  slug = CATEGORY_SLUG_MAP[legacy_category.to_s] || legacy_category.to_s.tr("_", "-")
  Category.find_by(slug: slug)
end

# =============================================================================
# STEP 2: Load Form Schemas from YAML files
# =============================================================================
puts "\n--- Loading Form Schemas ---"

schema_dir = Rails.root.join("config", "form_schemas")

if Dir.exist?(schema_dir)
  # Support both flat and nested directory structures
  Dir.glob(schema_dir.join("**", "*.yml")).each do |file|
    # Skip shared field definitions
    next if file.include?("_shared/")

    schema = YAML.load_file(file)
    form_data = schema["form"]

    next unless form_data

    form = FormDefinition.find_or_initialize_by(code: form_data["code"])
    category = find_category_by_legacy(form_data["category"])

    form.assign_attributes(
      title: form_data["title"],
      description: form_data["description"],
      category: category,
      pdf_filename: form_data["pdf_filename"],
      metadata: { instructions: form_data["instructions"] }.compact,
      fillable: true,
      active: true
    )
    form.save!

    puts "  Created/Updated form: #{form.code} - #{form.title}"

    # Create field definitions
    if schema["sections"]
      position = 0
      schema["sections"].each do |section_name, section_data|
        next unless section_data["fields"]

        section_data["fields"].each do |field_data|
          position += 1
          field = form.field_definitions.find_or_initialize_by(name: field_data["name"])
          field.assign_attributes(
            pdf_field_name: field_data["pdf_field_name"] || field_data["name"],
            field_type: field_data["type"],
            label: field_data["label"],
            placeholder: field_data["placeholder"],
            help_text: field_data["help_text"],
            required: field_data["required"] || false,
            options: field_data["options"],
            conditions: { show_when: field_data.dig("conditions", "show_when") }.compact,
            section: section_name.to_s,
            position: position,
            shared_field_key: field_data["shared_key"],
            width: field_data["width"] || "full"
          )
          field.save!
        end
      end
    end
  end
end

# =============================================================================
# STEP 3: Load Workflows from YAML files
# =============================================================================
puts "\n--- Loading Workflows ---"

workflow_dir = Rails.root.join("config", "workflows")

if Dir.exist?(workflow_dir)
  Dir.glob(workflow_dir.join("*.yml")).each do |file|
    schema = YAML.load_file(file)
    workflow_data = schema["workflow"]

    next unless workflow_data

    workflow = Workflow.find_or_initialize_by(slug: workflow_data["slug"])
    category = find_category_by_legacy(workflow_data["category"])

    workflow.assign_attributes(
      name: workflow_data["name"],
      description: workflow_data["description"],
      category: category,
      active: true
    )
    workflow.save!

    puts "  Created/Updated workflow: #{workflow.name}"

    # Create workflow steps
    if schema["steps"]
      schema["steps"].each do |step_data|
        form = FormDefinition.find_by(code: step_data["form_code"])
        next unless form

        step = workflow.workflow_steps.find_or_initialize_by(position: step_data["position"])
        step.assign_attributes(
          form_definition: form,
          instructions: step_data["instructions"],
          required: step_data["required"] != false,
          conditions: step_data["conditions"],
          data_mappings: step_data["data_mappings"]
        )
        step.save!
      end
    end
  end
end

# =============================================================================
# STEP 4: Non-fillable forms (PDFs without fillable form fields)
# =============================================================================
puts "\n--- Loading Non-Fillable Forms ---"

non_fillable_forms = [
  { code: "SC-101", title: "Plaintiff's Claim and ORDER to Go to Small Claims Court (Spanish)", category: "plaintiff", pdf_filename: "sc101.pdf", description: "Spanish version - non-fillable" },
  { code: "SC-103", title: "Application for Waiver of Court Fees and Costs", category: "fee_waiver", pdf_filename: "sc103.pdf", description: "Fee waiver application - non-fillable" },
  { code: "SC-104", title: "Proof of Service (Small Claims) - Personal", category: "service", pdf_filename: "sc104.pdf", description: "Proof of personal service - non-fillable" },
  { code: "SC-104A", title: "Proof of Service (Small Claims) - Certified Mail", category: "service", pdf_filename: "sc104a.pdf", description: "Proof of certified mail service - non-fillable" },
  { code: "SC-104B", title: "Proof of Substituted Service (Small Claims)", category: "service", pdf_filename: "sc104b.pdf", description: "Proof of substituted service - non-fillable" },
  { code: "SC-107", title: "Information for the Small Claims Plaintiff", category: "informational", pdf_filename: "sc107.pdf", description: "Informational guide for plaintiffs" },
  { code: "SC-113A", title: "Information Sheet for Waiver of Court Fees and Costs", category: "informational", pdf_filename: "sc113a.pdf", description: "Information about fee waivers" },
  { code: "SC-130", title: "Judgment (Small Claims)", category: "judgment", pdf_filename: "sc130.pdf", description: "Court judgment form - completed by court" },
  { code: "SC-133", title: "Judgment Debtor's Statement of Assets", category: "judgment", pdf_filename: "sc133.pdf", description: "Asset statement - non-fillable" },
  { code: "SC-134", title: "Information for the Judgment Creditor", category: "informational", pdf_filename: "sc134.pdf", description: "Informational guide for collecting judgments" },
  { code: "SC-135", title: "Information for the Judgment Debtor", category: "informational", pdf_filename: "sc135.pdf", description: "Informational guide for debtors" },
  { code: "SC-136", title: "Information About Payment Order After Small Claims Court", category: "informational", pdf_filename: "sc136.pdf", description: "Information about payment orders" },
  { code: "SC-140", title: "Notice of Appeal", category: "appeal", pdf_filename: "sc140.pdf", description: "Appeal notice - non-fillable" },
  { code: "SC-145", title: "Request for Postponement of Small Claims Trial", category: "pre_trial", pdf_filename: "sc145.pdf", description: "Postponement request - non-fillable" },
  { code: "SC-200", title: "Plaintiff's Claim and ORDER to Go to Small Claims Court (Vehicle)", category: "plaintiff", pdf_filename: "sc200.pdf", description: "Vehicle claim form - non-fillable" },
  { code: "SC-220", title: "Request to Make Payments (Small Claims)", category: "judgment", pdf_filename: "sc220.pdf", description: "Payment request - non-fillable" },
  { code: "SC-224", title: "Request to Terminate or Modify Payment Order", category: "judgment", pdf_filename: "sc224.pdf", description: "Modify payment order - non-fillable" },
  { code: "SC-500", title: "Information Sheet on Waiver of Hearing for Collection Cases", category: "informational", pdf_filename: "sc500.pdf", description: "Collection cases information" },
  { code: "SC-501", title: "Request to Waive Court Hearing (Collections)", category: "collections", pdf_filename: "sc501.pdf", description: "Waive hearing request - non-fillable" },
  { code: "SC-502", title: "Response to Request to Waive Court Hearing (Collections)", category: "collections", pdf_filename: "sc502.pdf", description: "Response form - non-fillable" },
  { code: "SC-505", title: "Declaration of Plaintiff (Collections)", category: "collections", pdf_filename: "sc505.pdf", description: "Collections declaration - non-fillable" }
]

non_fillable_forms.each do |form_data|
  form = FormDefinition.find_or_initialize_by(code: form_data[:code])
  category = find_category_by_legacy(form_data[:category])

  form.assign_attributes(
    title: form_data[:title],
    description: form_data[:description],
    category: category,
    pdf_filename: form_data[:pdf_filename],
    fillable: false,
    active: true
  )
  form.save!
  puts "  Created/Updated non-fillable form: #{form.code} - #{form.title}"
end

# =============================================================================
# STEP 5: Test Users (Development/Test only)
# =============================================================================
if Rails.env.development? || Rails.env.test?
  puts "\n--- Creating Test Users ---"

  test_users = [
    {
      email: "aline.entrepreneur@flukebase.me",
      password: "password123",
      full_name: "Aline Rodriguez",
      address: "1234 Entrepreneur Way, Suite 100",
      city: "Los Angeles",
      state: "CA",
      zip_code: "90001",
      phone: "(213) 555-0123",
      date_of_birth: Date.new(1985, 6, 15),
      admin: false
    },
    {
      email: "admin@example.com",
      password: "admin123",
      full_name: "Admin User",
      address: "100 Court Street",
      city: "Sacramento",
      state: "CA",
      zip_code: "95814",
      phone: "(916) 555-0100",
      admin: true
    }
  ]

  test_users.each do |user_data|
    user = User.find_or_initialize_by(email: user_data[:email])
    user.assign_attributes(
      password: user_data[:password],
      password_confirmation: user_data[:password],
      full_name: user_data[:full_name],
      address: user_data[:address],
      city: user_data[:city],
      state: user_data[:state],
      zip_code: user_data[:zip_code],
      phone: user_data[:phone],
      date_of_birth: user_data[:date_of_birth],
      admin: user_data[:admin] || false
    )
    user.save!
    puts "  Created/Updated user: #{user.email} (#{user.admin? ? 'admin' : 'user'})"
  end
end

# =============================================================================
# Summary
# =============================================================================
puts "\n=== Seeding Complete ==="
puts "  Categories: #{Category.count} (#{Category.roots.count} parents, #{Category.where.not(parent_id: nil).count} children)"
puts "  Forms: #{FormDefinition.count} (#{FormDefinition.where(fillable: true).count} fillable, #{FormDefinition.where(fillable: false).count} non-fillable)"
puts "  Workflows: #{Workflow.count}"
puts "  Users: #{User.count}" if Rails.env.development? || Rails.env.test?
