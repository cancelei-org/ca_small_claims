# frozen_string_literal: true

# Burner Instance Management Tasks
# Manages Docker-based isolated test instances for schema testing
#
# Usage:
#   bin/rails burner:up[ca1]       # Start a specific burner instance
#   bin/rails burner:down[ca1]     # Stop a specific burner instance
#   bin/rails burner:status        # Show status of all burner instances
#   bin/rails burner:logs[ca1]     # Tail logs for a burner instance
#   bin/rails burner:shell[ca1]    # Open shell in burner instance
#   bin/rails burner:migrate[ca1]  # Run migrations on burner instance
#   bin/rails burner:schema[ca1]   # Dump schema from burner instance

namespace :burner do
  COMPOSE_FILE = "docker-compose.burner.yml"
  VALID_INSTANCES = %w[ca1 ca2 ca3].freeze

  desc "Start a burner instance (ca1, ca2, or ca3)"
  task :up, [ :instance ] => :environment do |_t, args|
    instance = validate_instance(args[:instance])
    puts "Starting burner instance: #{instance}..."

    run_compose("up", "-d", "db_#{instance}", instance)

    puts "Waiting for instance to be ready..."
    wait_for_instance(instance)

    puts "Burner instance #{instance} is ready!"
    puts "  App: http://localhost:#{port_for(instance)}"
    puts "  DB:  localhost:#{db_port_for(instance)}"
  end

  desc "Stop a burner instance"
  task :down, [ :instance ] => :environment do |_t, args|
    instance = validate_instance(args[:instance])
    puts "Stopping burner instance: #{instance}..."

    run_compose("stop", "db_#{instance}", instance)
    puts "Burner instance #{instance} stopped."
  end

  desc "Stop all burner instances"
  task down_all: :environment do
    puts "Stopping all burner instances..."
    run_compose("down")
    puts "All burner instances stopped."
  end

  desc "Show status of all burner instances"
  task status: :environment do
    puts "Burner Instance Status:"
    puts "-" * 60

    VALID_INSTANCES.each do |instance|
      app_status = container_status("ca_burner_#{instance}")
      db_status = container_status("ca_burner_db_#{instance}")

      app_indicator = status_indicator(app_status)
      db_indicator = status_indicator(db_status)

      puts "#{instance}:"
      puts "  App: #{app_indicator} #{app_status} (http://localhost:#{port_for(instance)})"
      puts "  DB:  #{db_indicator} #{db_status} (localhost:#{db_port_for(instance)})"
      puts
    end
  end

  desc "Tail logs for a burner instance"
  task :logs, [ :instance ] => :environment do |_t, args|
    instance = validate_instance(args[:instance])
    puts "Tailing logs for #{instance} (Ctrl+C to stop)..."

    exec("docker-compose", "-f", COMPOSE_FILE, "logs", "-f", instance)
  end

  desc "Open Rails console in burner instance"
  task :console, [ :instance ] => :environment do |_t, args|
    instance = validate_instance(args[:instance])
    exec("docker-compose", "-f", COMPOSE_FILE, "exec", instance, "bin/rails", "console")
  end

  desc "Open shell in burner instance"
  task :shell, [ :instance ] => :environment do |_t, args|
    instance = validate_instance(args[:instance])
    exec("docker-compose", "-f", COMPOSE_FILE, "exec", instance, "bash")
  end

  desc "Run migrations on burner instance"
  task :migrate, [ :instance ] => :environment do |_t, args|
    instance = validate_instance(args[:instance])
    puts "Running migrations on #{instance}..."

    run_compose("exec", instance, "bin/rails", "db:migrate")
    puts "Migrations complete."
  end

  desc "Dump schema from burner instance"
  task :schema, [ :instance ] => :environment do |_t, args|
    instance = validate_instance(args[:instance])
    output_file = Rails.root.join("tmp", "burner_schemas", "#{instance}_schema.rb")

    FileUtils.mkdir_p(output_file.dirname)

    puts "Dumping schema from #{instance}..."
    schema_content = `docker-compose -f #{COMPOSE_FILE} exec -T #{instance} bin/rails runner "puts File.read('db/schema.rb')"`

    File.write(output_file, schema_content)
    puts "Schema saved to: #{output_file}"
  end

  desc "Reset database on burner instance"
  task :reset, [ :instance ] => :environment do |_t, args|
    instance = validate_instance(args[:instance])
    puts "Resetting database on #{instance}..."

    run_compose("exec", instance, "bin/rails", "db:drop", "db:create", "db:migrate", "db:seed")
    puts "Database reset complete."
  end

  desc "Run tests on burner instance"
  task :test, [ :instance ] => :environment do |_t, args|
    instance = validate_instance(args[:instance])
    puts "Running tests on #{instance}..."

    run_compose("exec", "-e", "RAILS_ENV=test", instance, "bin/rails", "spec")
  end

  desc "Compare schemas between two burner instances"
  task :diff, [ :instance1, :instance2 ] => :environment do |_t, args|
    instance1 = validate_instance(args[:instance1])
    instance2 = validate_instance(args[:instance2] || "ca2")

    puts "Comparing schemas: #{instance1} vs #{instance2}"

    # Dump both schemas
    Rake::Task["burner:schema"].invoke(instance1)
    Rake::Task["burner:schema"].reenable
    Rake::Task["burner:schema"].invoke(instance2)

    schema1 = Rails.root.join("tmp", "burner_schemas", "#{instance1}_schema.rb")
    schema2 = Rails.root.join("tmp", "burner_schemas", "#{instance2}_schema.rb")

    # Run diff
    puts "\nSchema differences:"
    puts "-" * 60
    system("diff", "-u", schema1.to_s, schema2.to_s) || puts("Schemas are identical!")
  end

  desc "Build burner Docker images"
  task build: :environment do
    puts "Building burner Docker images..."
    run_compose("build")
    puts "Build complete."
  end

  desc "Clean up burner volumes and images"
  task clean: :environment do
    puts "Cleaning up burner resources..."
    run_compose("down", "-v", "--rmi", "local")
    puts "Cleanup complete."
  end

  # Helper methods
  def validate_instance(instance)
    instance ||= "ca1"
    abort "Invalid instance: #{instance}. Valid options: #{VALID_INSTANCES.join(', ')}" unless VALID_INSTANCES.include?(instance)
    instance
  end

  def run_compose(*args)
    system("docker-compose", "-f", COMPOSE_FILE, *args) || abort("Command failed")
  end

  def container_status(name)
    status = `docker inspect --format='{{.State.Status}}' #{name} 2>/dev/null`.strip
    status.empty? ? "not created" : status
  end

  def status_indicator(status)
    case status
    when "running" then "\e[32m●\e[0m"  # Green
    when "exited" then "\e[33m●\e[0m"   # Yellow
    else "\e[31m●\e[0m"                  # Red
    end
  end

  def port_for(instance)
    { "ca1" => 3011, "ca2" => 3012, "ca3" => 3013 }[instance]
  end

  def db_port_for(instance)
    { "ca1" => 5441, "ca2" => 5442, "ca3" => 5443 }[instance]
  end

  def wait_for_instance(instance, timeout: 120)
    start_time = Time.now
    loop do
      if container_status("ca_burner_#{instance}") == "running"
        # Check if Rails is responding
        result = `docker-compose -f #{COMPOSE_FILE} exec -T #{instance} curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/up 2>/dev/null`.strip
        return if result == "200"
      end

      abort "Timeout waiting for #{instance} to be ready" if Time.now - start_time > timeout

      sleep 2
      print "."
    end
  end
end
