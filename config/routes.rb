# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users

  # Home
  root "home#index"
  get "about", to: "home#about"
  get "help", to: "home#help"
  get "accessibility", to: "home#accessibility"
  get "glossary", to: "home#glossary"
  get "home/forms_picker", to: "home#forms_picker", as: :forms_picker_home

  # Form Finder wizard
  resource :form_finder, only: [ :show ], controller: "form_finder" do
    post :update
    post :back
    post :restart
  end

  # Admin namespace
  namespace :admin do
    root "dashboard#index"
    resources :alerts, only: [ :index ]
    resources :users, only: [ :index, :show ] do
      member do
        get :activity
      end
    end

    # Impersonation
    resource :impersonation, only: [ :destroy ] do
      collection do
        get :index, to: "impersonations#index"
      end
    end
    post "users/:user_id/impersonate", to: "impersonations#create", as: :impersonate_user
    resources :feedbacks, only: [ :index, :show, :update ] do
      member do
        # Status transitions
        patch :start_progress
        patch :acknowledge  # Legacy alias for start_progress
        patch :resolve
        patch :close
        patch :reopen
        # Priority management
        patch :escalate
        patch :de_escalate
        patch :set_priority
      end
      collection do
        patch :bulk_start_progress
        patch :bulk_acknowledge  # Legacy alias
        patch :bulk_resolve
        patch :bulk_close
        patch :bulk_set_priority
        delete :bulk_delete
      end
    end
    resources :analytics, only: [ :index ] do
      collection do
        get :export
        get :funnel
        get :time_metrics
        get :drop_off
        get :geographic
        get :sentiment
      end
    end
    resources :submissions, only: [ :index, :show ] do
      member do
        patch :update_notes
      end
    end
    resources :session_submissions, only: [ :index, :show, :destroy ] do
      member do
        patch :recover
      end
      collection do
        delete :cleanup_expired
        patch :bulk_recover
      end
    end
    resources :product_feedbacks, only: [ :index, :show, :update ] do
      member do
        patch :update_status
        patch :update_admin_notes
      end
      collection do
        get :export
      end
    end
  end

  # Form Feedbacks (public submission)
  resources :form_feedbacks, only: [ :create ]

  # Product Feedbacks (general platform feedback, requires login)
  resources :product_feedbacks, only: [ :index, :new, :create, :show ] do
    member do
      post :vote
      delete :unvote
    end
  end

  # Profile
  resource :profile, only: [ :show, :update ] do
    post :tutorial_completed
  end

  # Forms (individual access)
  resources :forms, only: [ :index, :show, :update ], param: :id do
    member do
      get :preview
      get :download
      post :toggle_wizard
      post :apply_template
      delete :clear_template
      post :send_email
    end
  end

  # Form Dependencies and Visualization
  resources :form_dependencies, only: [ :show ], param: :id do
    collection do
      get :kits
      get :timeline
    end
  end

  # Template API endpoints
  get "templates", to: "templates#index", as: :templates
  get "templates/:id", to: "templates#show", as: :template

  # Court Finder (Courthouse locations with map)
  resources :courthouses, only: [ :index, :show ] do
    collection do
      get :markers
    end
  end

  # Workflows (guided wizard)
  resources :workflows, only: [ :index, :show ], param: :id do
    member do
      patch :step
      post :advance
      post :back
      get :complete
    end
  end

  # Submissions (user's saved forms)
  resources :submissions, only: [ :index, :show, :destroy ] do
    member do
      get :pdf
      get :download_pdf
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  mount OkComputer::Engine, at: "/health"

  # Test-only routes (development/test only)
  if Rails.env.development? || Rails.env.test?
    scope :test_only do
      get "create_submission", to: "test_only#create_submission"
      get "create_session_submission", to: "test_only#create_session_submission"
      post "reset", to: "test_only#reset"
    end
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :forms, only: [ :index, :show ]
    end

    get :docs, to: "docs#show"
  end

  resource :metrics, only: :show
end
