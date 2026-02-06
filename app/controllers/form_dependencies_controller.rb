class FormDependenciesController < ApplicationController
  # Show flowchart and dependencies for a specific form
  def show
    @form_definition = FormDefinition.find_by!(code: params[:id])

    # Get dependency data from service
    @dependency_mapper = FormDependencies::DependencyMapper.instance
    @flowchart = @dependency_mapper.flowchart_for(@form_definition.code)
    @dependencies = @dependency_mapper.dependencies_for(@form_definition.code)

    # Get Form Kit recommendations
    @form_kit_builder = FormDependencies::FormKitBuilder.instance
    @recommended_kits = @form_kit_builder.recommended_kits_for(@form_definition.code)
    @containing_kit = @form_kit_builder.kit_containing(@form_definition.code)

    # Get all kits for reference
    @all_kits = @form_kit_builder.all_kits
  end

  # Show all form kits
  def kits
    @form_kit_builder = FormDependencies::FormKitBuilder.instance
    @all_kits = @form_kit_builder.all_kits

    # Filter by role if specified
    @all_kits = @form_kit_builder.kits_for_role(params[:role]) if params[:role].present?

    # Filter by stage if specified
    @all_kits = @form_kit_builder.kits_for_stage(params[:stage]) if params[:stage].present?

    # Track completion if user is signed in
    if user_signed_in?
      @kit_completions = @all_kits.map do |kit|
        completion = @form_kit_builder.kit_completion(kit[:key], current_user, nil)
        [ kit[:key], completion ]
      end.to_h
    elsif session_id.present?
      @kit_completions = @all_kits.map do |kit|
        completion = @form_kit_builder.kit_completion(kit[:key], nil, session_id)
        [ kit[:key], completion ]
      end.to_h
    else
      @kit_completions = {}
    end
  end

  # Show timeline/roadmap of all stages
  def timeline
    @dependency_mapper = FormDependencies::DependencyMapper.instance

    # Get all stages with forms grouped
    @stages_with_forms = @dependency_mapper.instance_variable_get(:@dependencies).values
      .group_by { |dep| dep[:stage] }
      .transform_values { |deps| deps.map { |d| d[:code] } }
      .sort_by { |stage, _| stage_order(stage) }

    # Enrich with stage metadata
    @stage_metadata = @dependency_mapper.instance_variable_get(:@stages)
  end

  private

  def session_id
    session.id&.to_s
  end

  def stage_order(stage)
    order_map = {
      "filing" => 1,
      "service" => 2,
      "hearing" => 3,
      "judgment" => 4,
      "enforcement" => 5,
      "appeal" => 6
    }
    order_map[stage.to_s] || 999
  end
end
