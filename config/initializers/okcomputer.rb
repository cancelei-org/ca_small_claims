# frozen_string_literal: true

# Skip OkComputer setup during db:prepare or when Rails isn't fully loaded
# This prevents issues in Docker burner containers
return unless defined?(Rails::Server) || Rails.env.test? || ENV["OKCOMPUTER_ENABLED"]

OkComputer.mount_at = "health"

OkComputer::Registry.register "database", OkComputer::ActiveRecordCheck.new
OkComputer::Registry.register "cache", OkComputer::CacheCheck.new

class QueueBacklogCheck < OkComputer::Check
  def check
    backlog = SolidQueue::Job.pending.count
    mark_message "pending jobs: #{backlog}"
    mark_failure if backlog > 1000
  end
end

class PdfTemplatesCheck < OkComputer::Check
  def check
    path = Rails.root.join("lib", "pdf_templates")
    present = File.directory?(path)
    mark_message "templates_dir_present=#{present}"
    mark_failure unless present
  end
end

OkComputer::Registry.register "queue", QueueBacklogCheck.new
OkComputer::Registry.register "pdf_templates", PdfTemplatesCheck.new
